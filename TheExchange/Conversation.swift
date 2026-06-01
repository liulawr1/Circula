//
//  Conversation.swift
//  TheExchange
//

import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    let listingID: UUID
    let listingTitle: String
    let buyerEmail: String
    let buyerName: String
    let sellerEmail: String
    let sellerName: String
    let participantEmails: [String]
    var lastMessage: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        listingID: UUID,
        listingTitle: String,
        buyerEmail: String,
        buyerName: String,
        sellerEmail: String,
        sellerName: String,
        participantEmails: [String],
        lastMessage: String,
        updatedAt: Date
    ) {
        self.id = id
        self.listingID = listingID
        self.listingTitle = listingTitle
        self.buyerEmail = buyerEmail
        self.buyerName = buyerName
        self.sellerEmail = sellerEmail
        self.sellerName = sellerName
        self.participantEmails = participantEmails
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
    }

    func otherStudentName(for currentUserEmail: String) -> String {
        currentUserEmail.lowercased() == sellerEmail.lowercased() ? buyerName : sellerName
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let conversationID: UUID
    let text: String
    let senderEmail: String
    let senderName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        text: String,
        senderEmail: String,
        senderName: String,
        createdAt: Date
    ) {
        self.id = id
        self.conversationID = conversationID
        self.text = text
        self.senderEmail = senderEmail
        self.senderName = senderName
        self.createdAt = createdAt
    }
}
