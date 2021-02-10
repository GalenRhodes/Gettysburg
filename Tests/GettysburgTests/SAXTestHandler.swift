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

open class SAXTestHandler: SAXDefaultHandler {

    open override func documentBegin<H>(parser: SAXParser<H>, version: String?, encoding: String?, standAlone: Bool?) where H: SAXHandler {
        print("Begin Document: version = \"\(version ?? NULL)\"; encoding = \"\(encoding ?? NULL)\"; standAlone = \"\(standAlone ?? true)\"")
        super.documentBegin(parser: parser, version: version, encoding: encoding, standAlone: standAlone)
    }

    open override func dtdInternalBegin<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler {
        print("Begin Internal DTD: rootElementName = \"\(rootElementName)\"")
        super.dtdInternalBegin(parser: parser, rootElementName: rootElementName)
    }

    open override func dtdExternalBegin<H>(parser: SAXParser<H>, rootElementName: String, type: SAXParser<H>.DTDExternalType, externalId: String?, systemId: String) where H: SAXHandler {
        print("Begin External DTD: rootElementName = \"\(rootElementName)\"; type = \"\(type)\"; externalId = \"\(externalId ?? NULL)\"; systemId = \"\(systemId)\";")
        super.dtdExternalBegin(parser: parser, rootElementName: rootElementName, type: type, externalId: externalId, systemId: systemId)
    }

    public override func dtdExternalEntityDecl<H>(parser: SAXParser<H>, name: String, entityType: SAXParser<H>.DTDEntityType, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String) where H: SAXHandler {
        print("DTD External Entity Decl: name = \"\(name)\"; entityType = \"\(entityType)\"; type = \"\(type)\"; publicId = \"\(publicId ?? NULL)\"; systemId = \"\(systemId)\";")
        super.dtdExternalEntityDecl(parser: parser, name: name, entityType: entityType, type: type, publicId: publicId, systemId: systemId)
    }

    public override func dtdEntityDecl<H>(parser: SAXParser<H>, name: String, entityType: SAXParser<H>.DTDEntityType, content: String) where H: SAXHandler {
        print("DTD Entity Decl: name = \"\(name)\"; entityType = \"\(entityType)\"; content = \"\(content)\";")
        super.dtdEntityDecl(parser: parser, name: name, entityType: entityType, content: content)
    }

