import Foundation

struct DeletionOptions {
    let dryRun: Bool

    static let live = DeletionOptions(dryRun: false)
}
