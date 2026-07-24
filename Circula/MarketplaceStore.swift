//
//  MarketplaceStore.swift
//  Circula
//

import Combine
import Foundation

struct AuthSession {
    let userID: UUID
    let email: String
    let accessToken: String
    let refreshToken: String
    let displayName: String
}

@MainActor
final class MarketplaceStore: ObservableObject {
    @Published private(set) var listings: [Listing]
    @Published private(set) var savedListingIDs: Set<UUID> = []
    @Published private(set) var reports: [ListingReport] = []
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var messagesByConversationID: [UUID: [ChatMessage]] = [:]
    @Published private(set) var blockedUserEmails: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var syncError: String?
    @Published private(set) var isCloudConnected = false
    @Published private(set) var lastSyncedAt: Date?

    private let client: SupabaseRESTClient?
    private var currentUserName = ""
    private var currentUserEmail = ""
    private let moderatorEmails = Set([
        "lawrencel2026@headroyce.org"
    ])

    private var cacheURL: URL? {
        guard !currentUserEmail.isEmpty else {
            return nil
        }

        let cacheID = UUIDv5.make(name: "cache-\(currentUserEmail)").uuidString
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("marketplace-cache-\(cacheID)")
            .appendingPathExtension("json")
    }

    init(useSampleData: Bool = false, client: SupabaseRESTClient? = nil) {
        self.client = client ?? SupabaseRESTClient.fromBundleConfig()
        self.listings = useSampleData ? Listing.sampleListings : []
    }

    static var preview: MarketplaceStore {
        MarketplaceStore(useSampleData: true, client: nil)
    }

    func configureCurrentUser(name: String, email: String, accessToken: String? = nil) {
        let normalizedEmail = email.lowercased()
        if currentUserEmail != normalizedEmail {
            listings = []
            savedListingIDs = []
            reports = []
            conversations = []
            messagesByConversationID = [:]
        }

        currentUserName = name
        currentUserEmail = normalizedEmail
        client?.setAccessToken(accessToken)
        loadBlockedUsers()
        loadLocalCache()

        Task {
            await refreshAll()
        }
    }

    func configureGuest() async {
        currentUserName = "Guest"
        currentUserEmail = ""
        client?.setAccessToken(nil)
        savedListingIDs = []
        reports = []
        conversations = []
        messagesByConversationID = [:]
        loadBlockedUsers()

        await refreshPublicListings()
    }

    func clearSession() {
        currentUserName = ""
        currentUserEmail = ""
        listings = []
        savedListingIDs = []
        reports = []
        conversations = []
        messagesByConversationID = [:]
        blockedUserEmails = []
        syncError = nil
        isCloudConnected = false
        lastSyncedAt = nil
        client?.setAccessToken(nil)
    }

    func signUp(email: String, password: String, name: String) async throws -> AuthSession? {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedEmail.hasSuffix("@headroyce.org") else {
            throw SupabaseRESTClient.APIError.auth("Please use your Head-Royce school email.")
        }

        guard let client else {
            throw SupabaseRESTClient.APIError.missingConfig
        }

        let session = try await client.signUp(
            email: cleanedEmail,
            password: password,
            displayName: cleanedName.isEmpty ? displayName(from: cleanedEmail) : cleanedName
        )

        if let session {
            client.setAccessToken(session.accessToken)
            try await client.upsertProfile(session: session)
        }

        return session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard cleanedEmail.hasSuffix("@headroyce.org") else {
            throw SupabaseRESTClient.APIError.auth("Please use your Head-Royce school email.")
        }

        guard let client else {
            throw SupabaseRESTClient.APIError.missingConfig
        }

        let session = try await client.signInWithPassword(
            email: cleanedEmail,
            password: password
        )
        client.setAccessToken(session.accessToken)
        try? await client.upsertProfile(session: session)
        return session
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        guard let client else {
            throw SupabaseRESTClient.APIError.missingConfig
        }

        let session = try await client.refreshSession(refreshToken: refreshToken)
        client.setAccessToken(session.accessToken)
        return session
    }

