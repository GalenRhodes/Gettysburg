/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/1/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//******************************************************************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

open class SAXParser {

    public internal(set) var xmlVersion:      String = "1.0"
    public internal(set) var xmlEncoding:     String = "UTF-8"
    public internal(set) var xmlIsStandalone: Bool   = true
    public internal(set) var handler:         SAXHandler

    open var url:      URL { inputStream.url }
    open var baseURL:  URL { inputStream.baseURL }
    open var filename: String { inputStream.filename }

    @usableFromInline let inputStream: SAXCharInputStreamStack

    public init(inputStream: InputStream, url: URL, handler: SAXHandler) throws {
        self.inputStream = try SAXCharInputStreamStack(initialInputStream: inputStream, url: url)
        self.xmlEncoding = self.inputStream.encodingName
        self.handler = handler
    }

    public convenience init(url: URL, handler: SAXHandler) throws {
        guard let _is = InputStream(url: url) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        try self.init(inputStream: _is, url: url.absoluteURL, handler: handler)
    }

    public convenience init(fileAtPath: String, handler: SAXHandler) throws {
        guard let _is = InputStream(fileAtPath: fileAtPath) else { throw StreamError.FileNotFound(description: fileAtPath) }
        try self.init(inputStream: _is, url: GetFileURL(filename: fileAtPath), handler: handler)
    }

