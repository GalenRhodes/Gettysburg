/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDefaultHandler.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/15/21
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

open class SAXDefaultHandler: SAXHandler {
    public typealias H = SAXDefaultHandler

    open func documentBegin(parser: SAXParser<H>, version: String?, encoding: String?, standAlone: Bool?) {
        /* TODO: Implement me... */
    }

    open func dtdInternalBegin(parser: SAXParser<H>, rootElementName: String) {
        /* TODO: Implement me... */
    }

    open func dtdExternalBegin(parser: SAXParser<H>, rootElementName: String, type: SAXParser<H>.DTDExternalType, externalId: String?, systemId: String) {
        /* TODO: Implement me... */
    }

    open func dtdEntityDecl(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDEntityType, publicId: String?, systemId: String?, content: String) {
        /* TODO: Implement me... */
    }

    open func dtdUnparsedEntityDecl(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String, notation: String) {
        /* TODO: Implement me... */
    }

    open func dtdNotationDecl(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String) {
        /* TODO: Implement me... */
    }

    open func dtdElementDecl(parser: SAXParser<H>, name: String, allowedContent: DTDElementContent) {
        /* TODO: Implement me... */
    }

    open func dtdAttrDecl(parser: SAXParser<H>, elementName: String, attrName: String, type: SAXParser<H>.DTDAttrType, defaultType: SAXParser<H>.DTDAttrDefaultType, defaultValue: String?, values: [String]) {
        /* TODO: Implement me... */
    }

    open func dtdEnd(parser: SAXParser<H>) {
        /* TODO: Implement me... */
    }

    open func cdataSection(parser: SAXParser<H>, content: String) {
        /* TODO: Implement me... */
    }

    open func text(parser: SAXParser<H>, content: String) {
        /* TODO: Implement me... */
    }

    open func comment(parser: SAXParser<H>, comment: String) {
        /* TODO: Implement me... */
    }

    open func processingInstruction(parser: SAXParser<H>, target: String, data: String) {
        /* TODO: Implement me... */
    }

    open func elementBegin(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?, namespaces: [String: String], attributes: [SAXParsedAttribute]) {
        /* TODO: Implement me... */
    }

    open func elementEnd(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?) {
        /* TODO: Implement me... */
    }

    open func entityReference(parser: SAXParser<H>, name: String) -> SAXParsedEntity? {
        fatalError("entityReference(parser:name:) has not been implemented")
        /* TODO: Implement me... */
    }

    open func resolveEntity(parser: SAXParser<H>, publicId: String?, systemId: String) -> InputStream? {
        fatalError("resolveEntity(parser:publicId:systemId:) has not been implemented")
        /* TODO: Implement me... */
    }

    open func parseErrorOccurred(parser: SAXParser<H>, error: Error) {
        /* TODO: Implement me... */
    }

    open func validationErrorOccurred(parser: SAXParser<H>, error: Error) {
        /* TODO: Implement me... */
    }

    open func warningOccurred(parser: SAXParser<H>, warning: Error) {
        /* TODO: Implement me... */
    }

    open func documentEnd(parser: SAXParser<H>) {
        /* TODO: Implement me... */
    }
}
