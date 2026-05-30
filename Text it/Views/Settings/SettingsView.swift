//
//  SettingsView.swift
//  Text it
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearance")   private var appearance: String = "system"
    @AppStorage("editorWidth")  private var editorWidth: Double = 900
    @AppStorage("editorFont")   private var editorFont: String = "default"
    @AppStorage("lineSpacing")  private var lineSpacing: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Farbschema
                themeSection
                Divider()

                // Darstellung
                appearanceSection
                Divider()

                // Editor
                editorSection
                Divider()

                // Apple Pencil
                pencilSection
                Divider()

                // Synchronisation
                syncSection
                Divider()

                // Über
                aboutSection
            }
            .padding(24)
        }
        .navigationTitle("Einstellungen")
        .frame(minWidth: 500, minHeight: 560)
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Farbschema", icon: "paintpalette.fill")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeOptionCard(theme: theme, isSelected: appState.theme == theme) {
                        withAnimation(.spring(response: 0.3)) {
                            appState.setTheme(theme)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Darstellung", icon: "moon.stars.fill")

            HStack(spacing: 10) {
                ForEach(["system", "light", "dark"], id: \.self) { mode in
                    AppearanceOption(
                        mode: mode,
                        isSelected: appearance == mode
                    ) { appearance = mode }
                }
            }
        }
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Editor", icon: "doc.text.fill")

            VStack(alignment: .leading, spacing: 12) {
                // Breite
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Editorbreite")
                            .font(.callout)
                        Spacer()
                        Text("\(Int(editorWidth)) pt")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $editorWidth, in: 600...1400, step: 20)
                        .tint(appState.theme.accent)
                }

                // Zeilenabstand
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Zeilenabstand")
                            .font(.callout)
                        Spacer()
                        Text(lineSpacingLabel)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $lineSpacing, in: 0.8...1.8, step: 0.1)
                        .tint(appState.theme.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.4))
            )
        }
    }

    private var lineSpacingLabel: String {
        switch lineSpacing {
        case ..<0.9:  return "Eng"
        case ..<1.1:  return "Normal"
        case ..<1.4:  return "Entspannt"
        default:      return "Weit"
        }
    }

    // MARK: - Pencil Section

    private var pencilSection: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Apple Pencil", icon: "applepencil.tip")

            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $state.pencilHandwritingMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Handschrift-Modus")
                            .font(.callout.weight(.medium))
                        Text("Pencil zeichnet echte Handschrift über Textblöcke")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(appState.theme.accent)

                Divider()

                Toggle(isOn: Binding(
                    get: { appState.pencilAutoDetect },
                    set: { appState.setPencilAutoDetect($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatische Erkennung")
                            .font(.callout.weight(.medium))
                        Text("Stift erkannt → Schreiben an; nur Finger → Schreiben aus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(appState.theme.accent)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Doppeltippen")
                            .font(.callout.weight(.medium))
                        Text("Schaltet zwischen aktivem Werkzeug und Radierer um")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "applepencil.tip")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.4))
            )
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Synchronisation", icon: "icloud.fill")

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("iCloud-Status", systemImage: "icloud")
                        .font(.callout)
                    Spacer()
                    SyncStatusView()
                }

                Divider()

                Text("Aktiviere iCloud Drive und melde dich mit derselben Apple-ID an. Änderungen werden automatisch synchronisiert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.4))
            )
        }
    }

    // MARK: - About Section

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "Über", icon: "info.circle.fill")

            VStack(spacing: 0) {
                AboutRow(label: "App", value: "Text it")
                Divider().padding(.horizontal, 16)
                AboutRow(label: "Version", value: appVersion)
                Divider().padding(.horizontal, 16)
                AboutRow(label: "Entwickler", value: "Justin Guel")
                Divider().padding(.horizontal, 16)

                // Datenschutzerklärung
                Link(destination: URL(string: "https://raw.githubusercontent.com/g0403345-oss/text-it/main/PRIVACY.md")!) {
                    HStack {
                        Label("Datenschutzerklärung", systemImage: "lock.shield")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().padding(.horizontal, 16)

                // Support
                Link(destination: URL(string: "https://github.com/g0403345-oss/text-it/issues")!) {
                    HStack {
                        Label("Support & Feedback", systemImage: "questionmark.circle")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.4))
            )
        }
    }
}

// MARK: - ThemeOptionCard

struct ThemeOptionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Farbkreis
                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 44, height: 44)
                        .shadow(color: theme.accent.opacity(0.4), radius: 6, y: 3)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(theme.displayName)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? theme.accent.opacity(0.10) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AppearanceOption

struct AppearanceOption: View {
    let mode: String
    let isSelected: Bool
    let onTap: () -> Void

    private var label: String {
        switch mode {
        case "light": return "Hell"
        case "dark":  return "Dunkel"
        default:      return "System"
        }
    }

    private var icon: String {
        switch mode {
        case "light": return "sun.max.fill"
        case "dark":  return "moon.fill"
        default:      return "circle.lefthalf.filled"
        }
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(label)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

struct SettingsSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title3.weight(.bold))
        }
    }
}

struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
