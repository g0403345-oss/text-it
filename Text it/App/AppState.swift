//
//  AppState.swift
//  Text it
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    // MARK: - Navigation
    var selectedPageID: UUID?
    var showSearch: Bool = false
    var showSettings: Bool = false
    var activeSidebarSection: SidebarSection = .dashboard
    var pencilHandwritingMode: Bool = true
    var pencilAutoDetect: Bool = true

    // MARK: - Pomodoro / Lern-Timer
    var showPomodoro: Bool = false

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool

    // MARK: - Theme (persisted in UserDefaults)
    var theme: AppTheme

    func setTheme(_ newTheme: AppTheme) {
        theme = newTheme
        UserDefaults.standard.set(newTheme.rawValue, forKey: "appTheme")
    }

    // MARK: - Navigation History
    private(set) var pageHistory: [UUID] = []
    var canGoBack: Bool { !pageHistory.isEmpty }

    init() {
        let stored = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.indigo.rawValue
        self.theme = AppTheme(rawValue: stored) ?? .indigo
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.pencilAutoDetect = UserDefaults.standard.object(forKey: "pencilAutoDetect") as? Bool ?? true
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func setPencilAutoDetect(_ value: Bool) {
        pencilAutoDetect = value
        UserDefaults.standard.set(value, forKey: "pencilAutoDetect")
    }

    func navigateTo(pageID: UUID) {
        if let current = selectedPageID {
            pageHistory.append(current)
        }
        selectedPageID = pageID
    }

    func navigateBack() {
        guard !pageHistory.isEmpty else { return }
        selectedPageID = pageHistory.removeLast()
    }

    func openSection(_ section: SidebarSection) {
        selectedPageID = nil
        activeSidebarSection = section
        pageHistory.removeAll()
    }

    // MARK: - Sidebar Sections
    enum SidebarSection: String, Hashable, CaseIterable {
        case dashboard  = "dashboard"
        case todos      = "todos"
        case pages      = "pages"
        case favorites  = "favorites"
        case tags       = "tags"
        case templates  = "templates"
        case timeline    = "timeline"
        case flashcards  = "flashcards"
        case trash       = "trash"

        var title: String {
            switch self {
            case .dashboard:  "Dashboard"
            case .todos:      "Tägliche Todos"
            case .pages:      "Alle Seiten"
            case .favorites:  "Favoriten"
            case .tags:       "Tags"
            case .templates:  "Vorlagen"
            case .timeline:    "Zeitstrahl"
            case .flashcards:  "Lernkarten"
            case .trash:       "Papierkorb"
            }
        }

        var icon: String {
            switch self {
            case .dashboard:  "house.fill"
            case .todos:      "checklist"
            case .pages:      "doc.text.fill"
            case .favorites:  "star.fill"
            case .tags:       "tag.fill"
            case .templates:  "rectangle.grid.2x2.fill"
            case .timeline:    "calendar"
            case .flashcards:  "rectangle.on.rectangle.angled"
            case .trash:       "trash.fill"
            }
        }

        var color: Color {
            switch self {
            case .dashboard:  .blue
            case .todos:      Color(red: 0.18, green: 0.72, blue: 0.45)
            case .pages:      .primary
            case .favorites:  .yellow
            case .tags:       .purple
            case .templates:  .orange
            case .timeline:    .teal
            case .flashcards:  Color(red: 0.55, green: 0.25, blue: 0.9)
            case .trash:       .red
            }
        }
    }
}
