/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ExternalEntities.swift
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
    /*===========================================================================================================================================================================*/
    /// Get a <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> for an external entity.
    /// 
    /// - Parameter url: the URL. If the URL is relative then it will be resolved against the Base URL of the document.
    /// - Returns: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there is an I/O error.
    ///
    func getExternalEntityCharInputStream(url: URL) throws -> SAXCharInputStream {
        guard let inStream = MarkInputStream(url: url) else { throw SAXError.IOError(0, 0, description: "Unable to open URL: \(url.absoluteString)") }
        let chStream = try SAXCharInputStream(inputStream: inStream, url: url)

        //------------------------------------------------------
        // Now skip over the text declaration if there was one.
        //------------------------------------------------------
        chStream.open()
        chStream.markSet()
        defer { chStream.markReturn() }

        let str = try chStream.readString(count: 6, errorOnEOF: false)
        if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
            _ = try chStream.readUntil(found: "?>", memLimit: memLimit)
            chStream.markUpdate()
        }

        return chStream
    }

    /*===========================================================================================================================================================================*/
    /// Get the value for a general entity.
    /// 
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - rng: the range in the DTD where the parameter entity is referenced.
    ///   - ent: the name of the parameter entity.
    /// - Returns: the value of the parameter entity.
    /// - Throws: if there is an error getting the value.
    ///
    func getGeneralEntityValue(dtd: String, rng: Range<String.Index>, ent: String) throws -> String {
        let fullEntity = String(dtd[rng])
        let entities   = docType.entities

        if let v = handler.getEntity(self, name: ent)?.value {
            return v
        }
        else if let ent = entities.first(where: { i in ((i.entityType == .Unparsed) && (i.name == ent)) }) {
            
        }
        else if let ent = entities.first(where: { i in ((i.entityType == .General) && (i.name == ent)) }) {
            if let v = ent.value {
                return v
            }
            else if let sid = ent.systemId {
                let v = try getExternalEntityInputStream(publicId: ent.publicId, systemId: sid).readAll()
                ent.value = v
                return v
            }
        }

        return fullEntity
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
    func getParamEntityValue(dtd: String, rng: Range<String.Index>, ent: String) throws -> String {
        let fullEntity = String(dtd[rng])
        let entities   = docType.entities

        if let v = handler.getParameterEntity(self, name: ent)?.value {
            return v
        }
        else if let ent = entities.first(where: { i in ((i.entityType == .Parameter) && (i.name == ent)) }) {
            if let v = ent.value {
                return v
            }
            else if let sid = ent.systemId {
                let v = try getExternalEntityInputStream(publicId: ent.publicId, systemId: sid).readAll()
                ent.value = v
                return v
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
    private func getExternalEntityInputStream(publicId: String?, systemId: String) throws -> SAXCharInputStream {
        let inStream = handler.resolveEntity(self, publicId: publicId, systemId: systemId)
        let chStream = try getCharStreamFor(inputStream: inStream, systemId: systemId)
        chStream.open()
        return chStream
    }
}
