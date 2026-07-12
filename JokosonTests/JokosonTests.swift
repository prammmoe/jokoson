//
//  JokosonTests.swift
//  JokosonTests
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import Testing
@testable import Jokoson

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

    @Test func jsonPathsAreReadable() {
        let path = JSONPath.root
            .appending(.member(ordinal: 0, key: "users"))
            .appending(.index(0))
            .appending(.member(ordinal: 0, key: "display name"))
        #expect(path.description == "$.users[0][\"display name\"]")
    }
}
