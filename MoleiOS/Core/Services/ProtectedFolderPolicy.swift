import Foundation

protocol ProtectedFolderChecking {
    func isProtected(url: URL, protectedFolders: [URL]) -> Bool
}

struct ProtectedFolderPolicy: ProtectedFolderChecking {
    func isProtected(url: URL, protectedFolders: [URL]) -> Bool {
        let candidatePath = normalizedPath(for: url)
        for folder in protectedFolders {
            let protectedPath = normalizedPath(for: folder)
            if candidatePath == protectedPath || candidatePath.hasPrefix(protectedPath + "/") {
                return true
            }
        }
        return false
    }

    private func normalizedPath(for url: URL) -> String {
        let standardized = url.standardizedFileURL
        return standardized.resolvingSymlinksInPath().path
    }
}
