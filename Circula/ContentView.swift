//
//  ContentView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/5/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MarketplaceStore

    @AppStorage("hasAcceptedTerms") private var hasAcceptedTerms = false
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("isGuestMode") private var isGuestMode = false
    @AppStorage("currentUserName") private var storedCurrentUserName = ""
    @AppStorage("currentUserEmail") private var currentUserEmail = ""
    @AppStorage("currentUserID") private var currentUserID = ""
    @AppStorage("accessToken") private var accessToken = ""
    @AppStorage("refreshToken") private var refreshToken = ""

    @State private var didRestoreSession = false
    @State private var authCallbackTitle = ""
    @State private var authCallbackMessage = ""

    init() {
        let defaults = UserDefaults.standard
        let previouslyAccepted = defaults.bool(forKey: "hasAcceptedTerms") ||
            !(defaults.string(forKey: "acceptedTermsVersion") ?? "").isEmpty

        if previouslyAccepted {
            defaults.set(true, forKey: "hasAcceptedTerms")
        }

        hasAcceptedTerms = previouslyAccepted
    }

    var currentUserName: String {
        if !storedCurrentUserName.isEmpty {
            return storedCurrentUserName
        }

        if currentUserEmail.isEmpty {
            return "Student"
        }

        let emailName = currentUserEmail.components(separatedBy: "@").first ?? "Student"
        let nameParts = emailName
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")

        if nameParts.isEmpty {
            return "Student"
        }

        return nameParts
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst() }
            .joined(separator: " ")
    }

    var body: some View {
        Group {
            if !hasAcceptedTerms {
                TermsOfUseView {
                    hasAcceptedTerms = true
                }
            } else if isSignedIn && !accessToken.isEmpty {
                MainTabView(
                    currentUserName: currentUserName,
                    currentUserEmail: currentUserEmail
                ) {
                    signOut()
                }
                .task {
                    await restoreSessionAndConfigure()
                }
            } else if isGuestMode {
                GuestMainView {
                    exitGuestMode()
                }
            } else {
                SignInView(
                    isSignedIn: $isSignedIn,
                    currentUserName: $storedCurrentUserName,
                    currentUserEmail: $currentUserEmail,
                    currentUserID: $currentUserID,
                    accessToken: $accessToken,
                    refreshToken: $refreshToken
                ) {
                    enterGuestMode()
                }
            }
        }
        .keyboardDismissControls()
        .tapToDismissKeyboard()
        .onOpenURL { url in
            handleAuthCallback(url)
        }
        .alert(authCallbackTitle, isPresented: Binding(
            get: { !authCallbackTitle.isEmpty },
            set: { isPresented in
                if !isPresented {
                    authCallbackTitle = ""
                    authCallbackMessage = ""
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authCallbackMessage)
        }
    }

    func restoreSessionAndConfigure() async {
        guard !didRestoreSession else {
            return
        }

        didRestoreSession = true

        if !refreshToken.isEmpty {
            do {
                let session = try await store.refreshSession(refreshToken: refreshToken)
                storedCurrentUserName = session.displayName
                currentUserEmail = session.email
                currentUserID = session.userID.uuidString
                accessToken = session.accessToken
                refreshToken = session.refreshToken
            } catch {
                if shouldEndSession(after: error) {
                    signOut()
                    return
                }
            }
        }

        store.configureCurrentUser(
            name: currentUserName,
            email: currentUserEmail,
            accessToken: accessToken
        )
    }

    func shouldEndSession(after error: Error) -> Bool {
        guard let apiError = error as? SupabaseRESTClient.APIError else {
            return false
        }

        switch apiError {
        case .unauthorized, .auth:
            return true
        case .missingConfig, .forbidden, .server, .invalidResponse:
            return false
        }
    }

    func enterGuestMode() {
        isGuestMode = true
        didRestoreSession = false
        store.clearSession()
    }

    func exitGuestMode() {
        isGuestMode = false
        didRestoreSession = false
        store.clearSession()
    }

    func signOut() {
        isSignedIn = false
        isGuestMode = false
        storedCurrentUserName = ""
        currentUserEmail = ""
        currentUserID = ""
        accessToken = ""
        refreshToken = ""
        didRestoreSession = false
        store.clearSession()
    }

    func handleAuthCallback(_ url: URL) {
        guard url.scheme == "circula" else {
            return
        }

        if let errorDescription = authCallbackValue("error_description", in: url) {
            authCallbackTitle = "Verification Link Expired"
            authCallbackMessage = errorDescription.replacingOccurrences(of: "+", with: " ")
            return
        }

        guard url.host == "email-verified" else {
            return
        }

        authCallbackTitle = "Email Verified"
        authCallbackMessage = "Thank you for verifying your email. You can now sign in to Circula."
    }

    func authCallbackValue(_ name: String, in url: URL) -> String? {
        if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value {
            return value
        }

        guard let fragment = url.fragment,
              let components = URLComponents(string: "circula://callback?\(fragment)") else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == name })?.value
    }
}

struct GuestMainView: View {
    @EnvironmentObject private var store: MarketplaceStore

    let onSignIn: () -> Void

    var body: some View {
        TabView {
            BrowseView(
                currentUserName: "Guest",
                currentUserEmail: "",
                isGuest: true,
                onSignIn: onSignIn
            )
            .tabItem {
                Label("Browse", systemImage: "magnifyingglass")
            }

            NavigationStack {
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 58))
                        .foregroundStyle(CirculaTheme.forest)

                    Text("Join Circula")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(CirculaTheme.ink)

                    Text("You can browse listings as a guest. Sign in with a Head-Royce account to post, save items, and message other students.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Button(action: onSignIn) {
                        Label("Sign In or Create Account", systemImage: "person.badge.key")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(CirculaTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
                .background(CirculaBackground())
                .navigationTitle("Account")
            }
            .tabItem {
                Label("Sign In", systemImage: "person.circle")
            }
        }
        .tint(CirculaTheme.forest)
        .task {
            await store.configureGuest()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: MarketplaceStore

    let currentUserName: String
    let currentUserEmail: String
    let onSignOut: () -> Void

    var body: some View {
        TabView {
            BrowseView(
                currentUserName: currentUserName,
                currentUserEmail: currentUserEmail
            )
                .tabItem {
                    Label("Browse", systemImage: "magnifyingglass")
                }

            NavigationStack {
                CreateListingView(
                    currentUserName: currentUserName,
                    currentUserEmail: currentUserEmail
                )
            }
            .tabItem {
                Label("Post", systemImage: "plus.circle")
            }

            MessagesView(
                currentUserName: currentUserName,
                currentUserEmail: currentUserEmail
            )
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right")
                }

            ActivityView(
                currentUserEmail: currentUserEmail,
                listings: store.listings,
                savedListingIDs: store.savedListingIDs
            )
            .tabItem {
                Label("Activity", systemImage: "bell")
            }

            ProfileView(
                currentUserName: currentUserName,
                currentUserEmail: currentUserEmail,
                onSignOut: onSignOut
            )
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .tint(CirculaTheme.forest)
    }
}

#Preview {
    ContentView()
        .environmentObject(MarketplaceStore.preview)
}
