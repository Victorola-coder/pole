import SwiftUI
import Photos
import UIKit

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var photoPermissionStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showClearFoldersConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy & Permissions") {
                    LabeledContent("Photo Library") {
                        Text(photoPermissionLabel)
                            .foregroundStyle(.secondary)
                    }
                    Button("Request Photo Access") {
                        Task {
                            let _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                            photoPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                        }
                    }
                    Link("Open iOS Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }

                Section("Scan Behavior") {
                    Toggle("Auto Scan On Launch", isOn: $appState.autoScanOnLaunch)
                    Toggle("Include Videos", isOn: $appState.includeVideosInScan)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Minimum Candidate Size: \(Int(appState.minimumCandidateSizeMB)) MB")
                            .font(.subheadline)
                        Slider(value: $appState.minimumCandidateSizeMB, in: 1...2048, step: 1)
                    }
                }

                Section("Cleanup Safety") {
                    Toggle("Use Face ID / Touch ID", isOn: $appState.shouldUseBiometricLock)
                    Toggle("Strict Double Confirmation", isOn: $appState.strictDeleteConfirmation)
                    Toggle("Dry Run Deletions", isOn: $appState.dryRunDeletionEnabled)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appState.appearance) {
                        ForEach(AppearanceOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    Picker("Accent", selection: $appState.accent) {
                        ForEach(AccentOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

//                Section("App Icon Concept") {
//                    HStack {
//                        Spacer()
//                        AppIconPreview()
//                        Spacer()
//                    }
//                    Text("Minimal flat concept: shield + sparkle, optimized for readability.")
//                        .font(.footnote)
//                        .foregroundStyle(.secondary)
//                }

                Section("Data Management") {
                    Button("Clear Saved Folder Access", role: .destructive) {
                        showClearFoldersConfirmation = true
                    }
                }

                Section("App State") {
                    Toggle("Onboarding Completed", isOn: $appState.isOnboardingComplete)
                }
            }
            .navigationTitle("Settings")
            .task {
                photoPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            }
            .alert("Clear saved folder access?", isPresented: $showClearFoldersConfirmation) {
                Button("Clear", role: .destructive) {
                    appState.clearSavedFolders()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all previously granted Files folders from the app.")
            }
        }
    }

    private var photoPermissionLabel: String {
        switch photoPermissionStatus {
        case .authorized: return "Authorized"
        case .limited: return "Limited"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}
