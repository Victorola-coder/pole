import SwiftUI

struct AppIconPreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "shield.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Image(systemName: "sparkle")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 34, y: -28)
        }
        .frame(width: 160, height: 160)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        .accessibilityLabel("App icon preview")
    }
}
