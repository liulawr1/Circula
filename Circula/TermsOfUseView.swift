//
//  TermsOfUseView.swift
//  Circula
//

import SwiftUI

struct TermsOfUseView: View {
    let onAccept: () -> Void

    @State private var hasAgreed = false

    private let privacyPolicyURL = URL(string: "https://liulawr1.github.io/Circula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(CirculaTheme.forest)

                        Text("Welcome to Circula")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(CirculaTheme.ink)

                        Text("Please review and accept these Terms of Use before signing in or creating an account.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        termsSection(
                            "School-only community",
                            "Circula is for verified Head-Royce students. Use your real school identity and only arrange exchanges on campus."
                        )

                        termsSection(
                            "Zero tolerance for harmful content",
                            "Circula does not tolerate objectionable content or abusive users. Do not post, send, request, or encourage harassment, bullying, hate speech, threats, sexual content, scams, illegal items, unsafe activity, or anything that makes another student feel unsafe."
                        )

                        termsSection(
                            "Report and block",
                            "You can report unsafe or inappropriate listings from a listing's detail page and block a user there as well. Reports may be reviewed by school moderators. We may remove content, suspend access, or take other action when these Terms are violated."
                        )

                        termsSection(
                            "Respect and privacy",
                            "Keep communication respectful, share only what is needed to arrange an exchange, and do not post another person's private information. You are responsible for the content you post and messages you send."
                        )

                        termsSection(
                            "Safety",
                            "Meet only on campus, use good judgment, and tell a trusted adult about any safety concern. Circula is a student marketplace, not a payment processor or guarantor of any exchange."
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy Policy")
                                .font(.headline)
                                .foregroundStyle(CirculaTheme.ink)

                            Link("Read Circula's Privacy Policy", destination: privacyPolicyURL)
                                .font(.subheadline)
                        }
                    }
                    .padding(18)
                    .circulaCard()

                    Toggle(isOn: $hasAgreed) {
                        Text("I have read and agree to the Terms of Use, including the no-tolerance policy for abusive and objectionable content.")
                            .font(.subheadline)
                            .foregroundStyle(CirculaTheme.ink)
                    }
                    .tint(CirculaTheme.forest)

                    Button(action: onAccept) {
                        Text("Agree and Continue")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(CirculaTheme.forest)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(!hasAgreed)
                    .opacity(hasAgreed ? 1 : 0.5)
                }
                .padding()
            }
            .background(CirculaBackground())
            .tint(CirculaTheme.forest)
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func termsSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundStyle(CirculaTheme.ink)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TermsOfUseView { }
}
