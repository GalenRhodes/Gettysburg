/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXTestHandler.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/18/21
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
import Rubicon
@testable import Gettysburg

class SAXTestHandler: SAXDelegate {
    func beginDocument(_ parser: SAXParser) {
        nDebug(.In, "Document begin: \(parser.url.absoluteString)")
    }

    func endDocument(_ parser: SAXParser) {
        nDebug(.Out, "Document end: \(parser.url.absoluteString)")
    }

    func beginDocType(_ parser: SAXParser, elementName: String) {
        nDebug(.In, "DOCTYPE begin: \(elementName)")
    }

    func endDocType(_ parser: SAXParser, elementName: String) {
        nDebug(.Out, "DOCTYPE end: \(elementName)")
    }

    func dtdInternal(_ parser: SAXParser, elementName: String) {
        nDebug(.None, "Internal DTD: \(elementName)")
    }

    func dtdExternal(_ parser: SAXParser, elementName: String, publicId: String?, systemId: String) {
        nDebug(.None, "External DTD: \(elementName); Public ID: \(publicId?.surroundedWith("\"") ?? "nil"); System ID: \(systemId.surroundedWith("\""))")
    }

    func dtdInternalEntityDecl(_ parser: SAXParser, name: String, content: String) {
        /* TODO: Implement me... */
    }

    func dtdExternalEntityDecl(_ parser: SAXParser, name: String, type: DOMDocType.DTDExternalType, publicId: String?, systemId: String) {
        /* TODO: Implement me... */
    }

    func dtdUnparsedEntityDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String, notation: String) {
        /* TODO: Implement me... */
    }

    func dtdElementDecl(_ parser: SAXParser, name: String, allowedContent: DTDElement.AllowedContent) {
        /* TODO: Implement me... */
    }

    func dtdAttributeDecl(_ parser: SAXParser, name: String, elementName: String, type: DTDAttribute.AttributeType, defaultType: DTDAttribute.DefaultType) {
        /* TODO: Implement me... */
    }

    func dtdNotationDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String?) {
        /* TODO: Implement me... */
    }

    func comment(_ parser: SAXParser, content: String) {
        nDebug(.In, "COMMENT")
        defer { nDebug(.Out, "COMMENT") }
        nDebug(.None, content)
    }

    func text(_ parser: SAXParser, content: String) {
        nDebug(.In, "TEXT")
        defer { nDebug(.Out, "TEXT") }
        nDebug(.None, content)
    }

    func cdataSection(_ parser: SAXParser, content: String) {
        nDebug(.In, "CDATA")
        defer { nDebug(.Out, "CDATA") }
        nDebug(.None, content)
    }

    func resolveEntity(_ parser: SAXParser, publicId: String?, systemId: String) -> InputStream? {
        fatalError("resolveEntity(_:publicId:systemId:) has not been implemented")
        /* TODO: Implement me... */
    }

    func beginPrefixMapping(_ parser: SAXParser, mapping: NSMapping) {
        nDebug(.In, "Prefix mapping: xmlns:\(mapping.prefix)=\"\(mapping.uri)\"")
    }

    func endPrefixMapping(_ parser: SAXParser, prefix: String) {
        nDebug(.Out, "Prefix mapping: xmlns:\(prefix)")
    }

    func beginElement(_ parser: SAXParser, name: NSName, attributes: SAXRawAttribList) {
        nDebug(.In, "Element: \(name)")
        attributes.forEach { nDebug(.None, "\($0.name)=\"\($0.value)\"") }
    }

    func endElement(_ parser: SAXParser, name: NSName) {
        nDebug(.Out, "Element: \(name)")
    }

    func getEntity(_ parser: SAXParser, name: String) -> Any? {
        fatalError("getEntity(_:name:) has not been implemented")
        /* TODO: Implement me... */
    }

    func getParameterEntity(_ parser: SAXParser, name: String) -> Any? {
        return nil
        /* TODO: Implement me... */
    }

    func processingInstruction(_ parser: SAXParser, target: String, data: String) {
        nDebug(.None, "Processing Instruction: target=\"\(target)\"; data=\"\(data)\"")
    }

    func handleError(_ parser: SAXParser, error: Error) -> Bool {
        print("ERROR: \(error)")
        return true
    }
}
