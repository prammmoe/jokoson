import SwiftUI

@main
struct JokosonApp: App {
    @StateObject private var workspace = JSONWorkspace()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView(workspace: workspace)
        }
        .defaultSize(width: 980, height: 720)
        .commands {
            JokosonCommands(workspace: workspace)
        }
        #else
        WindowGroup {
            ContentView(workspace: workspace)
        }
        #endif
    }
}
