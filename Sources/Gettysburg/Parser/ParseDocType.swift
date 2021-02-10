/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ParseDocType.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/8/21
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
#if os(Windows)
    import WinSDK
#endif

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Parse out a DOCTYPE Declaration. This method picks up AFTER the text "<!DOCTYPE " has already been read from the input stream.
    /// 
    /// - Parameter handler: The handler.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    func parseDocType(_ handler: H) throws {
        markSet()
        defer { markDelete() }

        // Get past any additional whitespace.
        try skipWhitespace(push: true)
        let elemName: String    = try readXmlName()
        let ch:       Character = try skipWhitespace(mustHave: true, push: true)

        switch ch {
            case "S": try parseExternalSystemDTD(handler, element: elemName)
            case "P": try parseExternalPublicDTD(handler, element: elemName)
            case "[": try parseInternalDTD(handler, element: elemName)
            default:  throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg(ch))
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse an external public DTD
    /// 
    /// - Parameters:
    ///   - handler: the handler
    ///   - elemName: the root element name.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    private func parseExternalPublicDTD(_ handler: H, element elemName: String) throws {
        let str = try readUntilWhitespace()
        guard str == "PUBLIC" else { throw SAXError.MalformedDTD(charStream, description: "Unknown identifier for DTD: \(str)") }

        let name = try readQuotedString()
        let loc  = try readQuotedString()

        let ch   = try skipWhitespace(mustHave: false)
        guard ch == ">" else { markBackup(); throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg2(expected: ">", found: ch)) }

        try parseExternalDTD(handler, element: elemName, type: .Public, name: name, location: loc)
    }

    /*===========================================================================================================================================================================*/
    /// Parse an external system DTD
    /// 
    /// - Parameters:
    ///   - handler: the handler
    ///   - elemName: the root element name.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    private func parseExternalSystemDTD(_ handler: H, element elemName: String) throws {
        let str = try readUntilWhitespace()
        guard str == "SYSTEM" else { throw SAXError.MalformedDTD(charStream, description: "Unknown identifier for DTD: \(str)") }

        let loc = try readQuotedString()
        let ch  = try skipWhitespace(mustHave: false)

        try parseExternalDTD(handler, element: elemName, type: .System, name: nil, location: loc)

        if ch == "[" { try parseInternalDTD(handler, element: elemName) }
        else if ch != ">" { markBackup(); throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg2(expected: ">", found: ch)) }
    }

    /*===========================================================================================================================================================================*/
    /// Parse an internal DTD
    /// 
    /// - Parameters:
    ///   - handler: the handler
    ///   - elemName: the root element name.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    private func parseInternalDTD(_ handler: H, element elemName: String) throws {
        handler.dtdInternalBegin(parser: self, rootElementName: elemName)
        try parseDTD(handler, charInputStream: charStream, elementName: elemName, isInternal: true)
        handler.dtdInternalEnd(parser: self, rootElementName: elemName)
    }

    /*===========================================================================================================================================================================*/
    /// Parse an external DTD
    /// 
    /// - Parameters:
    ///   - handler: the handler
    ///   - elemName: the root element name.
    ///   - type: the external type.
    ///   - name: the public ID
    ///   - location: the system ID
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    private func parseExternalDTD(_ handler: H, element elemName: String, type: DTDExternalType, name: String?, location: String) throws {
        handler.dtdExternalBegin(parser: self, rootElementName: elemName, type: type, externalId: name, systemId: location)
        // TODO: Read from external file. Encoding?
        handler.dtdExternalEnd(parser: self, rootElementName: elemName)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an internal or external DTD.
    /// 
    /// - Parameters:
    ///   - handler: the handler
    ///   - elemName: the root element name.
    ///   - isInternal: `true` if the DTD is internal or `false` if it is external.
    ///   - chStream: the character input stream to read from.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    private func parseDTD(_ handler: H, charInputStream chStream: CharInputStream, elementName elemName: String, isInternal: Bool) throws {
        chStream.markSet()
        defer { chStream.markDelete() }

        while let ch = try chStream.read() {
            if try parseDTD001(handler: handler, charInputStream: chStream, elementName: elemName, lastChar: ch, isInternal: isInternal) { break }
            chStream.markUpdate()
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an internal or external DTD.
    /// 
    /// - Parameters:
    ///   - handler: the handler
    ///   - chStream: the character input stream to read from.
    ///   - elemName: the root element name.
    ///   - ch: the last character read from the character input stream.
    ///   - isInternal: `true` if the DTD is internal or `false` if it is external.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    private func parseDTD001(handler: H, charInputStream chStream: CharInputStream, elementName elemName: String, lastChar ch: Character, isInternal: Bool) throws -> Bool {
        if isInternal && ch == "]" {
            try readCharAnd(chStream, expected: ">")
            return true
        }
        else if ch == "<" {
            let str = try readString(chStream, count: 3)

            switch str {
                case "!--":
                    // Comment
                    try parseComment(handler, charInputStream: chStream)
                case "!EN":
                    // Entity
                    try parseEntityDecl(handler, charInputStream: chStream, isInternal: isInternal)
                case "!EL":
                    // Element
                    try parseElementDecl(handler, charInputStream: chStream, isInternal: isInternal)
                case "!AT":
                    // Attribute
                    try parseAttributeDecl(handler, charInputStream: chStream, isInternal: isInternal)
                case "!NO":
                    // Notation
                    try parseNotationDecl(handler, charInputStream: chStream, isInternal: isInternal)
                default:
                    // Conditional?
                    try parseConditionalDecl(handler, charInputStream: chStream, isInternal: isInternal)
            }
        }
        else if !ch.isXmlWhitespace {
            chStream.markReset()
            throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg2(expected: "<", found: ch))
        }
        return false
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a conditional declaration.
    /// 
    /// - Parameters:
    ///   - handler: the SAX handler.
    ///   - chStream: the character input stream.
    ///   - isInternal: `true` if the DTD is internal or `false` if the DTD is external.
    /// - Throws: if an I/O error occurs or if the conditional declaration is malformed, not allowed, or incomplete.
    ///
    private func parseConditionalDecl(_ handler: H, charInputStream chStream: CharInputStream, isInternal: Bool) throws {
        chStream.markReset()
        let str = try readString(chStream, count: 3)

        if str == "<![" {
            if isInternal {
                chStream.markReset()
                throw SAXError.MalformedDTD(chStream, description: "Conditional declaration not allowed in an internal DTD.")
            }
            // Conditional
            // TODO: implement.
        }
        else {
            chStream.markReset()
            throw SAXError.MalformedDTD(chStream, description: "Unknown DTD declaration: \"\(str)\"")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a notation declaration.
    /// 
    /// - Parameters:
    ///   - handler: the SAX handler.
    ///   - chStream: the character input stream.
    ///   - isInternal: `true` if the DTD is internal or `false` if the DTD is external.
    /// - Throws: if an I/O error occurs or if the notation declaration is malformed or incomplete.
    ///
    private func parseNotationDecl(_ handler: H, charInputStream chStream: CharInputStream, isInternal: Bool) throws {
        try readCharAnd(chStream, expected: "TATION")
        // TODO: implement.
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an attribute declaration.
    /// 
    /// - Parameters:
    ///   - handler: the SAX handler.
    ///   - chStream: the character input stream.
    ///   - isInternal: `true` if the DTD is internal or `false` if the DTD is external.
    /// - Throws: if an I/O error occurs or if the attribute declaration is malformed or incomplete.
    ///
    private func parseAttributeDecl(_ handler: H, charInputStream chStream: CharInputStream, isInternal: Bool) throws {
        try readCharAnd(chStream, expected: "TLIST")
        // TODO: implement.
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an element declaration.
    /// 
    /// - Parameters:
    ///   - handler: the SAX handler.
    ///   - chStream: the character input stream.
    ///   - isInternal: `true` if the DTD is internal or `false` if the DTD is external.
    /// - Throws: if an I/O error occurs or if the element declaration is malformed or incomplete.
    ///
    private func parseElementDecl(_ handler: H, charInputStream chStream: CharInputStream, isInternal: Bool) throws {
        try readCharAnd(chStream, expected: "EMENT")
        // TODO: implement.
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an entity declaration.
    /// 
    /// - Parameters:
    ///   - handler: the SAX handler.
    ///   - chStream: the character input stream.
    ///   - isInternal: `true` if the DTD is internal or `false` if the DTD is external.
    /// - Throws: if an I/O error occurs or if the entity declaration is malformed or incomplete.
    ///
    private func parseEntityDecl(_ handler: H, charInputStream chStream: CharInputStream, isInternal: Bool) throws {
        try readCharAnd(chStream, expected: "TITY")

        var ch:         Character     = try skipWhitespace(chStream, mustHave: true, push: true)
        let entityType: DTDEntityType = try getEntityType(chStream, ch, isInternal)
        let name:       String        = try readXmlName(chStream)

        ch = try skipWhitespace(chStream, mustHave: true, push: true)

        if value(ch, isOneOf: "S", "P") {
            let extTypeEnum = try getExternalType(chStream)
            // External Entity Decl
            try parseExternalEntityDecl(handler, charInputStream: chStream, name: name, entityType: entityType, extType: extTypeEnum)
        }
        else if value(ch, isOneOf: "\"", "'") {
            // Internal Entity Decl
            chStream.push(char: ch)
            let content = try readQuotedString(charStream)
            ch = try skipWhitespace(chStream)
            guard ch == ">" else {
                chStream.push(char: ch)
                throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg2(expected: ">", found: ch))
            }
            handler.dtdEntityDecl(parser: self, name: name, entityType: entityType, content: content)
        }
        else {
            chStream.push(char: ch)
            throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg3(expected: "S", "P", "\"", "'", found: ch))
        }
    }

    /*===========================================================================================================================================================================*/
    /// Determine if the external entity is a public or system external type.
    /// 
    /// - Parameter chStream: the character input stream.
    /// - Returns: `SAXParser.DTDExternalType.Public` or `SAXParser.DTDExternalType.System`.
    /// - Throws: if an I/O error occurs or if the external entity type is not "SYSTEM" or "PUBLIC"
    ///
    private func getExternalType(_ chStream: CharInputStream) throws -> DTDExternalType {
        let extType = try readUntilWhitespace(chStream)
        guard value(extType, isOneOf: "SYSTEM", "PUBLIC") else { throw SAXError.MalformedDTD(chStream, description: "Invalid external type for entity declaration: \(extType)") }
        return ((extType == "PUBLIC") ? .Public : .System)
    }

    /*===========================================================================================================================================================================*/
    /// Determine if the entity is a general entity or a parameter entity.
    /// 
    /// - Parameters:
    ///   - chStream: The character input stream.
    ///   - ch: the last character read.
    ///   - isInternal: `true` if this is an internal entity.
    /// - Returns: `SAXParser.DTDEntityType.General` or `SAXParser.DTDEntityType.Parameter`
    /// - Throws: if an I/O error occurs, it is a parameter entity and this is an internal DTD, or if the first non-whitespace character after the '%' is invalid for an entity
    ///           name.
    ///
    private func getEntityType(_ chStream: CharInputStream, _ ch: Character, _ isInternal: Bool) throws -> DTDEntityType {
        if ch == "%" {
            if isInternal { throw SAXError.MalformedDTD(chStream.lineNumber, (chStream.columnNumber - 1), description: "Parameter entities are only allowed in external DTDs.") }
            let ch = try skipWhitespace(chStream, mustHave: true, push: true)
            guard ch.isXmlNameStartChar else { throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg(ch)) }
            return .Parameter
        }
        chStream.push(char: ch)
        guard ch.isXmlNameStartChar else { throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg(ch)) }
        return .General
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an external entity declaration.
    /// 
    /// - Parameters:
    ///   - handler: the handler.
    ///   - chStream: the character input stream.
    ///   - name: the entity name.
    ///   - entityType: the entity type.
    ///   - extType: the external type.
    /// - Throws: if an I/O error occurs or if the external entity declaration is malformed or incomplete.
    ///
    private func parseExternalEntityDecl(_ handler: H, charInputStream chStream: CharInputStream, name: String, entityType: DTDEntityType, extType: DTDExternalType) throws {
        let publicId: String? = ((extType == .Public) ? (try readQuotedString(chStream)) : nil)
        let systemId: String  = try readQuotedString(chStream)

        let ch = try skipWhitespace(chStream)
        guard value(ch, isOneOf: "N", ">") else { throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg3(expected: "N", ">", found: ch)) }

        if ch == "N" { try parseUnparsedEntityDecl(handler, charInputStream: chStream, name: name, extType: extType, publicId: publicId, systemId: systemId) }
        else { handler.dtdExternalEntityDecl(parser: self, name: name, entityType: entityType, type: extType, publicId: publicId, systemId: systemId) }
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an Unparsed Entity Declaration.
    /// 
    /// - Parameters:
    ///   - handler: the handler.
    ///   - chStream: the character input stream.
    ///   - name: the name of the entity.
    ///   - extType: the external type.
    ///   - publicId: the public ID.
    ///   - systemId: the system ID.
    /// - Throws: if an I/O error occurs or if the unparsed entity declaration is malformed or incomplete.
    ///
    private func parseUnparsedEntityDecl(_ handler: H, charInputStream chStream: CharInputStream, name: String, extType: DTDExternalType, publicId: String?, systemId: String) throws {
        let s = try readUntilWhitespace(chStream)
        guard s == "DATA" else { throw SAXError.MalformedDTD(chStream, description: "Expected \"NDATA\" but found \"N\(s)\" instead.") }

        let noteName = try readXmlName(chStream)
        if noteName.isEmpty { throw SAXError.MalformedDTD(chStream, description: "Missing notation name.") }

        let ch = try skipWhitespace(chStream)
        guard ch == ">" else { throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg2(expected: ">", found: ch)) }

        handler.dtdUnparsedEntityDecl(parser: self, name: name, type: extType, publicId: publicId, systemId: systemId, notation: noteName)
    }
}
