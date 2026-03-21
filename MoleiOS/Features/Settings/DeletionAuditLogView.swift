import SwiftUI

struct DeletionAuditLogView: View {
    let auditLogger: DeletionAuditLogging
    @State private var entries: [DeletionAuditEntry] = []

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Audit Entries Yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Deletion and dry-run operations will appear here.")
                )
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.candidateName)
                                .font(.headline)
                            Spacer()
                            Text(resultLabel(for: entry.result))
                                .font(.caption)
                                .foregroundStyle(resultColor(for: entry.result))
                        }
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(entry.source.rawValue.capitalized) • \(ByteCountFormatter.string(fromByteCount: entry.sizeBytes, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let message = entry.message, !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Deletion Audit Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) {
                    auditLogger.clear()
                    reload()
                }
                .disabled(entries.isEmpty)
            }
        }
        .task {
            reload()
        }
    }

    private func reload() {
        entries = auditLogger.recentEntries(limit: 300)
    }

    private func resultLabel(for result: DeletionAuditResult) -> String {
        switch result {
        case .deleted: return "Deleted"
        case .dryRun: return "Dry Run"
        case .blocked: return "Blocked"
        case .failed: return "Failed"
        }
    }

    private func resultColor(for result: DeletionAuditResult) -> Color {
        switch result {
        case .deleted: return .green
        case .dryRun: return .blue
        case .blocked: return .orange
        case .failed: return .red
        }
    }
}
