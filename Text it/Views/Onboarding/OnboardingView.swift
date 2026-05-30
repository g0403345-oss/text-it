//
//  OnboardingView.swift
//  Text it
//
//  Erster Start: Willkommens-Onboarding mit Feature-Highlights.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage: Int = 0
    @State private var selectedTheme: AppTheme = .indigo

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            // Hintergrund-Gradient (theme-aware)
            LinearGradient(
                colors: [selectedTheme.accent.opacity(0.12), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .background(.background.opacity(0.98))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Seitenindikator (nur einmal, oben)
                pageIndicator
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                // Seite – iOS nutzt swipbaren TabView, macOS manuell
                #if os(iOS)
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        pageContent(page).tag(idx)
                    }
                    themePicker.tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                #else
                // macOS: kein TabView-Chrome (Tab-Leiste), manuelles Blend-in/out
                ZStack {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        pageContent(page)
                            .opacity(currentPage == idx ? 1 : 0)
                            .scaleEffect(currentPage == idx ? 1 : 0.96, anchor: .top)
                            .allowsHitTesting(currentPage == idx)
                    }
                    themePicker
                        .opacity(currentPage == pages.count ? 1 : 0)
                        .scaleEffect(currentPage == pages.count ? 1 : 0.96, anchor: .top)
                        .allowsHitTesting(currentPage == pages.count)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                #endif

                // Navigation
                navigationBar
                    #if os(iOS)
                    .padding(.bottom, 32)
                    #else
                    .padding(.bottom, 20)
                    #endif
            }
        }
        .onAppear { selectedTheme = appState.theme }
    }

    // MARK: - Seiten-Indikator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<(pages.count + 1), id: \.self) { idx in
                Capsule()
                    .fill(currentPage == idx ? selectedTheme.accent : Color.secondary.opacity(0.3))
                    .frame(width: currentPage == idx ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Seiten-Inhalt

    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: page.icon)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(page.color)
            }
            .shadow(color: page.color.opacity(0.25), radius: 20, y: 10)

            // Text
            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Feature-Chips
            if !page.features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(page.features, id: \.self) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(page.color)
                                .font(.callout)
                            Text(feature)
                                .font(.callout)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Theme-Picker (letzte Seite)

    private var themePicker: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 14) {
                Text("Wähle deine Farbe")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Du kannst das Farbschema jederzeit in den Einstellungen ändern.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
                spacing: 14
            ) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTheme = theme
                            appState.setTheme(theme)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 48, height: 48)
                                    .shadow(color: theme.accent.opacity(0.35), radius: 8, y: 4)
                                if selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.callout.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(theme.displayName)
                                .font(.caption.weight(selectedTheme == theme ? .semibold : .regular))
                                .foregroundStyle(selectedTheme == theme ? theme.accent : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if currentPage > 0 {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Zurück")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentPage < pages.count {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("Weiter")
                        Image(systemName: "chevron.right")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(selectedTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation { appState.completeOnboarding() }
                } label: {
                    Text("Los geht's!")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(selectedTheme.accent, in: Capsule())
                        .shadow(color: selectedTheme.accent.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Onboarding Page Data

struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let features: [String]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            title: "Willkommen bei\nText it",
            subtitle: "Dein smartes Notiz-Tool für Schule, Studium und Alltag.",
            icon: "sparkles",
            color: .indigo,
            features: []
        ),
        OnboardingPage(
            title: "Seiten & Blöcke",
            subtitle: "Strukturiere dein Wissen wie du willst – mit verschachtelten Seiten, Ordnern und über 15 Block-Typen.",
            icon: "doc.text.fill",
            color: .blue,
            features: [
                "Texte, Überschriften, Listen & Tabellen",
                "Ordner & verschachtelte Seiten",
                "Code-Blöcke & Hinweise",
                "Bilder & Handschrift",
            ]
        ),
        OnboardingPage(
            title: "Tägliche Todos",
            subtitle: "Plane deinen Tag und verpasse keine Aufgabe mehr. Nicht erledigte Todos werden automatisch auf den nächsten Tag übertragen.",
            icon: "checklist",
            color: Color(red: 0.18, green: 0.72, blue: 0.45),
            features: [
                "Täglich neue Aufgabenliste",
                "Automatischer Übertrag",
                "Fortschrittsanzeige",
                "Schnelles Abhaken",
            ]
        ),
        OnboardingPage(
            title: "Apple Pencil",
            subtitle: "Schreibe und zeichne direkt auf deinen Seiten – mit natürlicher Druckempfindlichkeit.",
            icon: "applepencil.tip",
            color: .purple,
            features: [
                "Handschrift über Text-Blöcke",
                "Doppeltippen = Radierer",
                "Stift/Finger automatisch erkennen",
                "Füllfeder, Bleistift & Textmarker",
            ]
        ),
    ]
}