    public convenience init(data: Data, url: URL? = nil, handler: SAXHandler) throws {
        let _url = (url ?? URL(fileURLWithPath: "temp_\(UUID().uuidString).xml", isDirectory: false, relativeTo: GetCurrDirURL()))
        try self.init(inputStream: InputStream(data: data), url: _url, handler: handler)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML document from the given input stream.
    ///
    /// - Throws: If an error occured.
    ///
    open func parse() throws {
        do {
            inputStream.open()
            defer { inputStream.close() }

            try getXmlDeclaration()
            markSet()
            defer { markDelete() }

            var hasDocType:  Bool = false
            var hasRootElem: Bool = false

            while let ch = try read() {
                switch ch {
                    case "<": try handleRootNodeItem(&hasDocType, &hasRootElem)
                    default:  guard ch.isXmlWhitespace else { throw SAXError.MalformedDocument(markBackup(), description: "Unexpected character: \"\(ch)\"") }
                }
                markUpdate()
            }
        }
        catch let e {
            guard handler.handleError(self, error: e) else { throw e }
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a root node item.
    ///
    /// - Parameters:
    ///   - hasDocType: A flag that indicates the DOCTYPE node has already been found.
    ///   - hasRootElem: A flag that indicates the root element node has already been found.
    /// - Throws: If an I/O error occurs or the root node item is malformed.
    ///
    func handleRootNodeItem(_ hasDocType: inout Bool, _ hasRootElem: inout Bool) throws {
        guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput() }
        switch ch {
            case "!":
                guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput() }
                switch ch {
                    case "-":
                        markBackup(count: 3)
                        try handleComment()
                    case "D":
                        markBackup(count: 3)
                        // TODO: Possible DOCTYPE
                        break
                    default:
                        throw SAXError.MalformedDocument(markBackup(), description: "Unexpected character: \"\(ch)\"")
                }
                break
            case "?":
                markBackup(count: 2)
                try handleProcessingInstruction()
            default:
                guard ch.isXmlNameStartChar else { throw SAXError.MalformedDocument(markBackup(), description: "Unexpected character: \"\(ch)\"") }
                markBackup(count: 2)
                // TODO: Handle Document Element.
                break
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a processing instruction.
    ///
    /// - Throws: If there is an I/O error or the comment is malformed.
    ///
    func handleProcessingInstruction() throws {
        var buffer: [Character] = []
        guard try read(chars: &buffer, count: 2) == 2 else { throw SAXError.UnexpectedEndOfInput() }
        guard String(buffer) == "<?" else { throw SAXError.MalformedProcessingInstruction(markBackup(count: 2), description: "Bad processing instruction opening: \"\(String(buffer))\"") }
        markUpdate()
        guard let target: String = try nextIdentifier() else { throw SAXError.MalformedProcessingInstruction(markReset(), description: "Missing target.") }
        markUpdate()
        guard try read(chars: &buffer, count: 2) == 2 else { throw SAXError.UnexpectedEndOfInput() }
        guard String(buffer) != "?>" else {
            handler.processingInstruction(self, target: target, data: "")
            return
        }

        while let ch = try read() {
            if ch == ">" && buffer[buffer.endIndex - 1] == "?" {
                handler.processingInstruction(self, target: target, data: String(buffer[buffer.startIndex ..< buffer.endIndex - 1]).trimmed)
                return
            }
            buffer <+ ch
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a comment.
    ///
    /// - Throws: If there is an I/O error or the comment is malformed.
    ///
    func handleComment() throws {
        var buffer: [Character] = []
        guard try read(chars: &buffer, count: 4) == 4 else { throw SAXError.UnexpectedEndOfInput() }
        guard String(buffer) == "<!--" else { throw SAXError.MalformedComment(markBackup(count: 4), description: "Bad comment opening: \"\(String(buffer))\"") }
        guard try read(chars: &buffer, count: 3) == 3 else { throw SAXError.UnexpectedEndOfInput() }

        if String(buffer) == "-->" {
            handler.comment(self, content: "")
            return
        }

        if buffer[0] == "-" && buffer[1] == "-" { throw SAXError.MalformedComment(markBackup(count: 2), description: "Illegal character: \"-\"") }

        while let ch = try read() {
            if buffer[buffer.endIndex - 1] == "-" && buffer[buffer.endIndex - 2] == "-" {
                if ch == ">" {
                    handler.comment(self, content: String(buffer[buffer.startIndex ..< (buffer.endIndex - 2)]))
                    return
                }
                else {
                    throw SAXError.MalformedComment(markBackup(count: 2), description: "Illegal character: \"-\"")
                }
            }
            buffer <+ ch
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the document's XML Declaration.
    ///
    /// - Throws: If an I/O error occured or the XML Declaration was malformed.
    ///
    func getXmlDeclaration() throws {
        markSet()
        defer { markDelete() }
        var buffer: [Character] = []

        guard try read(chars: &buffer, count: 6) == 6 else { markReset(); return }
        guard buffer.matches(pattern: "(?i)<\\?xml\\s") else { markReset(); return }

        markUpdate()
        while let kv = try nextParameter() {
            switch kv.key {
                case "version":
                    guard value(kv.value, isOneOf: "1.0", "1.1") else { throw SAXError.MalformedXmlDecl(markReset(), description: "Unsupported XML Version: \"\(kv.value)\"") }
                    xmlVersion = kv.value
                case "encoding":
                    // This is just for show. The encoding has already been determined.
                    xmlEncoding = kv.value
                case "standalone":
                    let val = kv.value.lowercased()
                    guard value(val, isOneOf: "yes", "no") else { throw SAXError.MalformedXmlDecl(markReset(), description: "Invalid value of standalone: \"\(kv.value)\"") }
                    xmlIsStandalone = (val == "yes")
                default: throw SAXError.MalformedXmlDecl(markReset(), description: "Unexpected parameter: \(kv.key)")
            }
            markUpdate()
        }

        try readWhitespace()
        guard try getChar(errorOnEOF: true, allowed: "?") != nil else { throw SAXError.MalformedXmlDecl(markBackup(), description: "Unexpected Character.") }
        guard try getChar(errorOnEOF: true, allowed: ">") != nil else { throw SAXError.MalformedXmlDecl(markBackup(), description: "Unexpected Character.") }
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character from the input stream.
    ///
    /// - Returns: The next character or `nil` if the EOF has been found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func read() throws -> Character? { try inputStream.read() }

    /*===========================================================================================================================================================================*/
    /// Read, but do not remove, the next character from the input stream.
    ///
    /// - Returns: The next character or `nil` if the EOF has been found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func peek() throws -> Character? { try inputStream.peek() }

    /*===========================================================================================================================================================================*/
    /// Read the next `count` characters from the input stream.
    ///
    /// - Parameters:
    ///   - chars: The array to receive the characters. Any characters already in the array will be removed.
    ///   - count: The maximum number of characters to read.
    /// - Returns: The actual number of characters read which might be less than `count` if EOF is found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func read(chars: inout [Character], count: Int) throws -> Int { try inputStream.read(chars: &chars, maxLength: count) }

    /*===========================================================================================================================================================================*/
    /// Read the next `count` characters from the input stream and append them to the given character array.
    ///
    /// - Parameters:
    ///   - chars: The array to receive the characters. Any characters already in the array will be preserved.
    ///   - count: The maximum number of characters to read.
    /// - Returns: The actual number of characters read which might be less than `count` if EOF is found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func append(to chars: inout [Character], count: Int) throws -> Int { try inputStream.append(to: &chars, maxLength: count) }

    /*===========================================================================================================================================================================*/
    /// Mark Set
    ///
    @inlinable final func markSet() { inputStream.markSet() }

    /*===========================================================================================================================================================================*/
    /// Mark Delete
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markDelete() -> SAXCharInputStream { inputStream.markDelete(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Return
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markReturn() -> SAXCharInputStream { inputStream.markReturn(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Reset
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markReset() -> SAXCharInputStream { inputStream.markReset(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Update
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markUpdate() -> SAXCharInputStream { inputStream.markUpdate(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Backup
    ///
    /// - Parameter count: The number of characters to back up.
    /// - Returns: The number of characters actually backed up.
    ///
    @discardableResult @inlinable final func markBackup(count: Int = 1) -> SAXCharInputStream { inputStream.markBackup(count: count); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Get and return the next character in the input stream only if it is one of the allowed characters.
    ///
    /// - Parameters:
    ///   - errorOnEOF: If `true` then an error will be thrown if the EOF is found. The default is `false`.
    ///   - chars: The allowed characters.
    /// - Returns: The character or `nil` if the next character would not have been one of the allowed characters or if `errorOnEOF` is `true` and there was no next character.
    /// - Throws: If there was an I/O error or `errorOnEOF` is `true` and the EOF was found.
    ///
    @discardableResult @inlinable final func getChar(errorOnEOF: Bool = false, allowed chars: Character...) throws -> Character? { try getChar(errorOnEOF: errorOnEOF) { chars.contains($0) } }

    /*===========================================================================================================================================================================*/
    /// Get and return the next character in the input stream only if it passes the test.
    ///
    /// - Parameters:
    ///   - errorOnEOF: If `true` then an error will be thrown if the EOF is found. The default is `false`.
    ///   - test: The closure used to test the character.
    /// - Returns: The character or `nil` if the character did not pass the test.
    /// - Throws: If an I/O error occurs.
    ///
    @discardableResult @inlinable final func getChar(errorOnEOF: Bool = false, test: (Character) throws -> Bool) throws -> Character? {
        guard let ch = try peek() else {
            if errorOnEOF { throw SAXError.UnexpectedEndOfInput() }
            return nil
        }
        guard try test(ch) else { return nil }
        return try read()
    }

    /*===========================================================================================================================================================================*/
    /// Read and return any whitespace characters that are next in the input stream.
    ///
    /// - Returns: A string containing the whitespace characters. May be an empty string.
    /// - Throws: If an I/O error occurs.
    ///
    @discardableResult func readWhitespace() throws -> String {
        var buffer: [Character] = []
        while let ch = try getChar(test: { $0.isXmlWhitespace }) { buffer <+ ch }
        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next identifier from the input stream. An identifer starts with an XML Name Start Char and then zero or more XML Name Chars.
    ///
    /// - Returns: The identifier or `nil` if there is no identifier.
    /// - Throws: If an I/O error occurs.
    ///
    func nextIdentifier() throws -> String? {
        try readWhitespace()
        guard let ch1 = try getChar(test: { $0.isXmlNameStartChar }) else { return nil }
        var buffer: [Character] = [ ch1 ]
        while let ch2 = try getChar(test: { $0.isXmlNameChar }) { buffer <+ ch2 }
        return (buffer.isEmpty ? nil : String(buffer))
    }

    /*===========================================================================================================================================================================*/
    /// Read the next quoted value from the input stream.
    ///
    /// - Returns: The value without the quotes.
    /// - Throws: If an I/O error occurs or if the EOF is found before the closing quote.
    ///
    func nextQuotedValue() throws -> String? {
        guard let quote = try getChar(allowed: "\"", "'") else { return nil }
        var buffer: [Character] = []
        while let ch = try read() {
            if ch == quote { return String(buffer) }
            buffer <+ ch
        }
        throw SAXError.UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Read the next parameter. A parameter consists of an identifier and a quoted value separated by an equals sign (=).
    ///
    /// - Returns: An instance of KVPair or `nil` if there is no parameter.
    /// - Throws: If an I/O error occurs or if the EOF is found before the closing quote on the parameter quoted value.
    ///
    func nextParameter() throws -> KVPair? {
        try readWhitespace()
        guard let key = try nextIdentifier() else { return nil }
        let ch = try read()
        guard ch == "=" else { return nil }
        guard let value = try nextQuotedValue() else { return nil }
        return KVPair(key: key, value: replaceEntities(string: value))
    }

    /*===========================================================================================================================================================================*/
    /// Replace all of the defined entities in a string. Any entity that is undefined is left in place.
    ///
    /// - Parameter string: The string.
    /// - Returns: The new string with all the defined entities replaced.
    ///
    func replaceEntities(string: String) -> String {
        let res = GetRegularExpression(pattern: "\\&(\\w+);").stringByReplacingMatches(in: string) { match in
            guard let eName = match[1].subString else { return match.subString }
            switch eName {
                case "quot": return "\""
                case "lt":   return "<"
                case "gt":   return ">"
                case "apos": return "'"
                case "amp":  return "&"
                default: return match.subString
            }
        }
        return res.0
    }
}
