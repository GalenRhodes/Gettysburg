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
    /// Parse the DTD entities.
    /// 
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> the DTD was read from.
    /// - Throws: if any of the entities are malformed.
    ///
    @inlinable func parseDTDEntities(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        try RegularExpression(pattern: "\\<\\!ENTITY\\s+([^%].*?)\\>", options: RXO)!.forEachMatch(in: dtd) { m, _ in
            if let m = m, let r = m[1].range {
                let (s, p) = getSubStringAndPos(dtd, range: r, position: pos, charStream: chStream)
                try parseSingleDTDEntity(s.trimmed, type: .General, position: p, charStream: chStream)
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
    @inlinable func parseDTDParamEntities(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream, externalType extTp: SAXExternalType) throws {
        try RegularExpression(pattern: "\\<\\!ENTITY\\s+\\%\\s+(.*?)\\>", options: RXO)!.forEachMatch(in: dtd) { m, _ in
            if let m = m {
                guard value(extTp, isOneOf: .Public, .System) else {
                    let p = dtd.positionOfIndex(m.range.lowerBound, position: pos, charStream: chStream)
                    throw SAXError.MalformedDTD(p, description: "Only external DTDs can have parameter entities.")
                }
                if let r = m[1].range {
                    let (s, p) = getSubStringAndPos(dtd, range: r, position: pos, charStream: chStream)
                    try parseSingleDTDEntity(s.trimmed, type: .Parameter, position: p, charStream: chStream)
                }
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
    @usableFromInline func parseSingleDTDEntity(_ str: String, type: SAXEntityType, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let bPattern: String = "(\(rxNamePattern))"                         // For the entity name, the notation name, and the entity value.
        let cPattern: String = "([\"'])(.*?)\\"                             // For the public ID and the system ID.
        let dPattern: String = "(?:SYSTEM\\s+\(cPattern)5)"                 // For system external entities.
        let ePattern: String = "(?:PUBLIC\\s+\(cPattern)7\\s+\(cPattern)9)" // For public external entities.
        let fPattern: String = "(?:\\s+NDATA\\s+\(bPattern))?"              // For the unparsed entity notation name.
        let pattern:  String = "\\A(\\%)?\(bPattern)(?:\\s+(?:(?:\(cPattern)3)|(?:(?:\(dPattern)|\(ePattern))\(fPattern))))\\z"
        #if DEBUG
            print(pattern)
            print("========================================================================================================================")
        #endif

        guard let regex = RegularExpression(pattern: pattern, options: RXO) else { fatalError() }

        if let m = regex.firstMatch(in: str), let name = m[2].subString {
            try! handleEntity(chStream, pos, name, type, m[4].subString, m[8].subString, (m[6].subString ?? m[10].subString), m[11].subString)
        }
        else {
            throw SAXError.MalformedDTD(pos, description: "Malformed \(type) Entity Declaration.")
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
            throw SAXError.MalformedDTD(pos, description: "Malformed \(type) Entity Declaration.")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Replace all of the parameter entities in the DTD.
    /// 
    /// - Parameter string: the DTD
    /// - Returns: the DTD with all of the parameter entities replaced.
    /// - Throws: if an error occurs.
    ///
    func replaceParamEntities(in string: String) throws -> String {
        let pat:  String       = "\\%(\(rxNamePattern));"
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
        let fullEntity = String(dtd[rng])
        let entities   = docType.entities

        if let ee = handler.getParameterEntity(self, name: ent) {
            return (ee.value ?? fullEntity)
        }
        else if let ee = entities.first(where: { i in i.entityType == .Parameter && i.name == ent }) {
            if ee.externType == .Internal {
                return (ee.value ?? fullEntity)
            }
            else if let sid = ee.systemId {
                let chStream = try getExternalEntityInputStream(publicId: ee.publicId, systemId: sid)
                defer { chStream.close() }
                return try chStream.readAll()
            }
        }

        return fullEntity
    }

    /*===========================================================================================================================================================================*/
    /// Get the input stream to used to read an external entity.
    /// 
    /// - Parameters:
    ///   - publicId: the public ID
    ///   - systemId: the system ID
    /// - Returns: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to read the external entity from.
    /// - Throws: if there is an I/O error or the URI is malformed.
    ///
    func getExternalEntityInputStream(publicId: String?, systemId: String) throws -> SAXCharInputStream {
        let inStream = handler.resolveEntity(self, publicId: publicId, systemId: systemId)
        let chStream = try getCharStreamFor(inputStream: inStream, systemId: systemId)
        chStream.open()
        return chStream
    }
}
