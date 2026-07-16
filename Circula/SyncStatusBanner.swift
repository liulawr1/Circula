//
//  SyncStatusBanner.swift
//  Circula
//

import SwiftUI

struct SyncStatusBanner: View {
    @EnvironmentObject private var store: MarketplaceStore

    var body: some View {
        if let syncError = store.syncError {
            Label(syncError, systemImage: "network.slash")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
        }
    }
}
