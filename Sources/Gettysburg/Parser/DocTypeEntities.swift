/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeEntities.swift
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
    /// Replace all of the parameter entities in the DTD.
    /// 
    /// - Parameter items: the DTD
    /// - Returns: the DTD with all of the parameter entities replaced.
    /// - Throws: if an error occurs.
    ///
    func replaceParamEntities(items: [DTDItem]) throws {
        let pat: String            = "\\%(\(rxNamePattern));"
        let rx:  RegularExpression = RegularExpression(pattern: pat)!

        for i in items {
            var cIdx: String.Index = i.string.startIndex
            var out:  String       = ""

            try rx.forEachMatch(in: i.string) { m, _ in
                if let m: RegularExpression.Match = m, let ent: String = m[1].subString {
                    out.append(contentsOf: i.string[cIdx ..< m.range.lowerBound])
                    out.append(contentsOf: try getParamEntityValue(dtd: i.string, rng: m.range, ent: ent))
                    cIdx = m.range.upperBound
                }
                return false
            }

            out.append(contentsOf: i.string[cIdx ..< i.string.endIndex])
            i.string = out
        }
    }

    /*===========================================================================================================================================================================*/
    /// Handle the parameter entities.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - extType: the external type.
    ///   - items: the DTD items.
    /// - Throws: if there is an error.
    ///
    func parseDTDParameterEntities(_ chStream: SAXCharInputStream, extType: SAXExternalType, items: [DTDItem]) throws {
        try parseDTDEntities(chStream, type: .Parameter, extType: extType, items: items)
    }

    /*===========================================================================================================================================================================*/
    /// Handle the general entities.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - extType: the external type.
    ///   - items: the DTD items.
    /// - Throws: if there is an error.
    ///
    func parseDTDGeneralEntities(_ chStream: SAXCharInputStream, extType: SAXExternalType, items: [DTDItem]) throws { try parseDTDEntities(chStream, type: .General, extType: extType, items: items) }

    /*===========================================================================================================================================================================*/
    /// Handle entities
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - type: the entity type to be handled.
    ///   - extType: the external type.
    ///   - items: the DTD items.
    /// - Throws: if there is an error.
    ///
    private func parseDTDEntities(_ chStream: SAXCharInputStream, type: SAXEntityType, extType: SAXExternalType, items: [DTDItem]) throws {
        guard let rx = RegularExpression(pattern: "\\A\\<\\!ENTITY\\s+(.*?)\\>\\z", options: RXO) else { fatalError() }
        for i in items {
            if let m = rx.firstMatch(in: i.string), let r = m[1].range {
                let p = getSubStringAndPos(i.string, range: r, position: i.pos, charStream: chStream)
                try parseSingleDTDEntity(p.0.trimmed, type: type, extType: extType, position: p.1, charStream: chStream)
            }
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
    private func parseSingleDTDEntity(_ str: String, type: SAXEntityType, extType: SAXExternalType, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let bPattern: String = "(\(rxNamePattern))"                         // For the entity name, the notation name, and the entity value.
        let cPattern: String = "([\"'])(.*?)\\"                             // For the public ID and the system ID.
        let dPattern: String = "(?:SYSTEM\\s+\(cPattern)5)"                 // For system external entities.
        let ePattern: String = "(?:PUBLIC\\s+\(cPattern)7\\s+\(cPattern)9)" // For public external entities.
        let fPattern: String = "(?:\\s+NDATA\\s+\(bPattern))?"              // For the unparsed entity notation name.
        let pattern:  String = "\\A(?:(\\%)\\s+)?\(bPattern)(?:\\s+(?:(?:\(cPattern)3)|(?:(?:\(dPattern)|\(ePattern))\(fPattern))))\\z"

        guard let m = RegularExpression(pattern: pattern, options: RXO)?.firstMatch(in: str) else { throw SAXError.MalformedDTD(pos, description: "Malformed \(type) Entity Declaration.") }

        let noteName = m[11].subString
        let isParsed = (noteName == nil)

        guard (type == ((m[1].subString == "%") ? .Parameter : .General)) else { return }
        guard ((type != .Parameter) || isParsed) else { throw SAXError.MalformedDTD(chStream, description: "A parameter entity cannot be UNPARSED.") }
        guard ((type != .Parameter) || (extType == .Internal)) else { throw SAXError.MalformedDTD(chStream, description: "Only external DTDs can have parameter entities.") }
        try handleEntity(chStream, pos, m[2].subString!, (isParsed ? type : .Unparsed), m[4].subString, m[8].subString, (m[6].subString ?? m[10].subString), noteName)
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
            // Internal Entities...
            docType._entities <+ SAXDTDEntity(name: name, entityType: type, value: value)
            handler.dtdInternalEntityDecl(self, name: name, type: type, content: value)
        }
        else if let systemId = sysId {
            // External Entities...
            switch type {
                case .General:
                    docType._entities <+ SAXDTDEntity(name: name, entityType: type, publicId: pubId, systemId: systemId, value: nil)
                    handler.dtdExternalEntityDecl(self, name: name, type: type, publicId: pubId, systemId: systemId)
                case .Parameter:
                    docType._entities <+ SAXDTDEntity(name: name, entityType: type, publicId: pubId, systemId: systemId, value: nil)
                    handler.dtdExternalEntityDecl(self, name: name, type: type, publicId: pubId, systemId: systemId)
                case .Unparsed:
                    docType._entities <+ SAXDTDUnparsedEntity(name: name, publicId: pubId, systemId: systemId, notation: note!)
                    handler.dtdUnparsedEntityDecl(self, name: name, publicId: pubId, systemId: systemId, notation: note!)
            }
        }
        else {
            // Neither Internal nor External!?!!
            throw SAXError.MalformedDTD(pos, description: "Malformed \(type) Entity Declaration: Must have either a value or a system ID.")
        }
    }
}
