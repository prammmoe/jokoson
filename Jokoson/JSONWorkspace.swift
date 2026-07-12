//
//  JSONWorkspace.swift
//  Jokoson
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import Foundation
import Combine
import SwiftUI

enum WorkspaceMode: String, CaseIterable, Identifiable, Sendable {
    case input = "Input"
    case viewer = "Viewer"

    var id: String { rawValue }
}

private enum FileReadResult: Sendable {
    case success(String)
    case failure(String)
}

@MainActor
final class JSONWorkspace: ObservableObject {
    @Published var mode: WorkspaceMode = .input
    @Published var rawText = ""
    @Published private(set) var document: JSONDocument?
    @Published private(set) var parseError: JSONParseError?
    @Published private(set) var isParsing = false
    @Published var searchQuery = ""
    @Published var expandedPaths: Set<JSONPath> = []
    @Published var notice: String?
    @Published var isFileImporterPresented = false

    var visibleRows: [JSONTreeRow] {
        guard let document else { return [] }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = matchingPaths(in: document.root, query: query)
        let directMatches = directMatchingPaths(in: document.root, query: query)
        return flattenedRows(
            value: document.root,
            path: .root,
            key: nil,
            depth: 0,
            query: query,
            matches: matches,
            directMatches: directMatches
        )
    }

    var matchCount: Int {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document, !query.isEmpty else { return 0 }
        return directMatchingPaths(in: document.root, query: query).count
    }

    func parse() {
        let text = rawText
        isParsing = true
        parseError = nil

        let task = Task.detached(priority: .userInitiated) { () -> Result<JSONValue, JSONParseError> in
            do {
                return .success(try JSONParser().parse(text))
            } catch let error as JSONParseError {
                return .failure(error)
            } catch {
                return .failure(JSONParseError(message: error.localizedDescription, offset: 0, line: 1, column: 1))
            }
        }

        Task { [weak self] in
            let result = await task.value
            self?.apply(result, sourceText: text)
        }
    }

    @discardableResult
    func parseSynchronously() -> Result<JSONValue, JSONParseError> {
        do {
            let value = try JSONParser().parse(rawText)
            apply(.success(value), sourceText: rawText)
            return .success(value)
        } catch let error as JSONParseError {
            apply(.failure(error), sourceText: rawText)
            return .failure(error)
        } catch {
            let parseError = JSONParseError(message: error.localizedDescription, offset: 0, line: 1, column: 1)
            apply(.failure(parseError), sourceText: rawText)
            return .failure(parseError)
        }
    }

    func importFile(from url: URL) {
        isParsing = true
        parseError = nil
        let task = Task.detached(priority: .userInitiated) { () -> FileReadResult in
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            do {
                return .success(try String(contentsOf: url, encoding: .utf8))
            } catch {
                return .failure("Could not open \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        Task { [weak self] in
            guard let self else { return }
            switch await task.value {
            case .success(let text):
                rawText = text
                mode = .input
                parse()
            case .failure(let message):
                isParsing = false
                notice = message
            }
        }
    }

    func toggleExpansion(for path: JSONPath) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
    }

    func selectMode(_ requestedMode: WorkspaceMode) {
        switch requestedMode {
        case .input:
            mode = .input
        case .viewer:
            guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                mode = .input
                notice = "Enter JSON to open Viewer"
                return
            }

            guard !isParsing else { return }
            if document?.sourceText == rawText {
                mode = .viewer
            } else {
                parse()
            }
        }
    }

    func expandAll() {
        guard let root = document?.root else { return }
        var paths = Set<JSONPath>()
        collectContainerPaths(root, path: .root, into: &paths)
        expandedPaths = paths
    }

    func collapseAll() {
        expandedPaths.removeAll()
    }

    func showViewer() {
        selectMode(.viewer)
    }

    func reset() {
        mode = .input
        rawText = ""
        document = nil
        parseError = nil
        isParsing = false
        searchQuery = ""
        expandedPaths.removeAll()
        notice = nil
    }

    private func apply(_ result: Result<JSONValue, JSONParseError>, sourceText: String) {
        isParsing = false
        switch result {
        case .success(let value):
            document = JSONDocument(root: value, sourceText: sourceText)
            parseError = nil
            expandedPaths = [.root]
            mode = .viewer
        case .failure(let error):
            document = nil
            parseError = error
            mode = .input
        }
    }

