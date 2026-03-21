import SwiftUI
import LocalAuthentication

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @ObservedObject var appState: AppState
    @State private var pendingDeleteCandidate: CleanupCandidate?
    @State private var pendingStrictCandidate: CleanupCandidate?
    @State private var showStrictConfirmation = false
    @State private var showAuthError = false
    @State private var authErrorMessage = ""

    init(viewModel: DashboardViewModel, appState: AppState) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.appState = appState
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView(value: viewModel.scanProgress)
                        Text(viewModel.scanStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Cancel Scan", role: .cancel) {
                            viewModel.cancelScan()
                        }
                    }
                    .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Scan failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                        .overlay(alignment: .bottom) {
                            HStack(spacing: 12) {
                                Button("Retry") {
                                    Task { await viewModel.load() }
                                }
                                Button("Dismiss") {
                                    viewModel.clearError()
                                }
                            }
                            .padding(.bottom, 20)
                        }
                } else {
                    List {
                        if !viewModel.canScanPhotos {
                            Section("Permissions") {
                                Button("Allow Photo Access") {
                                    Task {
                                        await viewModel.requestPhotoAccess()
                                        await viewModel.load()
                                    }
                                }
                            }
                        }

                        Section("Overview") {
                            statRow(title: "Used Storage", value: String(format: "%.1f GB", viewModel.totalUsed))
                            statRow(title: "Potential Savings", value: String(format: "%.1f GB", viewModel.totalRecoverable))
                        }

                        Section("Suggestions") {
                            ForEach(viewModel.insights) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.category)
                                        .font(.headline)
                                    Text("Used: \(item.usedGigabytes, specifier: "%.1f") GB")
                                    Text("Recoverable: \(item.suggestedSavingsGigabytes, specifier: "%.1f") GB")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        Section("Cleanup Candidates") {
                            if viewModel.candidates.isEmpty {
                                Text("No candidates found.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.candidates.prefix(20)) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.displayName)
                                            Text(item.source.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(item.sizeLabel)
                                            .font(.footnote)
                                        Button("Delete", role: .destructive) {
                                            pendingDeleteCandidate = item
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pole")
            .sheet(item: $pendingDeleteCandidate) { item in
                NavigationStack {
                    List {
                        Section("Preview") {
                            CleanupCandidatePreview(candidate: item)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }

                        Section("Item") {
                            HStack(spacing: 12) {
                                Image(systemName: item.sourceSymbolName)
                                    .font(.title3)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName)
                                        .font(.headline)
                                    Text(item.source.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section("Metadata") {
                            statRow(title: "Size", value: item.sizeLabel)
                            if let createdAt = item.createdAt {
                                statRow(title: "Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let detailText = item.detailText {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Details")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(detailText)
                                        .font(.footnote)
                                }
                            }
                        }

                        Section {
                            Button("Delete This Item", role: .destructive) {
                                Task {
                                    await handleDeleteRequest(for: item)
                                }
                                pendingDeleteCandidate = nil
                            }
                            Button("Cancel", role: .cancel) {
                                pendingDeleteCandidate = nil
                            }
                        } footer: {
                            Text("Deletion is permanent for files. Photo library deletion follows iOS behavior and may move items to Recently Deleted.")
                        }
                    }
                    .navigationTitle("Review Deletion")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .task {
                if appState.autoScanOnLaunch && viewModel.insights.isEmpty {
                    await viewModel.load()
                }
            }
            .alert("Biometric Check Failed", isPresented: $showAuthError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authErrorMessage)
            }
            .alert("Final Confirmation", isPresented: $showStrictConfirmation, presenting: pendingStrictCandidate) { item in
                Button("Delete \(item.displayName)", role: .destructive) {
                    Task {
                        await viewModel.delete(candidate: item)
                    }
                    pendingStrictCandidate = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingStrictCandidate = nil
                }
            } message: { _ in
                Text("Strict mode is enabled. Confirm again to proceed.")
            }
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold()
        }
    }

    private func handleDeleteRequest(for item: CleanupCandidate) async {
        if appState.shouldUseBiometricLock {
            let ok = await authenticateBiometrically()
            if !ok { return }
        }

        if appState.strictDeleteConfirmation {
            pendingStrictCandidate = item
            showStrictConfirmation = true
            return
        }

        await viewModel.delete(candidate: item)
    }

    private func authenticateBiometrically() async -> Bool {
        await withCheckedContinuation { continuation in
            let context = LAContext()
            var error: NSError?
            let reason = "Confirm identity before deleting data."

            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                authErrorMessage = "Biometric authentication is unavailable on this device."
                showAuthError = true
                continuation.resume(returning: false)
                return
            }

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
                DispatchQueue.main.async {
                    if !success {
                        authErrorMessage = evalError?.localizedDescription ?? "Authentication failed."
                        showAuthError = true
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
