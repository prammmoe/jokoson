//
//  JSONValue.swift
//  Jokoson
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import Foundation

struct JSONMember: Equatable, Sendable, Identifiable {
    let ordinal: Int
    let key: String
    let value: JSONValue

    var id: Int { ordinal }
}

indirect enum JSONValue: Equatable, Sendable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    var isContainer: Bool {
        switch self {
        case .object, .array:
            true
        default:
            false
        }
    }

    var childCount: Int? {
        switch self {
        case .object(let members): members.count
        case .array(let values): values.count
        default: nil
        }
    }

    var summary: String {
        switch self {
        case .object(let members):
            return members.isEmpty ? "{}" : "{ … }"
        case .array(let values):
            return values.isEmpty ? "[]" : "[ … ]"
        case .string(let value): return "\"\(value)\""
        case .number(let value): return value
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        }
    }

    var openingDelimiter: String {
        switch self {
        case .object: return "{"
        case .array: return "["
        default: return ""
        }
    }

    var closingDelimiter: String {
        switch self {
        case .object: return "}"
        case .array: return "]"
        default: return ""
        }
    }

    func jsonString(pretty: Bool = true, indent: String = "  ") -> String {
        render(level: 0, pretty: pretty, indent: indent)
    }

    private func render(level: Int, pretty: Bool, indent: String) -> String {
        switch self {
        case .object(let members):
            guard !members.isEmpty else { return "{}" }
            let rendered = members.map { member in
                let key = "\"\(Self.escape(member.key))\""
                let value = member.value.render(level: level + 1, pretty: pretty, indent: indent)
                let prefix = pretty ? String(repeating: indent, count: level + 1) : ""
                return "\(prefix)\(key)\(pretty ? ": " : ":")\(value)"
            }
            let separator = pretty ? ",\n" : ","
            let closingPrefix = pretty ? "\n\(String(repeating: indent, count: level))" : ""
            return "{\(pretty ? "\n" : "")\(rendered.joined(separator: separator))\(closingPrefix)}"

        case .array(let values):
            guard !values.isEmpty else { return "[]" }
            let rendered = values.map { value in
                let prefix = pretty ? String(repeating: indent, count: level + 1) : ""
                return "\(prefix)\(value.render(level: level + 1, pretty: pretty, indent: indent))"
            }
            let separator = pretty ? ",\n" : ","
            let closingPrefix = pretty ? "\n\(String(repeating: indent, count: level))" : ""
            return "[\(pretty ? "\n" : "")\(rendered.joined(separator: separator))\(closingPrefix)]"

        case .string(let value): return "\"\(Self.escape(value))\""
        case .number(let value): return value
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        }
    }

    static func escape(_ value: String) -> String {
        value.unicodeScalars.reduce(into: "") { result, scalar in
            switch scalar.value {
            case 0x22: result += "\\\""
            case 0x5C: result += "\\\\"
            case 0x08: result += "\\b"
            case 0x0C: result += "\\f"
            case 0x0A: result += "\\n"
            case 0x0D: result += "\\r"
            case 0x09: result += "\\t"
            case 0..<0x20:
                result += String(format: "\\u%04X", scalar.value)
            default:
                result.append(String(scalar))
            }
        }
    }
}

enum JSONPathComponent: Hashable, Sendable {
    case member(ordinal: Int, key: String)
    case index(Int)
}

struct JSONPath: Hashable, Sendable, CustomStringConvertible {
    let components: [JSONPathComponent]

    static let root = JSONPath(components: [])

    func appending(_ component: JSONPathComponent) -> JSONPath {
        JSONPath(components: components + [component])
    }

    var description: String {
        components.reduce("$") { result, component in
            switch component {
            case .index(let index): return "\(result)[\(index)]"
            case .member(_, let key):
                let safe = key.first.map { $0.isLetter || $0 == "_" } == true && key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
                return safe ? "\(result).\(key)" : "\(result)[\"\(JSONValue.escape(key))\"]"
            }
        }
    }
}

struct JSONDocument: Equatable, Sendable {
    let root: JSONValue
    let sourceText: String
}

struct JSONTreeRow: Identifiable, Equatable, Sendable {
    let path: JSONPath
    let depth: Int
    let key: String?
    let value: JSONValue
    let isExpanded: Bool
    let isMatch: Bool
    let isClosing: Bool

    var id: String { path.description + (isClosing ? ":closing" : "") }
}
