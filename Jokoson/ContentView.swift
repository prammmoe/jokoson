//
//  ContentView.swift
//  Jokoson
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

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
        .alert("No JSON Entered", isPresented: $workspace.isEmptyJSONAlertPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Paste or enter JSON before opening Viewer.")
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
                .navigationTitle("Jokoson")
                .toolbar { WorkspaceToolbar(workspace: workspace) }
        }
    }
}

private struct RegularWorkspaceView: View {
    @ObservedObject var workspace: JSONWorkspace
    @State private var isMacSplitViewPresented = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jokoson")
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
            }
            .padding(22)
            #if os(macOS)
            .padding(.top, 38)
            #endif
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            #if os(macOS)
            Group {
                if isMacSplitViewPresented {
                    MacSplitWorkspaceView(workspace: workspace)
                        .navigationTitle("Jokoson")
                } else {
                    WorkspaceSurface(workspace: workspace)
                        .navigationTitle(workspace.mode == .input ? "Input" : "Viewer")
                }
            }
            .padding(.top, 38)
            .toolbar {
                WorkspaceToolbar(workspace: workspace, isSplitViewPresented: $isMacSplitViewPresented)
            }
            #else
            WorkspaceSurface(workspace: workspace)
                .navigationTitle(workspace.mode == .input ? "Input" : "Viewer")
                .toolbar {
                    WorkspaceToolbar(workspace: workspace)
                }
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 600)
    }
}

#if os(macOS)
private struct MacSplitWorkspaceView: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        HSplitView {
            MacSplitPane(title: "Input", systemImage: "square.and.pencil") {
                InputSurface(workspace: workspace)
            }
            .frame(minWidth: 360, idealWidth: 520)

            MacSplitPane(title: "Viewer", systemImage: "list.bullet.rectangle") {
                ViewerSurface(workspace: workspace)
            }
            .frame(minWidth: 360, idealWidth: 520)
        }
        .background(Color.primary.opacity(0.012))
        .accessibilityIdentifier("macSplitWorkspace")
    }
}

private struct MacSplitPane<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.bar)

            Divider()

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif

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
    @State private var isSearchPresented = false

    var body: some View {
        Group {
            if workspace.document != nil {
                #if os(macOS)
                HSplitView {
                    ViewerTreePane(workspace: workspace)
                        .frame(minWidth: 420, idealWidth: 620, maxWidth: 900, maxHeight: .infinity)

                    JSONTableViewerPane(workspace: workspace)
                        .frame(minWidth: 0, idealWidth: 360, maxHeight: .infinity)
                }
                #else
                ViewerTreePane(workspace: workspace)
                #endif
            } else {
                ContentUnavailableView("No JSON Loaded", systemImage: "curlybraces", description: Text("Paste JSON or open a local .json file to begin."))
            }
        }
        #if !os(macOS)
        .frame(maxWidth: 980, maxHeight: .infinity)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $workspace.searchQuery, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Search keys and values")
        .onChange(of: workspace.viewerSearchFocusRequest) { _, _ in
            isSearchPresented = true
        }
        #if os(macOS)
        .background {
            ZStack {
                ViewerSearchFocusBridge(request: workspace.viewerSearchFocusRequest)
                ViewerFindShortcutMonitor()
            }
        }
        #endif
        .accessibilityIdentifier("jsonViewer")
    }
}

private struct ViewerTreePane: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
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
    }
}

#if os(macOS)
private struct JSONTableViewerPane: View {
    @ObservedObject var workspace: JSONWorkspace

    var body: some View {
        Table(workspace.tableRows) {
            TableColumn("Name") { row in
                Text(row.name)
                    .lineLimit(1)
            }
            .width(min: 24, ideal: 160)

            TableColumn("Value") { row in
                Text(row.displayValue)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .width(min: 40, ideal: 220)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(-1)
        .font(.system(size: 12, design: .monospaced))
        .accessibilityIdentifier("jsonTableViewer")
    }
}
#endif

#if os(macOS)
private struct ViewerSearchFocusBridge: NSViewRepresentable {
    let request: Int

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard request > 0 else { return }
        DispatchQueue.main.async {
            focusViewerSearch(in: view.window)
        }
    }
}

private struct ViewerFindShortcutMonitor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { }

    final class Coordinator {
        private var monitor: Any?
        private weak var view: NSView?

        func install(on view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.modifierFlags.contains(.command),
                      event.charactersIgnoringModifiers?.lowercased() == "f" else {
                    return event
                }

                DispatchQueue.main.async {
                    focusViewerSearch(in: self?.view?.window)
                }
                return nil
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

private func focusViewerSearch(in window: NSWindow?) {
    window?.toolbar?.items
        .compactMap { $0 as? NSSearchToolbarItem }
        .first?
        .beginSearchInteraction()
}
#endif

private struct JSONTreeRowView: View {
    let row: JSONTreeRow
    @ObservedObject var workspace: JSONWorkspace
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let jsonFontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 7) {
            Color.clear
                .frame(width: CGFloat(row.depth) * 20)

            if row.isClosing {
                Color.clear.frame(width: 22)

                Text(row.value.closingDelimiter)
                    .font(.system(size: jsonFontSize, design: .monospaced))
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
                        .font(.system(size: jsonFontSize, design: .monospaced).weight(.medium))
                        .foregroundStyle(JSONSyntaxTheme.key)
                    Text(":")
                        .foregroundStyle(JSONSyntaxTheme.punctuation)
                }

                Text(valueText)
                    .font(.system(size: jsonFontSize, design: .monospaced))
                    .foregroundStyle(JSONSyntaxTheme.valueColor(for: row.value))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 24)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            workspace.selectTreeRow(row)
        }
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

    private var rowBackground: Color {
        if !row.isClosing && row.path == workspace.selectedPath {
            return Color.accentColor.opacity(0.18)
        }
        if row.isMatch {
            return Color.primary.opacity(0.09)
        }
        return isHovered ? Color.primary.opacity(0.035) : .clear
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
private func WorkspaceToolbar(
    workspace: JSONWorkspace,
    isSplitViewPresented: Binding<Bool>? = nil
) -> some ToolbarContent {
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
        #if os(macOS)
        if let isSplitViewPresented {
            Toggle(isOn: isSplitViewPresented) {
                Label(
                    isSplitViewPresented.wrappedValue ? "Hide Split View" : "Show Split View",
                    systemImage: "rectangle.split.2x1"
                )
            }
            .toggleStyle(.button)
            .help(isSplitViewPresented.wrappedValue ? "Hide Input and Viewer split view" : "Show Input and Viewer split view")
            .accessibilityIdentifier("splitViewButton")
        }
        #endif

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
        CommandGroup(after: .textEditing) {
            Button("Find in Viewer") { workspace.requestViewerSearchFocus() }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(workspace.mode != .viewer)
        }

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
