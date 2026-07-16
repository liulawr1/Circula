//
//  ActivityView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI

struct ActivityView: View {
    let currentUserEmail: String
    let listings: [Listing]
    let savedListingIDs: Set<UUID>

    var myListings: [Listing] {
        listings.filter { listing in
            listing.ownerEmail.lowercased() == currentUserEmail.lowercased()
        }
    }

    var savedListings: [Listing] {
        listings.filter { listing in
            savedListingIDs.contains(listing.id)
        }
    }

    var pendingListings: [Listing] {
        myListings.filter { listing in
            listing.status == "Pending"
        }
    }

    var completedListings: [Listing] {
        myListings.filter { listing in
            listing.status == "Completed"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    ActivityRowView(
                        iconName: "shippingbox",
                        color: .blue,
                        title: "Your Listings",
                        subtitle: "\(myListings.count) items posted"
                    )

                    ActivityRowView(
                        iconName: "heart.fill",
                        color: .red,
                        title: "Saved Listings",
                        subtitle: "\(savedListings.count) items saved"
                    )

                    ActivityRowView(
                        iconName: "clock.fill",
                        color: .orange,
                        title: "Pending Trades",
                        subtitle: "\(pendingListings.count) items pending"
                    )

                    ActivityRowView(
                        iconName: "checkmark.circle.fill",
                        color: .green,
                        title: "Completed Trades",
                        subtitle: "\(completedListings.count) completed"
                    )
                }
                .listRowBackground(Color.white.opacity(0.82))

                Section("Recent Activity") {
                    if myListings.isEmpty && savedListings.isEmpty {
                        ContentUnavailableView(
                            "No Activity Yet",
                            systemImage: "bell",
                            description: Text("Post or save a listing to start building activity.")
                        )
                    } else {
                        ForEach(myListings.prefix(3)) { listing in
                            ActivityRowView(
                                iconName: "plus.circle.fill",
                                color: .blue,
                                title: "You posted \(listing.title)",
                                subtitle: "\(listing.status) • \(listing.type)"
                            )
                        }

                        ForEach(savedListings.prefix(3)) { listing in
                            ActivityRowView(
                                iconName: "heart.fill",
                                color: .red,
                                title: "Saved \(listing.title)",
                                subtitle: "Posted by \(listing.ownerName)"
                            )
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.82))

                Section("Reminders") {
                    Text("Meet only on campus.")
                    Text("Keep messages respectful.")
                    Text("Mark listings completed after a meetup.")
                }
                .listRowBackground(Color.white.opacity(0.82))
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(CirculaBackground())
            .tint(CirculaTheme.forest)
            .navigationTitle("Activity")
        }
    }
}

struct ActivityRowView: View {
    let iconName: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
