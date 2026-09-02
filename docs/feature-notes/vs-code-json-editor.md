# VS Code JSON Editor Implementation Notes

Branch: `main`

## 2026-09-02 - VS Code-style JSON editor

### Changed
- Replaced saturated system syntax colors with adaptive muted tokens shared by the Input editor and Viewer.
- Added native macOS and iOS Input-editor rendering for line-number gutters, indentation guides, and the active-line highlight.
- Added unit coverage for syntax token attributes and editor line/indent metrics.

### Stayed The Same
- JSON parsing, tree Viewer interactions, input accessibility identifiers, selections, and smart-text suppression remain unchanged.
- The existing uncommitted Jokoson title change in `ContentView.swift` was not altered.

### Verification
- Built the macOS Debug target with code signing disabled and ran all 9 unit tests successfully.
- iOS source compilation was reached, but the local Xcode simulator runtime service is unavailable during asset compilation.

## 2026-09-02 - Empty Viewer guard and empty-editor gutter fix

### Changed
- Added a native alert when Viewer is requested with empty or whitespace-only JSON.
- Added test coverage for the empty-Viewer guard.

### Bugs And Fixes
- Bug: The macOS and iOS line-number renderers enumerated layout fragments for an empty editor, producing a long sequence of phantom line numbers.
  Fix: Empty editors now render only line 1 and ignore synthetic fragments beyond the source length.

### Verification
- Built the macOS test target and ran all 10 unit tests successfully.

## 2026-09-02 - 160 pt Table Viewer limit

### Changed
- Reduced the macOS Table Viewer minimum drag width to 160 pt and lowered its column minima so the divider can move further right.

## 2026-09-02 - Further reduce Table Viewer minimum width

### Changed
- Reduced the macOS Table Viewer minimum drag width to 80 pt and relaxed both column minimums, allowing the panel to be collapsed much further when its divider is dragged right.

## 2026-09-02 - Remove Table Viewer split minimum

### Changed
- Removed the outer macOS table pane minimum width and lowered its layout priority, allowing the main tree/table divider to be dragged all the way toward the right edge.

## 2026-09-02 - Stable macOS window layout

### Changed
- Made the desktop window respect its content minimum size and use balanced navigation columns, preventing the sidebar and detail panes from being compressed into an off-screen-looking layout when using macOS Zoom or Fill.

### Verification
- Built the macOS Debug target successfully with code signing disabled.

## 2026-09-02 - macOS title-bar safe area

### Changed
- Reserved a top safe-area inset for the macOS workspace so sidebar and editor content stay below the unified title bar and traffic-light controls after Zoom or Fill.

### Verification
- Built the macOS Debug target successfully with code signing disabled.

## 2026-09-02 - Stable split-view title-bar spacing

### Changed
- Replaced the root safe-area inset with fixed macOS top padding on the sidebar and detail content.

### Bugs And Fixes
- Bug: Toggling the desktop Input/Viewer split could trigger repeated AppKit constraint updates and terminate with `EXC_BAD_ACCESS`.
  Fix: Keep title-bar clearance inside stable column content instead of dynamically changing the root safe-area layout.

### Verification
- Source diff was checked for whitespace errors; the macOS build-and-test command was not completed because its execution was rejected.

## 2026-09-02 - Expand Table Viewer pane

### Changed
- Let the macOS Viewer split view fill the available detail width and cap the tree pane at 900 pt, so the remaining space expands the table pane while preserving its draggable divider.

### Verification
- Built the macOS test target and ran all 11 unit tests successfully.

## 2026-09-02 - Narrower Table Viewer limit

### Changed
- Reduced the macOS table pane's minimum drag width from 300 pt to 220 pt, with matching compact column minima, so it can be collapsed further toward the right edge.

## 2026-09-02 - Compact Viewer typography

### Changed
- Reduced the Viewer JSON tree font size to 14 pt while leaving Input-editor and toolbar typography unchanged.

## 2026-09-02 - Compact Viewer row spacing

### Changed
- Reduced Viewer row minimum height from 34 pt to 28 pt to match the smaller JSON font.

## 2026-09-02 - Table Viewer

### Changed
- Added a resizable macOS split view with the JSON tree on the left and a read-only Name/Value table on the right.
- Added persistent tree-row selection and table context resolution: containers show their children while scalar selections show their parent object's children.
- Added unit coverage for root, object, array, and scalar table contexts.

### Stayed The Same
- iOS and iPad retain the existing tree-only Viewer; table rows do not edit JSON or change tree selection.

### Verification
- Built the macOS test target and ran all 11 unit tests successfully.

## 2026-09-02 - Match Viewer width to Input

### Changed
- Reduced the Viewer content column from 1120 pt to 980 pt, matching the Input container width.

## 2026-09-02 - Reliable Viewer Find shortcut

### Changed
- Reduced the Viewer content column from 1280 pt to 1120 pt.
- Added a Viewer-scoped AppKit key monitor for Cmd+F, which directly starts the native toolbar search interaction on macOS 14 and later.

### Bugs And Fixes
- Bug: The SwiftUI menu shortcut could lose to the standard Find command and never focus the Viewer search field.
  Fix: Capture Cmd+F while Viewer is visible and invoke `NSSearchToolbarItem.beginSearchInteraction()` directly.

### Verification
- Built the macOS test target and ran all 10 unit tests successfully.

## 2026-09-02 - Simplify Input editor chrome

### Changed
- Removed line-number gutters and indentation guides from the macOS and iOS Input editors at the user's request.

### Stayed The Same
- Syntax highlighting, the current-line highlight, editing behavior, and the empty-Viewer alert remain in place.

### Verification
- Built the macOS test target and ran all 9 unit tests successfully.

## 2026-09-02 - Compact Viewer and Find shortcut

### Changed
- Centered Viewer content in a responsive 1280 pt maximum-width column.
- Added a Viewer-only Cmd+F command that opens and focuses the native toolbar search field on macOS 14 and later.
- Added workspace test coverage for Viewer search-focus requests.

### Stayed The Same
- Viewer tree expansion, search matching, text selection, and iOS toolbar search behavior remain unchanged.

### Verification
- Built the macOS test target and ran all 10 unit tests successfully.
