//
//  ContentModeration.swift
//  Circula
//

import Foundation

enum ContentModeration {
    private static let prohibitedTerms = [
        "alcohol",
        "ammo",
        "ammunition",
        "cigarette",
        "cigarettes",
        "drug",
        "drugs",
        "firearm",
        "firearms",
        "gun",
        "guns",
        "hate speech",
        "kill you",
        "knife",
        "knives",
        "nude",
        "nudes",
        "porn",
        "sexual",
        "stolen",
        "threat",
        "threaten",
        "vape",
        "vapes",
        "weapon",
        "weapons"
    ]

    static func listingIssue(
        title: String,
        description: String,
        exchangePreference: String
    ) -> String? {
        let combinedText = [title, description, exchangePreference].joined(separator: " ")

        guard containsProhibitedContent(combinedText) else {
            return nil
        }

        return "This listing may include prohibited or unsafe content. Remove references to dangerous or illegal items, threats, harassment, sexual content, or other content that violates the Community Standards."
    }

    static func messageIssue(_ message: String) -> String? {
        guard containsProhibitedContent(message) else {
            return nil
        }

        return "This message may violate Circula's Community Standards. Remove threats, harassment, sexual content, or references to prohibited items before sending."
    }

    private static func containsProhibitedContent(_ text: String) -> Bool {
        let normalizedText = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let words = Set(
            normalizedText
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )

        return prohibitedTerms.contains { term in
            term.contains(" ")
                ? normalizedText.contains(term)
                : words.contains(term)
        }
    }
}
