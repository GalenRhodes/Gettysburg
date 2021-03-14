/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeAttribute.swift
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

extension SAXParser {
    /*===========================================================================================================================================================================*/
    /// Parse a DTD Attribute Declaration.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    ///   - items: the array of items from the DTD.
    /// - Throws: if the attribute declaration is malformed.
    ///
    func parseDTDAttributes(_ chStream: SAXCharInputStream, items: [DTDItem]) throws {
        let rx = RegularExpression(pattern: "\\A\\<\\!ATTLIST\\s+(.*?)\\>\\z", options: RXO)!

        for i in items {
            if let m = rx.firstMatch(in: i.string), let r = m[1].range {
                let p = getSubStringAndPos(i.string, range: r, position: i.pos, charStream: chStream)
                try parseSingleDTDAttribute(p.0.trimmed, position: p.1, charStream: chStream)
            }
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
            let attrType = SAXAttributeType.valueFor(description: enums)
            let defType  = SAXAttributeDefaultType.valueFor(description: m[4].subString)
            try handleAttributeDecl(chStream, pos, str, element, name, attrType, defType, m[6].subString, enums, m[3].range!)
        }
        else {
            throw SAXError.MalformedDTD(pos, description: "Malformed Attribute Declaration")
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
                throw SAXError.MalformedDTD(p, description: errorMsg)
            }
        }

        return enumList
    }
}
