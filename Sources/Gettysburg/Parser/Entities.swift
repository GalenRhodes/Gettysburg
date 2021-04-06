/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Entities.swift
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

    func parseParameterEntityName(_ chStream: SAXCharInputStream) throws -> String {
        try chStream.readChar(mustBeOneOf: "%")
        let name = try chStream.readXmlName(leadingWS: .None)
        try chStream.readChar(mustBeOneOf: ";")
        return name
    }

    func parseEntityName(_ chStream: SAXCharInputStream) throws -> String {
        try chStream.readChar(mustBeOneOf: "&")
        // TODO: Handle numeric character entity names.
        let name = try chStream.readXmlName(leadingWS: .None)
        try chStream.readChar(mustBeOneOf: ";")
        return name
    }

    func getDTDParameterEntityFor(name: String) -> SAXDTDEntity? {
        getDTDEntityFor(name: name, type: .Parameter)
    }

    func getDTDEntityFor(name: String) -> SAXDTDEntity? {
        if let e = getDTDEntityFor(name: name, type: .General) { return e }
        return getDTDEntityFor(name: name, type: .Unparsed)
    }

    func getDTDEntityFor(name: String, type: SAXEntityType) -> SAXDTDEntity? {
        docType._entities.first { entity in ((entity.entityType == type) && (entity.name == name)) }
    }

    func getInternalEntityValue(entity ev: SAXDTDEntity) -> String? {
        nil
    }
}
