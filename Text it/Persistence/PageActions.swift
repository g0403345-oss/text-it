//
//  PageActions.swift
//  Text it
//
//  Zentrale Mutationen für Pages & Blocks.
//

import Foundation
import SwiftData

@MainActor
struct PageActions {
    let context: ModelContext

    // MARK: - Page

    @discardableResult
    func createPage(in workspace: Workspace?, parent: Page? = nil, title: String = "Unbenannt") -> Page {
        let siblings = parent?.sortedChildren ?? (workspace?.pages?.filter { $0.parent == nil && !$0.isTrashed } ?? [])
        let nextIndex = (siblings.map(\.sortIndex).max() ?? -1) + 1
        let page = Page(title: title, parent: parent, workspace: workspace)
        page.sortIndex = nextIndex
        context.insert(page)

        let firstBlock = Block(type: .text, text: "", sortIndex: 0, page: page)
        context.insert(firstBlock)
        try? context.save()
        NearbySync.shared.sendPageUpsert(page)
        NearbySync.shared.sendBlockUpsert(firstBlock)
        return page
    }

    @discardableResult
    func createFolder(in workspace: Workspace?, parent: Page? = nil, title: String = "Neuer Ordner") -> Page {
        let siblings = parent?.sortedChildren
            ?? (workspace?.pages?.filter { $0.parent == nil && !$0.isTrashed } ?? [])
        let nextIndex = (siblings.map(\.sortIndex).max() ?? -1) + 1
        let folder = Page(title: title, icon: "folder.fill", parent: parent, workspace: workspace, isFolder: true)
        folder.sortIndex = nextIndex
        context.insert(folder)
        try? context.save()
        return folder
    }

    func movePage(_ page: Page, toParent newParent: Page?, inWorkspace newWorkspace: Workspace?) {
        let targetWS = newWorkspace ?? newParent?.workspace ?? page.workspace
        page.parent = newParent
        page.workspace = targetWS
        let siblings = newParent?.sortedChildren
            ?? (targetWS?.pages?.filter { $0.parent == nil && !$0.isTrashed } ?? [])
        page.sortIndex = (siblings.map(\.sortIndex).max() ?? -1) + 1
        page.updatedAt = Date()
        try? context.save()
        NearbySync.shared.sendPageUpsert(page)
    }

    func rename(_ page: Page, to title: String) {
        page.title = title
        page.updatedAt = Date()
        try? context.save()
        NearbySync.shared.sendPageUpsert(page)
    }

    func toggleFavorite(_ page: Page) {
        page.isFavorite.toggle()
        try? context.save()
        NearbySync.shared.sendPageUpsert(page)
    }

    func moveToTrash(_ page: Page) {
        page.isTrashed = true
        page.updatedAt = Date()
        for child in page.children ?? [] {
            moveToTrash(child)
        }
        try? context.save()
        NearbySync.shared.sendPageUpsert(page)
    }

    func restore(_ page: Page) {
        page.isTrashed = false
        for child in page.children ?? [] { restore(child) }
        try? context.save()
        NearbySync.shared.sendPageUpsert(page)
    }

    func deletePermanently(_ page: Page) {
        let pid = page.id
        markPermanentlyDeleted(page)
        context.delete(page)
        try? context.save()
        NearbySync.shared.sendPageDelete(pid)
    }

    private func markPermanentlyDeleted(_ page: Page) {
        page.isPermanentlyDeleted = true
        page.isTrashed = true
        for child in page.children ?? [] { markPermanentlyDeleted(child) }
    }

    func duplicate(_ page: Page) {
        let copy = Page(title: page.title + " (Kopie)", icon: page.icon, parent: page.parent, workspace: page.workspace)
        copy.sortIndex = page.sortIndex + 1
        context.insert(copy)
        for b in page.sortedBlocks {
            let nb = Block(type: b.type, text: b.text, sortIndex: b.sortIndex, page: copy)
            nb.checked = b.checked
            nb.level = b.level
            nb.language = b.language
            nb.emoji = b.emoji
            nb.colorHex = b.colorHex
            nb.imageData = b.imageData
            nb.drawingData = b.drawingData
            nb.url = b.url
            nb.parentBlockID = b.parentBlockID
            nb.linkedPageID = b.linkedPageID
            context.insert(nb)
        }
        try? context.save()
    }

