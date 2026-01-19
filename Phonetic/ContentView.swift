import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText = ""
    @State private var showCopied = false
    @StateObject private var speechManager = SpeechManager()

    private var outputText: String {
        PhoneticTranslator.translate(inputText)
    }

    private var hasOutput: Bool {
        !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("", text: $inputText)
                    .frame(height: 48)
                    .padding(.horizontal, 12)
                    .font(.system(size: 24, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .onChange(of: inputText) { _, _ in
                        speechManager.lastErrorMessage = nil
                    }

                Button("Clear") {
                    inputText = ""
                }
                .buttonStyle(.bordered)
                .disabled(inputText.isEmpty)
                .opacity(inputText.isEmpty ? 0.4 : 1.0)
            }

            Text("Output")
                .font(.headline)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))

                Text(outputText.isEmpty ? " " : outputText)
                    .font(.system(size: 24))
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
            .contentShape(RoundedRectangle(cornerRadius: 12))
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
            .disabled(!hasOutput && !speechManager.isSpeaking)
            .opacity((hasOutput || speechManager.isSpeaking) ? 1.0 : 0.6)

            if let message = speechManager.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
