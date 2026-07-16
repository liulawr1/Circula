//
//  Listing.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import Foundation

struct Listing: Identifiable, Codable {
    let id: UUID
    let title: String
    let category: String
    let condition: String
    let type: String
    let description: String
    let exchangePreference: String
    let imageData: Data?
    let ownerName: String
    let ownerEmail: String
    let createdAt: Date
    var status: String

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        condition: String,
        type: String,
        description: String,
        exchangePreference: String,
        imageData: Data?,
        ownerName: String,
        ownerEmail: String,
        createdAt: Date,
        status: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.condition = condition
        self.type = type
        self.description = description
        self.exchangePreference = exchangePreference
        self.imageData = imageData
        self.ownerName = ownerName
        self.ownerEmail = ownerEmail
        self.createdAt = createdAt
        self.status = status
    }

    static let sampleListings = [
        Listing(
            title: "AP Biology Textbook",
            category: "Textbooks",
            condition: "Good",
            type: "Trade",
            description: "Used for AP Bio this year. Some highlighting, but still very usable.",
            exchangePreference: "Looking for AP Chemistry materials",
            imageData: nil,
            ownerName: "Lawrence Liu",
            ownerEmail: "student@headroyce.org",
            createdAt: Date(),
            status: "Available"
        ),
        Listing(
            title: "TI-84 Calculator",
            category: "School Supplies",
            condition: "Excellent",
            type: "Sell",
            description: "Works perfectly. Comes with batteries.",
            exchangePreference: "$45",
            imageData: nil,
            ownerName: "Maya Chen",
            ownerEmail: "maya@headroyce.org",
            createdAt: Date(),
            status: "Available"
        ),
        Listing(
            title: "Soccer Cleats",
            category: "Sports Gear",
            condition: "Fair",
            type: "Free",
            description: "Size 9 cleats. A little worn, but good for practice.",
            exchangePreference: "Free to anyone who needs them",
            imageData: nil,
            ownerName: "Jordan Lee",
            ownerEmail: "jordan@headroyce.org",
            createdAt: Date(),
            status: "Pending"
        ),
        Listing(
            title: "Acrylic Paint Set",
            category: "Art Supplies",
            condition: "Good",
            type: "Trade",
            description: "Several colors included. Good for studio art or poster projects.",
            exchangePreference: "Open to school supplies or sketchbooks",
            imageData: nil,
            ownerName: "Sofia Patel",
            ownerEmail: "sofia@headroyce.org",
            createdAt: Date(),
            status: "Available"
        ),
        Listing(
            title: "Graphing Notebook Pack",
            category: "School Supplies",
            condition: "New",
            type: "Free",
            description: "Three unused graphing notebooks.",
            exchangePreference: "No trade needed",
            imageData: nil,
            ownerName: "Lawrence Liu",
            ownerEmail: "student@headroyce.org",
            createdAt: Date(),
            status: "Completed"
        )
    ]
}
