//
//  NearbySync.swift
//  Text it
//
//  Echtzeit-Synchronisation zwischen iPad und Mac über Bluetooth/WLAN
//  (MultipeerConnectivity). Kein Internet nötig — beide Geräte müssen
//  nur in Reichweite sein.
//

import Foundation
import MultipeerConnectivity
import SwiftData
import CoreData

// MARK: - Interne Codable-Snapshots

private struct WorkspaceSnap: Codable {
    var id: UUID; var name: String; var icon: String; var createdAt: Date
}

private struct PageSnap: Codable {
    var id: UUID
    var title: String; var icon: String; var coverColorHex: String?
    var createdAt: Date; var updatedAt: Date; var sortIndex: Int
    var isFavorite: Bool; var isTrashed: Bool; var isExpanded: Bool
    var parentID: UUID?; var workspaceID: UUID?
    var tagsData: Data?; var drawingData: Data?

    init(_ p: Page) {
        id = p.id; title = p.title; icon = p.icon; coverColorHex = p.coverColorHex
        createdAt = p.createdAt; updatedAt = p.updatedAt; sortIndex = p.sortIndex
        isFavorite = p.isFavorite; isTrashed = p.isTrashed; isExpanded = p.isExpanded
        parentID = p.parent?.id; workspaceID = p.workspace?.id
        tagsData = p.tagsData; drawingData = p.drawingData
    }
}

private struct BlockSnap: Codable {
    var id: UUID; var rawType: String; var text: String
    var sortIndex: Int; var createdAt: Date; var updatedAt: Date
    var checked: Bool; var expanded: Bool; var level: Int; var language: String
    var colorHex: String?; var emoji: String
    var imageData: Data?; var drawingData: Data?
    var url: String?; var jsonPayload: Data?
    var pageID: UUID?; var parentBlockID: UUID?; var linkedPageID: UUID?
    var imageWidth: Double; var pdfBlockHeight: Double

    init(_ b: Block) {
        id = b.id; rawType = b.rawType; text = b.text
        sortIndex = b.sortIndex; createdAt = b.createdAt; updatedAt = b.updatedAt
        checked = b.checked; expanded = b.expanded; level = b.level; language = b.language
        colorHex = b.colorHex; emoji = b.emoji
        imageData = b.imageData; drawingData = b.drawingData
        url = b.url; jsonPayload = b.jsonPayload
        pageID = b.page?.id; parentBlockID = b.parentBlockID; linkedPageID = b.linkedPageID
        imageWidth = b.imageWidth; pdfBlockHeight = b.pdfBlockHeight
    }
}

private struct FlashcardSnap: Codable {
    var id: UUID; var front: String; var back: String; var deck: String
    var easeFactor: Double; var interval: Int; var repetitions: Int
    var dueDate: Date; var createdAt: Date; var sourceBlockID: UUID?

    init(_ f: Flashcard) {
        id = f.id; front = f.front; back = f.back; deck = f.deck
        easeFactor = f.easeFactor; interval = f.interval; repetitions = f.repetitions
        dueDate = f.dueDate; createdAt = f.createdAt; sourceBlockID = f.sourceBlockID
    }
}

private struct DailyTodoSnap: Codable {
    var id: UUID
    var text: String
    var isChecked: Bool
    var targetDate: Date
    var sortIndex: Int
    var carriedOver: Bool

    init(_ t: DailyTodo) {
        id = t.id; text = t.text; isChecked = t.isChecked
        targetDate = t.targetDate; sortIndex = t.sortIndex; carriedOver = t.carriedOver
    }
}

private enum SyncMsg: Codable {
    case fullState(workspaces: [WorkspaceSnap], pages: [PageSnap], blocks: [BlockSnap],
                   todos: [DailyTodoSnap], flashcards: [FlashcardSnap])
    case pageUpsert(PageSnap)
    case pageDelete(UUID)
    case blockUpsert(BlockSnap)
    case blockDelete(UUID)
    case todoUpsert(DailyTodoSnap)
    case todoDelete(UUID)
    case timerSync(TimerSnap)
    case flashcardUpsert(FlashcardSnap)
    case flashcardDelete(UUID)
}

