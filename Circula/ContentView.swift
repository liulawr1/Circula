//
//  ContentView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/5/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MarketplaceStore

    @AppStorage("acceptedTermsVersion") private var acceptedTermsVersion = ""
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("currentUserName") private var storedCurrentUserName = ""
    @AppStorage("currentUserEmail") private var currentUserEmail = ""
    @AppStorage("currentUserID") private var currentUserID = ""
    @AppStorage("accessToken") private var accessToken = ""
    @AppStorage("refreshToken") private var refreshToken = ""

    @State private var didRestoreSession = false
    @State private var authCallbackTitle = ""
    @State private var authCallbackMessage = ""

    private let currentTermsVersion = "2026-07-22"

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
            if acceptedTermsVersion != currentTermsVersion {
                TermsOfUseView {
                    acceptedTermsVersion = currentTermsVersion
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
            } else {
                SignInView(
                    isSignedIn: $isSignedIn,
                    currentUserName: $storedCurrentUserName,
                    currentUserEmail: $currentUserEmail,
                    currentUserID: $currentUserID,
                    accessToken: $accessToken,
                    refreshToken: $refreshToken
                )
            }
        }
        .keyboardDismissControls()
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
                signOut()
                return
            }
        }

        store.configureCurrentUser(
            name: currentUserName,
            email: currentUserEmail,
            accessToken: accessToken
        )
    }

    func signOut() {
        isSignedIn = false
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