    func deleteCurrentAccount() async throws {
        guard let client else {
            throw SupabaseRESTClient.APIError.missingConfig
        }

        try await client.deleteCurrentAccount()
        if let cacheURL {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        UserDefaults.standard.removeObject(forKey: blockedUsersDefaultsKey())
        clearSession()
    }

    func refreshAll() async {
        if currentUserEmail.isEmpty {
            await refreshPublicListings()
            return
        }

        guard let client else {
            syncError = "Supabase config needed. Add your project URL and anon key to SupabaseConfig.plist."
            isCloudConnected = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedListings = try await client.fetchListings()
            let fetchedSavedIDs = try await client.fetchSavedListingIDs(for: currentUserEmail)
            let fetchedConversations = try await client.fetchConversations(for: currentUserEmail)
            let fetchedReports = moderatorEmails.contains(currentUserEmail)
                ? try await client.fetchReports()
                : []

            listings = filteredListings(fetchedListings)
            let visibleListingIDs = Set(listings.map(\.id))
            savedListingIDs = Set(fetchedSavedIDs.filter { visibleListingIDs.contains($0) })
            reports = fetchedReports
            conversations = filteredConversations(fetchedConversations)
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            saveLocalCache()
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
        }
    }

    func refreshPublicListings() async {
        guard let client else {
            syncError = "Circula could not connect. Check your internet connection and try again."
            isCloudConnected = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedListings = try await client.fetchPublicListings()
            listings = filteredListings(fetchedListings)
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
        }
    }

    func createListing(_ listing: Listing) async -> Bool {
        guard let client else {
            syncError = "Circula could not connect. Your listing was not posted."
            isCloudConnected = false
            return false
        }

        do {
            let savedListing = try await client.upsertListing(listing)
            upsertListing(savedListing)
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            saveLocalCache()
            return true
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return false
        }
    }

    func updateListingStatus(listingID: UUID, status: String) async -> Bool {
        guard let client else {
            syncError = "Circula could not connect. The status was not changed."
            isCloudConnected = false
            return false
        }

        do {
            try await client.updateListingStatus(listingID: listingID, status: status)
            if let listingIndex = listings.firstIndex(where: { $0.id == listingID }) {
                listings[listingIndex].status = status
            }
            saveLocalCache()
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            return true
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return false
        }
    }

    func deleteListing(id: UUID) async -> Bool {
        guard let client else {
            syncError = "Circula could not connect. The listing was not deleted."
            isCloudConnected = false
            return false
        }

        do {
            try await client.deleteListing(id: id)
            listings.removeAll { $0.id == id }
            savedListingIDs.remove(id)
            saveLocalCache()
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            return true
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return false
        }
    }

    func toggleSavedListing(id: UUID) async -> Bool {
        guard !currentUserEmail.isEmpty else {
            return false
        }

        let shouldSave = !savedListingIDs.contains(id)

        guard let client else {
            syncError = "Circula could not connect. The saved item was not changed."
            isCloudConnected = false
            return false
        }

        do {
            if shouldSave {
                try await client.saveListing(id: id, userEmail: currentUserEmail)
            } else {
                try await client.unsaveListing(id: id, userEmail: currentUserEmail)
            }

            if shouldSave {
                savedListingIDs.insert(id)
            } else {
                savedListingIDs.remove(id)
            }
            saveLocalCache()
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            return true
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return false
        }
    }

    func reportListing(_ report: ListingReport) async -> Bool {
        guard let client else {
            syncError = "Circula could not connect. The report was not submitted."
            isCloudConnected = false
            return false
        }

        do {
            try await client.upsertReport(report)
            if moderatorEmails.contains(currentUserEmail) {
                reports.append(report)
                saveLocalCache()
            }
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            return true
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return false
        }
    }

    func updateReportStatus(reportID: UUID, status: String) async {
        guard let index = reports.firstIndex(where: { $0.id == reportID }) else {
            return
        }

        let previousStatus = reports[index].status
        reports[index].status = status
        saveLocalCache()

        guard let client else {
            syncError = "Supabase config needed. Report status saved on this device only."
            isCloudConnected = false
            return
        }

        do {
            try await client.updateReportStatus(reportID: reportID, status: status)
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
        } catch {
            if let currentIndex = reports.firstIndex(where: { $0.id == reportID }) {
                reports[currentIndex].status = previousStatus
                saveLocalCache()
            }
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
        }
    }

    func conversation(for listing: Listing) async -> Conversation? {
        guard !currentUserEmail.isEmpty,
              listing.ownerEmail.lowercased() != currentUserEmail else {
            return nil
        }

        let conversationID = deterministicConversationID(for: listing.id, buyerEmail: currentUserEmail)

        guard let client else {
            syncError = "Circula could not connect. The conversation could not be opened."
            isCloudConnected = false
            return nil
        }

        do {
            let conversation = try await client.upsertConversation(
                localConversation(for: listing, id: conversationID)
            )
            upsertConversation(conversation)
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            saveLocalCache()
            return conversation
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return nil
        }
    }

    func loadMessages(for conversationID: UUID) async {
        guard let client else {
            syncError = "Supabase config needed. Messages are stored on this device only."
            isCloudConnected = false
            return
        }

        do {
            messagesByConversationID[conversationID] = try await client.fetchMessages(for: conversationID)
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            saveLocalCache()
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
        }
    }

    func sendMessage(_ text: String, in conversation: Conversation) async -> Bool {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedText.isEmpty else {
            return false
        }

        let message = ChatMessage(
            conversationID: conversation.id,
            text: cleanedText,
            senderEmail: currentUserEmail,
            senderName: currentUserName,
            createdAt: Date()
        )

        var updatedConversation = conversation
        updatedConversation.lastMessage = cleanedText
        updatedConversation.updatedAt = message.createdAt

        guard let client else {
            syncError = "Circula could not connect. Your message was not sent."
            isCloudConnected = false
            return false
        }

        do {
            try await client.upsertMessage(message)
            try await client.updateConversationPreview(updatedConversation)
            messagesByConversationID[conversation.id, default: []].append(message)
            upsertConversation(updatedConversation)
            saveLocalCache()
            syncError = nil
            isCloudConnected = true
            lastSyncedAt = Date()
            return true
        } catch {
            syncError = friendlySyncError(for: error)
            isCloudConnected = false
            return false
        }
    }

    func isUserBlocked(_ email: String) -> Bool {
        blockedUserEmails.contains(normalizedEmail(email))
    }

    func isConversationBlocked(_ conversation: Conversation) -> Bool {
        isUserBlocked(conversation.otherStudentEmail(for: currentUserEmail))
    }

    func blockUser(email: String) {
        let email = normalizedEmail(email)

        guard !email.isEmpty,
              email != currentUserEmail else {
            return
        }

        blockedUserEmails.insert(email)
        saveBlockedUsers()
        removeBlockedContent()
        saveLocalCache()
    }

    func unblockUser(email: String) {
        blockedUserEmails.remove(normalizedEmail(email))
        saveBlockedUsers()

        Task {
            await refreshAll()
        }
    }
}

private extension MarketplaceStore {
    struct CacheSnapshot: Codable {
        let listings: [Listing]
        let savedListingIDs: Set<UUID>
        let reports: [ListingReport]
        let conversations: [Conversation]
        let messageThreads: [MessageThread]
    }

