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
        let tag                = try charStream.readString(count: 10, errorOnEOF: true)
        guard try tag.matches(pattern: "^\\<\\!DOCTYPE\\s$") else { throw SAXError.MalformedDTD(charStream, description: "Expected \"<!DOCTYPE\" but found \"\(tag)\" instead.") }

        while let ch = try charStream.read() {
            switch ch {
                case "[":
                    try handleInternalDocType(String(chars))
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
        let pattern = "\\A\\s*(\(rxNamePattern))\\s+(SYSTEM|PUBLIC)\\s+([\"'])(.*?)\\3(?:\\s+([\"'])(.*?)\\5)?\\s*\\z"
        guard let match = RegularExpression(pattern: pattern, options: RXO)!.firstMatch(in: string) else { throw SAXError.MalformedDTD(charStream, description: string) }

        let elementName: String          = match[1].subString!
        let extType:     SAXExternalType = ((match[2].subString == "PUBLIC") ? .Public : .System)
        let publicId:    String?         = ((extType == .Public) ? match[4].subString : nil)
        let systemId:    String          = match[(extType == .Public) ? 6 : 4].subString!

        try parseExternalDTD(elementName, extType: extType, publicId: publicId, systemId: systemId)
    }

    /*===========================================================================================================================================================================*/
    /// Handle an internal DTD.
    /// 
    /// - Parameter string: the string prefix of the DTD declaration.
    /// - Throws: the the DTD is malformed or there is an I/O error.
    ///
    private func handleInternalDocType(_ string: String) throws {
        let pattern = "\\A\\s*(\(rxNamePattern))(?:\\s+SYSTEM\\s+([\"'])(.+?)\\2)?\\s+\\z"
        guard let match = RegularExpression(pattern: pattern, options: RXO)?.firstMatch(in: string) else { throw SAXError.MalformedDTD(charStream, description: string) }

        let rootElementName: String      = match[1].subString!
        let pos:             (Int, Int)  = (charStream.lineNumber, charStream.columnNumber)
        var chars:           [Character] = []

        while let cx = try charStream.read() {
            if cx == ">" && chars.last == "]" {
                chars.removeLast()
                try parseDTD(String(chars), pos: pos, charStream: charStream, rootElement: rootElementName, extType: .Internal)
                if let systemId = match[3].subString { try parseExternalDTD(rootElementName, extType: .System, publicId: nil, systemId: systemId) }
                return
            }
            chars <+ cx
        }

        throw SAXError.UnexpectedEndOfInput(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse an external DTD.
    /// 
    /// - Parameters:
    ///   - rootElement: the name of the root element.
    ///   - extType: the external type.
    ///   - publicId: the public ID.
    ///   - systemId: the system ID.
    /// - Throws: if the DTD is malformed or there is an I/O error.
    ///
    private func parseExternalDTD(_ rootElement: String, extType: SAXExternalType, publicId: String?, systemId: String) throws {
        let chs: SAXCharInputStream = try getCharStreamFor(systemId: systemId)
        let dtd: String             = try chs.readAll()
        try parseDTD(dtd, pos: (chs.lineNumber, chs.columnNumber), charStream: chs, rootElement: rootElement, extType: extType, publicId: publicId, systemId: systemId)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the DTD string.
    /// 
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the starting position in the document for the DTD.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    ///   - rootElement: the root element for the DTD
    ///   - extType: the external type.
    ///   - publicId: the public ID.
    ///   - systemId: the system ID.
    /// - Throws: if the DTD is malformed.
    ///
    private func parseDTD(_ dtd: String, pos: (Int, Int), charStream chStream: SAXCharInputStream, rootElement: String, extType: SAXExternalType, publicId: String? = nil, systemId: String? = nil) throws {
        #if DEBUG
            print("========================================================================================================================")
            print(dtd)
            print("========================================================================================================================")
        #endif

        try parseDTDParamEntities(dtd, position: pos, charStream: chStream)
        let dtd2 = try replaceParamEntities(in: dtd)
        #if DEBUG
            if dtd != dtd2 {
                print(dtd2)
                print("========================================================================================================================")
            }
        #endif

        try validateWhitespace(dtd2, charStream: chStream, pos: pos)
        try parseDTDEntities(dtd2, position: pos, charStream: chStream)
        try parseDTDNotations(dtd2, position: pos, charStream: chStream)
        for e in docType._entities { e.setNotation(docType._notations) }
        try parseDTDAttributes(dtd2, position: pos, charStream: chStream)
        try parseDTDElements(dtd2, position: pos, charStream: chStream)
    }
}
