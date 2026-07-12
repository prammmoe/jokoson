//
//  JSONParser.swift
//  Jokoson
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import Foundation

struct JSONParseError: Error, Equatable, LocalizedError, Sendable {
    let message: String
    let offset: Int
    let line: Int
    let column: Int

    var errorDescription: String? {
        "\(message) at line \(line), column \(column)."
    }
}

struct JSONParser: Sendable {
    func parse(_ text: String) throws -> JSONValue {
        var parser = Parser(text: text)
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.isAtEnd else {
            throw parser.error("Unexpected content after the JSON value")
        }
        return value
    }

    private struct Parser {
        let text: String
        let bytes: [UInt8]
        var index = 0

        init(text: String) {
            self.text = text
            self.bytes = Array(text.utf8)
        }

        var isAtEnd: Bool { index >= bytes.count }

        mutating func parseValue() throws -> JSONValue {
            skipWhitespace()
            guard let byte = current else {
                throw error("Expected a JSON value")
            }

            switch byte {
            case 0x7B: return try parseObject()
            case 0x5B: return try parseArray()
            case 0x22: return .string(try parseString())
            case 0x2D, 0x30...0x39: return .number(try parseNumber())
            case 0x74:
                try consumeLiteral("true")
                return .bool(true)
            case 0x66:
                try consumeLiteral("false")
                return .bool(false)
            case 0x6E:
                try consumeLiteral("null")
                return .null
            default:
                throw error("Unexpected character '\(String(decoding: [byte], as: UTF8.self))'")
            }
        }

        mutating func parseObject() throws -> JSONValue {
            try consume(0x7B, expected: "'{'")
            skipWhitespace()
            if consumeIfPresent(0x7D) {
                return .object([])
            }

            var members: [JSONMember] = []
            while true {
                skipWhitespace()
                guard current == 0x22 else {
                    throw error("Expected a quoted object key")
                }
                let key = try parseString()
                skipWhitespace()
                try consume(0x3A, expected: "':' after object key")
                let value = try parseValue()
                members.append(JSONMember(ordinal: members.count, key: key, value: value))
                skipWhitespace()

                if consumeIfPresent(0x7D) {
                    return .object(members)
                }
                try consume(0x2C, expected: "',' or '}' after object value")
                skipWhitespace()
                if current == 0x7D {
                    throw error("Trailing commas are not valid in JSON")
                }
            }
        }

        mutating func parseArray() throws -> JSONValue {
            try consume(0x5B, expected: "'['")
            skipWhitespace()
            if consumeIfPresent(0x5D) {
                return .array([])
            }

            var values: [JSONValue] = []
            while true {
                values.append(try parseValue())
                skipWhitespace()

                if consumeIfPresent(0x5D) {
                    return .array(values)
                }
                try consume(0x2C, expected: "',' or ']' after array value")
                skipWhitespace()
                if current == 0x5D {
                    throw error("Trailing commas are not valid in JSON")
                }
            }
        }

        mutating func parseString() throws -> String {
            try consume(0x22, expected: "'\"'")
            var output: [UInt8] = []

            while let byte = current {
                index += 1
                switch byte {
                case 0x22:
                    guard let string = String(bytes: output, encoding: .utf8) else {
                        throw error("Invalid UTF-8 in string")
                    }
                    return string
                case 0x5C:
                    guard let escape = current else {
                        throw error("Unterminated escape sequence")
                    }
                    index += 1
                    switch escape {
                    case 0x22, 0x5C, 0x2F: output.append(escape)
                    case 0x62: output.append(0x08)
                    case 0x66: output.append(0x0C)
                    case 0x6E: output.append(0x0A)
                    case 0x72: output.append(0x0D)
                    case 0x74: output.append(0x09)
                    case 0x75:
                        let scalar = try parseUnicodeEscape()
                        output.append(contentsOf: String(scalar).utf8)
                    default:
                        throw error("Invalid escape sequence")
                    }
                case 0..<0x20:
                    throw error("Control characters must be escaped in strings")
                default:
                    output.append(byte)
                }
            }

            throw error("Unterminated string")
        }

