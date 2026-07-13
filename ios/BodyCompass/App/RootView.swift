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
    @EnvironmentObject private var authentication: AuthenticationStore
    @State private var email = ""
    @State private var code = ""
    @State private var challenge: EmailCodeChallenge?
    @State private var isWorking = false
    @State private var message: String?
    @State private var resendSeconds = 0
    @FocusState private var focusedField: Field?

    private enum Field { case email, code }

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

                    if challenge == nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Sign in with email")
                                .font(.title3.bold())
                            Text("We will email you a six-digit code. The same secure flow creates your account the first time.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.go)
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 44)
                                .onSubmit(requestCode)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Label(email, systemImage: "envelope.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Enter your code")
                                .font(.title3.bold())
                            TextField("000000", text: $code)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .code)
                                .multilineTextAlignment(.center)
                                .font(.title2.monospacedDigit().weight(.semibold))
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 52)
                                .onChange(of: code) { _, value in
                                    code = String(value.filter(\.isNumber).prefix(6))
                                }

                            HStack {
                                Button("Change email") { reset() }
                                Spacer()
                                Button(resendSeconds > 0 ? "Resend in \(resendSeconds)s" : "Resend code") { requestCode() }
                                    .disabled(resendSeconds > 0 || isWorking)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }

                    if let message {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Theme.coral)
                    }

                    Button(action: challenge == nil ? requestCode : verifyCode) {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(challenge == nil ? "Email me a code" : "Verify and continue").fontWeight(.semibold)
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
            .task(id: resendSeconds) {
                guard resendSeconds > 0 else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                resendSeconds -= 1
            }
        }
    }

    private var canSubmit: Bool {
        if challenge == nil {
            return email.contains("@") && email.contains(".")
        }
        return code.count == 6
    }

    private func requestCode() {
        guard email.contains("@"), !isWorking else { return }
        focusedField = nil
        isWorking = true
        message = nil
        Task {
            do {
                let result = try await authentication.requestEmailCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                challenge = result
                resendSeconds = 60
                code = result.developmentCode ?? ""
                message = result.developmentCode == nil ? "Code sent. Check your inbox and spam folder." : "Local development code filled in."
                focusedField = .code
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func verifyCode() {
        guard let challenge, code.count == 6, !isWorking else { return }
        focusedField = nil
        isWorking = true
        message = nil
        Task {
            do {
                try await authentication.verifyEmailCode(challengeId: challenge.challengeId, code: code)
            } catch {
                message = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func reset() {
        challenge = nil
        code = ""
        message = nil
        resendSeconds = 0
        focusedField = .email
    }
}
