//
//  FlashcardReviewView.swift
//  Text it
//
//  Lernkarten-Wiederholung: animiertes 3D-Umdrehen, SM-2-Bewertung,
//  Fortschrittsbalken, Abschluss-Screen.
//

import SwiftUI
import SwiftData

struct FlashcardReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let cards: [Flashcard]
    let title: String

    @State private var queue: [Flashcard] = []
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var flipAngle: Double = 0
    @State private var finished = false
    @State private var ratingAnimationID: UUID = UUID()

    private var current: Flashcard? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    private var progress: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(currentIndex) / Double(queue.count)
    }

    var body: some View {
        ZStack {
            if finished || queue.isEmpty {
                completionScreen
            } else {
                reviewScreen
            }
        }
        .onAppear { queue = cards.shuffled() }
    }

    // MARK: - Review Screen

    private var reviewScreen: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)

                Spacer()
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()

                Text("\(currentIndex + 1) / \(queue.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 4)
                    Capsule()
                        .fill(flashcardPurple)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Spacer()

            // Card
            if let card = current {
                cardView(card: card)
                    .padding(.horizontal, 24)
                    .id(card.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }

            Spacer()

            // Tap hint or rating buttons
            if !isFlipped {
                tapHint
            } else {
                ratingButtons
                    .id(ratingAnimationID)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(platformBackground).ignoresSafeArea())
    }

    // MARK: - Card

    private func cardView(card: Flashcard) -> some View {
        ZStack {
            // Front face
            cardFace(text: card.front, isFront: true)
                .opacity(flipAngle < 90 ? 1 : 0)

            // Back face (pre-rotated 180° on Y so it appears right-side up after flip)
            cardFace(text: card.back.isEmpty ? "(keine Rückseite)" : card.back, isFront: false)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipAngle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
        .frame(maxWidth: 600)
        .onTapGesture { flipCard() }
    }

    private func cardFace(text: String, isFront: Bool) -> some View {
        VStack(spacing: 16) {
            if isFront {
                Text("FRAGE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(flashcardPurple.opacity(0.7))
                    .tracking(2)
            } else {
                Text("ANTWORT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green.opacity(0.8))
                    .tracking(2)
            }
            Text(text)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isFront
                    ? Color(platformSecondaryBackground)
                    : Color(platformSecondaryBackground))
                .shadow(color: .black.opacity(0.08), radius: 20, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isFront ? flashcardPurple.opacity(0.2) : Color.green.opacity(0.3), lineWidth: 1.5)
                )
        )
    }

    private var tapHint: some View {
        VStack(spacing: 4) {
            Image(systemName: "hand.tap")
                .foregroundStyle(.tertiary)
            Text("Tippe um umzudrehen")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("Wie gut wusstest du es?")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach([FlashcardRating.again, .hard, .good, .easy], id: \.label) { rating in
                    ratingButton(rating)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func ratingButton(_ rating: FlashcardRating) -> some View {
        Button {
            applyRating(rating)
        } label: {
            VStack(spacing: 4) {
                Text(rating.label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(rating.color)
                if let card = current {
                    Text(nextIntervalLabel(card: card, rating: rating))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(rating.color.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(rating.color.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func nextIntervalLabel(card: Flashcard, rating: FlashcardRating) -> String {
        switch rating {
        case .again: return "1 Tag"
        case .hard:
            let next = card.repetitions == 0 ? 1 : max(1, Int((Double(card.interval) * 1.2).rounded()))
            return next == 1 ? "1 Tag" : "\(next) Tage"
        case .good:
            let next: Int
            if card.repetitions == 0 { next = 1 }
            else if card.repetitions == 1 { next = 6 }
            else { next = max(1, Int((Double(card.interval) * card.easeFactor).rounded())) }
            return next == 1 ? "1 Tag" : "\(next) Tage"
        case .easy:
            let next: Int
            if card.repetitions == 0 { next = 4 }
            else if card.repetitions == 1 { next = 8 }
            else { next = max(1, Int((Double(card.interval) * card.easeFactor * 1.3).rounded())) }
            return next == 1 ? "1 Tag" : "\(next) Tage"
        }
    }

    // MARK: - Completion Screen

    private var completionScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(flashcardPurple)
                .symbolEffect(.bounce, value: finished)

            Text("Geschafft!")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            VStack(spacing: 8) {
                Text("Du hast \(queue.count) Karte\(queue.count == 1 ? "" : "n") wiederholt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Bis zur nächsten Runde 👏")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Fertig") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(flashcardPurple)
                .font(.callout.weight(.semibold))
                .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(platformBackground).ignoresSafeArea())
    }

    // MARK: - Actions

    private func flipCard() {
        guard !isFlipped else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            flipAngle = 180
            isFlipped = true
        }
        ratingAnimationID = UUID()
    }

    private func applyRating(_ rating: FlashcardRating) {
        guard let card = current else { return }
        card.applyRating(rating)
        try? context.save()
        NearbySync.shared.sendFlashcardUpsert(card)

        let nextIdx = currentIndex + 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            flipAngle = 0
            isFlipped = false
            currentIndex = nextIdx
        }

        if nextIdx >= queue.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                finished = true
            }
        }
    }

    private var flashcardPurple: Color { Color(red: 0.55, green: 0.25, blue: 0.9) }

    #if os(iOS) || os(visionOS)
    private var platformBackground: UIColor { .systemBackground }
    private var platformSecondaryBackground: UIColor { .secondarySystemBackground }
    #else
    private var platformBackground: NSColor { .windowBackgroundColor }
    private var platformSecondaryBackground: NSColor { .controlBackgroundColor }
    #endif
}
