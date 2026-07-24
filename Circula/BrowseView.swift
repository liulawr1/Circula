//
//  BrowseView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI
import UIKit

struct BrowseView: View {
    @EnvironmentObject private var store: MarketplaceStore

    let currentUserName: String
    let currentUserEmail: String
    let isGuest: Bool
    let onSignIn: () -> Void

    init(
        currentUserName: String,
        currentUserEmail: String,
        isGuest: Bool = false,
        onSignIn: @escaping () -> Void = { }
    ) {
        self.currentUserName = currentUserName
        self.currentUserEmail = currentUserEmail
        self.isGuest = isGuest
        self.onSignIn = onSignIn
    }

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedType = "All"
    @State private var selectedSort = "Newest"

    let categories = ["All", "Textbooks", "School Supplies", "Sports Gear", "Art Supplies", "Tech", "Other"]
    let types = ["All", "Trade", "Sell", "Free"]
    let sortOptions = ["Newest", "Title", "Status"]

    var cleanedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasActiveFilters: Bool {
        !cleanedSearchText.isEmpty || selectedCategory != "All" || selectedType != "All"
    }

    var couldNotLoadListings: Bool {
        store.listings.isEmpty && store.syncError != nil && !store.isLoading
    }

    var filteredListings: [Listing] {
        let filtered = store.listings.filter { listing in
            let matchesCategory = selectedCategory == "All" || listing.category == selectedCategory
            let matchesType = selectedType == "All" || listing.type == selectedType

            let matchesSearch = cleanedSearchText.isEmpty ||
                listing.title.localizedCaseInsensitiveContains(cleanedSearchText) ||
                listing.description.localizedCaseInsensitiveContains(cleanedSearchText) ||
                listing.category.localizedCaseInsensitiveContains(cleanedSearchText)

            return matchesCategory && matchesType && matchesSearch
        }

        switch selectedSort {
        case "Title":
            return filtered.sorted { first, second in
                first.title < second.title
            }
        case "Status":
            return filtered.sorted { first, second in
                first.status < second.status
            }
        default:
            return filtered.sorted { first, second in
                first.createdAt > second.createdAt
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BrowseHeaderView(
                    currentUserName: currentUserName,
                    listingCount: filteredListings.count,
                    isGuest: isGuest
                )
                .padding(.horizontal)
                .padding(.top, 8)

                categoryFilterBar
                typeFilterBar
                sortPicker

                if filteredListings.isEmpty && store.isLoading {
                    ProgressView("Loading listings...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredListings.isEmpty {
                    emptyState
                } else {
                    List(filteredListings) { listing in
                        NavigationLink {
                            ListingDetailView(
                                listing: listing,
                                currentUserName: currentUserName,
                                currentUserEmail: currentUserEmail,
                                isGuest: isGuest,
                                onSignIn: onSignIn
                            )
                        } label: {
                            ListingRowView(listing: listing)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable {
                        await store.refreshAll()
                    }
                }
            }
            .background(CirculaBackground())
            .tint(CirculaTheme.forest)
            .navigationTitle("Circula")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search listings"
            )
            .onSubmit(of: .search) {
                KeyboardHelper.dismiss()
            }
        }
    }

    var emptyState: some View {
        ScrollView {
            if couldNotLoadListings {
                ContentUnavailableView {
                    Label("Couldn't Load Listings", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Check your internet connection, then try again.")
                } actions: {
                    Button("Try Again") {
                        Task {
                            await store.refreshAll()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if hasActiveFilters {
                ContentUnavailableView {
                    Label("No Matches", systemImage: "magnifyingglass")
                } description: {
                    Text("Try changing your search or filters.")
                } actions: {
                    Button("Clear Filters") {
                        searchText = ""
                        selectedCategory = "All"
                        selectedType = "All"
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ContentUnavailableView(
                    "No Listings Yet",
                    systemImage: "shippingbox",
                    description: Text(
                        isGuest
                            ? "Check back soon for new student listings."
                            : "Be the first student to post an item."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            await store.refreshAll()
        }
    }

    var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? CirculaTheme.forest : Color.white.opacity(0.75))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.clear)
    }

    var typeFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.self) { type in
                Button {
                    selectedType = type
                } label: {
                    Text(type)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedType == type ? CirculaTheme.teal : Color.white.opacity(0.75))
                        .foregroundStyle(selectedType == type ? .white : .primary)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    var sortPicker: some View {
        Picker("Sort", selection: $selectedSort) {
            ForEach(sortOptions, id: \.self) { option in
                Text(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct BrowseHeaderView: View {
    let currentUserName: String
    let listingCount: Int
    let isGuest: Bool

    var firstName: String {
        currentUserName.components(separatedBy: " ").first ?? currentUserName
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isGuest ? "Browse as Guest" : "Hi, \(firstName)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(CirculaTheme.ink)

                Text("\(listingCount) listings ready to browse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(CirculaTheme.forest)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .circulaCard()
    }
}
