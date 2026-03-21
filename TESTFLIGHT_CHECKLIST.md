# TestFlight Release Checklist

## Pre-build

- [ ] `xcodegen generate`
- [ ] `xcodebuild -project Pole.xcodeproj -scheme Pole -destination 'platform=iOS Simulator,OS=18.4,name=iPhone 16' -configuration Debug build test`
- [ ] Verify CI is green for current branch.

## Product QA

- [ ] First-run onboarding appears and completes.
- [ ] Photo permission flow works (not determined/denied/limited/authorized).
- [ ] "Add Folder From Files" works and folders persist after app relaunch.
- [ ] Protected folders block deletion attempts.
- [ ] Dry-run mode does not delete data and surfaces confirmation messaging.
- [ ] Deletion audit log records entries and can be cleared.

## App Store Connect

- [ ] Increment build number.
- [ ] Update release notes with user-facing changes.
- [ ] Confirm privacy answers align with `PRIVACY.md`.
- [ ] Upload build and complete internal testing notes.

## Go/No-Go

- [ ] No blocker crash in smoke test.
- [ ] No regression in scan/delete flows.
- [ ] Team sign-off.
