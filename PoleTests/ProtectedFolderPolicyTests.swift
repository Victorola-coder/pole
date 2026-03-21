import XCTest
@testable import Pole

final class ProtectedFolderPolicyTests: XCTestCase {
    private let policy = ProtectedFolderPolicy()

    func testProtectedFolderMatchesContainedFile() {
        let protected = URL(fileURLWithPath: "/tmp/my-protected")
        let file = URL(fileURLWithPath: "/tmp/my-protected/sub/file.txt")
        XCTAssertTrue(policy.isProtected(url: file, protectedFolders: [protected]))
    }

    func testProtectedFolderDoesNotMatchOutsideFile() {
        let protected = URL(fileURLWithPath: "/tmp/my-protected")
        let file = URL(fileURLWithPath: "/tmp/my-protected-2/file.txt")
        XCTAssertFalse(policy.isProtected(url: file, protectedFolders: [protected]))
    }
}
