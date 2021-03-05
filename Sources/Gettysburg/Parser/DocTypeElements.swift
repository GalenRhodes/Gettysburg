/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeElements.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 3/3/21
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

@usableFromInline let errMsg: String = "Malformed element allowed content list."

extension SAXParser {
    /*===========================================================================================================================================================================*/
    /// Parse Element Declaration.
    /// 
    /// - Parameters:
    ///   - dtd: The string containing the DTD.
    ///   - pos: the position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the element declaration is malformed.
    ///
    @inlinable func parseDTDElements(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
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
    @usableFromInline func parseSingleDTDElement(_ elemDecl: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let pat1 = "\\A(\(rxNamePattern))\\s+(EMPTY|ANY|(?:\\(.+\\)[*+]?))\\z"

        guard let m = RegularExpression(pattern: pat1, options: RXO)?.firstMatch(in: elemDecl) else { throw SAXError.MalformedDTD(pos, description: "Element declaration is malformed.") }
        guard let n = m[1].subString else { throw SAXError.MalformedDTD(pos, description: "Element name missing from declaration.") }
        guard let r = m[2].range else { throw SAXError.MalformedDTD(pos, description: errMsg) }

        let (c, p)  = getSubStringAndPos(elemDecl, range: r, position: pos, charStream: chStream)
        let ac      = SAXElementAllowedContent.valueFor(description: c)
        let allowed = try getAllowedContentList(c, position: p, charStream: chStream, allowed: ac)
        var attrs   = Array<SAXDTDAttribute>()

        for a in docType._attributes { if a.element == n { attrs <+ a } }
        docType._elements <+ SAXDTDElement(name: n, attributes: attrs, allowedContent: ac, content: allowed)
        handler.dtdElementDecl(self, name: n, allowedContent: ac, content: allowed)
    }

    /*===========================================================================================================================================================================*/
    /// Get the allowed content list for the element declaration.
    /// 
    /// - Parameters:
    ///   - c: the string containing the allowed content list.
    ///   - p: the position of allowed content list in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - ac: the allowed content list type.
    /// - Returns: the allowed content list.
    /// - Throws: if the allowed content list is malformed.
    ///
    @inlinable func getAllowedContentList(_ c: String, position p: (Int, Int), charStream chStream: SAXCharInputStream, allowed ac: SAXElementAllowedContent) throws -> SAXDTDElementContentList? {
        var idx = c.startIndex
        switch ac {
            case .PCData:           return SAXDTDElementContentList(multiplicity: .Once, conjunction: .Or, items: [ SAXDTDElementContentPCData() ])
            case .Empty, .Any:      return nil
            case .Elements, .Mixed: return try parseDTDElementAllowed(c, index: &idx, isRoot: true, position: p, charStream: chStream)
        }
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
    @usableFromInline func parseDTDElementAllowed(_ str: String, index sIdx: inout String.Index, isRoot: Bool, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws -> SAXDTDElementContentList {
        var elems:  [SAXDTDElementContentItem]                = []
        var conj:   SAXDTDElementContentList.ItemConjunction? = nil
        var ch:     Character                                 = str[sIdx]

        guard ch == "(" else { throw SAXError.MalformedDTD(pos, description: errMsg) }
        str.formIndex(after: &sIdx)

        ch = str[sIdx]
        guard ch != ")" else { throw SAXError.MalformedDTD(pos, description: errMsg) }

        repeat {
            if ch == ")" { return parseDTDElementAllowedEnd(str, conjunction: conj, elements: elems, index: &sIdx) }
            else { try parseDTDElementItem(str, charStream: chStream, position: pos, isRoot: isRoot, elements: &elems, conjunction: &conj, index: &sIdx) }
            guard sIdx < str.endIndex else { break }

            try checkConjunction(str, position: pos, index: &sIdx, conjunction: &conj)
            guard sIdx < str.endIndex else { break }

            ch = str[sIdx]
        }
        while true

        throw SAXError.MalformedDTD(pos, description: errMsg)
    }

    /*===========================================================================================================================================================================*/
    /// Finish the element's allowed content list.
    /// 
    /// - Parameters:
    ///   - str: the string containing the allowed content list.
    ///   - conj: the conjunction used for the list.
    ///   - elems: the elements array.
    ///   - idx: the current index in the string.
    /// - Returns: the allowed elements list.
    ///
    public func parseDTDElementAllowedEnd(_ str: String, conjunction conj: SAXDTDElementContentList.ItemConjunction?, elements elems: [SAXDTDElementContentItem], index idx: inout String.Index) -> SAXDTDElementContentList {
        str.formIndex(after: &idx)
        return SAXDTDElementContentList(multiplicity: getMultiplicity(str, index: &idx), conjunction: conj ?? .And, items: elems)
    }

    /*===========================================================================================================================================================================*/
    /// Check the conjunction. If the conjunction has not yet been set, then set it.  If the conjunction has already been set then make sure this one matches it.
    /// 
    /// - Parameters:
    ///   - str: the string containing the allowed content list.
    ///   - pos:
    ///   - idx:
    ///   - conj: the conjunction used for the list.
    /// - Throws: if the current conjunction does not match the one previously set for this list.
    ///
    @inlinable final func checkConjunction(_ str: String, position pos: (Int, Int), index idx: inout String.Index, conjunction conj: inout SAXDTDElementContentList.ItemConjunction?) throws {
        if value(str[idx], isOneOf: "|", ",") {
            let oc: SAXDTDElementContentList.ItemConjunction = ((str[idx] == "|") ? .Or : .And)
            str.formIndex(after: &idx)
            if let c = conj { guard c == oc else { throw SAXError.MalformedDTD(pos, description: errMsg) } }
            else { conj = oc }
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DTD Element Allowed Content Item
    /// 
    /// - Parameters:
    ///   - str: the string.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - pos: the position of the item in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - isRoot: is this the root list.
    ///   - elems: the elements.
    ///   - conj: the conjuction.
    ///   - sIdx: the index.
    /// - Throws: if the item is malformed.
    ///
    @inlinable func parseDTDElementItem(_ str: String, charStream chStream: SAXCharInputStream, position pos: (Int, Int), isRoot: Bool, elements elems: inout [SAXDTDElementContentItem], conjunction conj: inout SAXDTDElementContentList.ItemConjunction?, index sIdx: inout String.Index) throws {
        var ch = str[sIdx]

        if ch == "(" {
            elems <+ try parseDTDElementAllowed(str, index: &sIdx, isRoot: false, position: str.positionOfIndex(sIdx, position: pos, charStream: chStream), charStream: chStream)
        }
        else if str[sIdx...].hasPrefix(PCDATA) {
            guard isRoot && elems.isEmpty else { throw SAXError.MalformedDTD(pos, description: errMsg) }
            elems <+ SAXDTDElementContentPCData()
            str.formIndex(&sIdx, offsetBy: PCDATA.count)
            conj = .Or
        }
        else if ch.isXmlNameStartChar {
            var b: [Character] = [ ch ]

            str.formIndex(after: &sIdx)
            ch = str[sIdx]

            while sIdx < str.endIndex && ch.isXmlNameChar {
                b <+ ch
                str.formIndex(after: &sIdx)
                ch = str[sIdx]
            }

            elems <+ SAXDTDElementContentElement(multiplicity: getMultiplicity(str, index: &sIdx), elementName: String(b))
        }
        else {
            throw SAXError.MalformedDTD(pos, description: errMsg)
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the multiplicity from a character.
    /// 
    /// - Parameters:
    ///   - str: the string.
    ///   - idx: the index of the character in the string to examine.
    /// - Returns: the multiplicity.
    ///
    @inlinable final func getMultiplicity(_ str: String, index idx: inout String.Index) -> SAXDTDElementContentItem.ItemMultiplicity {
        let mult: SAXDTDElementContentList.ItemMultiplicity

        if idx < str.endIndex && value(str[idx], isOneOf: "?", "*", "+") {
            mult = (str[idx] == "?" ? .Optional : (str[idx] == "*" ? .ZeroOrMore : .OneOrMore))
            str.formIndex(after: &idx)
        }
        else {
            mult = .Once
        }

        return mult
    }
}
