import SwiftUI
import AVFoundation
import UIKit

private enum DrillOrder: String, CaseIterable, Identifiable {
    case ordered
    case random

    var id: String { rawValue }
    var title: String {
        switch self {
        case .ordered: return "Ordered"
        case .random: return "Random"
        }
    }
}

private final class DrillSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        guard ProcessInfo.processInfo.environment["UITEST_DISABLE_SPEECH"] != "1" else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        synthesizer.speak(utterance)
    }
}

private struct DrillCard: Identifiable, Equatable {
    let id = UUID()
    let letter: Character
    let word: String
}

struct FlashcardTabView: View {
    let visitToken: Int

    @AppStorage(AppPreferences.phoneticModeKey) private var phoneticModeRaw = PhoneticMode.nato.rawValue
    @AppStorage(AppPreferences.flashcardSwipeHintSeenCountKey) private var swipeHintSeenCount = 0

    @State private var cardOrder: DrillOrder = .ordered
    @State private var deck: [DrillCard] = []
    @State private var selectedIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0
    @State private var dragY: CGFloat = 0
    @State private var isTransitioning = false
    @State private var flipPulse: CGFloat = 1.0
    @State private var flipGlow: Double = 0.0
    @State private var isShowingSwipeHint = false
    @State private var lastRegisteredVisitToken = -1

    private let speaker = DrillSpeaker()

    private var mode: PhoneticMode {
        AppPreferences.mode(from: phoneticModeRaw)
    }

    private var currentCard: DrillCard? {
        guard !deck.isEmpty, deck.indices.contains(selectedIndex) else { return nil }
        return deck[selectedIndex]
    }

    private var shouldShowSwipeHint: Bool {
        isShowingSwipeHint && swipeHintSeenCount <= 3
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width - 40, 760)
            let cardHeight = min(max(proxy.size.height * 0.58, 430), 670)

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Flashcard")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                }