    struct MessageThread: Codable {
        let conversationID: UUID
        let messages: [ChatMessage]
    }

    func blockedUsersDefaultsKey() -> String {
        "blocked-users-\(currentUserEmail)"
    }

    func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func loadBlockedUsers() {
        let emails = UserDefaults.standard.stringArray(forKey: blockedUsersDefaultsKey()) ?? []
        blockedUserEmails = Set(emails.map(normalizedEmail))
    }

    func saveBlockedUsers() {
        UserDefaults.standard.set(Array(blockedUserEmails).sorted(), forKey: blockedUsersDefaultsKey())
    }

    func filteredListings(_ source: [Listing]) -> [Listing] {
        source.filter { listing in
            listing.ownerEmail.lowercased() == currentUserEmail || !isUserBlocked(listing.ownerEmail)
        }
    }

    func filteredConversations(_ source: [Conversation]) -> [Conversation] {
        source.filter { conversation in
            !isConversationBlocked(conversation)
        }
    }

    func removeBlockedContent() {
        let hiddenListingIDs = Set(listings.filter { listing in
            listing.ownerEmail.lowercased() != currentUserEmail && isUserBlocked(listing.ownerEmail)
        }.map(\.id))

        listings.removeAll { listing in
            hiddenListingIDs.contains(listing.id)
        }
        savedListingIDs.subtract(hiddenListingIDs)

        let hiddenConversationIDs = Set(conversations.filter(isConversationBlocked).map(\.id))
        conversations.removeAll { conversation in
            hiddenConversationIDs.contains(conversation.id)
        }
        messagesByConversationID = messagesByConversationID.filter { conversationID, _ in
            !hiddenConversationIDs.contains(conversationID)
        }
    }

    func loadLocalCache() {
        guard let cacheURL,
              let data = try? Data(contentsOf: cacheURL),
              let snapshot = try? JSONDecoder().decode(CacheSnapshot.self, from: data) else {
            return
        }

        listings = snapshot.listings
        savedListingIDs = snapshot.savedListingIDs
        reports = snapshot.reports
        conversations = filteredConversations(snapshot.conversations)
        messagesByConversationID = Dictionary(
            uniqueKeysWithValues: snapshot.messageThreads.map { thread in
                (thread.conversationID, thread.messages)
            }
        )
        removeBlockedContent()
    }