    private func matchingPaths(in value: JSONValue, query: String) -> Set<JSONPath> {
        guard !query.isEmpty else { return [] }
        var result = Set<JSONPath>()

        func visit(_ value: JSONValue, path: JSONPath, key: String?) -> Bool {
            var matched = key?.localizedCaseInsensitiveContains(query) == true
            switch value {
            case .object(let members):
                for member in members {
                    matched = visit(member.value, path: path.appending(.member(ordinal: member.ordinal, key: member.key)), key: member.key) || matched
                }
            case .array(let values):
                for (index, child) in values.enumerated() {
                    matched = visit(child, path: path.appending(.index(index)), key: nil) || matched
                }
            case .string(let string): matched = string.localizedCaseInsensitiveContains(query) || matched
            case .number(let number): matched = number.localizedCaseInsensitiveContains(query) || matched
            case .bool(let bool): matched = (bool ? "true" : "false").localizedCaseInsensitiveContains(query) || matched
            case .null: matched = "null".localizedCaseInsensitiveContains(query) || matched
            }

            if matched { result.insert(path) }
            return matched
        }

        _ = visit(value, path: .root, key: nil)
        return result
    }

    private func flattenedRows(
        value: JSONValue,
        path: JSONPath,
        key: String?,
        depth: Int,
        query: String,
        matches: Set<JSONPath>,
        directMatches: Set<JSONPath>
    ) -> [JSONTreeRow] {
        guard query.isEmpty || matches.contains(path) else { return [] }
        let isExpanded = expandedPaths.contains(path) || !query.isEmpty
        var rows = [JSONTreeRow(path: path, depth: depth, key: key, value: value, isExpanded: isExpanded, isMatch: directMatches.contains(path), isClosing: false)]

        guard value.isContainer, isExpanded else { return rows }
        switch value {
        case .object(let members):
            for member in members {
                rows += flattenedRows(
                    value: member.value,
                    path: path.appending(.member(ordinal: member.ordinal, key: member.key)),
                    key: member.key,
                    depth: depth + 1,
                    query: query,
                    matches: matches,
                    directMatches: directMatches
                )
            }
        case .array(let values):
            for (index, child) in values.enumerated() {
                rows += flattenedRows(
                    value: child,
                    path: path.appending(.index(index)),
                    key: nil,
                    depth: depth + 1,
                    query: query,
                    matches: matches,
                    directMatches: directMatches
                )
            }
        default: break
        }

        if value.childCount != 0 {
            rows.append(JSONTreeRow(path: path, depth: depth, key: nil, value: value, isExpanded: false, isMatch: false, isClosing: true))
        }
        return rows
    }

    private func directMatchingPaths(in value: JSONValue, query: String) -> Set<JSONPath> {
        guard !query.isEmpty else { return [] }
        var result = Set<JSONPath>()

        func visit(_ value: JSONValue, path: JSONPath, key: String?) {
            let isMatch: Bool = {
                if key?.localizedCaseInsensitiveContains(query) == true { return true }
                switch value {
                case .object, .array: return false
                case .string(let string): return string.localizedCaseInsensitiveContains(query)
                case .number(let number): return number.localizedCaseInsensitiveContains(query)
                case .bool(let bool): return (bool ? "true" : "false").localizedCaseInsensitiveContains(query)
                case .null: return "null".localizedCaseInsensitiveContains(query)
                }
            }()
            if isMatch { result.insert(path) }

            switch value {
            case .object(let members):
                for member in members {
                    visit(member.value, path: path.appending(.member(ordinal: member.ordinal, key: member.key)), key: member.key)
                }
            case .array(let values):
                for (index, child) in values.enumerated() {
                    visit(child, path: path.appending(.index(index)), key: nil)
                }
            default: break
            }
        }

        visit(value, path: .root, key: nil)
        return result
    }

    private func collectContainerPaths(_ value: JSONValue, path: JSONPath, into paths: inout Set<JSONPath>) {
        guard value.isContainer else { return }
        paths.insert(path)
        switch value {
        case .object(let members):
            for member in members {
                collectContainerPaths(member.value, path: path.appending(.member(ordinal: member.ordinal, key: member.key)), into: &paths)
            }
        case .array(let values):
            for (index, child) in values.enumerated() {
                collectContainerPaths(child, path: path.appending(.index(index)), into: &paths)
            }
        default: break
        }
    }
}
