import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var training: TrainingStore
    @EnvironmentObject private var authentication: AuthenticationStore

    var body: some View {
        Group {
            switch authentication.state {
            case .checking:
                ProgressView("Checking your account...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            case .signedOut:
                AuthenticationView()
            case .signedIn:
                if store.hasCompletedOnboarding {
                    mainTabs
                } else {
                    OnboardingView()
                }
            }
        }
        .onChange(of: authentication.user?.id, initial: true) { _, userID in
            guard let userID else { return }
            if store.bindToAuthenticatedUser(userID) {
                training.deleteAllTrainingData()
            }
            Task { await store.syncNow() }
        }
    }

    private var mainTabs: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "target") }

            MealLogView()
                .tabItem { Label("Meals", systemImage: "camera.viewfinder") }

            GoalView()
                .tabItem { Label("Goal", systemImage: "chart.line.uptrend.xyaxis") }

            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }

            CoachChatView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
        }
        .tint(Theme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}

private struct AuthenticationView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case createAccount = "Create Account"
        var id: Self { self }
    }

    @EnvironmentObject private var authentication: AuthenticationStore
    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var message: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, confirmation }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "scope")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.accent)
                        Text("BodyCompass")
                            .font(.largeTitle.bold())
                        Text("Your health plan, progress, and coaching stay connected to your private account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Account action", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 16) {
                        if mode == .createAccount {
                            field("Name", text: $name, contentType: .name, field: .name)
                        }
                        field("Email", text: $email, contentType: .emailAddress, field: .email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        secureField("Password", text: $password, contentType: mode == .signIn ? .password : .newPassword, field: .password)
                        if mode == .createAccount {
                            secureField("Confirm password", text: $confirmation, contentType: .newPassword, field: .confirmation)
                        }
                    }

                    if let message {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Theme.coral)
                    }

                    Button(action: submit) {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(mode.rawValue).fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(isWorking || !canSubmit)

                    Label("Meal and progress photos are analyzed transiently and are never saved to your history or backup.", systemImage: "hand.raised.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .onChange(of: mode) { _, _ in
                message = nil
                password = ""
                confirmation = ""
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= (mode == .createAccount ? 10 : 1)
            && (mode == .signIn || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password == confirmation))
    }

    private func field(_ title: String, text: Binding<String>, contentType: UITextContentType, field: Field) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .submitLabel(.next)
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: 44)
    }

    private func secureField(_ title: String, text: Binding<String>, contentType: UITextContentType, field: Field) -> some View {
        SecureField(title, text: text)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .submitLabel(field == .confirmation || mode == .signIn ? .go : .next)
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: 44)
    }

    private func submit() {
        guard canSubmit else { return }
        focusedField = nil
        isWorking = true
        message = nil
        Task {
            do {
                if mode == .signIn {
                    try await authentication.login(email: email, password: password)
                } else {
                    try await authentication.register(displayName: name, email: email, password: password)
                }
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }
}
