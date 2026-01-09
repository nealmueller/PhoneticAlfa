import SwiftUI
import UIKit

struct ContentView: View {
    @State private var inputText = ""
    @State private var showCopied = false
    @StateObject private var speechManager = SpeechManager()

    private var outputText: String {
        PhoneticTranslator.translate(inputText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Input")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    inputText = ""
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("clearButton")
            }

            TextEditor(text: $inputText)
                .frame(minHeight: 140)
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .accessibilityIdentifier("inputEditor")
                .accessibilityElement(children: .contain)

            Text("Output")
                .font(.headline)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))

                Text(outputText.isEmpty ? " " : outputText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
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
            .accessibilityIdentifier("outputView")
            .accessibilityElement(children: .contain)
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

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
