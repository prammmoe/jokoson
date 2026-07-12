# macOS DMG distribution

Build an internal DMG from the project root:

```sh
./build_dmg.sh
```

The default output is `Jokoson.dmg`. The script builds the macOS Release target, places the app and an Applications shortcut in a drag-to-install disk image, and uses unsigned output by default for local/internal testing.

For a signed build using the configured Apple Developer team:

```sh
CODE_SIGNING_ALLOWED=YES ALLOW_PROVISIONING_UPDATES=YES ./build_dmg.sh
```

For office-wide distribution outside the development team, sign the app with a Developer ID Application certificate and notarize the DMG. Unsigned DMGs can be blocked by Gatekeeper on other Macs.