    func saveLocalCache() {
        guard let cacheURL else {
            return
        }

        let messageThreads = messagesByConversationID.map { conversationID, messages in
            MessageThread(conversationID: conversationID, messages: messages)
        }

        let snapshot = CacheSnapshot(
            listings: listings,
            savedListingIDs: savedListingIDs,
            reports: reports,
            conversations: conversations,
            messageThreads: messageThreads
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            syncError = "Local changes could not be saved on this device."
        }
    }

    func localConversation(for listing: Listing, id: UUID) -> Conversation {
        if let existingConversation = conversations.first(where: { $0.id == id }) {
            return existingConversation
        }

        return Conversation(
            id: id,
            listingID: listing.id,
            listingTitle: listing.title,
            buyerEmail: currentUserEmail,
            buyerName: currentUserName,
            sellerEmail: listing.ownerEmail.lowercased(),
            sellerName: listing.ownerName,
            participantEmails: [currentUserEmail, listing.ownerEmail.lowercased()],
            lastMessage: "",
            updatedAt: Date()
        )
    }

    func upsertListing(_ listing: Listing) {
        if let index = listings.firstIndex(where: { $0.id == listing.id }) {
            listings[index] = listing
        } else {
            listings.insert(listing, at: 0)
        }

        listings.sort { $0.createdAt > $1.createdAt }
    }

    func upsertConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }

        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    func deterministicConversationID(for listingID: UUID, buyerEmail: String) -> UUID {
        let name = "conversation-\(listingID.uuidString)-\(buyerEmail.lowercased())"
        return UUIDv5.make(name: name)
    }

    func displayName(from email: String) -> String {
        let emailName = email.components(separatedBy: "@").first ?? "Student"
        let parts = emailName
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")

        guard !parts.isEmpty else {
            return "Student"
        }

        return parts
            .map { part in part.prefix(1).uppercased() + part.dropFirst() }
            .joined(separator: " ")
    }

    func friendlySyncError(for error: Error) -> String {
        if let error = error as? SupabaseRESTClient.APIError {
            switch error {
            case .missingConfig:
                return "Supabase config needed. Add your project URL and anon key to SupabaseConfig.plist."
            case .unauthorized:
                return "Supabase rejected the anon key. Check SupabaseConfig.plist."
            case .forbidden:
                return "Supabase policies blocked this action. Check that you ran the schema SQL."
            case .server(let message):
                if message.localizedCaseInsensitiveContains("over_email_send_rate_limit") ||
                    message.localizedCaseInsensitiveContains("rate limit") {
                    return "Supabase is rate-limiting requests. Wait a few minutes, then try again."
                }

                return "Supabase sync failed: \(message)"
            case .invalidResponse:
                return "Supabase returned an unexpected response."
            case .auth(let message):
                if message.localizedCaseInsensitiveContains("over_email_send_rate_limit") ||
                    message.localizedCaseInsensitiveContains("rate limit") {
                    return "Too many verification emails were sent. Wait a few minutes, then try again."
                }

                return message
            }
        }

        return "Supabase sync unavailable. Using this device only for now."
    }
}

final class SupabaseRESTClient {
    enum APIError: Error {
        case missingConfig
        case unauthorized
        case forbidden
        case auth(String)
        case server(String)
        case invalidResponse
    }

    private let baseURL: URL
    private let anonKey: String
    private let authRedirectURL = URL(string: "circula://email-verified")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var accessToken: String?

    init(baseURL: URL, anonKey: String, session: URLSession = .shared) {
        self.baseURL = SupabaseRESTClient.normalizedProjectURL(from: baseURL)
        self.anonKey = anonKey
        self.session = session
        self.decoder = SupabaseRESTClient.makeDecoder()
        self.encoder = SupabaseRESTClient.makeEncoder()
    }

    func setAccessToken(_ accessToken: String?) {
        self.accessToken = accessToken
    }

    static func fromBundleConfig() -> SupabaseRESTClient? {
        guard let config = bundleConfigValues(),
              let baseURL = URL(string: config.urlString) else {
            return nil
        }

        return SupabaseRESTClient(baseURL: baseURL, anonKey: config.anonKey)
    }

    static func bundleConfigValues() -> (urlString: String, anonKey: String)? {
        if let urlString = cleanedConfigValue(Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String),
           let anonKey = cleanedConfigValue(Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String) {
            return (urlString, anonKey)
        }

        guard let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let urlString = cleanedConfigValue(plist["SupabaseURL"]),
              let anonKey = cleanedConfigValue(plist["SupabaseAnonKey"]) else {
            return nil
        }

        return (urlString, anonKey)
    }

