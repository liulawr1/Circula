//
//  ListingReport.swift
//  TheExchange
//
//  Created by Lawrence Liu on 5/6/26.
//

import Foundation

struct ListingReport: Identifiable, Codable {
    let id: UUID
    let listingID: UUID
    let listingTitle: String
    let reportedByEmail: String
    let reason: String
    let createdAt: Date
    var status: String

    init(
        id: UUID = UUID(),
        listingID: UUID,
        listingTitle: String,
        reportedByEmail: String,
        reason: String,
        createdAt: Date,
        status: String
    ) {
        self.id = id
        self.listingID = listingID
        self.listingTitle = listingTitle
        self.reportedByEmail = reportedByEmail
        self.reason = reason
        self.createdAt = createdAt
        self.status = status
    }
}
