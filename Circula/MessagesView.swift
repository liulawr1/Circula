//
//  MessagesView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var store: MarketplaceStore

    let currentUserName: String
    let currentUserEmail: String

    var body: some View {
        NavigationStack {
            List {
                if store.conversations.isEmpty && store.isLoading {
                    ProgressView("Loading messages...")
                } else if store.conversations.isEmpty {
                    ContentUnavailableView(
                        "No Messages Yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Message a listing owner to start a conversation.")
                    )
                } else {
                    ForEach(store.conversations) { conversation in
                        NavigationLink {
                            ChatView(
                                conversation: conversation,
                                currentUserName: currentUserName,
                                currentUserEmail: currentUserEmail
                            )
                        } label: {
                            MessageRowView(
                                conversation: conversation,
                                currentUserEmail: currentUserEmail
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(CirculaBackground())
            .tint(CirculaTheme.forest)
            .navigationTitle("Messages")
            .refreshable {
                await store.refreshAll()
            }
        }
    }
}

struct MessageRowView: View {
    let conversation: Conversation
    let currentUserEmail: String

    private var otherStudentName: String {
        conversation.otherStudentName(for: currentUserEmail)
    }

    private var initials: String {
        let pieces = otherStudentName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }

        let value = pieces.map(String.init).joined().uppercased()
        return value.isEmpty ? "?" : value
    }

    private var messagePreview: String {
        conversation.lastMessage.isEmpty ? "Start the conversation" : conversation.lastMessage
    }

    private var formattedUpdatedAt: String {
        if Calendar.current.isDateInToday(conversation.updatedAt) {
            return Self.timeFormatter.string(from: conversation.updatedAt)
        }

        if Calendar.current.isDate(conversation.updatedAt, equalTo: Date(), toGranularity: .weekOfYear) {
            return Self.weekdayFormatter.string(from: conversation.updatedAt)
        }

        return Self.dateFormatter.string(from: conversation.updatedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CirculaTheme.teal, CirculaTheme.forest],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(initials)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(otherStudentName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(CirculaTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(formattedUpdatedAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(conversation.listingTitle)
                    .font(.subheadline)
                    .foregroundStyle(CirculaTheme.ink.opacity(0.78))
                    .lineLimit(1)

                Text(messagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CirculaTheme.softStroke)
                .frame(height: 1)
                .padding(.leading, 78)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter
    }()
}

struct ChatView: View {
    @EnvironmentObject private var store: MarketplaceStore

    let listing: Listing?
    let currentUserName: String
    let currentUserEmail: String

    @State private var conversation: Conversation?
    @State private var messageText = ""
    @State private var isLoadingConversation = false
    @FocusState private var isMessageFieldFocused: Bool

    init(
        listing: Listing,
        currentUserName: String,
        currentUserEmail: String
    ) {
        self.listing = listing
        self.currentUserName = currentUserName
        self.currentUserEmail = currentUserEmail
        _conversation = State(initialValue: nil)
    }

    init(
        conversation: Conversation,
        currentUserName: String,
        currentUserEmail: String
    ) {
        self.listing = nil
        self.currentUserName = currentUserName
        self.currentUserEmail = currentUserEmail
        _conversation = State(initialValue: conversation)
    }

    var messages: [ChatMessage] {
        guard let conversation else {
            return []
        }

        return store.messagesByConversationID[conversation.id] ?? []
    }

    var itemTitle: String {
        conversation?.listingTitle ?? listing?.title ?? "Listing"
    }

    var navigationTitle: String {
        if let conversation {
            return conversation.otherStudentName(for: currentUserEmail)
        }

        return listing?.ownerName ?? "Messages"
    }

    var body: some View {
        VStack {
            Text("About: \(itemTitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

            if isLoadingConversation {
                ProgressView("Opening conversation...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        if messages.isEmpty {
                            ContentUnavailableView(
                                "No Messages Yet",
                                systemImage: "bubble.left",
                                description: Text("Send the first message about this listing.")
                            )
                        } else {
                            ForEach(messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    isCurrentUser: message.senderEmail.lowercased() == currentUserEmail.lowercased()
                                )
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await reloadMessages()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isLoadingConversation {
                messageComposer
            }
        }
        .background(CirculaBackground())
        .tint(CirculaTheme.forest)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onSubmit {
            sendCurrentMessage()
        }
        .task {
            await openConversationIfNeeded()
            await reloadMessages()
        }
    }

    var messageComposer: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .focused($isMessageFieldFocused)
                .submitLabel(.send)

            Button {
                sendCurrentMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 42, height: 36)
                    .background(CirculaTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CirculaTheme.softStroke)
                .frame(height: 1)
        }
    }

    func sendCurrentMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedMessage.isEmpty,
              let conversation else {
            return
        }

        messageText = ""
        isMessageFieldFocused = false

        Task {
            await store.sendMessage(trimmedMessage, in: conversation)
        }
    }

    func openConversationIfNeeded() async {
        guard conversation == nil,
              let listing else {
            return
        }

        isLoadingConversation = true
        conversation = await store.conversation(for: listing)
        isLoadingConversation = false
    }

    func reloadMessages() async {
        guard let conversation else {
            return
        }

        await store.loadMessages(for: conversation.id)
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(isCurrentUser ? CirculaTheme.forest : Color.white.opacity(0.82))
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(message.senderName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isCurrentUser {
                Spacer()
            }
        }
    }
}
