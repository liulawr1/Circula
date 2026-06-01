//
//  ProfileView.swift
//  TheExchange
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: MarketplaceStore

    let currentUserName: String
    let currentUserEmail: String
    let onSignOut: () -> Void

    @State private var showingDeleteAccountAlert = false
    @State private var deleteAccountError = ""
    @State private var isDeletingAccount = false

    var myListings: [Listing] {
        store.listings.filter { listing in
            listing.ownerEmail.lowercased() == currentUserEmail.lowercased()
        }
    }

    var activeListingCount: Int {
        store.listings.filter { listing in
            listing.ownerEmail.lowercased() == currentUserEmail.lowercased() && listing.status != "Completed"
        }.count
    }

    var completedListingCount: Int {
        store.listings.filter { listing in
            listing.ownerEmail.lowercased() == currentUserEmail.lowercased() && listing.status == "Completed"
        }.count
    }
    
    var savedListings: [Listing] {
        store.listings.filter { listing in
            store.savedListingIDs.contains(listing.id)
        }
    }
    
    var isModerator: Bool {
        let moderatorEmails = [
            "lawrencel2026@headroyce.org"
        ]

        return moderatorEmails.contains(currentUserEmail.lowercased())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ExchangeTheme.forest)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentUserName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(ExchangeTheme.ink)

                            Text(currentUserEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.white.opacity(0.82))

                Section("Student") {
                    LabeledContent("Name", value: currentUserName)
                    LabeledContent("School", value: "HRS")
                    LabeledContent("Email", value: currentUserEmail)
                }
                .listRowBackground(Color.white.opacity(0.82))

                Section("Marketplace") {
                    LabeledContent("Active Listings", value: "\(activeListingCount)")
                    LabeledContent("Completed Trades", value: "\(completedListingCount)")
                }
                .listRowBackground(Color.white.opacity(0.82))

                Section("My Listings") {
                    if myListings.isEmpty {
                        ContentUnavailableView(
                            "No Listings Yet",
                            systemImage: "shippingbox",
                            description: Text("Post an item to start sharing with other students.")
                        )   
                    } else {
                        ForEach(myListings) { listing in
                            NavigationLink {
                                ManageListingView(listing: listing)
                            } label: {
                                ListingRowView(listing: listing)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                        }
                    }
                }
                .listRowBackground(Color.clear)
                
                Section("Saved Listings") {
                    if savedListings.isEmpty {
                        ContentUnavailableView(
                            "No Saved Listings",
                            systemImage: "heart",
                            description: Text("Save listings you want to revisit later.")
                        )
                    } else {
                        ForEach(savedListings) { listing in
                            NavigationLink {
                                ListingDetailView(
                                    listing: listing,
                                    currentUserName: currentUserName,
                                    currentUserEmail: currentUserEmail
                                )
                            } label: {
                                ListingRowView(listing: listing)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section("Safety") {
                    NavigationLink {
                        CommunityStandardsView()
                    } label: {
                        Label("Community Standards", systemImage: "checkmark.shield")
                    }

                    if isModerator {
                        NavigationLink {
                            ModeratorReportsView()
                        } label: {
                            Label("Moderator Reports", systemImage: "exclamationmark.triangle")
                        }
                    }

                    Text("Head-Royce email required")
                    Text("On-campus exchanges only")
                    Text("Report unsafe listings")
                }
                .listRowBackground(Color.white.opacity(0.82))
                
                Section {
                    Button(role: .destructive) {
                        onSignOut()
                    } label: {
                        Text("Sign Out")
                    }

                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        if isDeletingAccount {
                            ProgressView()
                        } else {
                            Text("Delete Account")
                        }
                    }
                    .disabled(isDeletingAccount)
                }
                .listRowBackground(Color.white.opacity(0.82))
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(ExchangeBackground())
            .tint(ExchangeTheme.forest)
            .navigationTitle("Profile")
            .refreshable {
                await store.refreshAll()
            }
            .alert("Delete Account?", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }

                Button("Delete Account", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account, listings, saved listings, reports, conversations, and messages from The Exchange.")
            }
            .alert("Could Not Delete Account", isPresented: Binding(
                get: { !deleteAccountError.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        deleteAccountError = ""
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError)
            }
        }
    }

    func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await store.deleteCurrentAccount()
            onSignOut()
        } catch {
            deleteAccountError = "Run SUPABASE_AUTH_UPDATE.sql, then try again. If it still fails, check your Supabase policies."
        }
    }
}

