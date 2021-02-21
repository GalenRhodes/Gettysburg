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

extension SAXParser {

    /// Parse and handle a DOCTYPE element.
    ///
    /// - Throws: if an I/O error occurs or the DOCTYPE is malformed.
    ///
    func parseDocType() throws {
        let str = try charStream.readString(count: 10)
        guard try str.matches(pattern: "\\A\\<\\!DOCTYPE\\s\\z") else { throw SAXError.MalformedDocument(charStream, description: "Expected DOCTYPE tag but found \"\(str)\" instead.") }
        try charStream.skipWhitespace(returnLast: true)
        let elementName = try charStream.readName()
        let ch          = try charStream.skipWhitespace(mustHave: true, returnLast: false)

        switch ch {
            case "[":
                try parseExternalDocType(charStream, elementName: elementName, type: .Internal, publicId: nil, systemId: nil)
            case "P":
                _ = try charStream.readChars(mustBe: "UBLIC")
                try resolveExternalDocType(elementName, type: .Public, publicId: try charStream.readQuotedString(leadingWS: .Required))
            case "S":
                _ = try charStream.readChars(mustBe: "YSTEM")
                try resolveExternalDocType(elementName, type: .System, publicId: nil)
            default:
                throw SAXError.InvalidCharacter(charStream, found: ch, expected: "[", "P", "S")
        }
    }

    private func resolveExternalDocType(_ elementName: String, type: SAXExternalType, publicId: String?) throws {
        guard !xmlStandalone else { throw SAXError.MalformedDTD(charStream, description: "A standalone XML document cannot have an external DTD.") }

        let systemId = try charStream.readQuotedString(leadingWS: .Required)
        let char     = try charStream.skipWhitespace(returnLast: false)

        if char == "[" {
            guard type == .System else { throw SAXError.MalformedDTD(charStream, description: "External DTD type must be SYSTEM if there is also an internal DTD.") }
            try parseExternalDocType(charStream, elementName: elementName, type: .Internal, publicId: nil, systemId: nil)
        }
        else if char != ">" {
            throw SAXError.InvalidCharacter(charStream, found: char, expected: ">")
        }

        guard let url = URL(string: systemId, relativeTo: baseURL) else { throw SAXError.MalformedURL(charStream, url: systemId) }
        let extChStream = try getExternalEntityCharInputStream(url: url)
        try parseExternalDocType(extChStream, elementName: elementName, type: type, publicId: publicId, systemId: systemId)
    }

    private func parseExternalDocType(_ chStream: SAXCharInputStream, elementName: String, type: SAXExternalType, publicId: String?, systemId: String?) throws {
        while let ch = try chStream.read() {
            switch ch {
                case "<":
                    try parseDTDItem(chStream, rootElement: elementName, type: type)
                case "]":
                    guard type == .Internal else { throw SAXError.InvalidCharacter(chStream, found: ch, expected: "<") }
                    try chStream.readChar(mustBeOneOf: ">")
                    return
                default:
                    guard ch.isXmlWhitespace else { throw SAXError.InvalidCharacter(chStream, found: ch, expected: "<") }
            }
        }

        guard value(type, isOneOf: .Public, .System) else { throw SAXError.UnexpectedEndOfInput(charStream) }
    }

    private func parseDTDItem(_ chStream: SAXCharInputStream, rootElement: String, type: SAXExternalType) throws {
        chStream.markSet()
        defer { chStream.markDelete() }
        let str = try chStream.readString(count: 3)

        switch str {
            case "!--":
                try parseComment(charStream: chStream)
            case "!EL":
                chStream.markBackup(count: 2)
                try parseElementDecl(chStream, rootElement)
            case "!AT":
                chStream.markBackup(count: 2)
                try parseAttributeDecl(chStream, rootElement)
            case "!EN":
                chStream.markBackup(count: 2)
                try parseEntityDecl(chStream, rootElement, type)
            case "!NO":
                chStream.markBackup(count: 2)
                try parseNotationDecl(chStream, rootElement)
            default:
                chStream.markBackup(count: 3)
                let (ch, chars) = str.getInvalidCharInfo(strings: "!EL", "!AT", "!NO", "!EN", "!--")
                throw SAXError.InvalidCharacter(chStream, found: ch, expected: chars)
        }
    }

    private func parseNotationDecl(_ chStream: SAXCharInputStream, _ rootElement: String) throws {
        try chStream.readChars(mustBe: "NOTATION")
        let name = try chStream.readName()
        let type = try chStream.readName()

        if type == "PUBLIC" {
            let publicId: String    = try chStream.readQuotedString(leadingWS: .Required)
            var systemId: String?   = nil
            var ch:       Character = try chStream.skipWhitespace(returnLast: false)

            if value(ch, isOneOf: "\"", "'") {
                systemId = try chStream.readQuotedString(quote: ch)
                ch = try chStream.skipWhitespace(returnLast: true)
            }

            guard ch == ">" else { throw SAXError.InvalidCharacter(chStream, found: ch, expected: ">") }
            handler.dtdNotationDecl(self, name: name, publicId: publicId, systemId: systemId)
        }
        else if type == "SYSTEM" {
            handler.dtdNotationDecl(self, name: name, publicId: nil, systemId: try chStream.readQuotedString(leadingWS: .Required))
        }
        else {
            throw SAXError.MalformedDTD(chStream, description: "Notation external type must be PUBLIC or SYSTEM.")
        }
    }
}
