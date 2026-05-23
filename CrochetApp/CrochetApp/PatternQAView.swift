import SwiftUI

struct QAPair: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

@available(macOS 26.0, *)
struct PatternQAView: View {
    @ObservedObject var service: PatternAIService
    let patternID: UUID
    let patternText: String

    @State private var question: String = ""
    @State private var isAsking: Bool = false
    @State private var errorMessage: String? = nil

    private var history: [QAPair] { service.qaHistory[patternID] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !history.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(history) { pair in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pair.question)
                                    .font(Typo.bodyText.weight(.semibold))
                                    .foregroundColor(.textPrimary)
                                Text(pair.answer)
                                    .font(Typo.bodyText)
                                    .foregroundColor(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 200)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 8) {
                TextField("Ask anything about this pattern…", text: $question)
                    .textFieldStyle(.plain)
                    .font(Typo.bodyText)
                    .padding(8)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { askQuestion() }
                    .disabled(isAsking)

                if isAsking {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                } else {
                    Button {
                        askQuestion()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(question.isEmpty ? .secondary : Color.appAccent)
                    }
                    .buttonStyle(.plain)
                    .disabled(question.isEmpty)
                    .accessibilityLabel("Send question")
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func askQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAsking = true
        errorMessage = nil
        let asked = trimmed
        question = ""
        Task {
            do {
                let answer = try await service.answerQuestion(asked, patternText: patternText)
                service.qaHistory[patternID, default: []].append(QAPair(question: asked, answer: answer))
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isAsking = false
        }
    }
}
