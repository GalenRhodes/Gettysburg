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
import CoreFoundation
import Rubicon
#if os(Windows)
    import WinSDK
#endif

internal let NULL = "⏚"

open class SAXDefaultHandler: SAXHandler {
    public func documentBegin<H>(parser: SAXParser<H>, version: String?, encoding: String?, standAlone: Bool?) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdInternalBegin<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdExternalBegin<H>(parser: SAXParser<H>, rootElementName: String, type: SAXParser<H>.DTDExternalType, externalId: String?, systemId: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdEntityDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDEntityType, publicId: String?, systemId: String?, content: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdUnparsedEntityDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String, notation: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdNotationDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdElementDecl<H>(parser: SAXParser<H>, name: String, allowedContent: DTDElementContent) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdAttrDecl<H>(parser: SAXParser<H>, elementName: String, attrName: String, type: SAXParser<H>.DTDAttrType, defaultType: SAXParser<H>.DTDAttrRequirementType, defaultValue: String?, values: [String]) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdExternalEnd<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func dtdInternalEnd<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func cdataSection<H>(parser: SAXParser<H>, content: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func text<H>(parser: SAXParser<H>, content: String, isWhitespace: Bool) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func comment<H>(parser: SAXParser<H>, comment: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func processingInstruction<H>(parser: SAXParser<H>, target: String, data: String) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func elementBegin<H>(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?, namespaces: [String: String], attributes: [SAXParsedAttribute]) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func elementEnd<H>(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func entityReference<H>(parser: SAXParser<H>, name: String) -> SAXParsedEntity? where H: SAXHandler {
        fatalError("entityReference(parser:name:) has not been implemented")
        /* TODO: Implement me... */
    }

    public func resolveEntity<H>(parser: SAXParser<H>, publicId: String?, systemId: String) -> InputStream? where H: SAXHandler {
        fatalError("resolveEntity(parser:publicId:systemId:) has not been implemented")
        /* TODO: Implement me... */
    }

    public func parseErrorOccurred<H>(parser: SAXParser<H>, error: Error) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func validationErrorOccurred<H>(parser: SAXParser<H>, error: Error) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func warningOccurred<H>(parser: SAXParser<H>, warning: Error) where H: SAXHandler {
        /* TODO: Implement me... */
    }

    public func documentEnd<H>(parser: SAXParser<H>) where H: SAXHandler {
        /* TODO: Implement me... */
    }
}
