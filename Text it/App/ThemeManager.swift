//
//  ThemeManager.swift
//  Text it
//
//  Farbschema-System: 8 Themes, jeweils mit Akzentfarbe, Gradienten und Icons.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case indigo  = "indigo"
    case rose    = "rose"
    case sky     = "sky"
    case teal    = "teal"
    case violet  = "violet"
    case amber   = "amber"
    case emerald = "emerald"
    case crimson = "crimson"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indigo:  "Indigo"
        case .rose:    "Rose"
        case .sky:     "Sky"
        case .teal:    "Türkis"
        case .violet:  "Violett"
        case .amber:   "Amber"
        case .emerald: "Smaragd"
        case .crimson: "Karmesin"
        }
    }

    var systemIcon: String {
        switch self {
        case .indigo:  "circle.hexagongrid.fill"
        case .rose:    "heart.fill"
        case .sky:     "cloud.sun.fill"
        case .teal:    "drop.fill"
        case .violet:  "sparkles"
        case .amber:   "sun.max.fill"
        case .emerald: "leaf.fill"
        case .crimson: "flame.fill"
        }
    }

    var accent: Color {
        switch self {
        case .indigo:  Color(red: 0.44, green: 0.35, blue: 0.96)
        case .rose:    Color(red: 0.96, green: 0.26, blue: 0.50)
        case .sky:     Color(red: 0.10, green: 0.64, blue: 0.97)
        case .teal:    Color(red: 0.06, green: 0.78, blue: 0.73)
        case .violet:  Color(red: 0.72, green: 0.20, blue: 0.97)
        case .amber:   Color(red: 0.97, green: 0.70, blue: 0.12)
        case .emerald: Color(red: 0.12, green: 0.80, blue: 0.48)
        case .crimson: Color(red: 0.92, green: 0.14, blue: 0.30)
        }
    }

    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.22), accent.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.40), accent.opacity(0.12), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var softGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.18), accent.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
