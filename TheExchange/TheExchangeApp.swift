//
//  TheExchangeApp.swift
//  TheExchange
//
//  Created by Lawrence Liu on 5/5/26.
//

import SwiftUI

@main
struct TheExchangeApp: App {
    @StateObject private var store = MarketplaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
