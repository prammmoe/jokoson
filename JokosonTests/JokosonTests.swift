//
//  JokosonTests.swift
//  JokosonTests
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import Testing
@testable import Jokoson

#if os(macOS)
import AppKit
#endif

struct JokosonTests {
    @Test func parsesOrderedNestedJSON() throws {
        let value = try JSONParser().parse("{\"first\":1,\"second\":[true,null,{\"name\":\"Ada\"}]}")

        guard case .object(let members) = value else {
            Issue.record("Expected an object")
            return
        }
        #expect(members.map(\.key) == ["first", "second"])
        #expect(members[0].ordinal == 0)
        #expect(members[1].ordinal == 1)
    }

    @Test func parsesEscapesUnicodeAndNumbers() throws {
        let value = try JSONParser().parse("[\"line\\n\\u0041\",-12.50e+2]")

        guard case .array(let values) = value else {
            Issue.record("Expected an array")
            return
        }
        #expect(values[0] == .string("line\nA"))
        #expect(values[1] == .number("-12.50e+2"))
    }

    @Test func rejectsMalformedJSONWithLocation() {
        do {
            _ = try JSONParser().parse("{\n  \"name\": \"Ada\",\n}")
            Issue.record("Expected malformed JSON to fail")
        } catch let error as JSONParseError {
            #expect(error.line == 3)
            #expect(error.column == 1)
            #expect(error.message.contains("Trailing"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func preservesDuplicateKeysAndFormats() throws {
        let value = try JSONParser().parse("{\"key\":1,\"key\":2}")
        #expect(value.jsonString(pretty: false) == "{\"key\":1,\"key\":2}")

        guard case .object(let members) = value else {
            Issue.record("Expected an object")
            return
        }
        #expect(members.count == 2)
        #expect(members[0].key == members[1].key)
    }

    @Test @MainActor func workspaceParsesAndSearches() {
        let workspace = JSONWorkspace()
        workspace.rawText = "{\"user\":{\"name\":\"Ada\",\"active\":true}}"
        let result = workspace.parseSynchronously()

        guard case .success = result else {
            Issue.record("Expected workspace parsing to succeed")
            return
        }
        #expect(workspace.mode == .viewer)
        #expect(workspace.expandedPaths.contains(.root))

        workspace.searchQuery = "Ada"
        #expect(workspace.visibleRows.contains { $0.key == "name" && $0.isMatch })
    }

    @Test @MainActor func workspaceCanExpandAndCollapseAll() {
        let workspace = JSONWorkspace()
        workspace.rawText = "{\"outer\":{\"inner\":[]}}"
        _ = workspace.parseSynchronously()

        workspace.expandAll()
        #expect(workspace.expandedPaths.count == 3)
        workspace.collapseAll()
        #expect(workspace.expandedPaths.isEmpty)
    }

    @Test @MainActor func workspaceShowsAlertWhenViewerIsRequestedWithoutJSON() {
        let workspace = JSONWorkspace()

        workspace.selectMode(.viewer)

        #expect(workspace.mode == .input)
        #expect(workspace.isEmptyJSONAlertPresented)
    }

    @Test @MainActor func workspaceOnlyProvidesValidJSONForSaving() {
        let workspace = JSONWorkspace(historyStore: JSONHistoryStore(inMemory: true))

        workspace.rawText = "{\"name\":\"Ada\"}"
        #expect(workspace.validatedJSONText() == "{\"name\":\"Ada\"}")
        workspace.saveToHistory()
        #expect(workspace.history.first?.source == .manual)

        workspace.rawText = "{"
        #expect(workspace.validatedJSONText() == nil)
        #expect(workspace.parseError != nil)
    }

    @Test @MainActor func workspaceRequestsViewerSearchFocusOnlyInViewerMode() {
        let workspace = JSONWorkspace()

        workspace.requestViewerSearchFocus()
        #expect(workspace.viewerSearchFocusRequest == 0)

        workspace.rawText = "{\"name\":\"Ada\"}"
        _ = workspace.parseSynchronously()
        workspace.requestViewerSearchFocus()

        #expect(workspace.mode == .viewer)
        #expect(workspace.viewerSearchFocusRequest == 1)
    }

    @Test @MainActor func historyPersistsParsedPastesAndFiles() {
        let workspace = JSONWorkspace(historyStore: JSONHistoryStore(inMemory: true))

        workspace.rawText = "{\"paste\":true}"
        _ = workspace.parseSynchronously(historySource: .paste)
        workspace.rawText = "{\"paste\":true}"
        _ = workspace.parseSynchronously(historySource: .file)
        workspace.rawText = "{\"file\":true}"
        _ = workspace.parseSynchronously(historySource: .file)

        #expect(workspace.history.count == 2)
        #expect(workspace.history.map(\.sourceText) == ["{\"file\":true}", "{\"paste\":true}"])
        #expect(workspace.history.map(\.source) == [.file, .file])
    }

    @Test @MainActor func invalidJSONDoesNotEnterHistoryAndEntriesCanBeManaged() {
        let workspace = JSONWorkspace(historyStore: JSONHistoryStore(inMemory: true))

        workspace.rawText = "{"
        _ = workspace.parseSynchronously(historySource: .paste)
        #expect(workspace.history.isEmpty)

        workspace.rawText = "{\"name\":\"Ada\"}"
        _ = workspace.parseSynchronously(historySource: .paste)
        guard let item = workspace.history.first else {
            Issue.record("Expected saved history")
            return
        }
        workspace.renameHistory(item.id, to: "Ada")
        workspace.setHistoryColor(.blue, for: item.id)
        #expect(workspace.history.first?.title == "Ada")
        #expect(workspace.history.first?.color == .blue)

        workspace.deleteHistory(item.id)
        #expect(workspace.history.isEmpty)

        workspace.rawText = "{\"one\":1}"
        _ = workspace.parseSynchronously(historySource: .paste)
        workspace.rawText = "{\"two\":2}"
        _ = workspace.parseSynchronously(historySource: .paste)
        workspace.clearHistory()
        #expect(workspace.history.isEmpty)
    }

    @Test @MainActor func tableRowsFollowSelectedContainerOrScalarParent() {
        let workspace = JSONWorkspace()
        workspace.rawText = "{\"data\":{\"type\":\"checkout\",\"products\":[{\"id\":1,\"active\":true}]}}"
        _ = workspace.parseSynchronously()
        workspace.expandAll()

        #expect(workspace.tableRows.map(\.name) == ["data"])

        guard let dataRow = workspace.visibleRows.first(where: { $0.key == "data" }),
              let typeRow = workspace.visibleRows.first(where: { $0.key == "type" }),
              let productsRow = workspace.visibleRows.first(where: { $0.key == "products" }) else {
            Issue.record("Expected rows for data, type, and products")
            return
        }

        workspace.selectTreeRow(dataRow)
        #expect(workspace.tableRows.map(\.name) == ["type", "products"])

        workspace.selectTreeRow(typeRow)
        #expect(workspace.tableRows.map(\.name) == ["type", "products"])

        workspace.selectTreeRow(productsRow)
        #expect(workspace.tableRows.map(\.name) == ["0"])
        #expect(workspace.tableRows.first?.displayValue == "{ … }")
    }

    @Test func jsonPathsAreReadable() {
        let path = JSONPath.root
            .appending(.member(ordinal: 0, key: "users"))
            .appending(.index(0))
            .appending(.member(ordinal: 0, key: "display name"))
        #expect(path.description == "$.users[0][\"display name\"]")
    }

    #if os(macOS)
    @Test func syntaxHighlighterAssignsMutedTokenColors() {
        let source = "{\"key\":\"value\",\"number\":12,\"boolean\":true,\"empty\":null}"
        let highlighted = JSONSyntaxHighlighter.attributedString(for: source)

        func color(at token: String) -> NSColor? {
            let range = (source as NSString).range(of: token)
            return highlighted.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
        }

        let key = color(at: "\"key\"")
        let string = color(at: "\"value\"")
        let number = color(at: "12")
        let boolean = color(at: "true")
        let null = color(at: "null")
        let punctuation = color(at: ":")

        #expect(key != nil)
        #expect(string != nil)
        #expect(number != nil)
        #expect(boolean != nil)
        #expect(null != nil)
        #expect(punctuation != nil)
        func rgb(_ color: NSColor) -> [CGFloat] {
            let resolved = color.usingColorSpace(.deviceRGB)!
            return [resolved.redComponent, resolved.greenComponent, resolved.blueComponent]
        }

        #expect(rgb(key!) != rgb(string!))
        #expect(rgb(string!) != rgb(number!))
        #expect(rgb(number!) != rgb(boolean!))
        #expect(rgb(null!) == rgb(punctuation!))
    }
    #endif
}