    static func cleanedConfigValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.contains("YOUR_") else {
            return nil
        }

        return trimmed
    }

    func signUp(email: String, password: String, displayName: String) async throws -> AuthSession? {
        let body = AuthRequest(
            email: email,
            password: password,
            data: AuthMetadata(fullName: displayName)
        )
        let response: AuthResponse = try await authRequest(
            path: "signup",
            method: "POST",
            queryItems: [URLQueryItem(name: "redirect_to", value: authRedirectURL.absoluteString)],
            body: body
        )

        return response.session
    }

    func signInWithPassword(email: String, password: String) async throws -> AuthSession {
        let body = AuthRequest(
            email: email,
            password: password,
            data: nil
        )
        let response: AuthResponse = try await authRequest(
            path: "token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: body
        )

        guard let session = response.session else {
            throw APIError.auth("Check your email and password, then try again.")
        }

        return session
    }

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        let body = RefreshRequest(refreshToken: refreshToken)
        let response: AuthResponse = try await authRequest(
            path: "token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: body
        )

        guard let session = response.session else {
            throw APIError.auth("Your session expired. Please sign in again.")
        }

        return session
    }

    func upsertProfile(session: AuthSession) async throws {
        let row = ProfileRow(
            id: session.userID,
            email: session.email,
            fullName: session.displayName,
            createdAt: Date()
        )
        let _: [ProfileRow] = try await request(
            table: "profiles",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: row,
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    func deleteCurrentAccount() async throws {
        try await rpcWithoutBody(functionName: "delete_current_user")
    }

    func fetchListings() async throws -> [Listing] {
        let rows: [ListingRow] = try await request(
            table: "listings",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )

        return rows.map(\.listing)
    }

    func fetchPublicListings() async throws -> [Listing] {
        let rows: [PublicListingRow] = try await request(
            table: "listings",
            queryItems: [
                URLQueryItem(
                    name: "select",
                    value: "id,title,category,condition,type,description,exchange_preference,image_data,owner_name,owner_id,created_at,status"
                ),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )

        return rows.map(\.listing)
    }

    func upsertListing(_ listing: Listing) async throws -> Listing {
        let rows: [ListingRow] = try await request(
            table: "listings",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: ListingRow(listing: listing),
            prefer: "resolution=merge-duplicates,return=representation"
        )

        return rows.first?.listing ?? listing
    }

    func updateListingStatus(listingID: UUID, status: String) async throws {
        let body = ["status": status]
        let _: [ListingRow] = try await request(
            table: "listings",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(listingID.uuidString)")
            ],
            body: body,
            prefer: "return=minimal"
        )
    }

    func deleteListing(id: UUID) async throws {
        try await requestWithoutBody(
            table: "listings",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
            ]
        )
    }

    func fetchSavedListingIDs(for userEmail: String) async throws -> Set<UUID> {
        let rows: [SavedListingRow] = try await request(
            table: "saved_listings",
            queryItems: [
                URLQueryItem(name: "select", value: "listing_id"),
                URLQueryItem(name: "user_email", value: "eq.\(userEmail.lowercased())")
            ]
        )

        return Set(rows.map(\.listingID))
    }

    func saveListing(id: UUID, userEmail: String) async throws {
        let row = SavedListingRow(
            userEmail: userEmail.lowercased(),
            listingID: id,
            createdAt: Date()
        )
        let _: [SavedListingRow] = try await request(
            table: "saved_listings",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_email,listing_id")],
            body: row,
            prefer: "resolution=ignore-duplicates,return=minimal"
        )
    }

    func unsaveListing(id: UUID, userEmail: String) async throws {
        try await requestWithoutBody(
            table: "saved_listings",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "user_email", value: "eq.\(userEmail.lowercased())"),
                URLQueryItem(name: "listing_id", value: "eq.\(id.uuidString)")
            ]
        )
    }

    func fetchReports() async throws -> [ListingReport] {
        let rows: [ReportRow] = try await request(
            table: "listing_reports",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )

        return rows.map(\.report)
    }

    func upsertReport(_ report: ListingReport) async throws {
        let _: [ReportRow] = try await request(
            table: "listing_reports",
            method: "POST",
            body: ReportRow(report: report),
            prefer: "return=minimal"
        )
    }

    func updateReportStatus(reportID: UUID, status: String) async throws {
        let body = ["status": status]
        let _: [ReportRow] = try await request(
            table: "listing_reports",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(reportID.uuidString)")],
            body: body,
            prefer: "return=minimal"
        )
    }

    func fetchConversations(for userEmail: String) async throws -> [Conversation] {
        let rows: [ConversationRow] = try await request(
            table: "conversations",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "updated_at.desc")
            ]
        )

        return rows
            .map(\.conversation)
            .filter { conversation in
                conversation.participantEmails.contains { $0.lowercased() == userEmail.lowercased() }
            }
    }

    func upsertConversation(_ conversation: Conversation) async throws -> Conversation {
        let rows: [ConversationRow] = try await request(
            table: "conversations",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: ConversationRow(conversation: conversation),
            prefer: "resolution=ignore-duplicates,return=representation"
        )

        if let insertedConversation = rows.first?.conversation {
            return insertedConversation
        }

        let existingRows: [ConversationRow] = try await request(
            table: "conversations",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(conversation.id.uuidString)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        guard let existingConversation = existingRows.first?.conversation else {
            throw APIError.invalidResponse
        }

        return existingConversation
    }

    func updateConversationPreview(_ conversation: Conversation) async throws {
        let body = ConversationPreviewRow(
            lastMessage: conversation.lastMessage,
            updatedAt: conversation.updatedAt
        )
        let _: [ConversationRow] = try await request(
            table: "conversations",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(conversation.id.uuidString)")],
            body: body,
            prefer: "return=minimal"
        )
    }

    func fetchMessages(for conversationID: UUID) async throws -> [ChatMessage] {
        let rows: [MessageRow] = try await request(
            table: "messages",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "conversation_id", value: "eq.\(conversationID.uuidString)"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ]
        )

        return rows.map(\.message)
    }

    func upsertMessage(_ message: ChatMessage) async throws {
        let _: [MessageRow] = try await request(
            table: "messages",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: MessageRow(message: message),
            prefer: "resolution=ignore-duplicates,return=minimal"
        )
    }
}

