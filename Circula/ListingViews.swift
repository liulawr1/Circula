//
//  ListingViews.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI
import UIKit

struct ListingRowView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let listing: Listing

    private var thumbnailSize: CGFloat {
        horizontalSizeClass == .regular ? 112 : 104
    }

    private var imageColumnWidth: CGFloat {
        horizontalSizeClass == .regular ? 152 : 136
    }

    private var rowSpacing: CGFloat {
        horizontalSizeClass == .regular ? 14 : 10
    }

    var body: some View {
        HStack(spacing: rowSpacing) {
            listingImage
                .frame(width: imageColumnWidth, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(CirculaTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("\(listing.category) • \(listing.condition)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text(listing.exchangePreference)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                HStack(spacing: 8) {
                    Text(listing.type)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor(for: listing.type).opacity(0.15))
                        .foregroundStyle(badgeColor(for: listing.type))
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(listing.status)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(for: listing.status).opacity(0.15))
                        .foregroundStyle(statusColor(for: listing.status))
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text("by \(listing.ownerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .circulaCard()
        .padding(.vertical, 4)
    }

    var listingImage: some View {
        ZStack {
            if let imageData = listing.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize, height: thumbnailSize, alignment: .center)
                    .clipped()
            } else {
                CirculaTheme.teal.opacity(0.12)

                Image(systemName: iconName(for: listing.category))
                    .font(.title)
                    .foregroundStyle(CirculaTheme.teal)
                    .frame(width: thumbnailSize, height: thumbnailSize, alignment: .center)
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ListingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MarketplaceStore

    let listing: Listing
    let currentUserName: String
    let currentUserEmail: String

    @State private var showingReportAlert = false
    @State private var showingBlockUserAlert = false
    @State private var reportSubmitted = false

    var isOwnListing: Bool {
        listing.ownerEmail.lowercased() == currentUserEmail.lowercased()
    }

    var isSaved: Bool {
        store.savedListingIDs.contains(listing.id)
    }
    
    let reportReasons = [
        "Inappropriate item",
        "Unsafe meetup",
        "Spam or duplicate",
        "Incorrect information",
        "Other"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                listingImage
                    .frame(maxWidth: .infinity)

                Text(listing.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(CirculaTheme.ink)

                Text("\(listing.category) • \(listing.condition) • \(listing.type) • \(listing.status)")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exchangeLabel(for: listing.type))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(listing.exchangePreference)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Posted by")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(listing.ownerName)
                        .font(.headline)

                    Text(listing.ownerEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(listing.description)

                if isOwnListing {
                    Label("This is your listing", systemImage: "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    NavigationLink {
                        ManageListingView(listing: listing) {
                            dismiss()
                        }
                    } label: {
                        Label("Manage Listing", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(CirculaTheme.forest)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                } else {
                    Button {
                        Task {
                            await store.toggleSavedListing(id: listing.id)
                        }
                    } label: {
                        Label(isSaved ? "Saved" : "Save Listing", systemImage: isSaved ? "heart.fill" : "heart")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.82))
                            .foregroundStyle(isSaved ? .red : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    NavigationLink {
                        ChatView(
                            listing: listing,
                            currentUserName: currentUserName,
                            currentUserEmail: currentUserEmail
                        )
                    } label: {
                        Text("Message Owner")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(CirculaTheme.forest)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(role: .destructive) {
                        showingReportAlert = true
                    } label: {
                        Text("Report Listing")
                            .frame(maxWidth: .infinity)
                    }
                    .confirmationDialog(
                        "Why are you reporting this listing?",
                        isPresented: $showingReportAlert,
                        titleVisibility: .visible
                    ) {
                        ForEach(reportReasons, id: \.self) { reason in
                            Button(reason, role: reason == "Other" ? .none : .destructive) {
                                let report = ListingReport(
                                    listingID: listing.id,
                                    listingTitle: listing.title,
                                    reportedByEmail: currentUserEmail,
                                    reason: reason,
                                    createdAt: Date(),
                                    status: "Open"
                                )

                                Task {
                                    await store.reportListing(report)
                                    reportSubmitted = true
                                }
                            }
                        }

                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will flag the listing for review by a school moderator.")
                    }
                    .alert("Report Submitted", isPresented: $reportSubmitted) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Thank you for helping keep Circula safe.")
                    }

                    Button(role: .destructive) {
                        showingBlockUserAlert = true
                    } label: {
                        Text("Block User")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .circulaCard()
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CirculaBackground())
        .tint(CirculaTheme.forest)
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Block \(listing.ownerName)?", isPresented: $showingBlockUserAlert) {
            Button("Cancel", role: .cancel) { }

            Button("Block", role: .destructive) {
                store.blockUser(email: listing.ownerEmail)
                dismiss()
            }
        } message: {
            Text("You will no longer see this student's listings or conversations on this device.")
        }
    }

    var listingImage: some View {
        ZStack {
            if let imageData = listing.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                CirculaTheme.teal.opacity(0.12)

                Image(systemName: iconName(for: listing.category))
                    .font(.system(size: 56))
                    .foregroundStyle(CirculaTheme.teal)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

func iconName(for category: String) -> String {
    switch category {
    case "Textbooks":
        return "book.closed"
    case "School Supplies":
        return "pencil.and.ruler"
    case "Sports Gear":
        return "figure.soccer"
    case "Art Supplies":
        return "paintpalette"
    case "Tech":
        return "desktopcomputer"
    default:
        return "shippingbox"
    }
}

func badgeColor(for type: String) -> Color {
    switch type {
    case "Trade":
        return .green
    case "Sell":
        return .blue
    case "Free":
        return .purple
    default:
        return .gray
    }
}

func statusColor(for status: String) -> Color {
    switch status {
    case "Available":
        return .green
    case "Pending":
        return .orange
    case "Completed":
        return .gray
    default:
        return .gray
    }
}

func exchangeLabel(for type: String) -> String {
    switch type {
    case "Trade":
        return "Looking for"
    case "Sell":
        return "Price"
    case "Free":
        return "Free item note"
    default:
        return "Trade preference"
    }
}
