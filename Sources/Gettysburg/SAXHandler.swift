/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXHandler.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/14/21
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

public protocol SAXHandler {
    associatedtype H: SAXHandler

    func documentBegin(parser: SAXParser<H>, version: String?, encoding: String?, standAlone: Bool?)

    func dtdInternalBegin(parser: SAXParser<H>, rootElementName: String)

    func dtdExternalBegin(parser: SAXParser<H>, rootElementName: String, type: SAXParser<H>.DTDExternalType, externalId: String?, systemId: String)

    func dtdEntityDecl(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDEntityType, publicId: String?, systemId: String?, content: String)

    func dtdUnparsedEntityDecl(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String, notation: String)

    func dtdNotationDecl(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String)

    func dtdElementDecl(parser: SAXParser<H>, name: String, allowedContent: DTDElementContent)

    func dtdAttrDecl(parser: SAXParser<H>, elementName: String, attrName: String, type: SAXParser<H>.DTDAttrType, defaultType: SAXParser<H>.DTDAttrDefaultType, defaultValue: String?, values: [String])

    func dtdEnd(parser: SAXParser<H>)

    func cdataSection(parser: SAXParser<H>, content: String)

    func text(parser: SAXParser<H>, content: String)

    func comment(parser: SAXParser<H>, comment: String)

    func processingInstruction(parser: SAXParser<H>, target: String, data: String)

    func elementBegin(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?, namespaces: [String: String], attributes: [SAXParsedAttribute])

    func elementEnd(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?)

    func entityReference(parser: SAXParser<H>, name: String) -> SAXParsedEntity?

    func resolveEntity(parser: SAXParser<H>, publicId: String?, systemId: String) -> InputStream?

    func parseErrorOccurred(parser: SAXParser<H>, error: Error)

    func validationErrorOccurred(parser: SAXParser<H>, error: Error)

    func warningOccurred(parser: SAXParser<H>, warning: Error)

    func documentEnd(parser: SAXParser<H>)
}
