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
import CoreFoundation
import Rubicon
#if os(Windows)
    import WinSDK
#endif

public protocol SAXHandler {

    func documentBegin<H>(parser: SAXParser<H>, version: String?, encoding: String?, standAlone: Bool?) where H: SAXHandler

    func dtdInternalBegin<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler

    func dtdExternalBegin<H>(parser: SAXParser<H>, rootElementName: String, type: SAXParser<H>.DTDExternalType, externalId: String?, systemId: String) where H: SAXHandler

    func dtdExternalEntityDecl<H>(parser: SAXParser<H>, name: String, entityType: SAXParser<H>.DTDEntityType, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String) where H: SAXHandler

    func dtdEntityDecl<H>(parser: SAXParser<H>, name: String, entityType: SAXParser<H>.DTDEntityType, content: String) where H: SAXHandler

    func dtdUnparsedEntityDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String, notation: String) where H: SAXHandler

    func dtdNotationDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String) where H: SAXHandler

    func dtdElementDecl<H>(parser: SAXParser<H>, name: String, allowedContent: DTDElementContent) where H: SAXHandler

    func dtdAttrDecl<H>(parser: SAXParser<H>, elementName: String, attrName: String, type: SAXParser<H>.DTDAttrType, defaultType: SAXParser<H>.DTDAttrRequirementType, defaultValue: String?, values: [String]) where H: SAXHandler

    func dtdExternalEnd<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler

    func dtdInternalEnd<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler

    func cdataSection<H>(parser: SAXParser<H>, content: String) where H: SAXHandler

    func text<H>(parser: SAXParser<H>, content: String, isWhitespace: Bool) where H: SAXHandler

    func comment<H>(parser: SAXParser<H>, comment: String) where H: SAXHandler

    func processingInstruction<H>(parser: SAXParser<H>, target: String, data: String) where H: SAXHandler

    func elementBegin<H>(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?, namespaces: [String: String], attributes: [SAXParsedAttribute]) where H: SAXHandler

    func elementEnd<H>(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?) where H: SAXHandler

    func entityReference<H>(parser: SAXParser<H>, name: String) -> SAXParsedEntity? where H: SAXHandler

    func resolveEntity<H>(parser: SAXParser<H>, publicId: String?, systemId: String) -> InputStream? where H: SAXHandler

    func parseErrorOccurred<H>(parser: SAXParser<H>, error: Error) where H: SAXHandler

    func validationErrorOccurred<H>(parser: SAXParser<H>, error: Error) where H: SAXHandler

    func warningOccurred<H>(parser: SAXParser<H>, warning: Error) where H: SAXHandler

    func documentEnd<H>(parser: SAXParser<H>) where H: SAXHandler
}
