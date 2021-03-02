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

let RXO: [RegularExpression.Options] = [ .dotMatchesLineSeparators ]

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
            print(dtd)
        #endif

        try parseDTDParamEntities(dtd, position: pos, charStream: chStream)
        let dtd = try replaceParamEntities(in: dtd)

        try validateWhitespace(dtd, charStream: chStream, pos: pos)
        try parseDTDEntities(dtd, position: pos, charStream: chStream)
        try parseDTDNotations(dtd, position: pos, charStream: chStream)
        try parseDTDElements(dtd, position: pos, charStream: chStream)
        try parseDTDAttributes(dtd, position: pos, charStream: chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse Element Declaration.
    ///
    /// - Parameters:
    ///   - dtd: The string containing the DTD.
    ///   - pos: the position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the element declaration is malformed.
    ///
    private func parseDTDElements(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let pat = "\\<\\!ELEMENT\\s+(.*?)\\>"

        try RegularExpression(pattern: pat, options: RXO)?.forEachMatch(in: dtd) { m, _ in
            if let m = m, let r = m[1].range {
                let (s, p) = getSubStringAndPos(dtd, range: r, position: pos, charStream: chStream)
                try parseSingleDTDElement(s.trimmed, position: p, charStream: chStream)
            }

            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a single Element Declaration.
    ///
    /// - Parameters:
    ///   - elemDecl: the string containing the element declaration.
    ///   - pos: the position of the element declaration within the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the element declaration is malformed.
    ///
    private func parseSingleDTDElement(_ elemDecl: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let pat1 = "\\A(\(rxNamePattern))\\s+(EMPTY|ANY|(?:\\(.+\\)[*+]?))\\z"
        guard let m = RegularExpression(pattern: pat1, options: RXO)?.firstMatch(in: elemDecl) else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "Element declaration is malformed.") }
        guard let n = m[1].subString else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "Element name missing from declaration.") }
        guard let c = m[2].subString else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "Element allowed content is missing from declaration.") }

        let ac: SAXElementAllowedContent
        switch c {
            case "ANY":       ac = .Any
            case "EMPTY":     ac = .Empty
            case "(#PCDATA)": ac = .PCData
            default:          ac = (c.hasPrefix("(#PCDATA") ? .Mixed : .Elements)
        }

        let (s, p)                            = getSubStringAndPos(elemDecl, range: m[2].range!, position: pos, charStream: chStream)
        var idx                               = s.startIndex
        let acList: SAXDTDElementContentList? = (value(ac, isOneOf: .Mixed, .Elements) ? try parseDTDElementAllowedContent(s, isRoot: true, position: p, charStream: chStream, idx: &idx) : nil)

        handler.dtdElementDecl(self, name: n, allowedContent: ac, content: acList)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the allowed content of an element declaration.
    ///
    /// - Parameters:
    ///   - content: the content string containing the allowed content.
    ///   - isRoot: is this the root of the list.
    ///   - pos: the position of the content in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - idx1: the index of the start of the content in the DTD.
    /// - Returns: the root allowed content list.
    /// - Throws: if the content string is malformed.
    ///
    private func parseDTDElementAllowedContent(_ content: String, isRoot: Bool, position pos: (Int, Int), charStream chStream: SAXCharInputStream, idx idx1: inout String.Index) throws -> SAXDTDElementContentList {
        let eIdx       = content.endIndex
        let subContent = content[idx1 ..< eIdx]

        if subContent == "(#PCDATA)" {
            guard isRoot else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "\"#PCDATA\" not allowed here.") }
            return SAXDTDElementContentList(multiplicity: .Once, conjunction: .Or, items: [ SAXDTDElementContentPCData() ])
        }

        var isMixed:  Bool                                     = false
        var conj:     SAXDTDElementContentList.ItemConjunction = .And
        var elements: [SAXDTDElementContentItem]               = []

        if subContent.hasPrefix("(#PCDATA|") {
            guard isRoot else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "\"#PCDATA\" not allowed here.") }
            elements <+ SAXDTDElementContentPCData()
            isMixed = true
            conj = .Or
            content.formIndex(&idx1, offsetBy: 9)
        }
        else if subContent.hasPrefix("(#PCDATA,") {
            throw SAXError.MalformedDTD(pos.0, pos.1, description: "Expected \"#PCDATA|\" but got \"#PCDATA,\" instead.")
        }
        else {
            content.formIndex(after: &idx1)
        }

        while idx1 < eIdx {
            if content[idx1] == "(" {
                elements <+ try parseDTDElementAllowedContent(content, isRoot: false, position: pos, charStream: chStream, idx: &idx1)
            }
            else if let m = RegularExpression(pattern: "\\A(\(rxNamePattern))([*+?]?)([|,]?)", options: RXO)?.firstMatch(in: content, range: idx1 ..< eIdx) {

            }
        }

        throw SAXError.MalformedDTD(pos.0, pos.1, description: "Malformed element allowed content list.")
    }

    private func getMultiplicity(_ str: String) -> SAXDTDElementContentItem.ItemMultiplicity {
        if let lc = str.last {
            switch lc {
                case "?": return .Optional
                case "*": return .ZeroOrMore
                case "+": return .OneOrMore
                default:  return .Once
            }
        }
        return .Once
    }

    /*===========================================================================================================================================================================*/
    /// Replace all of the parameter entities in the DTD.
    ///
    /// - Parameter string: the DTD
    /// - Returns: the DTD with all of the parameter entities replaced.
    /// - Throws: if an error occurs.
    ///
    private func replaceParamEntities(in string: String) throws -> String {
        let pat:  String       = "\\#(\(rxNamePattern));"
        var cIdx: String.Index = string.startIndex
        var out:  String       = ""

        try RegularExpression(pattern: pat)?.forEachMatch(in: string) { m, _ in
            if let m: RegularExpression.Match = m, let ent: String = m[1].subString {
                let rng = m.range
                out += try (String(string[cIdx ..< rng.lowerBound]) + getParamEntityValue(dtd: string, rng: rng, ent: ent))
                cIdx = rng.upperBound
            }
            return false
        }
        return (out + string[cIdx ..< string.endIndex])
    }

    /*===========================================================================================================================================================================*/
    /// Get the value for a parameter entity.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - rng: the range in the DTD where the parameter entity is referenced.
    ///   - ent: the name of the parameter entity.
    /// - Returns: the value of the parameter entity.
    /// - Throws: if there is an error getting the value.
    ///
    private func getParamEntityValue(dtd: String, rng: Range<String.Index>, ent: String) throws -> String {
        let xxx = String(dtd[rng])

        if let ee = handler.getParameterEntity(self, name: ent) {
            return (ee.value ?? xxx)
        }
        else if let ee = docType.entities.first(where: { i in i.entityType == .Parameter && i.name == ent }) {
            if ee.externType == .Internal {
                return (ee.value ?? xxx)
            }
            else if let sid = ee.systemId {
                let inStream = handler.resolveEntity(self, publicId: ee.publicId, systemId: sid)
                let chStream = try getCharStreamFor(inputStream: inStream, systemId: sid)
                chStream.open()
                defer { chStream.close() }
                return try chStream.readAll()
            }
        }

        return xxx
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DTD Attribute Declaration.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the starting position in the document for the DTD.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    /// - Throws: if the attribute declaration is malformed.
    ///
    private func parseDTDAttributes(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        try RegularExpression(pattern: "\\<\\!ATTLIST\\s+(.*?)\\>", options: RXO)?.forEachMatch(in: dtd) { match, _ in
            if let match = match, let range = match[1].range {
                let (s, p) = getSubStringAndPos(dtd, range: range, position: pos, charStream: chStream)
                try parseSingleDTDAttribute(s.trimmed, position: p, charStream: chStream)
            }
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a single attribute declaration.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the starting position in the document for the DTD.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    ///
    private func parseSingleDTDAttribute(_ str: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let p0: String = rxNamePattern
        let pA: String = "\\s+(CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|NOTATION|\\(\(p0)(?:\\|\(p0))*\\))"
        let pB: String = "\\A(\(p0))\\s+(\(p0))\(pA)(?:\\s+\\#(IMPLIED|REQUIRED|FIXED))?(?:\\s+([\"'])(.*?)\\5)?\\z"

        if let m = RegularExpression(pattern: pB, options: RXO)?.firstMatch(in: str), let element = m[1].subString, let name = m[2].subString, let enums = m[3].subString {
            try handleAttributeDecl(chStream, pos, str, element, name, getAttribType(enums), getDefaultType(m[4].subString), m[6].subString, enums, m[3].range!)
        }
        else {
            throw SAXError.MalformedDTD(pos.0, pos.1, description: "Malformed Attribute Declaration")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Handle a single attribute declaration.
    ///
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    ///   - pos: the starting position in the document for the DTD.
    ///   - str: the entire string of the attribute declaration.
    ///   - elemName: the attribute's element name.
    ///   - attrName: the attribute's name.
    ///   - attrType: the attribute type.
    ///   - defaultType: the default type.
    ///   - defaultValue: the default value.
    ///   - enums: the string containing the enumeration list.
    ///   - enumsRange: the range in the DTD that the list occupies.
    ///   - error: populated if the attribute declaration is malformed.
    ///
    private func handleAttributeDecl(_ chStream: SAXCharInputStream, _ pos: (Int, Int), _ str: String, _ elemName: String, _ attrName: String, _ attrType: SAXAttributeType, _ defaultType: SAXAttributeDefaultType, _ defaultValue: String?, _ enums: String, _ enumsRange: Range<String.Index>) throws {
        let enumList = try getEnumList(enums: enums, enumsRange: enumsRange, chStream: chStream, pos: pos, str: str, attrType: attrType)
        docType._attributes <+ SAXDTDAttribute(attrType: attrType, name: attrName, element: elemName, enumValues: enumList, defaultType: defaultType, defaultValue: defaultValue)
        handler.dtdAttributeDecl(self, name: attrName, elementName: elemName, type: attrType, enumList: enumList, defaultType: defaultType, defaultValue: defaultValue)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the string containing the enumeration list for the attribute into individual strings.
    ///
    /// - Parameters:
    ///   - enums: the string containing the enumeration list.
    ///   - enumsRange: the range in the DTD that the list occupies.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - pos: the position in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> of the DTD.
    ///   - str: the entire string of the attribute declaration.
    ///   - attrType: the attribute type.
    ///   - error: populated if the enumeration list is malformed.
    /// - Returns: an array of strings.
    ///
    private func getEnumList(enums: String, enumsRange: Range<String.Index>, chStream: SAXCharInputStream, pos: (Int, Int), str: String, attrType: SAXAttributeType) throws -> [String] {
        let errorMsg: String   = "Attribute declaration missing enumerated list."
        let pat2:     String   = "\\A\\((.+?)\\)\\z"
        var enumList: [String] = []

        if attrType == .Enumerated {
            if let m = RegularExpression(pattern: pat2, options: RXO)!.firstMatch(in: enums), let list = m[1].subString {
                enumList.append(contentsOf: list.components(separatedBy: "|"))
            }
            else {
                let (_, p) = getSubStringAndPos(str, range: enumsRange, position: pos, charStream: chStream)
                throw SAXError.MalformedDTD(p.0, p.1, description: errorMsg)
            }
        }

        return enumList
    }

    /*===========================================================================================================================================================================*/
    /// Get the attribute type based on it's name.
    ///
    /// - Parameter attribType: the attribute type name.
    /// - Returns: the attribute type.
    ///
    @inlinable final func getAttribType(_ attribType: String) -> SAXAttributeType {
        switch attribType {
            case "CDATA": return .CData
            case "ID": return .ID
            case "IDREF": return .IDRef
            case "IDREFS": return .IDRefs
            case "ENTITY": return .Entity
            case "ENTITIES": return .Entities
            case "NMTOKEN": return .NMToken
            case "NMTOKENS": return .NMTokens
            case "NOTATION": return .Notation
            default: return .Enumerated
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the default value type for an attribute based on the type name.
    ///
    /// - Parameter typeName: the type name.
    /// - Returns: the default value type.
    ///
    @inlinable final func getDefaultType(_ typeName: String?) -> SAXAttributeDefaultType {
        if let tn = typeName {
            switch tn {
                case "FIXED": return .Fixed
                case "IMPLIED": return .Implied
                case "REQUIRED": return .Required
                default: break
            }
        }
        return .Implied
    }

    /*===========================================================================================================================================================================*/
    /// Parse the DTD notations.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the starting position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    /// - Throws: if any of the notation declarations are malformed.
    ///
    private func parseDTDNotations(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        try RegularExpression(pattern: "\\<\\!NOTATION\\s+(.*?)\\>", options: RXO)?.forEachMatch(in: dtd) { match, _ in
            if let match = match {
                let group = match[1]
                if let range = group.range {
                    let (s, p) = getSubStringAndPos(dtd, range: range, position: pos, charStream: chStream)
                    try parseSingleDTDNotation(s.trimmed, position: p, charStream: chStream)
                }
            }
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a single notation declaration.
    ///
    /// - Parameters:
    ///   - str: the string containing the notation declaration.
    ///   - pos: the position of the notation declaration in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the notation declaration was read from.
    ///   - error: if the notation declaration is malformed.
    ///
    private func parseSingleDTDNotation(_ str: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let p = "\\A(\(rxNamePattern))\\s+(PUBLIC|SYSTEM)(?:\\s+([\"'])(.*?)\\3)(?:\\s+([\"'])(.*?)\\5)?\\z"
        guard let m = RegularExpression(pattern: p, options: RXO)?.firstMatch(in: str) else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "Malformed Notation Declaration.") }
        // If we matched on the regular expression then we will definitely have the string below so we can safely unwrap it.
        let noteName = m[1].subString!
        if m[2].subString == "PUBLIC" {
            guard let publicId = m[4].subString else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "Missing Public ID.") }
            docType._notations <+ SAXDTDNotation(name: noteName, publicId: publicId, systemId: m[6].subString)
            handler.dtdNotationDecl(self, name: noteName, publicId: publicId, systemId: m[6].subString)
        }
        else {
            guard let systemId = m[4].subString else { throw SAXError.MalformedDTD(pos.0, pos.1, description: "Missing System ID.") }
            docType._notations <+ SAXDTDNotation(name: noteName, publicId: nil, systemId: systemId)
            handler.dtdNotationDecl(self, name: noteName, publicId: nil, systemId: systemId)
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the DTD entities.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> the DTD was read from.
    /// - Throws: if any of the entities are malformed.
    ///
    private func parseDTDEntities(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        try RegularExpression(pattern: "\\<\\!ENTITY\\s+([^%].*?)\\>", options: RXO)!.forEachMatch(in: dtd) { m, _ in
            if let m = m, let r = m[1].range {
                let (s, p) = getSubStringAndPos(dtd, range: r, position: pos, charStream: chStream)
                try parseSingleDTDEntity(s.trimmed, position: p, charStream: chStream)
            }
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the DTD parameter entities.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> the DTD was read from.
    /// - Throws: if any of the entities are malformed.
    ///
    private func parseDTDParamEntities(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        try RegularExpression(pattern: "\\<\\!ENTITY\\s+\\%\\s+(.*?)\\>", options: RXO)!.forEachMatch(in: dtd) { m, _ in
            if let m = m, let r = m[1].range {
                let (s, p) = getSubStringAndPos(dtd, range: r, position: pos, charStream: chStream)
                try parseSingleDTDEntity(s.trimmed, position: p, charStream: chStream)
            }
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a single entity declaration from the DTD.
    ///
    /// - Parameters:
    ///   - str: the string containing the entity declaration.
    ///   - pos: the position of the entity declaration in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> the entity declaration was read from.
    ///
    private func parseSingleDTDEntity(_ str: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let bPattern: String = "\\s+(\(rxNamePattern))"                     // For the entity name, the notation name, and the entity value.
        let cPattern: String = "([\"'])(.*?)\\"                             // For the public ID and the system ID.
        let dPattern: String = "(?:SYSTEM\\s+\(cPattern)5)"                 // For system external entities.
        let ePattern: String = "(?:PUBLIC\\s+\(cPattern)7\\s+\(cPattern)9)" // For public external entities.
        let fPattern: String = "(?:\\s+NDATA\(bPattern))?"                  // For the unparsed entity notation name.
        let pattern:  String = "\\A(\\%)?\(bPattern)(?:\\s+(?:(?:\(cPattern)3)|(?:(?:\(dPattern)|\(ePattern))\(fPattern))))\\z"

        guard let regex = RegularExpression(pattern: pattern, options: RXO) else { fatalError() }

        if let m = regex.firstMatch(in: str), let name = m[2].subString {
            try! handleEntity(chStream, pos, name, ((m[1].subString == "%") ? .Parameter : .General), m[4].subString, m[8].subString, (m[6].subString ?? m[10].subString), m[11].subString)
        }
        else {
            throw SAXError.MalformedDTD(pos.0, pos.1, description: "Malformed Entity Declaration.")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Handle an internal or external entity.
    ///
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the entity declaration was read from.
    ///   - pos: the position of the entity declaration in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - name: the name of the entity.
    ///   - type: the type of the entity.
    ///   - value: the value of the internal entity.
    ///   - pubId: the public ID of the external entity.
    ///   - sysId: the system ID of the external entity.
    ///   - note: the notation name of the unparsed entity.
    /// - Throws: if the entity declaration is malformed.
    ///
    private func handleEntity(_ chStream: SAXCharInputStream, _ pos: (Int, Int), _ name: String, _ type: SAXEntityType, _ value: String?, _ pubId: String?, _ sysId: String?, _ note: String?) throws {
        if let value = value {
            docType._entities <+ SAXDTDEntity(name: name, entityType: type, value: value)
            handler.dtdInternalEntityDecl(self, name: name, type: type, content: value)
        }
        else if let systemId = sysId {
            if let notationName = note {
                if type == .Parameter {
                    throw SAXError.MalformedDTD(chStream, description: "A parameter entity cannot be UNPARSED.")
                }
                else {
                    docType._entities <+ SAXDTDUnparsedEntity(name: name, publicId: pubId, systemId: systemId, notation: notationName)
                    handler.dtdUnparsedEntityDecl(self, name: name, publicId: pubId, systemId: systemId, notation: notationName)
                }
            }
            else {
                docType._entities <+ SAXDTDEntity(name: name, entityType: type, publicId: pubId, systemId: systemId, value: nil)
                handler.dtdExternalEntityDecl(self, name: name, type: type, publicId: pubId, systemId: systemId)
            }
        }
        else {
            throw SAXError.MalformedDTD(pos.0, pos.1, description: "Malformed Entity Declaration.")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Validate that the whitespace does, in fact, contain just whitespace.
    ///
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - pos: the starting position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there is non-whitespace characters in the string.
    ///
    private func validateWhitespace(_ dtd: String, charStream chStream: SAXCharInputStream, pos: (Int, Int)) throws {
        let rx: RegularExpression = RegularExpression(pattern: "\\S+", options: RXO)!
        var i:  String.Index      = dtd.startIndex

        try RegularExpression(pattern: "\\<\\!(?:(?:(ENTITY|ATTLIST|ELEMENT|NOTATION)\\s(.+?))|(?:--(.*?)--))\\>", options: RXO)!.forEachMatch(in: dtd) { m1, _ in
            if let m1 = m1 {
                let r       = m1.range
                let (s, sp) = getSubStringAndPos(dtd, range: (i ..< r.lowerBound), position: pos, charStream: chStream)

                if let m2 = rx.firstMatch(in: s) { throw getDTDError(s, index: m2.range.lowerBound, position: sp, charStream: chStream, message: "Invalid DTD syntax: \"\(m2.subString)\"") }
                else if let comment = m1[3].subString { handler.comment(self, content: comment) }

                i = r.upperBound
            }
            return false
        }

        let (s, sp) = getSubStringAndPos(dtd, range: (i ..< dtd.endIndex), position: pos, charStream: chStream)
        if let m = rx.firstMatch(in: s) { throw getDTDError(s, index: m.range.lowerBound, position: sp, charStream: chStream, message: "Invalid DTD syntax: \"\(m.subString)\"") }
    }

    /*===========================================================================================================================================================================*/
    /// Create a Malformed DTD error.
    ///
    /// - Parameters:
    ///   - string: the string containing the error.
    ///   - idx: the index in the string where the error is.
    ///   - pos: the starting position of the string in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - msg: the error message.
    /// - Returns: the error.
    ///
    private func getDTDError(_ string: String, index idx: String.Index, position pos: (Int, Int), charStream chStream: SAXCharInputStream, message msg: String) -> SAXError.MalformedDTD {
        let p = string.positionOfIndex(idx, startingLine: pos.0, startingColumn: pos.1, tabSize: chStream.tabWidth)
        return SAXError.MalformedDTD(p.0, p.1, description: msg)
    }
}