                Picker("Card Order", selection: $cardOrder) {
                    ForEach(DrillOrder.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 2)
                .zIndex(3)

                ZStack {
                    if let previous = neighboringCard(offset: -1) {
                        drillCard(previous, isFaceUp: false, width: cardWidth, height: cardHeight, emphasized: false)
                            .scaleEffect(0.92)
                            .opacity(0.38)
                            .offset(x: -cardWidth * 0.82, y: 14)
                            .allowsHitTesting(false)
                    }

                    if let next = neighboringCard(offset: 1) {
                        drillCard(next, isFaceUp: false, width: cardWidth, height: cardHeight, emphasized: false)
                            .scaleEffect(0.92)
                            .opacity(0.38)
                            .offset(x: cardWidth * 0.82, y: 14)
                            .allowsHitTesting(false)
                    }

                    if let card = currentCard {
                        drillCard(
                            card,
                            isFaceUp: isFlipped,
                            width: cardWidth,
                            height: cardHeight,
                            emphasized: true,
                            pulse: flipPulse,
                            glow: flipGlow
                        )
                            .offset(x: dragOffset, y: dragY * 0.18)
                            .rotation3DEffect(
                                .degrees(Double(dragOffset / 6.8)),
                                axis: (x: 0.02, y: 1, z: 0),
                                perspective: 0.84
                            )
                            .rotation3DEffect(
                                .degrees(Double(-dragY / 22)),
                                axis: (x: 1, y: 0.02, z: 0),
                                perspective: 0.84
                            )
                            .rotationEffect(.degrees(Double(dragOffset / 30)))
                            .scaleEffect(1 - min(abs(dragOffset) / 2200, 0.045))
                            .shadow(color: .black.opacity(0.24), radius: 24, y: 16)
                            .gesture(dragGesture(cardWidth: cardWidth))
                            .onTapGesture {
                                guard !isTransitioning else { return }
                                let willShowWord = !isFlipped
                                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.07)) {
                                    flipPulse = 0.975
                                    flipGlow = 0.28
                                    isFlipped.toggle()
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                                        flipPulse = 1.018
                                    }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                                        flipPulse = 1.0
                                        flipGlow = 0.0
                                    }
                                }
                                if willShowWord {
                                    speaker.speak(card.word)
                                }
                            }

                        if shouldShowSwipeHint {
                            swipeHint(width: cardWidth, height: cardHeight)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                                .zIndex(5)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: cardWidth, height: cardHeight)
                            .overlay(
                                Text("No cards available")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight + 24, alignment: .center)
                .padding(.top, 4)
                .zIndex(1)

                Text(deck.isEmpty ? "" : "\(selectedIndex + 1)/\(deck.count)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 24)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(AppTheme.gradientBackground.ignoresSafeArea())
        .onAppear {
            rebuildDeck()
            registerSwipeHintImpressionIfNeeded(for: visitToken)
        }
        .onChange(of: cardOrder) { _, _ in
            rebuildDeck()
        }
        .onChange(of: phoneticModeRaw) { _, _ in
            rebuildDeck()
        }
        .onChange(of: visitToken) { _, _ in
            registerSwipeHintImpressionIfNeeded(for: visitToken)
        }
    }

    private func drillCard(
        _ card: DrillCard,
        isFaceUp: Bool,
        width: CGFloat,
        height: CGFloat,
        emphasized: Bool,
        pulse: CGFloat = 1.0,
        glow: Double = 0.0
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isFaceUp
                            ? [Color(red: 0.05, green: 0.31, blue: 0.53), Color(red: 0.06, green: 0.26, blue: 0.46)]
                            : [Color(red: 0.23, green: 0.50, blue: 0.74), Color(red: 0.14, green: 0.42, blue: 0.67)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.2)
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 120)
                        .blur(radius: 34)
                        .offset(y: -48)
                }

            ZStack {
                frontFace(card)
                    .opacity(isFaceUp ? 0 : 1)

                backFace(card)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                    .opacity(isFaceUp ? 1 : 0)
            }
            .animation(.linear(duration: 0.04), value: isFaceUp)
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
        }
        .frame(width: width, height: height)
        .scaleEffect((emphasized ? 1.0 : 0.98) * (emphasized ? pulse : 1.0))
        .rotation3DEffect(.degrees(isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
        .overlay {
            if emphasized {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.black.opacity(0.16 + (glow * 0.45)), lineWidth: 1.5 + (glow * 2))
            }
        }
        .compositingGroup()
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.79, blendDuration: 0.08), value: isFaceUp)
    }

    private func frontFace(_ card: DrillCard) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(String(card.letter))
                .font(.system(size: 172, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.62)
                .lineLimit(1)

            Spacer()
        }
    }

    private func backFace(_ card: DrillCard) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(card.word)
                .font(.system(size: 78, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.48)

            Spacer()
        }
    }

    private func dragGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard !isTransitioning else { return }
                dragOffset = max(-cardWidth * 1.05, min(cardWidth * 1.05, value.translation.width * 0.95))
                dragY = value.translation.height
            }
            .onEnded { value in
                guard !isTransitioning else { return }
                completeDrag(value: value, cardWidth: cardWidth)
            }
    }

    private func swipeHint(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            swipeHintArrow(systemName: "arrow.left")
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -18)

            swipeHintArrow(systemName: "arrow.right")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 18)
        }
        .frame(width: width, height: height)
    }

    private func swipeHintArrow(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.88))
            .frame(width: 64, height: 64)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.22))
            )
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    private func completeDrag(value: DragGesture.Value, cardWidth: CGFloat) {
        guard !deck.isEmpty else { return }
        let threshold = cardWidth * 0.22
        let velocityProjection = value.predictedEndTranslation.width
        let travel = value.translation.width
        let shouldAdvance = travel < -threshold || velocityProjection < -(threshold * 1.05)
        let shouldGoBack = travel > threshold || velocityProjection > (threshold * 1.05)

        if shouldAdvance {
            transition(to: 1, width: cardWidth)
        } else if shouldGoBack {
            transition(to: -1, width: cardWidth)
        } else {
            withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.78, blendDuration: 0.05)) {
                dragOffset = 0
                dragY = 0
            }
        }
    }

    private func transition(to direction: Int, width: CGFloat) {
        guard !isTransitioning else { return }
        isTransitioning = true
        isShowingSwipeHint = false
        isFlipped = false
        flipPulse = 1.0
        flipGlow = 0.0

        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.82, blendDuration: 0.06)) {
            dragOffset = CGFloat(direction) * -width * 1.08
            dragY = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selectedIndex = wrappedIndex(selectedIndex + direction)
            dragOffset = CGFloat(direction) * width * 0.46
            dragY = 0
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8, blendDuration: 0.05)) {
                dragOffset = 0
                dragY = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                isTransitioning = false
            }
        }
    }

    private func wrappedIndex(_ raw: Int) -> Int {
        guard !deck.isEmpty else { return 0 }
        let count = deck.count
        return ((raw % count) + count) % count
    }

    private func neighboringCard(offset: Int) -> DrillCard? {
        guard !deck.isEmpty else { return nil }
        return deck[wrappedIndex(selectedIndex + offset)]
    }

    private func rebuildDeck() {
        var cards = PhoneticTranslator.allLetterPairs(mode: mode).map { pair in
            DrillCard(
                letter: pair.letter,
                word: pair.word
            )
        }
        if cardOrder == .random {
            cards.shuffle()
        }
        deck = cards
        selectedIndex = 0
        isFlipped = false
        dragOffset = 0
        dragY = 0
        isTransitioning = false
        flipPulse = 1.0
        flipGlow = 0.0
    }

    private func registerSwipeHintImpressionIfNeeded(for token: Int) {
        guard token != lastRegisteredVisitToken else { return }
        lastRegisteredVisitToken = token
        guard swipeHintSeenCount < 3 else {
            isShowingSwipeHint = false
            return
        }
        swipeHintSeenCount += 1
        isShowingSwipeHint = true
    }
}