    open override func dtdUnparsedEntityDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String, notation: String) where H: SAXHandler {
        print("DTD Unparsed Entity Decl: name = \"\(name)\"; type = \"\(type)\"; publicId = \"\(publicId ?? NULL)\"; systemId = \"\(systemId)\"; notation = \"\(notation)\";")
        super.dtdUnparsedEntityDecl(parser: parser, name: name, type: type, publicId: publicId, systemId: systemId, notation: notation)
    }

    open override func dtdNotationDecl<H>(parser: SAXParser<H>, name: String, type: SAXParser<H>.DTDExternalType, publicId: String?, systemId: String) where H: SAXHandler {
        print("DTD Notation Decl: name = \"\(name)\"; type = \"\(type)\"; publicId = \"\(publicId ?? NULL)\"; systemId = \"\(systemId)\";")
        super.dtdNotationDecl(parser: parser, name: name, type: type, publicId: publicId, systemId: systemId)
    }

    open override func dtdElementDecl<H>(parser: SAXParser<H>, name: String, allowedContent: DTDElementContent) where H: SAXHandler {
        print("DTD Element Decl: name = \"\(name)\"; allowedContent = \"\(allowedContent)\";")
        super.dtdElementDecl(parser: parser, name: name, allowedContent: allowedContent)
    }

    open override func dtdAttrDecl<H>(parser: SAXParser<H>, elementName: String, attrName: String, type: SAXParser<H>.DTDAttrType, defaultType: SAXParser<H>.DTDAttrRequirementType, defaultValue: String?, values: [String]) where H: SAXHandler {
        print("DTD Attribute Decl: elementName = \"\(elementName)\"; attrName = \"\(attrName)\"; type = \"\(type)\";", terminator: "")
        print(" defaultType = \"\(defaultType)\"; defaultValue = \"\(defaultValue ?? NULL)\"; values = [", terminator: "")
        var f: Bool = true
        for s in values {
            if f { print(" \"\(s)\"", terminator: ""); f = false }
            else { print(", \"\(s)\"", terminator: "") }
        }
        print("\(f ? " " : "")];")
        super.dtdAttrDecl(parser: parser, elementName: elementName, attrName: attrName, type: type, defaultType: defaultType, defaultValue: defaultValue, values: values)
    }

    open override func dtdExternalEnd<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler {
        print("End External DTD: rootElementName = \"\(rootElementName)\";")
        super.dtdExternalEnd(parser: parser, rootElementName: rootElementName)
    }

    open override func dtdInternalEnd<H>(parser: SAXParser<H>, rootElementName: String) where H: SAXHandler {
        print("End Internal DTD: rootElementName = \"\(rootElementName)\";")
        super.dtdInternalEnd(parser: parser, rootElementName: rootElementName)
    }

    open override func cdataSection<H>(parser: SAXParser<H>, content: String) where H: SAXHandler {
        print("CData Section: content = \"\(content)\";")
        super.cdataSection(parser: parser, content: content)
    }

    open override func text<H>(parser: SAXParser<H>, content: String, isWhitespace: Bool) where H: SAXHandler {
        print("Text: isWhitespace = \(isWhitespace); content = \"\(content)\";")
        super.text(parser: parser, content: content, isWhitespace: isWhitespace)
    }

    open override func comment<H>(parser: SAXParser<H>, comment: String) where H: SAXHandler {
        print("Comment: comment = \"\(comment)\";")
        super.comment(parser: parser, comment: comment)
    }

    open override func processingInstruction<H>(parser: SAXParser<H>, target: String, data: String) where H: SAXHandler {
        print("Processing Instruction: target = \"\(target)\"; data = \"\(data)\";")
        super.processingInstruction(parser: parser, target: target, data: data)
    }

    open override func elementBegin<H>(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?, namespaces: [String: String], attributes: [SAXParsedAttribute]) where H: SAXHandler {
        print("Begin Element: localName = \"\(localName)\"; prefix = \"\(prefix ?? NULL)\"; namespaceURI = \"\(namespaceURI ?? NULL)\"; namespaces = [", terminator: "")
        var f: Bool = true
        for (k, v): (String, String) in namespaces {
            if f { print(" \"\(k)\":\"\(v)\"", terminator: ""); f = false }
            else { print(", \"\(k)\":\"\(v)\"", terminator: "") }
        }
        print("\(f ? " " : "")]; attributes = [", terminator: "")
        f = true
        for a in attributes {
            if f { print(" \(a)", terminator: ""); f = false }
            else { print(", \(a)", terminator: "") }
        }
        print("\(f ? " " : "")];")
        super.elementBegin(parser: parser, localName: localName, prefix: prefix, namespaceURI: namespaceURI, namespaces: namespaces, attributes: attributes)
    }

    open override func elementEnd<H>(parser: SAXParser<H>, localName: String, prefix: String?, namespaceURI: String?) where H: SAXHandler {
        print("End Element: localName = \"\(localName)\"; prefix = \"\(prefix ?? NULL)\"; namespaceURI = \"\(namespaceURI ?? NULL)\";")
        super.elementEnd(parser: parser, localName: localName, prefix: prefix, namespaceURI: namespaceURI)
    }

    open override func entityReference<H>(parser: SAXParser<H>, name: String) -> SAXParsedEntity? where H: SAXHandler {
        print("Entity Reference: name = \"\(name)\";")
        return super.entityReference(parser: parser, name: name)
    }

    open override func resolveEntity<H>(parser: SAXParser<H>, publicId: String?, systemId: String) -> InputStream? where H: SAXHandler {
        print("Resolve Entity: publicId = \"\(publicId ?? NULL)\"; systemId = \"\(systemId)\";")
        return super.resolveEntity(parser: parser, publicId: publicId, systemId: systemId)
    }

    open override func parseErrorOccurred<H>(parser: SAXParser<H>, error: Error) where H: SAXHandler {
        print("Parse Error Occurred: error = \"\(error)\";")
        super.parseErrorOccurred(parser: parser, error: error)
    }

    open override func validationErrorOccurred<H>(parser: SAXParser<H>, error: Error) where H: SAXHandler {
        print("Validation Error Occurred: error = \"\(error)\";")
        super.validationErrorOccurred(parser: parser, error: error)
    }

    open override func warningOccurred<H>(parser: SAXParser<H>, warning: Error) where H: SAXHandler {
        print("Warning Occurred: warning = \"\(warning)\";")
        super.warningOccurred(parser: parser, warning: warning)
    }

    open override func documentEnd<H>(parser: SAXParser<H>) where H: SAXHandler {
        print("End Document")
        super.documentEnd(parser: parser)
    }
}
