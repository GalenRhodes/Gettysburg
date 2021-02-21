/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeEntity.swift
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

    func parseEntityDecl(_ chStream: SAXCharInputStream, _ rootElement: String, _ exType: SAXExternalType) throws {
        try chStream.readChars(mustBe: "ENTITY")
        let (char, type) = try getEntityType(chStream, exType: exType)

        guard char.isXmlNameStartChar else { throw SAXError.InvalidCharacter(chStream, found: char, expected: []) }
        let name = (try "\(char)" + chStream.readNMToken(leadingWS: .None))

        let ch = try chStream.skipWhitespace(mustHave: true, returnLast: false)
        switch ch {
            case "P": try parsePublicExternalEntityDecl(chStream, rootElement, name, type)
            case "S": try parseSystemExternalEntityDecl(chStream, rootElement, name, type)
            case "\"", "'": try parseInternalEntityDecl(chStream, rootElement, name, type, char)
            default: throw SAXError.InvalidCharacter(chStream, found: ch, expected: "P", "S", "\"", "'")
        }
    }

    private func getEntityType(_ chStream: SAXCharInputStream, exType: SAXExternalType) throws -> (Character, SAXEntityType) {
        let char = try chStream.skipWhitespace(mustHave: true, returnLast: false)

        if char == "%" {
            guard value(exType, isOneOf: .Public, .System) else { throw SAXError.MalformedDTD(chStream, description: "Parameter entities are only allowed in external DOCTYPEs.") }
            return (try chStream.skipWhitespace(mustHave: true, returnLast: false), .Parameter)
        }

        return (char, .General)
    }

    private func parsePublicExternalEntityDecl(_ chStream: SAXCharInputStream, _ rootElement: String, _ name: String, _ type: SAXEntityType) throws {
        try chStream.readChars(mustBe: "UBLIC")
        let publicId = try chStream.readQuotedString(leadingWS: .Required)
        let systemId = try chStream.readQuotedString(leadingWS: .Required)
        try parseExternalEntityDecl(chStream, name, type, publicId, systemId)
    }

    private func parseSystemExternalEntityDecl(_ chStream: SAXCharInputStream, _ rootElement: String, _ name: String, _ type: SAXEntityType) throws {
        try chStream.readChars(mustBe: "YSTEM")
        let systemId = try chStream.readQuotedString(leadingWS: .Required)
        try parseExternalEntityDecl(chStream, name, type, nil, systemId)
    }

    private func parseExternalEntityDecl(_ chStream: SAXCharInputStream, _ name: String, _ type: SAXEntityType, _ publicId: String?, _ systemId: String) throws {
        let char = try chStream.skipWhitespace(mustHave: false, returnLast: false)

        if char == "N" {
            try chStream.readChars(mustBe: "DATA")
            try parseUnparsedEntityDecl(chStream, name, type, publicId, systemId)
        }
        else if char == ">" {
            handler.dtdExternalEntityDecl(self, name: name, type: type, publicId: publicId, systemId: systemId)
        }
        else {
            throw SAXError.InvalidCharacter(chStream, found: char, expected: "N", ">")
        }
    }

    private func parseUnparsedEntityDecl(_ chStream: SAXCharInputStream, _ name: String, _ type: SAXEntityType, _ publicId: String?, _ systemId: String) throws {
        let notation = try chStream.readName(leadingWS: .Required)
        try chStream.readTagCloser()
        handler.dtdUnparsedEntityDecl(self, name: name, publicId: publicId, systemId: systemId, notation: notation)
    }

    private func parseInternalEntityDecl(_ chStream: SAXCharInputStream, _ rootElement: String, _ name: String, _ type: SAXEntityType, _ quote: Character) throws {
        let content = try chStream.readQuotedString(quote: quote)
        try chStream.readTagCloser()
        handler.dtdInternalEntityDecl(self, name: name, type: type, content: content)
    }
}