// MARK: - NearbySync

@MainActor
@Observable
final class NearbySync: NSObject {
    static let shared = NearbySync()

    private(set) var connectedDevices: [String] = []
    private(set) var discoveredPeers: [String] = []
    private var discoveredPeerIDs: [String: MCPeerID] = [:]
    private(set) var isActive = false

    /// Timestamps of blocks last changed by a remote apply.
    /// BlockRowView checks this to skip echoing remote changes back.
    var remoteAppliedBlockTimestamps: [UUID: Date] = [:]

    var statusLabel: String {
        guard isActive else { return "Bluetooth-Sync inaktiv" }
        if connectedDevices.isEmpty { return "Suche nach Geräten…" }
        return "Verbunden: \(connectedDevices.joined(separator: ", "))"
    }

    var statusIcon: String {
        guard isActive else { return "wifi.slash" }
        return connectedDevices.isEmpty ? "antenna.radiowaves.left.and.right" : "wifi"
    }

    private let serviceType = "textit-sync"
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    private var modelContext: ModelContext?

    override init() {
        let deviceName = ProcessInfo.processInfo.hostName
            .components(separatedBy: ".").first ?? "Ger\u{E4}t"
        let pid = MCPeerID(displayName: deviceName)
        let sess = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .required)
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "textit-sync")
        let brow = MCNearbyServiceBrowser(peer: pid, serviceType: "textit-sync")
        peerID = pid; session = sess; advertiser = adv; browser = brow
        super.init()
        session.delegate = self; advertiser.delegate = self; browser.delegate = self
    }

    // MARK: - MPC stack recreation

    private func reinitMPC() {
        let name = peerID.displayName
        peerID = MCPeerID(displayName: name)
        let sess = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        let adv  = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        let brow = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        session = sess; advertiser = adv; browser = brow
        session.delegate = self; advertiser.delegate = self; browser.delegate = self
    }

    // MARK: - Lifecycle

    func start(context: ModelContext) {
        guard !isActive else { return }
        modelContext = context
        deduplicateWorkspaces()
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        isActive = true
        // No CoreData observers: all mutations call sendXxx() explicitly.
        // This prevents feedback loops and connection flooding.
    }

    private func deduplicateWorkspaces() {
        guard let ctx = modelContext else { return }
        guard let allWS = try? ctx.fetch(FetchDescriptor<Workspace>(
            sortBy: [SortDescriptor(\Workspace.createdAt)]
        )) else { return }
        var seen: [String: Workspace] = [:]; var toDelete: [Workspace] = []
        for ws in allWS {
            if let existing = seen[ws.name] {
                (ws.pages ?? []).forEach { $0.workspace = existing }
                toDelete.append(ws)
            } else { seen[ws.name] = ws }
        }
        if !toDelete.isEmpty { toDelete.forEach { ctx.delete($0) }; try? ctx.save() }
    }

    func stop() {
        guard isActive else { return }
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        isActive = false
        connectedDevices = []
        discoveredPeers = []
        discoveredPeerIDs = [:]
    }

    func restart() {
        let ctx = modelContext
        stop()
        reinitMPC()
        guard let ctx else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start(context: ctx)
        }
    }

    // MARK: - Broadcast

    func broadcastFullState() {
        guard !session.connectedPeers.isEmpty, let ctx = modelContext else { return }
        guard let ws         = try? ctx.fetch(FetchDescriptor<Workspace>()),
              let pages      = try? ctx.fetch(FetchDescriptor<Page>()),
              let blocks     = try? ctx.fetch(FetchDescriptor<Block>()),
              let todos      = try? ctx.fetch(FetchDescriptor<DailyTodo>()),
              let flashcards = try? ctx.fetch(FetchDescriptor<Flashcard>()) else { return }

        // Strip large binary data (images/drawings) from the full-state payload.
        // These sync via CloudKit; sending them here can crash the MPC session
        // with oversized payloads. Incremental sendBlockUpsert() still carries them.
        let blockSnaps = blocks.map { b -> BlockSnap in
            var s = BlockSnap(b); s.imageData = nil; s.drawingData = nil; return s
        }
        let pageSnaps = pages.map { p -> PageSnap in
            var s = PageSnap(p); s.drawingData = nil; return s
        }

        send(.fullState(
            workspaces: ws.map { WorkspaceSnap(id: $0.id, name: $0.name, icon: $0.icon, createdAt: $0.createdAt) },
            pages: pageSnaps,
            blocks: blockSnaps,
            todos: todos.map { DailyTodoSnap($0) },
            flashcards: flashcards.map { FlashcardSnap($0) }
        ))
    }

    func sendPageUpsert(_ page: Page)      { send(.pageUpsert(PageSnap(page))) }
    func sendPageDelete(_ id: UUID)        { send(.pageDelete(id)) }
    func sendBlockUpsert(_ block: Block)   { send(.blockUpsert(BlockSnap(block))) }
    func sendBlockDelete(_ id: UUID)       { send(.blockDelete(id)) }
    func sendFlashcardUpsert(_ card: Flashcard) { send(.flashcardUpsert(FlashcardSnap(card))) }
    func sendFlashcardDelete(_ id: UUID)   { send(.flashcardDelete(id)) }
    func sendTodoUpsert(_ todo: DailyTodo) { send(.todoUpsert(DailyTodoSnap(todo))) }
    func sendTodoDelete(_ id: UUID)        { send(.todoDelete(id)) }
    func sendTimerSync(_ snap: TimerSnap)  { send(.timerSync(snap)) }

    private func send(_ msg: SyncMsg) {
        guard let data = try? JSONEncoder().encode(msg) else { return }
        let peers = session.connectedPeers
        guard !peers.isEmpty else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    // MARK: - Apply received data

    private func apply(_ msg: SyncMsg) {
        guard let ctx = modelContext else { return }

        switch msg {
        case .fullState(let wSnaps, let pSnaps, let bSnaps, let tSnaps, let fSnaps):
            let wsRemap = buildWorkspaceRemap(wSnaps, ctx: ctx)
            pSnaps.sorted { $0.parentID == nil && $1.parentID != nil }
                  .forEach { applyPage($0, ctx: ctx, wsRemap: wsRemap) }
            bSnaps.forEach { applyBlock($0, ctx: ctx) }
            tSnaps.forEach { applyTodo($0, ctx: ctx) }
            fSnaps.forEach { applyFlashcard($0, ctx: ctx) }

        case .pageUpsert(let snap):   applyPage(snap, ctx: ctx)
        case .pageDelete(let id):
            let tid = id
            if let p = try? ctx.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.id == tid })).first {
                ctx.delete(p)
            }
        case .blockUpsert(let snap):  applyBlock(snap, ctx: ctx)
        case .blockDelete(let id):
            let tid = id
            if let b = try? ctx.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == tid })).first {
                ctx.delete(b)
            }
        case .todoUpsert(let snap):   applyTodo(snap, ctx: ctx)
        case .todoDelete(let id):
            let tid = id
            if let t = try? ctx.fetch(FetchDescriptor<DailyTodo>(predicate: #Predicate { $0.id == tid })).first {
                ctx.delete(t)
            }
        case .timerSync(let snap):
            StudyTimer.shared.applyRemoteState(snap)
            return
        case .flashcardUpsert(let snap): applyFlashcard(snap, ctx: ctx)
        case .flashcardDelete(let id):
            let fid = id
            if let f = try? ctx.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == fid })).first {
                ctx.delete(f)
            }
        }

        try? ctx.save()
    }

    private func applyFlashcard(_ s: FlashcardSnap, ctx: ModelContext) {
        let sid = s.id
        if let e = try? ctx.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == sid })).first {
            guard s.dueDate >= e.dueDate else { return }
            e.front = s.front; e.back = s.back; e.deck = s.deck
            e.easeFactor = s.easeFactor; e.interval = s.interval
            e.repetitions = s.repetitions; e.dueDate = s.dueDate
        } else {
            let f = Flashcard(front: s.front, back: s.back, deck: s.deck)
            f.id = s.id; f.easeFactor = s.easeFactor; f.interval = s.interval
            f.repetitions = s.repetitions; f.dueDate = s.dueDate
            f.createdAt = s.createdAt; f.sourceBlockID = s.sourceBlockID
            ctx.insert(f)
        }
    }

    private func buildWorkspaceRemap(_ snaps: [WorkspaceSnap], ctx: ModelContext) -> [UUID: UUID] {
        var remap: [UUID: UUID] = [:]
        for s in snaps {
            let sid = s.id
            if (try? ctx.fetch(FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == sid })).first) != nil {
                remap[s.id] = s.id
            } else {
                let sname = s.name
                if let existing = try? ctx.fetch(FetchDescriptor<Workspace>(
                    predicate: #Predicate { $0.name == sname }
                )).first {
                    remap[s.id] = existing.id
                } else {
                    let ws = Workspace(); ws.id = s.id; ws.name = s.name
                    ws.icon = s.icon; ws.createdAt = s.createdAt; ctx.insert(ws)
                    remap[s.id] = s.id
                }
            }
        }
        return remap
    }

    private func applyPage(_ s: PageSnap, ctx: ModelContext, wsRemap: [UUID: UUID] = [:]) {
        let sid = s.id
        if let e = try? ctx.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.id == sid })).first {
            guard s.updatedAt >= e.updatedAt else { return }
            e.title = s.title; e.icon = s.icon; e.coverColorHex = s.coverColorHex
            e.updatedAt = s.updatedAt; e.sortIndex = s.sortIndex
            e.isFavorite = s.isFavorite; e.isTrashed = s.isTrashed; e.isExpanded = s.isExpanded
            e.tagsData = s.tagsData
            if let drew = s.drawingData { e.drawingData = drew }
            if let pid = s.parentID {
                let ppid = pid
                e.parent = try? ctx.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.id == ppid })).first
            } else { e.parent = nil }
        } else {
            let p = Page(); p.id = s.id; p.title = s.title; p.icon = s.icon
            p.coverColorHex = s.coverColorHex; p.createdAt = s.createdAt; p.updatedAt = s.updatedAt
            p.sortIndex = s.sortIndex; p.isFavorite = s.isFavorite
            p.isTrashed = s.isTrashed; p.isExpanded = s.isExpanded
            p.tagsData = s.tagsData; p.drawingData = s.drawingData
            if let wsID = s.workspaceID {
                let wid = wsRemap[wsID] ?? wsID
                p.workspace = try? ctx.fetch(FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == wid })).first
            }
            if let pid = s.parentID {
                let ppid = pid
                p.parent = try? ctx.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.id == ppid })).first
            }
            ctx.insert(p)
        }
    }

    private func applyTodo(_ s: DailyTodoSnap, ctx: ModelContext) {
        let sid = s.id
        if let e = try? ctx.fetch(FetchDescriptor<DailyTodo>(predicate: #Predicate { $0.id == sid })).first {
            e.text = s.text; e.isChecked = s.isChecked
            e.targetDate = s.targetDate; e.sortIndex = s.sortIndex; e.carriedOver = s.carriedOver
        } else {
            let t = DailyTodo()
            t.id = s.id; t.text = s.text; t.isChecked = s.isChecked
            t.targetDate = s.targetDate; t.sortIndex = s.sortIndex; t.carriedOver = s.carriedOver
            ctx.insert(t)
        }
    }

    private func applyBlock(_ s: BlockSnap, ctx: ModelContext) {
        let sid = s.id
        if let e = try? ctx.fetch(FetchDescriptor<Block>(predicate: #Predicate { $0.id == sid })).first {
            guard s.updatedAt >= e.updatedAt else { return }
            e.rawType = s.rawType; e.text = s.text; e.sortIndex = s.sortIndex
            e.updatedAt = s.updatedAt; e.checked = s.checked; e.expanded = s.expanded
            e.level = s.level; e.language = s.language; e.colorHex = s.colorHex
            e.emoji = s.emoji
            if let img = s.imageData { e.imageData = img }
            if let drw = s.drawingData { e.drawingData = drw }
            e.url = s.url; e.jsonPayload = s.jsonPayload
            e.parentBlockID = s.parentBlockID; e.linkedPageID = s.linkedPageID
            e.imageWidth = s.imageWidth; e.pdfBlockHeight = s.pdfBlockHeight
        } else {
            let b = Block(type: BlockType(rawValue: s.rawType) ?? .text, text: s.text, sortIndex: s.sortIndex)
            b.id = s.id; b.createdAt = s.createdAt; b.updatedAt = s.updatedAt
            b.checked = s.checked; b.expanded = s.expanded; b.level = s.level
            b.language = s.language; b.colorHex = s.colorHex; b.emoji = s.emoji
            b.imageData = s.imageData; b.drawingData = s.drawingData
            b.url = s.url; b.jsonPayload = s.jsonPayload
            b.parentBlockID = s.parentBlockID; b.linkedPageID = s.linkedPageID
            b.imageWidth = s.imageWidth; b.pdfBlockHeight = s.pdfBlockHeight
            if let pgID = s.pageID {
                let pid = pgID
                b.page = try? ctx.fetch(FetchDescriptor<Page>(predicate: #Predicate { $0.id == pid })).first
            }
            ctx.insert(b)
        }
        // Record that this block's current timestamp came from a remote apply.
        // BlockRowView.onChange checks this to avoid echoing the change back.
        remoteAppliedBlockTimestamps[s.id] = s.updatedAt
    }
}

// MARK: - MCSessionDelegate

extension NearbySync: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID,
                              didChange state: MCSessionState) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            guard let self, session === self.session else { return }
            switch state {
            case .connected:
                if !self.connectedDevices.contains(name) {
                    self.connectedDevices.append(name)
                }
                // Send full state once so the newly connected peer is up to date
                self.broadcastFullState()

            case .notConnected:
                self.connectedDevices.removeAll { $0 == name }
                // Only the lexicographically "smaller" peer retries to avoid simultaneous reconnects
                guard self.isActive, self.peerID.displayName < name else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self, self.isActive,
                          !self.connectedDevices.contains(name),
                          let pid = self.discoveredPeerIDs[name] else { return }
                    self.browser.invitePeer(pid, to: self.session, withContext: nil, timeout: 10)
                }
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data,
                              fromPeer peerID: MCPeerID) {
        guard let msg = try? JSONDecoder().decode(SyncMsg.self, from: data) else { return }
        Task { @MainActor [weak self] in
            guard let self, session === self.session else { return }
            if case .timerSync(let snap) = msg {
                StudyTimer.shared.applyRemoteState(snap)
                return
            }
            self.apply(msg)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                              withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession,
                              didStartReceivingResourceWithName resourceName: String,
                              fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession,
                              didFinishReceivingResourceWithName resourceName: String,
                              fromPeer peerID: MCPeerID, at localURL: URL?,
                              withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbySync: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                 didReceiveInvitationFromPeer peerID: MCPeerID,
                                 withContext context: Data?,
                                 invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor [weak self] in
            guard let self, advertiser === self.advertiser else {
                invitationHandler(false, nil); return
            }
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                 didNotStartAdvertisingPeer error: Error) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbySync: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              foundPeer peerID: MCPeerID,
                              withDiscoveryInfo info: [String: String]?) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            guard let self, browser === self.browser else { return }
            if !self.discoveredPeers.contains(name) { self.discoveredPeers.append(name) }
            self.discoveredPeerIDs[name] = peerID
            // Single-side invitation: only the peer with the lexicographically smaller name
            // sends the invite. This prevents both sides simultaneously inviting each other,
            // which caused race conditions and immediate disconnects.
            if self.peerID.displayName < name {
                self.browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              lostPeer peerID: MCPeerID) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            guard let self, browser === self.browser else { return }
            self.discoveredPeers.removeAll { $0 == name }
            self.discoveredPeerIDs.removeValue(forKey: name)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              didNotStartBrowsingForPeers error: Error) {}

    func manualConnect(peerName: String) {
        guard let pid = discoveredPeerIDs[peerName] else { restart(); return }
        browser.invitePeer(pid, to: session, withContext: nil, timeout: 15)
    }
}