    // MARK: - Block

    /// Fügt einen Block ein. `parentBlockID` verknüpft ihn als Kind eines Toggle-Blocks.
    @discardableResult
    func addBlock(to page: Page,
                  type: BlockType = .text,
                  after: Block? = nil,
                  parentBlockID: UUID? = nil,
                  text: String = "") -> Block {
        let pid = parentBlockID
        // Geschwister auf derselben Ebene
        let siblings = (page.blocks ?? [])
            .filter { $0.parentBlockID == pid }
            .sorted { $0.sortIndex < $1.sortIndex }

        let insertAfterIndex = after?.sortIndex ?? (siblings.last?.sortIndex ?? -1)

        // Nachfolgende Geschwister verschieben
        for b in siblings where b.sortIndex > insertAfterIndex {
            b.sortIndex += 1
        }

        let new = Block(type: type, text: text, sortIndex: insertAfterIndex + 1, page: page)
        new.parentBlockID = parentBlockID
        if type == .heading { new.level = 1 }
        context.insert(new)
        page.updatedAt = Date()
        try? context.save()
        NearbySync.shared.sendBlockUpsert(new)
        return new
    }

    func deleteBlock(_ block: Block) {
        guard let page = block.page else { return }
        let pid = block.parentBlockID
        let blockID = block.id

        let children = (page.blocks ?? []).filter { $0.parentBlockID == blockID }
        for child in children {
            NearbySync.shared.sendBlockDelete(child.id)
            context.delete(child)
        }

        NearbySync.shared.sendBlockDelete(blockID)
        context.delete(block)

        let siblings = (page.blocks ?? [])
            .filter { $0.parentBlockID == pid && $0.id != blockID }
            .sorted { $0.sortIndex < $1.sortIndex }
        for (i, b) in siblings.enumerated() { b.sortIndex = i }

        page.updatedAt = Date()
        try? context.save()
    }

    func changeBlockType(_ block: Block, to newType: BlockType) {
        block.type = newType
        block.updatedAt = Date()
        block.page?.updatedAt = Date()
        try? context.save()
        NearbySync.shared.sendBlockUpsert(block)
    }

    func moveBlock(_ block: Block, up: Bool) {
        guard let page = block.page else { return }
        let pid = block.parentBlockID
        let blocks = (page.blocks ?? [])
            .filter { $0.parentBlockID == pid }
            .sorted { $0.sortIndex < $1.sortIndex }
        guard let idx = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        let other = up ? idx - 1 : idx + 1
        guard blocks.indices.contains(other) else { return }
        let tmp = blocks[other].sortIndex
        blocks[other].sortIndex = block.sortIndex
        block.sortIndex = tmp
        try? context.save()
        NearbySync.shared.sendBlockUpsert(block)
        NearbySync.shared.sendBlockUpsert(blocks[other])
    }

    // MARK: - Markdown-Export

    func exportMarkdown(page: Page) -> String {
        var lines = ["# \(page.title)", ""]
        for block in page.sortedTopLevelBlocks {
            lines.append(blockMarkdown(block, page: page))
        }
        return lines.joined(separator: "\n")
    }

    private func blockMarkdown(_ block: Block, page: Page, indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var line: String
        switch block.type {
        case .text:        line = block.text
        case .heading:     line = String(repeating: "#", count: min(block.level, 6)) + " " + block.text
        case .todo:        line = "- [\(block.checked ? "x" : " ")] \(block.text)"
        case .bullet:      line = "- \(block.text)"
        case .numbered:    line = "1. \(block.text)"
        case .toggle:
            line = "**\(block.text)**"
            let children = page.sortedChildBlocks(parentID: block.id)
            if !children.isEmpty {
                let childLines = children.map { blockMarkdown($0, page: page, indent: indent + 1) }
                line += "\n" + childLines.joined(separator: "\n")
            }
        case .quote:       line = "> \(block.text)"
        case .callout:     line = "> \(block.emoji) \(block.text)"
        case .code:        line = "```\(block.language)\n\(block.text)\n```"
        case .divider:     line = "---"
        case .pagelink:    line = "[Seitenlink →](page://\(block.linkedPageID?.uuidString ?? ""))"
        default:           line = block.text
        }
        return prefix + line
    }
}
