import SwiftUI
import UniformTypeIdentifiers

struct StorageBreakdownView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isFolderPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Categories") {
                    ForEach(viewModel.insights) { insight in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(insight.category)
                                Text("Recoverable \(insight.suggestedSavingsGigabytes, specifier: "%.1f") GB")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(insight.usedGigabytes, specifier: "%.1f") GB")
                                .bold()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Files Access") {
                    Button("Add Folder From Files") {
                        isFolderPickerPresented = true
                    }
                    if viewModel.scopedFolderNames.isEmpty {
                        Text("No external folders granted yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.scopedFolderNames, id: \.self) { name in
                            Text(name)
                        }
                    }
                }
            }
            .navigationTitle("Storage")
            .fileImporter(
                isPresented: $isFolderPickerPresented,
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case .success(let url):
                    Task {
                        await viewModel.addScopedFolder(url: url)
                    }
                case .failure:
                    viewModel.importFolderFailed()
                }
            }
            .task {
                viewModel.syncScopedFolders()
                if viewModel.insights.isEmpty {
                    await viewModel.load()
                }
            }
        }
    }
}
