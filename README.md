# Jokoson

Jokoson is a native, lightweight JSON viewer for macOS and iOS. It lets you paste or open JSON locally, validate it, and inspect the document as an expandable tree.

## Features

- Paste JSON from the clipboard or edit JSON directly
- Open local `.json` files
- Validate malformed JSON with line and column details
- View objects and arrays in a conventional JSON tree
- Expand and collapse individual nodes
- Expand all or collapse all nodes
- Search keys and values
- Highlight matching nodes
- Copy serialized values
- Copy JSON paths such as `$.users[0].name`
- Syntax highlighting for keys, strings, numbers, booleans, `null`, and punctuation
- Native SwiftUI layouts for iPhone, iPad, and macOS
- SF Pro for interface text and SF Mono for JSON content
- Light and dark macOS application icon variants
- Local-only processing with no Firebase, cloud sync, accounts, or backend services

## Supported platforms

| Platform | Minimum target |
| --- | --- |
| macOS | macOS 14.0 or later |
| iOS | iOS 26.2 or later |

The project currently uses Xcode 26.3 project settings and Swift 5 language mode.

## Requirements

- macOS with Xcode installed
- An Apple ID for running on a physical device
- Apple Developer Program membership for signed distribution builds

No external package installation is required. Firebase and other cloud SDK dependencies have been removed from the project.

## Clone and open the project

```sh
git clone https://github.com/prammmoe/jokoson.git
cd jokoson
open Jokoson.xcodeproj
```

In Xcode, select the `Jokoson` scheme and choose either a macOS destination or an iOS Simulator/device.

Press **Run** to launch the app.

## Use the app

1. Paste JSON into the Input editor, or open a local `.json` file.
2. Select **View JSON** or switch to **Viewer** mode.
3. Expand and collapse objects and arrays with the disclosure buttons.
4. Use the search field to find keys or values.
5. Right-click or long-press a node to copy its value or JSON path.

Example:

```json
{
  "users": [
    {
      "name": "Ada",
      "active": true
    }
  ]
}
```

## Build the macOS app

Build a Release app without creating a DMG:

```sh
xcodebuild \
  -project Jokoson.xcodeproj \
  -scheme Jokoson \
  -configuration Release \
  -sdk macosx \
  -derivedDataPath .build/Release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The app will be produced at:

```text
.build/Release/Build/Products/Release/Jokoson.app
```

## Create a macOS DMG

The repository includes [build_dmg.sh](build_dmg.sh). It builds the macOS Release target and creates a drag-to-install DMG containing only:

- `Jokoson.app`
- An `Applications` shortcut

Run:

```sh
./build_dmg.sh
```

The output is:

```text
Jokoson.dmg
```

The script uses unsigned output by default for local testing. To use automatic Apple signing during the build:

```sh
CODE_SIGNING_ALLOWED=YES \
ALLOW_PROVISIONING_UPDATES=YES \
./build_dmg.sh
```

## Install from a DMG

1. Download `Jokoson.dmg`.
2. Open the DMG.
3. Drag `Jokoson` to `Applications`.
4. Eject the DMG.
5. Open Jokoson from Applications.

For an unsigned internal build, macOS may display a security warning. Control-click the app, select **Open**, and confirm. This requirement is avoided by properly signing and notarizing the release.

## Testing

Unit and UI tests are located in:

- `JokosonTests/`
- `JokosonUITests/`

Run them from Xcode with **Product → Test**. The parser tests cover nested values, escaped strings, Unicode, numbers, duplicate keys, malformed JSON, and line/column errors.

## Project structure

```text
Jokoson/
├── ContentView.swift              # SwiftUI input, viewer, and platform layouts
├── JSONParser.swift               # Ordered recursive-descent parser
├── JSONSyntaxHighlighting.swift   # Native iOS/macOS syntax-colored editor
├── JSONValue.swift                # JSON model, formatting, and paths
├── JSONWorkspace.swift             # Shared workspace state and tree flattening
├── JokosonApp.swift                # SwiftUI app entry point
└── Assets.xcassets/               # App icon and accent color assets
```

## Privacy and data handling

Jokoson processes JSON locally in memory. It does not send JSON to a server, store document history, require an account, or use Firebase. Imported files are read locally and are not copied to a cloud service.

## Troubleshooting

### The DMG contains project files

You downloaded GitHub's **Source code (zip)** archive. Download `Jokoson.dmg` from the release's **Assets** section instead.

### The app icon looks stale

Rebuild the DMG and replace the existing copy in Applications. Finder can cache application icons; restarting Finder or logging out and back in may be necessary.

### macOS blocks the app

The default build is unsigned. Use Control-click → **Open** for internal testing, or distribute a Developer ID-signed and notarized build.

### The DMG script fails during `hdiutil`

Run the script directly on macOS with Xcode Command Line Tools installed. The script requires `xcodebuild` and `hdiutil`, both provided by macOS/Xcode.