struct ManageListingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MarketplaceStore

    let listing: Listing

    @State private var showingDeleteAlert = false
    @State private var selectedStatus: String

    let statuses = ["Available", "Pending", "Completed"]

    init(listing: Listing) {
        self.listing = listing
        _selectedStatus = State(initialValue: listing.status)
    }

    var body: some View {
        Form {
            Section("Listing") {
                Text(listing.title)
                    .font(.headline)

                Text("\(listing.category) • \(listing.condition) • \(listing.type)")
                    .foregroundStyle(.secondary)

                Text(listing.exchangePreference)
                    .font(.headline)

                Text(listing.description)
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("Status") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(statuses, id: \.self) { status in
                        Text(status)
                    }
                }
                .onChange(of: selectedStatus) {
                    Task {
                        await store.updateListingStatus(
                            listingID: listing.id,
                            status: selectedStatus
                        )
                    }
                }
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("Posted By") {
                LabeledContent("Name", value: listing.ownerName)
                LabeledContent("Email", value: listing.ownerEmail)
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Text("Delete Listing")
                }
            }
            .listRowBackground(Color.white.opacity(0.82))
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(ExchangeBackground())
        .tint(ExchangeTheme.forest)
        .navigationTitle("Manage Listing")
        .alert("Delete Listing?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                dismiss()

                Task {
                    await store.deleteListing(id: listing.id)
                }
            }
        } message: {
            Text("This will remove the listing from The Exchange.")
        }
    }
}

struct CommunityStandardsView: View {
    var body: some View {
        List {
            Section("Core Rules") {
                Label("Use your real school identity", systemImage: "person.crop.circle.badge.checkmark")
                Label("Meet only on campus", systemImage: "building.2")
                Label("Keep trades fair and respectful", systemImage: "handshake")
                Label("Do not post unsafe or prohibited items", systemImage: "exclamationmark.triangle")
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("Allowed Items") {
                Text("Textbooks")
                Text("School supplies")
                Text("Art materials")
                Text("Sports gear")
                Text("Club or activity equipment")
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("Not Allowed") {
                Text("Weapons or dangerous items")
                Text("Medication or health products")
                Text("Food or opened consumables")
                Text("Counterfeit or stolen items")
                Text("Anything inappropriate for school")
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("If Something Feels Wrong") {
                Text("Do not complete the exchange.")
                Text("Use the Report Listing button.")
                Text("Tell a teacher, advisor, or school administrator.")
            }
            .listRowBackground(Color.white.opacity(0.82))
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(ExchangeBackground())
        .tint(ExchangeTheme.forest)
        .navigationTitle("Standards")
    }
}

struct ProjectProgressView: View {
    var body: some View {
        List {
            Section("Complete in Prototype") {
                Label("Browse listings", systemImage: "checkmark.circle.fill")
                Label("Create listings", systemImage: "checkmark.circle.fill")
                Label("Search and category filters", systemImage: "checkmark.circle.fill")
                Label("My Listings management", systemImage: "checkmark.circle.fill")
                Label("Listing status controls", systemImage: "checkmark.circle.fill")
                Label("Supabase Auth sign up and login", systemImage: "checkmark.circle.fill")
                Label("Supabase listings database", systemImage: "checkmark.circle.fill")
                Label("Shared saved listings", systemImage: "checkmark.circle.fill")
                Label("Supabase messages", systemImage: "checkmark.circle.fill")
                Label("Community standards", systemImage: "checkmark.circle.fill")
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("Next Build Steps") {
                Label("Create a Supabase project", systemImage: "circle")
                Label("Run the Supabase schema SQL", systemImage: "circle")
                Label("Add Supabase URL and anon key", systemImage: "circle")
                Label("Tighten marketplace database policies", systemImage: "circle")
                Label("Pilot test with a small student group", systemImage: "circle")
            }
            .listRowBackground(Color.white.opacity(0.82))

            Section("Pilot Testing Goals") {
                Text("Test with a small group of students.")
                Text("Collect feedback on posting and browsing.")
                Text("Check whether students understand safe exchange rules.")
                Text("Use feedback to simplify confusing screens.")
            }
            .listRowBackground(Color.white.opacity(0.82))
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(ExchangeBackground())
        .tint(ExchangeTheme.forest)
        .navigationTitle("Progress")
    }
}

struct ModeratorReportsView: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        List {
            if store.reports.isEmpty {
                ContentUnavailableView(
                    "No Reports",
                    systemImage: "checkmark.shield",
                    description: Text("Reported listings will appear here for review.")
                )
            } else {
                ForEach(store.reports) { report in
                    Section(report.listingTitle) {
                        LabeledContent("Reported By", value: report.reportedByEmail)
                        LabeledContent("Reason", value: report.reason)
                        LabeledContent("Status", value: report.status)

                        Picker(
                            "Status",
                            selection: Binding(
                                get: { report.status },
                                set: { newStatus in
                                    Task {
                                        await store.updateReportStatus(
                                            reportID: report.id,
                                            status: newStatus
                                        )
                                    }
                                }
                            )
                        ) {
                            Text("Open").tag("Open")
                            Text("Reviewed").tag("Reviewed")
                            Text("Dismissed").tag("Dismissed")
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.82))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(ExchangeBackground())
        .tint(ExchangeTheme.forest)
        .navigationTitle("Reports")
    }
}
