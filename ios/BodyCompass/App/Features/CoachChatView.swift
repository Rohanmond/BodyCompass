import SwiftUI

struct CoachChatView: View {
    private enum AnswerTab: String, CaseIterable, Identifiable {
        case combined = "Combined"
        case openAI = "ChatGPT"
        case gemini = "Gemini"

        var id: Self { self }
    }

    @EnvironmentObject private var app: AppStore
    @EnvironmentObject private var training: TrainingStore
    @StateObject private var history = CoachHistoryStore()
    @State private var question = ""
    @State private var selectedTab: AnswerTab = .combined
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var proposalNotice: String?

    private let client = CoachAPIClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Answer source", selection: $selectedTab) {
                    ForEach(AnswerTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if training.proposal?.status == .pending {
                    NavigationLink {
                        RoutineProposalView()
                    } label: {
                        HStack {
                            Label("Review routine proposal", systemImage: "list.clipboard")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                conversation

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                composer
            }
            .padding()
            .background(Theme.background)
            .navigationTitle("Coach")
            .toolbar {
                if !history.exchanges.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            history.clear()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Clear Coach history")
                    }
                }
            }
            .alert("Coach proposal", isPresented: proposalNoticeBinding) {
                Button("OK", role: .cancel) { proposalNotice = nil }
            } message: {
                Text(proposalNotice ?? "")
            }
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if history.exchanges.isEmpty && !isSending {
                        ContentUnavailableView(
                            "Ask BodyCompass",
                            systemImage: "bubble.left.and.text.bubble.right",
                            description: Text("Ask about today's priorities, meals, progress, recovery, or your routine.")
                        )
                        .frame(minHeight: 300)
                    }

                    ForEach(history.exchanges) { exchange in
                        exchangeView(exchange)
                            .id(exchange.id)
                    }

                    if isSending {
                        HStack {
                            ProgressView()
                            Text("Checking your current data")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .id("loading")
                    }
                }
            }
            .onChange(of: history.exchanges.count) { _, _ in
                if let id = history.exchanges.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .onChange(of: isSending) { _, sending in
                if sending { withAnimation { proxy.scrollTo("loading", anchor: .bottom) } }
            }
        }
    }

    private func exchangeView(_ exchange: CoachExchange) -> some View {
        VStack(spacing: 10) {
            Text(exchange.question)
                .padding(12)
                .foregroundStyle(.white)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, alignment: .trailing)

            answerView(exchange.response)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func answerView(_ response: CoachAnswerBundle) -> some View {
        switch selectedTab {
        case .combined:
            answerPanel(
                answer: response.combined.answer,
                nextAction: response.combined.nextAction,
                safetyNotice: response.combined.safetyNotice,
                source: response.combined.confidence == "dual_provider" ? "Two-provider check" : "Single-provider fallback",
                proposal: response.combined.routineProposal
            )
        case .openAI:
            providerPanel(response.openai)
        case .gemini:
            providerPanel(response.gemini)
        }
    }

    @ViewBuilder
    private func providerPanel(_ provider: CoachProviderAnswer) -> some View {
        if let answer = provider.answer, let nextAction = provider.nextAction {
            answerPanel(
                answer: answer,
                nextAction: nextAction,
                safetyNotice: provider.safetyNotice ?? "",
                source: provider.mode == "live" ? "Live response" : "Demo response",
                proposal: provider.routineProposal
            )
        } else {
            Label(provider.error ?? "This provider did not return an answer.", systemImage: "wifi.exclamationmark")
                .padding(12)
                .foregroundStyle(Theme.warning)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func answerPanel(
        answer: String,
        nextAction: String,
        safetyNotice: String,
        source: String,
        proposal: CoachRoutineInstruction?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(source).font(.caption).foregroundStyle(.secondary)
            Text(answer)
            if !safetyNotice.isEmpty {
                Label(safetyNotice, systemImage: "cross.case.fill")
                    .font(.callout)
                    .foregroundStyle(Theme.warning)
            }
            Label(nextAction, systemImage: "arrow.right.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            if let proposal {
                Label(proposal.summary, systemImage: "list.clipboard")
                    .font(.callout.weight(.semibold))
            }
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your coach", text: $question, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedQuestion.isEmpty || isSending)
            .accessibilityLabel("Send question")
        }
    }

    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        let message = trimmedQuestion
        guard !message.isEmpty, !isSending else { return }
        question = ""
        errorMessage = nil
        isSending = true
        Task {
            do {
                let response = try await client.ask(
                    message: message,
                    app: app,
                    training: training,
                    exchanges: history.exchanges
                )
                history.append(question: message, response: response)
                if let instruction = response.combined.routineProposal {
                    handleProposalResult(training.createProposal(from: instruction))
                }
            } catch {
                errorMessage = error.localizedDescription
                question = message
            }
            isSending = false
        }
    }

    private func handleProposalResult(_ result: TrainingStore.CoachInstructionResult) {
        switch result {
        case .created:
            proposalNotice = "Coach created a routine proposal. Review it before deciding whether to apply it."
        case .needsSetup:
            proposalNotice = "Complete Training Setup before Coach can propose routine changes."
        case .alreadyPending:
            proposalNotice = "A routine proposal is already waiting for your decision."
        case let .invalid(message):
            proposalNotice = message
        }
    }

    private var proposalNoticeBinding: Binding<Bool> {
        Binding(get: { proposalNotice != nil }, set: { if !$0 { proposalNotice = nil } })
    }
}
