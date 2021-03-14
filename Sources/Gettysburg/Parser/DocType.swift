/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocType.swift
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

@usableFromInline let RXO:    [RegularExpression.Options] = [ .dotMatchesLineSeparators ]
@usableFromInline let PCDATA: String                      = "#PCDATA"

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Parse and handle a DOCTYPE element.
    /// 
    /// - Throws: if an I/O error occurs or the DOCTYPE is malformed.
    ///
    func parseDocType() throws {
        var chars: [Character] = []
        let tag:   String      = try charStream.readString(count: 10)

        guard try tag.matches(pattern: "^\\<\\!DOCTYPE\\s$") else { throw SAXError.MalformedDTD(charStream, description: "Expected \"<!DOCTYPE\" but found \"\(tag)\" instead.") }

        while let ch = try charStream.read() {
            switch ch {
                case "[":
                    try handleInternalDTD(String(chars))
                    return
                case ">":
                    try handleExternalOnlyDocType(String(chars))
                    return
                default: chars <+ ch
            }
        }

        throw SAXError.UnexpectedEndOfInput(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Handle an external DTD.
    /// 
    /// - Parameter string: the prefix for the DTD declaration.
    /// - Throws: the the DTD is malformed or there is an I/O error.
    ///
    private func handleExternalOnlyDocType(_ string: String) throws {
        // +---- 1 ---+ +- 2 + 3+-- 4 --+
        // |          | |    | ||       |
        // element_name SYSTEM "system_ID"
        //
        // +---- 1 ---+ +- 2 + 3+-- 4 --+  5+-- 6 --+
        // |          | |    | ||       |  ||       |
        // element_name PUBLIC "public_ID" "system_ID"
        //
        let p = "\\A\\s*(\(rxNamePattern))\\s+(SYSTEM|PUBLIC)\\s+([\"'])(.*?)\\3(?:\\s+([\"'])(.*?)\\5)?\\s*\\z"
        guard let m = RegularExpression(pattern: p, options: RXO)!.firstMatch(in: string) else { throw SAXError.MalformedDTD(charStream, description: string) }

        let xtp = SAXExternalType.valueFor(description: m[2].subString)
        let sid = m[(xtp == SAXExternalType.Public) ? 6 : 4].subString!

        try handleIntExtDTD(try getCharStreamFor(systemId: sid), rootElementName: m[1].subString!, externalType: xtp, publicId: ((xtp == .Public) ? m[4].subString : nil), systemId: sid)
    }

    /*===========================================================================================================================================================================*/
    /// Handle an internal DTD.
    /// 
    /// - Parameter string: the string prefix of the DTD declaration.
    /// - Throws: the the DTD is malformed or there is an I/O error.
    ///
    private func handleInternalDTD(_ string: String) throws {
        let pattern = "\\A\\s*(\(rxNamePattern))(?:\\s+SYSTEM\\s+([\"'])(.+?)\\2)?\\s+\\z"
        guard let match = RegularExpression(pattern: pattern, options: RXO)?.firstMatch(in: string) else { throw SAXError.MalformedDTD(charStream, description: string) }
        let name = match[1].subString!
        try handleIntExtDTD(charStream, rootElementName: name, externalType: .Internal, publicId: nil, systemId: nil)
        if let sid = match[3].subString { try handleIntExtDTD(try getCharStreamFor(systemId: sid), rootElementName: name, externalType: .System, publicId: nil, systemId: sid) }
    }

    /*===========================================================================================================================================================================*/
    /// Handle a combination of an Internal DTD with a possible External secondary DTD.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - elemName: the root element name.
    ///   - extType: the external type
    ///   - systemId: the system ID.
    ///   - publicId: the public ID.
    /// - Throws: if an I/O error occurs or either DTD is malformed.
    ///
    private func handleIntExtDTD(_ chStream: SAXCharInputStream, rootElementName elemName: String, externalType extType: SAXExternalType, publicId: String?, systemId: String?) throws {
        var items: [DTDItem] = []

        chStream.markSet()
        defer { chStream.markDelete() }

        while let cx = try chStream.read() {
            if cx == "<" {
                guard let cy = try chStream.read() else { throw SAXError.UnexpectedEndOfInput(chStream) }
                guard cy == "!" else { throw SAXError.InvalidCharacter(chStream, found: cy, expected: "!") }
                chStream.markBackup(count: 2)
                let pos = chStream.position
                let str = try foo(chStream)
                items <+ DTDItem(pos: pos, string: str)
            }
            else if extType == .Internal && cx == "]" {
                guard let cy = try chStream.read() else { break }
                guard cy == ">" else { throw SAXError.InvalidCharacter(chStream, found: cy, expected: ">") }
                try fooItAll(chStream, extType: extType, items: items)
                return
            }
            else if !cx.isXmlWhitespace {
                throw SAXError.InvalidCharacter(chStream, found: cx)
            }
        }

        if extType == .Internal { throw SAXError.UnexpectedEndOfInput(chStream) }
        try fooItAll(chStream, extType: extType, items: items)
    }

    /*===========================================================================================================================================================================*/
    /// Read the DTD Item.
    /// 
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the string.
    /// - Throws: if an I/O error occurs.
    ///
    private func foo(_ chStream: SAXCharInputStream) throws -> String {
        var buffer: [Character] = []
        while let ch = try chStream.read() {
            buffer <+ ch
            guard buffer.count <= memLimit else { throw SAXError.InternalError(description: "Too many characters.") }
            if ch == ">" { return String(buffer) }
        }
        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Foo it all.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - extType: the external type.
    ///   - items: the list of DTD Items.
    /// - Throws: if an error occurs.
    ///
    private func fooItAll(_ chStream: SAXCharInputStream, extType: SAXExternalType, items: [DTDItem]) throws {
        try parseDTDParameterEntities(chStream, extType: extType, items: items)
        try replaceParamEntities(items: items)
        try parseDTDGeneralEntities(chStream, extType: extType, items: items)
        try parseDTDNotations(chStream, items: items)
        for e in docType._entities { e.setNotation(docType._notations) }
        try parseDTDAttributes(chStream, items: items)
        try parseDTDElements(chStream, items: items)
    }

    /*===========================================================================================================================================================================*/
    /// Holds a DTD entry and it's position in the file.
    ///
    class DTDItem {
        let pos:    (Int, Int)
        var string: String

        init(pos: (Int, Int), string: String) {
            self.pos = pos
            self.string = string
        }
    }
}