        mutating func parseUnicodeEscape() throws -> UnicodeScalar {
            let first = try parseHexQuad()
            if (0xD800...0xDBFF).contains(first) {
                guard current == 0x5C, peek(1) == 0x75 else {
                    throw error("High surrogate must be followed by a low surrogate")
                }
                index += 2
                let second = try parseHexQuad()
                guard (0xDC00...0xDFFF).contains(second) else {
                    throw error("Invalid low surrogate")
                }
                let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                guard let scalar = UnicodeScalar(combined) else {
                    throw error("Invalid Unicode scalar")
                }
                return scalar
            }
            guard let scalar = UnicodeScalar(first), !(0xDC00...0xDFFF).contains(first) else {
                throw error("Invalid Unicode escape")
            }
            return scalar
        }

        mutating func parseHexQuad() throws -> UInt32 {
            guard index + 4 <= bytes.count else {
                throw error("Incomplete Unicode escape")
            }
            var value: UInt32 = 0
            for _ in 0..<4 {
                guard let digit = hexValue(bytes[index]) else {
                    throw error("Invalid Unicode escape")
                }
                value = value * 16 + digit
                index += 1
            }
            return value
        }

        mutating func parseNumber() throws -> String {
            let start = index
            _ = consumeIfPresent(0x2D)

            if consumeIfPresent(0x30) {
                if let byte = current, (0x30...0x39).contains(byte) {
                    throw error("Numbers cannot contain leading zeroes")
                }
            } else {
                guard consumeDigits(minimum: 1) else {
                    throw error("Expected digits in number")
                }
            }

            if consumeIfPresent(0x2E) {
                guard consumeDigits(minimum: 1) else {
                    throw error("Expected digits after decimal point")
                }
            }

            if current == 0x65 || current == 0x45 {
                index += 1
                _ = consumeIfPresent(0x2B)
                _ = consumeIfPresent(0x2D)
                guard consumeDigits(minimum: 1) else {
                    throw error("Expected digits in exponent")
                }
            }

            return String(decoding: bytes[start..<index], as: UTF8.self)
        }

        mutating func consumeLiteral(_ literal: String) throws {
            let literalBytes = Array(literal.utf8)
            guard index + literalBytes.count <= bytes.count,
                  Array(bytes[index..<(index + literalBytes.count)]) == literalBytes else {
                throw error("Expected '\(literal)'")
            }
            index += literalBytes.count
        }

        mutating func consume(_ byte: UInt8, expected: String) throws {
            guard consumeIfPresent(byte) else {
                throw error("Expected \(expected)")
            }
        }

        mutating func consumeIfPresent(_ byte: UInt8) -> Bool {
            guard current == byte else { return false }
            index += 1
            return true
        }

        mutating func consumeDigits(minimum: Int) -> Bool {
            let start = index
            while let byte = current, (0x30...0x39).contains(byte) {
                index += 1
            }
            return index - start >= minimum
        }

        mutating func skipWhitespace() {
            while let byte = current, byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                index += 1
            }
        }

        var current: UInt8? { index < bytes.count ? bytes[index] : nil }

        func peek(_ distance: Int) -> UInt8? {
            let position = index + distance
            return position < bytes.count ? bytes[position] : nil
        }

        func error(_ message: String) -> JSONParseError {
            let prefix = String(decoding: bytes.prefix(index), as: UTF8.self)
            let line = prefix.reduce(into: 1) { result, character in
                if character == "\n" { result += 1 }
            }
            let column = prefix.split(separator: "\n", omittingEmptySubsequences: false).last?.count ?? 0
            return JSONParseError(message: message, offset: index, line: line, column: column + 1)
        }

        func hexValue(_ byte: UInt8) -> UInt32? {
            switch byte {
            case 0x30...0x39: return UInt32(byte - 0x30)
            case 0x41...0x46: return UInt32(byte - 0x41 + 10)
            case 0x61...0x66: return UInt32(byte - 0x61 + 10)
            default: return nil
            }
        }
    }
}
