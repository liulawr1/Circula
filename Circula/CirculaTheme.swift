//
//  CirculaTheme.swift
//  Circula
//

import SwiftUI
import UIKit

enum CirculaTheme {
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

struct CirculaBackground: View {
    var body: some View {
        CirculaTheme.background
            .ignoresSafeArea()
    }
}

struct CirculaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(CirculaTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CirculaTheme.softStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 14, y: 8)
    }
}

extension View {
    func circulaCard() -> some View {
        modifier(CirculaCard())
    }

    func keyboardDismissControls() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    KeyboardHelper.dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(CirculaTheme.forest)
            }
        }
    }

    func tapToDismissKeyboard() -> some View {
        background(KeyboardDismissTapInstaller().frame(width: 0, height: 0))
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

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        func installIfNeeded(from view: UIView) {
            guard let window = view.window,
                  installedWindow !== window else {
                return
            }

            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.recognizer = recognizer
            installedWindow = window
        }

        @objc private func handleTap() {
            KeyboardHelper.dismiss()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view else {
                return true
            }

            return !view.isKeyboardControl
        }
    }
}

private extension UIView {
    var isKeyboardControl: Bool {
        if self is UITextField || self is UITextView || self is UIControl {
            return true
        }

        return superview?.isKeyboardControl ?? false
    }
}
