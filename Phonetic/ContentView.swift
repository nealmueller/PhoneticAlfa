import SwiftUI
import UIKit

struct ContentView: View {
    private let inputFontSize: CGFloat = 28
    private let outputFontSize: CGFloat = 28
    private let labelFontSize: CGFloat = 20
    private let outputMinHeight: CGFloat = 72

    @State private var inputText = ""
    @State private var showCopied = false
    @State private var outputTextHeight: CGFloat = 0
    @State private var outputWidth: CGFloat = 0
    @StateObject private var speechManager = SpeechManager()

    private var outputText: String {
        PhoneticTranslator.translate(inputText)
    }

    private var hasOutput: Bool {
        !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var outputHeight: CGFloat {
        max(outputMinHeight, outputTextHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type code")
                .font(.system(size: labelFontSize, weight: .semibold))

            HStack(spacing: 8) {
                TextField("", text: $inputText)
                    .frame(height: 48)
                    .padding(.horizontal, 12)
                    .font(.system(size: inputFontSize, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .accessibilityIdentifier("typeCodeField")
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
                .opacity(inputText.isEmpty ? 0.4 : 1.0)
            }

            Text("Phonetic readback")
                .font(.system(size: labelFontSize, weight: .semibold))

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))

                Text(outputText.isEmpty ? " " : outputText)
                    .font(.system(size: outputFontSize))
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
                    OutputTextHeightReader(text: outputText.isEmpty ? " " : outputText,
                                           fontSize: outputFontSize,
                                           width: max(0, outputWidth - 24)) { height in
                        outputTextHeight = height
                    }
                }
            )
            .onTapGesture {
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
            .opacity((hasOutput || speechManager.isSpeaking) ? 1.0 : 0.6)

            if let message = speechManager.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
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
    let fontSize: CGFloat
    let width: CGFloat
    let onChange: (CGFloat) -> Void

    var body: some View {
        Group {
            if width > 0 {
                Text(text)
                    .font(.system(size: fontSize))
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

#Preview {
    ContentView()
}
