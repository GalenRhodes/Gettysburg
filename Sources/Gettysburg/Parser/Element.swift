/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Element.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/18/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Parse and handle an element.
    /// 
    /// - Throws: if there is an I/O error or the element or one of it's children is malformed.
    ///
    func parseElement() throws {
        try parseElement(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the element from the given <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there is an I/O error or the element is malformed.
    ///
    func parseElement(_ chStream: SAXCharInputStream) throws {
        do {
            chStream.markSet()

            let pos:  (Int, Int)  = chStream.position
            var buff: [Character] = []

            while let ch = try chStream.read() {
                buff <+ ch
                if ch == ">" {
                    chStream.markDelete()
                    try parseElement(String(buff), position: pos, charStream: chStream)
                    return
                }
            }

            throw SAXError.UnexpectedEndOfInput(chStream)
        }
        catch let e {
            chStream.markDelete()
            throw e
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the element from the character string.
    /// 
    /// - Parameters:
    ///   - string: the string containing the element.
    ///   - pos: the position of the element in the document.
    ///   - chIn: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the element is malformed.
    ///
    private func parseElement(_ string: String, position pos: (Int, Int), charStream chIn: SAXCharInputStream) throws {
        let pat1 = "\\A\\<(\(rxNamePattern))(.*?)(/?)\\>\\z"

        guard let m1 = RegularExpression(pattern: pat1, options: RXO)?.firstMatch(in: string) else { throw SAXError.MalformedDocument(pos, description: "Not an XML Element: \"\(string)\"") }
        guard let name = m1[1].subString, let rng = m1[2].range, let sub = m1[2].subString else { throw SAXError.InternalError(description: "???") }

        let attrs:    [SAXAttribute]    = try parseElementAttributes(sub, position: string.positionOfIndex(rng.lowerBound, position: pos, charStream: chIn), charStream: chIn)
        let mappings: [NSMapping]       = docType._mappings.last!
        let pfxName:  (String?, String) = name.splitPrefix()
        let nsName:   SAXNSName         = SAXNSName(localName: pfxName.1, prefix: pfxName.0, uri: uriFor(prefix: pfxName.0))

        for m in mappings { handler.beginPrefixMapping(self, mapping: m) }
        handler.beginElement(self, name: nsName, attributes: attrs)
        if let r = m1[3].range, string[r] != "/" { try parseElementContent(chIn, element: name) }
        handler.endElement(self, name: nsName)
        for m in mappings.reversed() { handler.endPrefixMapping(self, prefix: m.prefix) }
        docType._mappings.removeLast()
    }

    /*===========================================================================================================================================================================*/
    /// Get the Namespace URI for the given Prefix.
    /// 
    /// - Parameter prefix: the prefix.
    /// - Returns: the namespace URI or `nil` if the prefix is `nil` or the prefix is not found.
    ///
    @inlinable func uriFor(prefix: String?) -> String? {
        let prefix: String = (prefix ?? "")
        for mappings in docType.mappings.reversed() { for m in mappings { if m.prefix == prefix { return m.uri } } }
        return nil
    }

    /*===========================================================================================================================================================================*/
    /// Parse the element attributes.
    /// 
    /// - Parameters:
    ///   - string: the string containing the elements.
    ///   - range: the range of the attributes in the string.
    /// - Returns: the attributes, the prefix/uri mappings, and the default URI.
    /// - Throws: if the attributes are malformed.
    ///
    private func parseElementAttributes(_ string: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws -> [SAXAttribute] {
        let pat:      String         = "\\A\\s+(\(rxNamePattern))\\=([\"'])(\\.*?)\\2"
        var string:   String         = string
        var pos:      (Int, Int)     = pos
        var attrs:    [SAXAttribute] = []
        var mappings: [NSMapping]    = []

        if let erx = RegularExpression(pattern: "\\A\\s*\\z"), let rx = RegularExpression(pattern: pat, options: RXO) {
            while erx.numberOfMatches(in: string) == 0 {
                guard let m = rx.firstMatch(in: string) else { throw SAXError.MalformedDocument(pos, description: "Malformed attribute.") }

                if let key = m[1].subString, let value = m[3].subString {
                    if key == "xmlns:" {
                        throw SAXError.MalformedDocument(pos, description: "Malformed attribute")
                    }
                    else if key.hasPrefix("xmlns:") {
                        mappings <+ NSMapping(prefix: key.substr(from: 6), uri: value)
                    }
                    else if key == "xmlns" {
                        mappings <+ NSMapping(prefix: "", uri: value)
                    }
                    else {
                        attrs <+ SAXAttribute(name: key, value: value, defaulted: false)
                    }
                }

                pos = string.positionOfIndex(m.range.upperBound, position: pos, charStream: chStream)
                string = String(string[m.range.upperBound ..< string.endIndex])
            }
        }

        docType._mappings <+ mappings
        return attrs
    }

    /*===========================================================================================================================================================================*/
    /// Parse the body of the element.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - elemName: the name of the element
    /// - Throws: if there is an I/O error or the body of the element is malformed.
    ///
    private func parseElementContent(_ chStream: SAXCharInputStream, element elemName: String) throws {
        var buffer: [Character] = []
        var pos:    (Int, Int)  = chStream.position

        chStream.markSet()
        defer { chStream.markDelete() }

        while let ch = try chStream.read() {
            if ch == "<" {
                handler.text(self, content: String(buffer), continued: false)
                buffer.removeAll(keepingCapacity: true)
                guard let ch2 = try chStream.read() else { break }

                switch ch2 {
                    case "/":
                        try handleClosingTag(chStream, element: elemName)
                        return
                    case "!":
                        let str = try chStream.readString(count: 7)
                        if str.hasPrefix("--") {
                            chStream.markBackup(count: 5)
                            try parseComment(chStream)
                        }
                        else if str == "[CDATA[" {
                            try parseCDATASection(chStream)
                        }
                        else {
                            throw SAXError.MalformedDocument(pos, description: "Expected \"<!--\" or \"<![CDATA[\" but found \"\(str)\" instead.")
                        }
                    case "?":
                        try parseProcessingInstruction(chStream)
                    default:
                        guard ch2.isXmlNameStartChar else { throw SAXError.InvalidCharacter(chStream, found: ch2) }
                        chStream.markBackup(count: 2)
                        try parseElement(chStream)
                }
            }
            else {
                buffer <+ ch
            }
            chStream.markUpdate()
            pos = chStream.position
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Handle a closing tag.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - elemName: the name of the element
    /// - Throws: if the closing tag does not belong to the element or there is an I/O error.
    ///
    private func handleClosingTag(_ chStream: SAXCharInputStream, element elemName: String) throws {
        chStream.markBackup(count: 2)
        var buffer: [Character] = []
        let pos:    (Int, Int)  = chStream.position

        while let ch = try chStream.read() {
            if !ch.isXmlWhitespace {
                buffer <+ ch

                if ch == ">" {
                    guard let m = RegularExpression(pattern: "</\\s*(\(rxNamePattern))\\s*>")?.firstMatch(in: String(buffer)) else {
                        throw SAXError.MalformedDocument(pos, description: "Expected a closing tag.")
                    }
                    guard elemName == m[1].subString else {
                        throw SAXError.MalformedDocument(pos, description: "Excected closing tag for element \"\(elemName)\" but found \"\(m[1].subString ?? "")\" instead.")
                    }
                    return
                }
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }
}
