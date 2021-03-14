/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXHandler.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
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

public protocol SAXHandler {
    func beginDocument(_ parser: SAXParser)

    func endDocument(_ parser: SAXParser)

    func dtdInternalDocType(_ parser: SAXParser, elementName elemName: String)

    func dtdExternalDocType(_ parser: SAXParser, elementName elemName: String, publicId: String?, systemId: String)

    func dtdInternalEntityDecl(_ parser: SAXParser, name: String, type: SAXEntityType, content: String)

    func dtdExternalEntityDecl(_ parser: SAXParser, name: String, type: SAXEntityType, publicId: String?, systemId: String)

    func dtdUnparsedEntityDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String, notation: String)

    func dtdNotationDecl(_ parser: SAXParser, name: String, publicId: String?, systemId: String?)

    func dtdElementDecl(_ parser: SAXParser, name: String, allowedContent: SAXElementAllowedContent, content: SAXDTDElementContentList?)

    func dtdAttributeDecl(_ parser: SAXParser, name: String, elementName: String, type: SAXAttributeType, enumList: [String], defaultType: SAXAttributeDefaultType, defaultValue: String?)

    func comment(_ parser: SAXParser, content: String, continued: Bool)

    func text(_ parser: SAXParser, content: String, continued: Bool)

    func cdataSection(_ parser: SAXParser, content: String, continued: Bool)

    func resolveEntity(_ parser: SAXParser, publicId: String?, systemId: String) -> InputStream

    func beginPrefixMapping(_ parser: SAXParser, mapping: NSMapping)

    func endPrefixMapping(_ parser: SAXParser, prefix: String)

    func beginElement(_ parser: SAXParser, name: SAXNSName, attributes: [SAXAttribute])

    func endElement(_ parser: SAXParser, name: SAXNSName)

    func getEntity(_ parser: SAXParser, name: String) -> SAXEntity?

    func getParameterEntity(_ parser: SAXParser, name: String) -> SAXEntity?

    func processingInstruction(_ parser: SAXParser, target: String, data: String)

    func handleError(_ parser: SAXParser, error: Error)
}
