/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeAttribute.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/21/21
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

    func parseAttributeDecl(_ chStream: SAXCharInputStream, _ rootElement: String) throws {
        try chStream.readChars(mustBe: "ATTLIST")
        let elemName: String            = try chStream.readName()
        let attrName: String            = try chStream.readName()
        let (type, enumList)            = try getAttributeTypeAndEnumList(chStream)
        let (defaultType, defaultValue) = try getAttributeDefaultTypeAndValue(chStream)
        try chStream.readTagCloser()
        handler.dtdAttributeDecl(self, name: attrName, elementName: elemName, type: type, enumList: enumList, defaultType: defaultType, defaultValue: defaultValue)
    }

    private func getAttributeTypeAndEnumList(_ chStream: SAXCharInputStream) throws -> (SAXAttributeType, [String]) {
        let char: Character = try chStream.skipWhitespace(mustHave: true, returnLast: false)

        if char == "(" {
            return try getAttributeEnumType(chStream)
        }
        else {
            let attrType = "\(char)\(try chStream.readName())"
            switch attrType {
                case "CDATA":    return (.CData, [])
                case "ID":       return (.ID, [])
                case "IDREF":    return (.IDRef, [])
                case "IDREFS":   return (.IDRefs, [])
                case "ENTITY":   return (.Entity, [])
                case "ENTITIES": return (.Entities, [])
                case "NMTOKEN":  return (.NMToken, [])
                case "NMTOKENS": return (.NMTokens, [])
                case "NOTATION": return (.Notation, [])
                default:         throw SAXError.MalformedDTD(chStream, description: "Incorrect attribute declaration type: \(attrType)")
            }
        }
    }

    private func getAttributeEnumType(_ chStream: SAXCharInputStream) throws -> (SAXAttributeType, [String]) {
        var enumList: [String] = []
        enumList.append(contentsOf: try chStream.readUntil(found: ")", excludeFound: true).components(separatedBy: "|").map { $0.trimmed })
        return (.Enumerated, enumList)
    }

    private func getAttributeDefaultTypeAndValue(_ chStream: SAXCharInputStream) throws -> (SAXAttributeDefaultType, String?) {
        let char = try chStream.skipWhitespace(mustHave: true, returnLast: false)
        guard value(char, isOneOf: "#", "\"", "'") else { throw SAXError.InvalidCharacter(chStream, found: char, expected: "#", "\"", "'") }

        if char == "#" {
            let str = try chStream.readName(leadingWS: .None)
            switch str {
                case "REQUIRED": return (.Required, nil)
                case "IMPLIED":  return (.Implied, try getDefaultValue(chStream, isRequired: false))
                case "FIXED":    return (.Fixed, try getDefaultValue(chStream, isRequired: true))
                default:         throw SAXError.MalformedDTD(chStream, description: "Invalid attribute default type: \(str)")
            }
        }
        else {
            return (.Implied, try chStream.readQuotedString(quote: char))
        }
    }

    private func getDefaultValue(_ chStream: SAXCharInputStream, isRequired: Bool) throws -> String? {
        var dValue: String?   = nil
        var char:   Character = try chStream.readNoNil()

        if char.isXmlWhitespace {
            char = try chStream.skipWhitespace(returnLast: false)
            if value(char, isOneOf: "\"", "'") {
                dValue = try chStream.readQuotedString(quote: char)
                char = try chStream.skipWhitespace(returnLast: false)
            }
        }

        guard char == ">" else { throw SAXError.InvalidCharacter(chStream, found: char, expected: ">") }
        if dValue == nil && isRequired { throw SAXError.MalformedDTD(chStream, description: "Default value is required.") }
        return dValue
    }
}
