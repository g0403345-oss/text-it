//
//  FlashcardsView.swift
//  Text it
//
//  Lernkarten-Hub: Stapel verwalten, Karten erstellen/bearbeiten,
//  Statistiken, Wiederholung starten.
//

import SwiftUI
import SwiftData

// Wrapper damit String als fullScreenCover-Item nutzbar ist
struct DeckReviewTarget: Identifiable {
    let id: String
    var deckName: String { id }
}

struct FlashcardsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(sort: \Flashcard.createdAt) private var allCards: [Flashcard]

    @State private var showAddCard = false
    @State private var editingCard: Flashcard? = nil
    @State private var reviewTarget: DeckReviewTarget? = nil
    @State private var reviewAll = false

    private var decks: [String] { Array(Set(allCards.map(\.deck))).sorted() }
    private var dueToday: [Flashcard] { allCards.filter(\.isDue) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !dueToday.isEmpty { dueSection }
                if allCards.isEmpty { emptyState } else { deckList }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .navigationTitle("Lernkarten")
        .sheet(isPresented: $showAddCard) {
            FlashcardEditSheet(card: nil, decks: decks)
        }
        .sheet(item: $editingCard) { card in
            FlashcardEditSheet(card: card, decks: decks)
        }
        #if os(iOS) || os(visionOS)
        .fullScreenCover(item: $reviewTarget) { target in
            FlashcardReviewView(
                cards: dueCards(for: target.deckName),
                title: target.deckName
            )
        }
        .fullScreenCover(isPresented: $reviewAll) {
            FlashcardReviewView(cards: dueToday, title: "Alle fälligen Karten")
        }
        #else
        .sheet(item: $reviewTarget) { target in
            FlashcardReviewView(
                cards: dueCards(for: target.deckName),
                title: target.deckName
            )
            .frame(minWidth: 600, minHeight: 680)
        }
        .sheet(isPresented: $reviewAll) {
            FlashcardReviewView(cards: dueToday, title: "Alle fälligen Karten")
                .frame(minWidth: 600, minHeight: 680)
        }
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lernkarten")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                HStack(spacing: 16) {
                    statBadge(value: allCards.count, label: "Gesamt", color: .secondary)
                    statBadge(value: dueToday.count, label: "Fällig heute",
                              color: dueToday.isEmpty ? .secondary : flashcardPurple)
                    statBadge(value: decks.count, label: "Stapel", color: .secondary)
                }
            }
            Spacer()
            Button { showAddCard = true } label: {
                Label("Neue Karte", systemImage: "plus")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(flashcardPurple)
        }
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Fällig heute

    private var dueSection: some View {
        HStack {
            Image(systemName: "bell.badge.fill").foregroundStyle(flashcardPurple)
            Text("\(dueToday.count) Karte\(dueToday.count == 1 ? "" : "n") zur Wiederholung fällig")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Alle lernen") { reviewAll = true }
                .buttonStyle(.borderedProminent)
                .tint(flashcardPurple)
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(flashcardPurple.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(flashcardPurple.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: - Deck List

    private var deckList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stapel")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(decks, id: \.self) { deck in
                DeckRow(
                    deck: deck,
                    cards: cards(for: deck),
                    due: dueCards(for: deck),
                    onReview: { reviewTarget = DeckReviewTarget(id: deck) },
                    onEditCard: { editingCard = $0 },
                    onDelete: deleteCard
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(flashcardPurple.opacity(0.4))
            Text("Noch keine Lernkarten")
                .font(.title3.weight(.semibold))
            Text("Erstelle Karten manuell oder füge sie direkt aus Definition-Blöcken hinzu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Button {
                showAddCard = true
            } label: {
                Label("Erste Karte erstellen", systemImage: "plus.circle.fill")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(flashcardPurple)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private var flashcardPurple: Color { Color(red: 0.55, green: 0.25, blue: 0.9) }

    private func cards(for deck: String) -> [Flashcard] {
        allCards.filter { $0.deck == deck }
    }

    private func dueCards(for deck: String) -> [Flashcard] {
        cards(for: deck).filter(\.isDue)
    }

    private func deleteCard(_ card: Flashcard) {
        NearbySync.shared.sendFlashcardDelete(card.id)
        context.delete(card)
        try? context.save()
    }
}

// MARK: - DeckRow

private struct DeckRow: View {
    let deck: String
    let cards: [Flashcard]
    let due: [Flashcard]
    let onReview: () -> Void
    let onEditCard: (Flashcard) -> Void
    let onDelete: (Flashcard) -> Void

    @State private var expanded = false

    private var flashcardPurple: Color { Color(red: 0.55, green: 0.25, blue: 0.9) }

    var body: some View {
        VStack(spacing: 0) {
            deckHeader
            if expanded {
                Divider().padding(.horizontal, 14)
                ForEach(cards) { card in
                    CardListRow(card: card, onEdit: { onEditCard(card) }, onDelete: { onDelete(card) })
                    if card.id != cards.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.quaternary.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary, lineWidth: 0.5))
        )
    }

    private var deckHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .foregroundStyle(flashcardPurple)
                    Text(deck)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if !due.isEmpty {
                Text("\(due.count) fällig")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(flashcardPurple))
            }

            Text("\(cards.count) Karten")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !due.isEmpty {
                Button("Lernen") { onReview() }
                    .buttonStyle(.bordered)
                    .tint(flashcardPurple)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - CardListRow

private struct CardListRow: View {
    let card: Flashcard
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var flashcardPurple: Color { Color(red: 0.55, green: 0.25, blue: 0.9) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.front.isEmpty ? "—" : card.front)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if !card.back.isEmpty {
                    Text(card.back)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(card.isDue ? "Fällig" : card.dueDate.formatted(.dateTime.day().month()))
                .font(.caption2)
                .foregroundStyle(card.isDue ? flashcardPurple : .secondary)
                .monospacedDigit()
            Menu {
                Button("Bearbeiten") { onEdit() }
                Divider()
                Button("Löschen", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - FlashcardFromBlockSheet (schnell aus Definition-Block erstellen)

struct FlashcardFromBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Flashcard.createdAt) private var existingCards: [Flashcard]

    let front: String
    let back: String

    @State private var editedFront = ""
    @State private var editedBack = ""
    @State private var selectedDeck = "Standard"
    @State private var newDeckName = ""

    private var decks: [String] { Array(Set(existingCards.map(\.deck))).sorted() }
    private var isNewDeck: Bool { selectedDeck == "__new__" || decks.isEmpty }
    private var flashcardPurple: Color { Color(red: 0.55, green: 0.25, blue: 0.9) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vorderseite") {
                    TextField("Begriff", text: $editedFront, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section("Rückseite") {
                    TextField("Erklärung", text: $editedBack, axis: .vertical)
                        .lineLimit(1...5)
                }
                Section("Stapel") {
                    if !decks.isEmpty {
                        Picker("Stapel", selection: $selectedDeck) {
                            ForEach(decks, id: \.self) { Text($0).tag($0) }
                            Text("Neuer Stapel…").tag("__new__")
                        }
                    }
                    if isNewDeck {
                        TextField("Stapelname", text: $newDeckName)
                    }
                }
            }
            .navigationTitle("Lernkarte hinzufügen")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { save() }
                        .disabled(editedFront.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(flashcardPurple)
        .onAppear {
            editedFront = front
            editedBack  = back
            if let first = decks.first { selectedDeck = first }
        }
    }

    private func save() {
        let finalDeck = isNewDeck
            ? (newDeckName.trimmingCharacters(in: .whitespaces).isEmpty ? "Standard" : newDeckName.trimmingCharacters(in: .whitespaces))
            : selectedDeck
        let card = Flashcard(
            front: editedFront.trimmingCharacters(in: .whitespaces),
            back:  editedBack.trimmingCharacters(in: .whitespaces),
            deck:  finalDeck
        )
        context.insert(card)
        try? context.save()
        NearbySync.shared.sendFlashcardUpsert(card)
        dismiss()
    }
}

// MARK: - FlashcardEditSheet

struct FlashcardEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let card: Flashcard?
    let decks: [String]

    @State private var front = ""
    @State private var back = ""
    @State private var selectedDeck = "Standard"
    @State private var newDeckName = ""

    private var isNewDeck: Bool { selectedDeck == "__new__" || decks.isEmpty }
    private var flashcardPurple: Color { Color(red: 0.55, green: 0.25, blue: 0.9) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vorderseite") {
                    TextField("Begriff / Frage", text: $front, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Rückseite") {
                    TextField("Erklärung / Antwort", text: $back, axis: .vertical)
                        .lineLimit(1...6)
                }
                Section("Stapel") {
                    if !decks.isEmpty {
                        Picker("Stapel", selection: $selectedDeck) {
                            ForEach(decks, id: \.self) { Text($0).tag($0) }
                            Text("Neuer Stapel…").tag("__new__")
                        }
                    }
                    if isNewDeck {
                        TextField("Stapelname", text: $newDeckName)
                    }
                }
            }
            .navigationTitle(card == nil ? "Neue Karte" : "Karte bearbeiten")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(flashcardPurple)
        .onAppear { loadCard() }
    }

    private func loadCard() {
        guard let c = card else {
            if let first = decks.first { selectedDeck = first }
            return
        }
        front = c.front
        back = c.back
        selectedDeck = c.deck
    }

    private func save() {
        let finalDeck = isNewDeck
            ? (newDeckName.trimmingCharacters(in: .whitespaces).isEmpty ? "Standard" : newDeckName.trimmingCharacters(in: .whitespaces))
            : selectedDeck

        if let c = card {
            c.front = front.trimmingCharacters(in: .whitespaces)
            c.back  = back.trimmingCharacters(in: .whitespaces)
            c.deck  = finalDeck
            try? context.save()
            NearbySync.shared.sendFlashcardUpsert(c)
        } else {
            let newCard = Flashcard(
                front: front.trimmingCharacters(in: .whitespaces),
                back:  back.trimmingCharacters(in: .whitespaces),
                deck:  finalDeck
            )
            context.insert(newCard)
            try? context.save()
            NearbySync.shared.sendFlashcardUpsert(newCard)
        }
        dismiss()
    }
}
