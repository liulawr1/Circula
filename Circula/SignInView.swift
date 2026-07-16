//
//  SignInView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var store: MarketplaceStore

    @Binding var isSignedIn: Bool
    @Binding var currentUserName: String
    @Binding var currentUserEmail: String
    @Binding var currentUserID: String
    @Binding var accessToken: String
    @Binding var refreshToken: String

    @State private var authMode = AuthMode.signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isWorking = false

    enum AuthMode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    var cleanedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isHrsEmail: Bool {
        cleanedEmail.hasSuffix("@headroyce.org")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(CirculaTheme.forest)
                        .padding(14)
                        .background(Color.white.opacity(0.75))
                        .clipShape(Circle())

                    Text("Circula")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(CirculaTheme.ink)

                    Text("A school-only marketplace for trading, selling, and sharing supplies.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Picker("Mode", selection: $authMode) {
                        ForEach(AuthMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: authMode) {
                        errorMessage = ""
                        successMessage = ""
                        password = ""
                        confirmPassword = ""
                    }

                    if authMode == .signUp {
                        TextField("Full name", text: $name)
                            .autocapitalization(.words)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("HRS email", text: $email)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(authMode == .signUp ? .oneTimeCode : .password)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    if authMode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            await submit()
                        }
                    } label: {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(authMode.rawValue)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(CirculaTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(isWorking)
                }
                .padding(.horizontal)
                .circulaCard()

                VStack(spacing: 8) {
                    Label("Supabase authentication", systemImage: "lock.shield")
                    Label("Head-Royce email required", systemImage: "checkmark.shield")
                    Label("Email confirmation blocks fake accounts", systemImage: "envelope.badge.shield.half.filled")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .background(CirculaBackground())
            .scrollDismissesKeyboard(.interactively)
            .tint(CirculaTheme.forest)
            .onSubmit {
                KeyboardHelper.dismiss()

                Task {
                    await submit()
                }
            }
        }
    }

    func submit() async {
        errorMessage = ""
        successMessage = ""

        guard !cleanedEmail.isEmpty,
              !password.isEmpty else {
            errorMessage = "Enter your school email and password."
            return
        }

        guard isHrsEmail else {
            errorMessage = "Please use your Head-Royce school email."
            return
        }

        if authMode == .signUp {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Enter your full name."
                return
            }

            guard password.count >= 6 else {
                errorMessage = "Use a password with at least 6 characters."
                return
            }

            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
        }

        isWorking = true
        defer { isWorking = false }

        do {
            switch authMode {
            case .signIn:
                let session = try await store.signIn(
                    email: cleanedEmail,
                    password: password
                )
                apply(session)

            case .signUp:
                _ = try await store.signUp(
                    email: cleanedEmail,
                    password: password,
                    name: name
                )

                authMode = .signIn
                name = ""
                email = ""
                password = ""
                confirmPassword = ""
                successMessage = "Check your Head-Royce email to verify your account, then sign in."
            }
        } catch {
            errorMessage = message(for: error)
        }
    }

    func apply(_ session: AuthSession) {
        currentUserName = session.displayName
        currentUserEmail = session.email
        currentUserID = session.userID.uuidString
        accessToken = session.accessToken
        refreshToken = session.refreshToken
        isSignedIn = true
    }

    func message(for error: Error) -> String {
        if let error = error as? SupabaseRESTClient.APIError {
            switch error {
            case .missingConfig:
                return "Supabase config is missing."
            case .unauthorized:
                return "Login failed. Check your email and password."
            case .forbidden:
                return "Supabase blocked this login. Check the auth SQL setup."
            case .auth(let message):
                return readableAuthMessage(message)
            case .server(let message):
                return readableAuthMessage(message)
            case .invalidResponse:
                return "Supabase returned an unexpected login response."
            }
        }

        return "Login failed. Please try again."
    }

    func readableAuthMessage(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("over_email_send_rate_limit") ||
            message.localizedCaseInsensitiveContains("rate limit") {
            return "Too many verification emails were sent. Wait a few minutes, then try again."
        }

        if message.localizedCaseInsensitiveContains("email not confirmed") {
            return "Please verify your email before signing in."
        }

        return message
    }
}
