import SwiftUI
import UIKit

struct SpeakTabView: View {
    @AppStorage(AppPreferences.phoneticModeKey) private var phoneticModeRaw = PhoneticMode.nato.rawValue

    @State private var inputText = ""
    @State private var showCopied = false
    @State private var outputTextHeight: CGFloat = 0
    @State private var outputWidth: CGFloat = 0
    @StateObject private var speechManager = SpeechManager()

    private let outputMinHeight: CGFloat = 72

    private var phoneticMode: PhoneticMode {
        AppPreferences.mode(from: phoneticModeRaw)
    }

    private var outputText: String {
        PhoneticTranslator.translate(inputText, mode: phoneticMode)
    }

    private var hasOutput: Bool {
        !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var outputHeight: CGFloat {
        max(outputMinHeight, outputTextHeight)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Speak")
                    .font(.largeTitle.weight(.bold))

                Text("Alphabet: \(phoneticMode.title)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter text")
                        .font(.headline)

                    HStack(spacing: 8) {
                        TextField("Code", text: $inputText)
                            .frame(height: 48)
                            .padding(.horizontal, 12)
                            .font(.system(.title3, design: .monospaced, weight: .medium))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.asciiCapable)
                            .submitLabel(.done)
                            .accessibilityIdentifier("enterTextField")
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                            .onChange(of: inputText) { _, _ in
                                if inputText.count > 30 {
                                    inputText = String(inputText.prefix(30))
                                }
                                speechManager.lastErrorMessage = nil
                            }

                        Button("Clear") {
                            inputText = ""
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("clearButton")
                        .disabled(inputText.isEmpty)
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Phonetic readback")
                        .font(.headline)

                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))

                        Text(outputText.isEmpty ? " " : outputText)
                            .font(.title3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)

                        if showCopied {
                            Text("Copied")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                                .padding(10)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: outputHeight, alignment: .topLeading)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("phoneticReadbackView")
                    .background(
                        ZStack {
                            OutputWidthReader { width in
                                outputWidth = width
                            }
                            OutputTextHeightReader(
                                text: outputText.isEmpty ? " " : outputText,
                                width: max(0, outputWidth - 24)
                            ) { height in
                                outputTextHeight = height
                            }
                        }
                    )
                    .onTapGesture {
                        guard hasOutput else { return }
                        UIPasteboard.general.string = outputText
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCopied = false
                            }
                        }
                    }

                    Button {
                        if speechManager.isSpeaking {
                            speechManager.stop()
                        } else {
                            speechManager.speak(outputText)
                        }
                    } label: {
                        Text(speechManager.isSpeaking ? "Stop" : "Speak")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("speakButton")
                    .disabled(!hasOutput && !speechManager.isSpeaking)

                    if let message = speechManager.lastErrorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle()
            }
            .padding()
        }
        .background(AppTheme.gradientBackground.ignoresSafeArea())
    }
}

private struct OutputWidthReader: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    onChange(proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, newValue in
                    onChange(newValue)
                }
        }
    }
}

private struct OutputTextHeightReader: View {
    let text: String
    let width: CGFloat
    let onChange: (CGFloat) -> Void

    var body: some View {
        Group {
            if width > 0 {
                Text(text)
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: width, alignment: .leading)
                    .padding(12)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: OutputHeightKey.self, value: proxy.size.height)
                        }
                    )
                    .onPreferenceChange(OutputHeightKey.self) { newValue in
                        onChange(newValue)
                    }
                    .hidden()
            }
        }
    }
}

private struct OutputHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
