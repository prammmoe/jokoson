import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ContentView: View {
    @ObservedObject var workspace: JSONWorkspace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isInvalidJSONAlertPresented = false

    init(workspace: JSONWorkspace) {
        self.workspace = workspace
    }

    var body: some View {
        Group {
            #if os(macOS)
            RegularWorkspaceView(workspace: workspace)
            #else
            if horizontalSizeClass == .compact {
                CompactWorkspaceView(workspace: workspace)
            } else {
                RegularWorkspaceView(workspace: workspace)
            }
            #endif
        }
        .fileImporter(
            isPresented: $workspace.isFileImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            workspace.importFile(from: url)
        }
        .alert("Invalid JSON", isPresented: $isInvalidJSONAlertPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(workspace.parseError?.errorDescription ?? "The pasted content could not be parsed as JSON.")
        }
        .onChange(of: workspace.parseError) { _, parseError in
            isInvalidJSONAlertPresented = parseError != nil
        }
        .overlay(alignment: .bottom) {
            if let notice = workspace.notice {
                NoticeView(message: notice)
                    .padding(.bottom, 18)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .task {
                        try? await Task.sleep(for: .seconds(1.8))
                        if workspace.notice == notice {
                            withAnimation(.easeOut(duration: 0.18)) {
                                workspace.notice = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: workspace.notice)
    }
}

private struct CompactWorkspaceView: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        NavigationStack {
            WorkspaceSurface(workspace: workspace)
                .navigationTitle("JSON Viewer")
                .toolbar { WorkspaceToolbar(workspace: workspace) }
        }
    }
}

private struct RegularWorkspaceView: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JSON Viewer")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                }

                Picker("Mode", selection: Binding(get: { workspace.mode }, set: { workspace.selectMode($0) })) {
                    ForEach(WorkspaceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("modePicker")

                Button {
                    workspace.isFileImporterPresented = true
                } label: {
                    Label("Open JSON File", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("openFileButton")

                Divider()

                if let document = workspace.document {
                    Label("Document ready", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Document ready")
                    Text("\(document.sourceText.utf8.count.formatted()) bytes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Paste JSON, open a local file, then switch to Viewer to inspect its structure.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("Nothing leaves this device.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(22)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            WorkspaceSurface(workspace: workspace)
                .navigationTitle(workspace.mode == .input ? "Input" : "Viewer")
                .toolbar { WorkspaceToolbar(workspace: workspace) }
        }
    }
}

private struct WorkspaceSurface: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        ZStack {
            switch workspace.mode {
            case .input:
                InputSurface(workspace: workspace)
            case .viewer:
                ViewerSurface(workspace: workspace)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.012))
    }
}

private struct InputSurface: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Paste JSON")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text("Validate and inspect a JSON document locally.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                SyntaxHighlightedTextEditor(text: $workspace.rawText, accessibilityIdentifier: "jsonInput")

                if workspace.rawText.isEmpty {
                    Text("{\n  \"hello\": \"world\"\n}")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }

            if let error = workspace.parseError {
                Label {
                    Text(error.errorDescription ?? "Invalid JSON")
                        .font(.callout)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityIdentifier("parseError")
            }

            HStack(spacing: 10) {
                Button {
                    if let pasted = PasteboardService.read() {
                        workspace.rawText = pasted
                        workspace.notice = "Pasted from clipboard"
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("pasteButton")

                Spacer()

                Button {
                    workspace.parse()
                } label: {
                    if workspace.isParsing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("View JSON", systemImage: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(workspace.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || workspace.isParsing)
                .accessibilityIdentifier("viewJSONButton")
            }
        }
        .padding(24)
        .frame(maxWidth: 980, maxHeight: .infinity, alignment: .top)
    }
}

private struct ViewerSurface: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        Group {
            if workspace.document != nil {
                VStack(spacing: 0) {
                    if !workspace.searchQuery.isEmpty {
                        HStack {
                            Label("\(workspace.matchCount) matching nodes", systemImage: "magnifyingglass")
                            Spacer()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Color.primary.opacity(0.035))
                    }

                    if workspace.visibleRows.isEmpty && !workspace.searchQuery.isEmpty {
                        ContentUnavailableView("No Matches", systemImage: "magnifyingglass", description: Text("Try a different key or value."))
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(workspace.visibleRows) { row in
                                    JSONTreeRowView(row: row, workspace: workspace)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .textSelection(.enabled)
                    }
                }
            } else {
                ContentUnavailableView("No JSON Loaded", systemImage: "curlybraces", description: Text("Paste JSON or open a local .json file to begin."))
            }
        }
        .searchable(text: $workspace.searchQuery, placement: .toolbar, prompt: "Search keys and values")
        .accessibilityIdentifier("jsonViewer")
    }
}

private struct JSONTreeRowView: View {
    let row: JSONTreeRow
    @ObservedObject var workspace: JSONWorkspace
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 7) {
            Color.clear
                .frame(width: CGFloat(row.depth) * 20)

            if row.isClosing {
                Color.clear.frame(width: 22)

                Text(row.value.closingDelimiter)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(JSONSyntaxTheme.punctuation)
            } else {
                if row.value.isContainer {
                    Button {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 1.0)) {
                            workspace.toggleExpansion(for: row.path)
                        }
                    } label: {
                        Image(systemName: row.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.isExpanded ? "Collapse node" : "Expand node")
                } else {
                    Color.clear.frame(width: 22)
                }

                if let key = row.key {
                    Text(key)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .foregroundStyle(JSONSyntaxTheme.key)
                    Text(":")
                        .foregroundStyle(JSONSyntaxTheme.punctuation)
                }

                Text(valueText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(JSONSyntaxTheme.valueColor(for: row.value))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 34)
        .background(row.isMatch ? Color.primary.opacity(0.09) : (isHovered ? Color.primary.opacity(0.035) : .clear), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc") {
                copy(row.value.jsonString(pretty: true))
            }
            Button("Copy JSON Path", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                copy(row.path.description)
            }
        }
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if row.isClosing {
            return "Closing \(row.value.openingDelimiter == "{" ? "object" : "array")"
        }
        let name = row.key ?? "Root"
        return "\(name), \(row.value.summary)"
    }

    private var valueText: String {
        guard row.value.isContainer else { return row.value.jsonString(pretty: false) }
        if row.value.childCount == 0 || !row.isExpanded {
            return row.value.summary
        }
        return row.value.openingDelimiter
    }

    private func copy(_ value: String) {
        PasteboardService.copy(value)
        withAnimation(.easeOut(duration: 0.18)) {
            workspace.notice = "Copied to clipboard"
        }
    }
}

@MainActor
@ToolbarContentBuilder
private func WorkspaceToolbar(workspace: JSONWorkspace) -> some ToolbarContent {
    ToolbarItem(placement: .principal) {
        Picker("Mode", selection: Binding(get: { workspace.mode }, set: { workspace.selectMode($0) })) {
            ForEach(WorkspaceMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 210)
        .accessibilityIdentifier("toolbarModePicker")
    }

    ToolbarItemGroup(placement: .primaryAction) {
        Button {
            workspace.isFileImporterPresented = true
        } label: {
            Label("Open", systemImage: "folder")
        }
        .keyboardShortcut("o", modifiers: [.command])
        .accessibilityIdentifier("toolbarOpenButton")

        if workspace.mode == .input {
            Button {
                if let pasted = PasteboardService.read() {
                    workspace.rawText = pasted
                }
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command])
        } else {
            Menu {
                Button("Expand All", systemImage: "arrow.down.right.and.arrow.up.left") { workspace.expandAll() }
                Button("Collapse All", systemImage: "arrow.up.left.and.arrow.down.right") { workspace.collapseAll() }
                Divider()
                Button("Copy Formatted JSON", systemImage: "doc.on.doc") {
                    guard let root = workspace.document?.root else { return }
                    PasteboardService.copy(root.jsonString(pretty: true))
                    workspace.notice = "Copied formatted JSON"
                }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
        }
    }
}

private struct NoticeView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }
}

private enum PasteboardService {
    static func read() -> String? {
        #if os(iOS) || os(tvOS)
        UIPasteboard.general.string
        #else
        NSPasteboard.general.string(forType: .string)
        #endif
    }

    static func copy(_ value: String) {
        #if os(iOS) || os(tvOS)
        UIPasteboard.general.string = value
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

#if os(macOS)
struct JokosonCommands: Commands {
    let workspace: JSONWorkspace

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open JSON File…") { workspace.isFileImporterPresented = true }
                .keyboardShortcut("o", modifiers: [.command])
            Button("Paste JSON") {
                if let pasted = PasteboardService.read() {
                    workspace.rawText = pasted
                    workspace.mode = .input
                }
            }
            .keyboardShortcut("v", modifiers: [.command])
        }

        CommandMenu("JSON") {
            Button("View JSON") { workspace.parse() }
                .keyboardShortcut(.return, modifiers: [.command])
            Divider()
            Button("Expand All") { workspace.expandAll() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Collapse All") { workspace.collapseAll() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Divider()
            Button("New JSON") { workspace.reset() }
                .keyboardShortcut("n", modifiers: [.command])
        }
    }
}
#endif
