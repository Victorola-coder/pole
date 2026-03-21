import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Pole")
                    .font(.largeTitle.bold())
                Text("A privacy-first cleanup assistant for photos and your approved folders.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    onboardingRow(
                        icon: "checkmark.shield",
                        title: "Safety First",
                        subtitle: "Dry-run mode, protected folders, and biometric confirmation are available before cleanup."
                    )
                    onboardingRow(
                        icon: "folder.badge.plus",
                        title: "You Control Access",
                        subtitle: "Pole scans only your app data and folders you explicitly select."
                    )
                    onboardingRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Actionable Insights",
                        subtitle: "Review large candidates and delete with confidence."
                    )
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                Button("Get Started") {
                    appState.isOnboardingComplete = true
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 20)
            }
            .padding(.top, 30)
            .navigationBarBackButtonHidden(true)
        }
    }

    private func onboardingRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
