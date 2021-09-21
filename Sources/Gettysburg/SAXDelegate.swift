/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXHandler.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided
 * that the above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*****************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

@frozen public struct SAXRawAttribute {
    public let name: QName
    public let value: String
}

public typealias SAXRawAttribList = [SAXRawAttribute]

public protocol SAXDelegate {
    func beginDocument(_ parser: SAXParser)

    func endDocument(_ parser: SAXParser)

    func beginDocType(_ parser: SAXParser, elementName: String)

    func endDocType(_ parser: SAXParser, elementName: String)

    func dtdInternal(_ parser: SAXParser, elementName: String)

    func dtdExternal(_ parser: SAXParser, elementName: String, publicId: String?, systemId: String)

    func dtdInternalEntityDecl(_ parser: SAXParser, name: String, content: String)

    func dtdExternalEntityDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String)

    func dtdUnparsedEntityDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String, notation: String)

    func dtdNotationDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String?)

    func dtdElementDecl(_ parser: SAXParser, name: String, allowedContent: ElementDeclNode.ContentList)

    func dtdAttributeDecl(_ parser: SAXParser, name: String, elementName: String, type: AttributeDeclNode.AttrType, defaultType: AttributeDeclNode.DefaultType, defaultValue: String?)

    func comment(_ parser: SAXParser, content: String)

    func text(_ parser: SAXParser, content: String)

    func cdataSection(_ parser: SAXParser, content: String)

    func resolveEntity(_ parser: SAXParser, publicId: String?, systemId: String) -> InputStream?

    func beginPrefixMapping(_ parser: SAXParser, mapping: NSMapping)

    func endPrefixMapping(_ parser: SAXParser, prefix: String)

    func beginElement(_ parser: SAXParser, name: NSName, attributes: SAXRawAttribList)

    func endElement(_ parser: SAXParser, name: NSName)

    func getEntity(_ parser: SAXParser, name: String) -> Any?

    func getParameterEntity(_ parser: SAXParser, name: String) -> Any?

    func processingInstruction(_ parser: SAXParser, target: String, data: String)

    func handleError(_ parser: SAXParser, error: Error) -> Bool
}

extension SAXRawAttribute: Hashable, Comparable {
    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(value)
    }

    @inlinable public static func < (lhs: SAXRawAttribute, rhs: SAXRawAttribute) -> Bool { ((lhs.name < rhs.name) || ((lhs.name == rhs.name) && (lhs.value < rhs.value))) }

    @inlinable public static func == (lhs: SAXRawAttribute, rhs: SAXRawAttribute) -> Bool { ((lhs.name == rhs.name) && (lhs.value == rhs.value)) }
}
