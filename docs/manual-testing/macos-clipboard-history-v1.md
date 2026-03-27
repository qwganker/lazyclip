# macOS Clipboard History v1 Manual QA Checklist

## Environment

- macOS 14+
- Build launched from Xcode or Finder
- Fresh enough environment to verify persisted history and settings behavior

## Acceptance Checklist

- [ ] Launch the app and confirm the LazyClip menu bar icon appears.
- [ ] Open the menu bar panel and confirm the history panel renders instead of placeholder content.
- [ ] Copy plain text and verify a new item appears in the panel near-immediately.
- [ ] Copy the same text twice in a row and verify only one new history record is added.
- [ ] Copy different text, then copy the earlier text again, and verify the later non-consecutive duplicate is recorded.
- [ ] Search for a known substring and verify the list filters to matching rows only.
- [ ] Clear the search field and verify the full newest-first history list returns.
- [ ] Click a history item and verify its text is written back to the system clipboard.
- [ ] After re-copying, verify no duplicate history row is created from the app's own clipboard write.
- [ ] Delete a single item and verify the row disappears immediately.
- [ ] Open Settings and verify the shared app state is shown instead of placeholder content.
- [ ] Toggle **Pause recording** on and verify the main panel shows a lightweight paused indicator.
- [ ] While paused, copy new text and verify no new history row is recorded.
- [ ] Toggle **Pause recording** off and verify new copied text starts appearing again.
- [ ] Change **History limit** to a smaller value and verify older rows are trimmed.
- [ ] Change **History limit** among 100, 500, 1000, and 5000 and verify the selection persists.
- [ ] Use **Clear all history**, confirm the destructive dialog, and verify history is removed while settings remain intact.
- [ ] Restart the app and verify clipboard history and settings persist across launch.
- [ ] Seed more than one page of history data and verify the initial panel open stays responsive.
- [ ] Scroll near the bottom of the list and verify older rows load on demand.
- [ ] Verify search still works correctly after paging additional results.
- [ ] Verify no AppKit-specific issues leak into the SwiftUI surfaces (panel/settings continue to behave normally).

## Automated Verification

Run:

```bash
xcodebuild test -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'
```

Expected:

- All tests pass.

Run:

```bash
xcodebuild build -project LazyClip.xcodeproj -scheme LazyClip -destination 'platform=macOS'
```

Expected:

- `BUILD SUCCEEDED`
