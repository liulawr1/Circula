//
//  ExchangeTheme.swift
//  TheExchange
//

import SwiftUI
import UIKit

enum ExchangeTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.98, blue: 0.96),
            Color(red: 0.91, green: 0.95, blue: 0.99),
            Color(red: 0.98, green: 0.96, blue: 0.91)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ink = Color(red: 0.08, green: 0.12, blue: 0.16)
    static let forest = Color(red: 0.05, green: 0.36, blue: 0.29)
    static let teal = Color(red: 0.06, green: 0.55, blue: 0.62)
    static let gold = Color(red: 0.86, green: 0.60, blue: 0.16)
    static let coral = Color(red: 0.82, green: 0.24, blue: 0.22)
    static let card = Color.white.opacity(0.86)
    static let softStroke = Color.black.opacity(0.08)
}

struct ExchangeBackground: View {
    var body: some View {
        ExchangeTheme.background
            .ignoresSafeArea()
    }
}

struct ExchangeCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(ExchangeTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ExchangeTheme.softStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 14, y: 8)
    }
}

extension View {
    func exchangeCard() -> some View {
        modifier(ExchangeCard())
    }

    func keyboardDismissControls() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    KeyboardHelper.dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(ExchangeTheme.forest)
            }
        }
    }
}

enum KeyboardHelper {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