private extension SupabaseRESTClient {
    struct ListingRow: Codable {
        let id: UUID
        let title: String
        let category: String
        let condition: String
        let type: String
        let description: String
        let exchangePreference: String
        let imageData: String?
        let ownerName: String
        let ownerEmail: String
        let createdAt: Date
        let status: String

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case category
            case condition
            case type
            case description
            case exchangePreference = "exchange_preference"
            case imageData = "image_data"
            case ownerName = "owner_name"
            case ownerEmail = "owner_email"
            case createdAt = "created_at"
            case status
        }

        init(listing: Listing) {
            self.id = listing.id
            self.title = listing.title
            self.category = listing.category
            self.condition = listing.condition
            self.type = listing.type
            self.description = listing.description
            self.exchangePreference = listing.exchangePreference
            self.imageData = listing.imageData?.base64EncodedString()
            self.ownerName = listing.ownerName
            self.ownerEmail = listing.ownerEmail.lowercased()
            self.createdAt = listing.createdAt
            self.status = listing.status
        }

        var listing: Listing {
            Listing(
                id: id,
                title: title,
                category: category,
                condition: condition,
                type: type,
                description: description,
                exchangePreference: exchangePreference,
                imageData: imageData.flatMap { Data(base64Encoded: $0) },
                ownerName: ownerName,
                ownerEmail: ownerEmail,
                createdAt: createdAt,
                status: status
            )
        }
    }

    struct PublicListingRow: Decodable {
        let id: UUID
        let title: String
        let category: String
        let condition: String
        let type: String
        let description: String
        let exchangePreference: String
        let imageData: String?
        let ownerName: String
        let ownerID: UUID?
        let createdAt: Date
        let status: String

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case category
            case condition
            case type
            case description
            case exchangePreference = "exchange_preference"
            case imageData = "image_data"
            case ownerName = "owner_name"
            case ownerID = "owner_id"
            case createdAt = "created_at"
            case status
        }

        var listing: Listing {
            let anonymousOwnerID = ownerID ?? id

            return Listing(
                id: id,
                title: title,
                category: category,
                condition: condition,
                type: type,
                description: description,
                exchangePreference: exchangePreference,
                imageData: imageData.flatMap { Data(base64Encoded: $0) },
                ownerName: ownerName,
                ownerEmail: "user-\(anonymousOwnerID.uuidString.lowercased())@anonymous.circula",
                createdAt: createdAt,
                status: status
            )
        }
    }

    struct SavedListingRow: Codable {
        let userEmail: String?
        let listingID: UUID
        let createdAt: Date?

        enum CodingKeys: String, CodingKey {
            case userEmail = "user_email"
            case listingID = "listing_id"
            case createdAt = "created_at"
        }
    }

    struct ReportRow: Codable {
        let id: UUID
        let listingID: UUID
        let listingTitle: String
        let reportedByEmail: String
        let reason: String
        let createdAt: Date
        let status: String

        enum CodingKeys: String, CodingKey {
            case id
            case listingID = "listing_id"
            case listingTitle = "listing_title"
            case reportedByEmail = "reported_by_email"
            case reason
            case createdAt = "created_at"
            case status
        }

        init(report: ListingReport) {
            self.id = report.id
            self.listingID = report.listingID
            self.listingTitle = report.listingTitle
            self.reportedByEmail = report.reportedByEmail.lowercased()
            self.reason = report.reason
            self.createdAt = report.createdAt
            self.status = report.status
        }

        var report: ListingReport {
            ListingReport(
                id: id,
                listingID: listingID,
                listingTitle: listingTitle,
                reportedByEmail: reportedByEmail,
                reason: reason,
                createdAt: createdAt,
                status: status
            )
        }
    }

    struct ConversationRow: Codable {
        let id: UUID
        let listingID: UUID
        let listingTitle: String
        let buyerEmail: String
        let buyerName: String
        let sellerEmail: String
        let sellerName: String
        let participantEmails: [String]
        let lastMessage: String
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case listingID = "listing_id"
            case listingTitle = "listing_title"
            case buyerEmail = "buyer_email"
            case buyerName = "buyer_name"
            case sellerEmail = "seller_email"
            case sellerName = "seller_name"
            case participantEmails = "participant_emails"
            case lastMessage = "last_message"
            case updatedAt = "updated_at"
        }

        init(conversation: Conversation) {
            self.id = conversation.id
            self.listingID = conversation.listingID
            self.listingTitle = conversation.listingTitle
            self.buyerEmail = conversation.buyerEmail.lowercased()
            self.buyerName = conversation.buyerName
            self.sellerEmail = conversation.sellerEmail.lowercased()
            self.sellerName = conversation.sellerName
            self.participantEmails = conversation.participantEmails.map { $0.lowercased() }
            self.lastMessage = conversation.lastMessage
            self.updatedAt = conversation.updatedAt
        }

        var conversation: Conversation {
            Conversation(
                id: id,
                listingID: listingID,
                listingTitle: listingTitle,
                buyerEmail: buyerEmail,
                buyerName: buyerName,
                sellerEmail: sellerEmail,
                sellerName: sellerName,
                participantEmails: participantEmails,
                lastMessage: lastMessage,
                updatedAt: updatedAt
            )
        }
    }

    struct ConversationPreviewRow: Codable {
        let lastMessage: String
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case lastMessage = "last_message"
            case updatedAt = "updated_at"
        }
    }

    struct MessageRow: Codable {
        let id: UUID
        let conversationID: UUID
        let text: String
        let senderEmail: String
        let senderName: String
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case conversationID = "conversation_id"
            case text
            case senderEmail = "sender_email"
            case senderName = "sender_name"
            case createdAt = "created_at"
        }

        init(message: ChatMessage) {
            self.id = message.id
            self.conversationID = message.conversationID
            self.text = message.text
            self.senderEmail = message.senderEmail.lowercased()
            self.senderName = message.senderName
            self.createdAt = message.createdAt
        }

        var message: ChatMessage {
            ChatMessage(
                id: id,
                conversationID: conversationID,
                text: text,
                senderEmail: senderEmail,
                senderName: senderName,
                createdAt: createdAt
            )
        }
    }

    struct ProfileRow: Codable {
        let id: UUID
        let email: String
        let fullName: String
        let createdAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case email
            case fullName = "full_name"
            case createdAt = "created_at"
        }
    }

    struct AuthRequest: Encodable {
        let email: String
        let password: String
        let data: AuthMetadata?
    }

    struct RefreshRequest: Encodable {
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    struct AuthMetadata: Codable {
        let fullName: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }

    struct AuthResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let user: AuthUser?
        let id: UUID?
        let email: String?
        let metadata: AuthMetadata?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
            case id
            case email
            case metadata = "user_metadata"
        }

        var session: AuthSession? {
            guard let user = user ?? rootUser,
                  let accessToken,
                  let refreshToken else {
                return nil
            }

            return AuthSession(
                userID: user.id,
                email: user.email.lowercased(),
                accessToken: accessToken,
                refreshToken: refreshToken,
                displayName: user.metadata?.fullName ?? displayName(from: user.email)
            )
        }

        var rootUser: AuthUser? {
            guard let id,
                  let email else {
                return nil
            }

            return AuthUser(id: id, email: email, metadata: metadata)
        }

        func displayName(from email: String) -> String {
            let emailName = email.components(separatedBy: "@").first ?? "Student"
            let parts = emailName
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")

            guard !parts.isEmpty else {
                return "Student"
            }

            return parts
                .map { part in part.prefix(1).uppercased() + part.dropFirst() }
                .joined(separator: " ")
        }
    }

    struct AuthUser: Decodable {
        let id: UUID
        let email: String
        let metadata: AuthMetadata?

        enum CodingKeys: String, CodingKey {
            case id
            case email
            case metadata = "user_metadata"
        }
    }

    struct ErrorPayload: Decodable {
        let message: String?
        let error: String?
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case message
            case error
            case errorDescription = "error_description"
        }
    }

    func authRequest<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: some Encodable
    ) async throws -> Response {
        guard var components = URLComponents(
            url: baseURL
                .appendingPathComponent("auth")
                .appendingPathComponent("v1")
                .appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.missingConfig
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(AnyEncodable(body))

        let data = try await perform(request)
        return try decoder.decode(Response.self, from: data)
    }

    func request<Response: Decodable>(
        table: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: (some Encodable)? = Optional<String>.none,
        prefer: String? = nil
    ) async throws -> Response {
        var request = try makeRequest(
            table: table,
            method: method,
            queryItems: queryItems,
            prefer: prefer
        )

        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let data = try await perform(request)

        if data.isEmpty {
            guard let emptyArray = [] as? Response else {
                throw APIError.invalidResponse
            }

            return emptyArray
        }

        return try decoder.decode(Response.self, from: data)
    }

    func requestWithoutBody(
        table: String,
        method: String,
        queryItems: [URLQueryItem]
    ) async throws {
        let request = try makeRequest(
            table: table,
            method: method,
            queryItems: queryItems,
            prefer: "return=minimal"
        )
        _ = try await perform(request)
    }

    func rpcWithoutBody(functionName: String) async throws {
        guard var components = URLComponents(
            url: baseURL
                .appendingPathComponent("rest")
                .appendingPathComponent("v1")
                .appendingPathComponent("rpc")
                .appendingPathComponent(functionName),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.missingConfig
        }

        components.queryItems = nil

        guard let url = components.url else {
            throw APIError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data("{}".utf8)

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        _ = try await perform(request)
    }

    func makeRequest(
        table: String,
        method: String,
        queryItems: [URLQueryItem],
        prefer: String?
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL
                .appendingPathComponent("rest")
                .appendingPathComponent("v1")
                .appendingPathComponent(table),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.missingConfig
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else if anonKey.hasPrefix("eyJ") {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        return request
    }

    func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 400, 422:
            throw APIError.auth(errorMessage(from: data) ?? "Authentication failed. Check your email and password.")
        default:
            let message = errorMessage(from: data) ??
                String(data: data, encoding: .utf8) ??
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIError.server(message)
        }
    }

    func errorMessage(from data: Data) -> String? {
        guard let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data) else {
            return nil
        }

        return payload.message ?? payload.errorDescription ?? payload.error
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.supabase.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.supabaseWithoutFractionalSeconds.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.supabase.string(from: date))
        }
        return encoder
    }

    static func normalizedProjectURL(from url: URL) -> URL {
        let urlString = url.absoluteString
        let suffixes = ["/rest/v1/", "/rest/v1"]

        for suffix in suffixes where urlString.hasSuffix(suffix) {
            let trimmed = String(urlString.dropLast(suffix.count))
            return URL(string: trimmed) ?? url
        }

        return url
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ wrapped: some Encodable) {
        self.encodeValue = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

private extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let supabaseWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private enum UUIDv5 {
    static func make(name: String) -> UUID {
        var hash = FNV1a.hash(name)

        let bytes = (0..<16).map { _ -> UInt8 in
            defer { hash = FNV1a.mix(hash) }
            return UInt8(truncatingIfNeeded: hash >> 56)
        }

        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            (bytes[6] & 0x0f) | 0x50, bytes[7],
            (bytes[8] & 0x3f) | 0x80, bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )

        return UUID(uuid: uuid)
    }
}

private enum FNV1a {
    static func hash(_ string: String) -> UInt64 {
        string.utf8.reduce(0xcbf29ce484222325) { partial, byte in
            mix((partial ^ UInt64(byte)) &* 0x100000001b3)
        }
    }

    static func mix(_ value: UInt64) -> UInt64 {
        var x = value
        x ^= x >> 30
        x &*= 0xbf58476d1ce4e5b9
        x ^= x >> 27
        x &*= 0x94d049bb133111eb
        x ^= x >> 31
        return x
    }
}
