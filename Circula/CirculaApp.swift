//
//  CirculaApp.swift
//  Circula
//
//  Created by Lawrence Liu on 5/5/26.
//

import SwiftUI

@main
struct CirculaApp: App {
    @StateObject private var store = MarketplaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tapToDismissKeyboard()
                .preferredColorScheme(.light)
        }
    }
}
