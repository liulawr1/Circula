//
//  CreateListingView.swift
//  Circula
//
//  Created by Lawrence Liu on 5/6/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct CreateListingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MarketplaceStore

    let currentUserName: String
    let currentUserEmail: String

    @State private var title = ""
    @State private var category = "Textbooks"
    @State private var condition = "Good"
    @State private var type = "Trade"
    @State private var description = ""
    @State private var exchangePreference = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isPosting = false
    @State private var showingCreatedAlert = false
    @State private var createdAlertTitle = ""
    @State private var createdAlertMessage = ""
    @State private var dismissAfterAlert = false

    let categories = ["Textbooks", "School Supplies", "Sports Gear", "Art Supplies", "Tech", "Other"]
    let conditions = ["New", "Excellent", "Good", "Fair", "Poor"]
    let types = ["Trade", "Sell", "Free"]

    var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedExchangePreference: String {
        exchangePreference.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canPost: Bool {
        !cleanedTitle.isEmpty &&
            !cleanedDescription.isEmpty &&
            !cleanedExchangePreference.isEmpty &&
            !isPosting
    }

    var preferencePrompt: String {
        switch type {
        case "Trade":
            return "What would you trade for?"
        case "Sell":
            return "Price"
        case "Free":
            return "Free item note"
    default:
        return "Trade preference"
    }
}

    var body: some View {
        Form {
            Section("Photo") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let selectedImageData,
                       let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Label("Choose Item Photo", systemImage: "photo")
                    }
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    selectedImageData = await preparedImageData(from: selectedPhoto)
                }
            }

            Section("Item Info") {
                TextField("Title", text: $title)

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        Text(category)
                    }
                }

                Picker("Condition", selection: $condition) {
                    ForEach(conditions, id: \.self) { condition in
                        Text(condition)
                    }
                }

                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { type in
                        Text(type)
                    }
                }

                TextField(preferencePrompt, text: $exchangePreference)
            }

            Section("Description") {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(4...8)
            }

            Section("Your Info") {
                LabeledContent("Name", value: currentUserName)
                LabeledContent("Email", value: currentUserEmail)
            }

            Button("Post Listing") {
                KeyboardHelper.dismiss()

                if let moderationMessage = ContentModeration.listingIssue(
                    title: cleanedTitle,
                    description: cleanedDescription,
                    exchangePreference: cleanedExchangePreference
                ) {
                    showAlert(title: "Review Your Listing", message: moderationMessage)
                    return
                }

                isPosting = true

                let newListing = Listing(
                    title: cleanedTitle,
                    category: category,
                    condition: condition,
                    type: type,
                    description: cleanedDescription,
                    exchangePreference: cleanedExchangePreference,
                    imageData: selectedImageData,
                    ownerName: currentUserName,
                    ownerEmail: currentUserEmail,
                    createdAt: Date(),
                    status: "Available"
                )

                Task {
                    let synced = await store.createListing(newListing)

                    isPosting = false

                    if synced {
                        title = ""
                        category = "Textbooks"
                        condition = "Good"
                        type = "Trade"
                        description = ""
                        exchangePreference = ""
                        selectedPhoto = nil
                        selectedImageData = nil
                        showAlert(
                            title: "Listing Created",
                            message: "Your listing has been posted to Circula.",
                            shouldDismiss: true
                        )
                    } else {
                        showAlert(
                            title: "Listing Not Posted",
                            message: "Circula could not reach the server. Your information is still here so you can try again."
                        )
                    }
                }
            }
            .disabled(!canPost)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(CirculaBackground())
        .tint(CirculaTheme.forest)
        .navigationTitle("Post Listing")
        .onSubmit {
            KeyboardHelper.dismiss()
        }
        .alert(createdAlertTitle, isPresented: $showingCreatedAlert) {
            Button("OK", role: .cancel) {
                if dismissAfterAlert {
                    dismiss()
                }
            }
        } message: {
            Text(createdAlertMessage)
        }
    }

    func preparedImageData(from item: PhotosPickerItem?) async -> Data? {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return nil
        }

        let maxDimension: CGFloat = 1200
        let largestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / largestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.75)
    }

    func showAlert(title: String, message: String, shouldDismiss: Bool = false) {
        createdAlertTitle = title
        createdAlertMessage = message
        dismissAfterAlert = shouldDismiss
        showingCreatedAlert = true
    }
}
