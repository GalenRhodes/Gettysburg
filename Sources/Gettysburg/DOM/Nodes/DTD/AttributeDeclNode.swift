/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: AttributeDeclNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/13/21
 *
 * Copyright © 2021. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *===============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

open class AttributeDeclNode: DTDElement {
    //@f:0
    public override var nodeType:     NodeTypes { .AttributeDecl }
    public          var elementName:  QName
    public          var type:         AttrType
    public          var defaultType:  DefaultType
    public          var defaultValue: String?
    public          var enumValues:   [String] = []
    //@f:1

    init(ownerDocument: DocumentNode?, qName: String, namespaceURI: String, elementName: String, type: AttrType, enumValues: [String], defaultType: DefaultType, defaultValue: String?) {
        self.type = type
        self.defaultType = defaultType
        self.defaultValue = defaultValue
        self.enumValues = enumValues
        self.elementName = QName(qName: elementName)
        super.init(ownerDocument: ownerDocument, qName: qName, namespaceURI: namespaceURI)
    }

    init(ownerDocument: DocumentNode?, name: String, elementName: String, type: AttrType, enumValues: [String], defaultType: DefaultType, defaultValue: String?) {
        self.type = type
        self.defaultType = defaultType
        self.defaultValue = defaultValue
        self.enumValues = enumValues
        self.elementName = QName(qName: elementName)
        super.init(ownerDocument: ownerDocument, name: name)
    }

    public enum AttrType: String, Codable {
        case CData      = "CDATA"
        case ID         = "ID"
        case IDRef      = "IDREF"
        case Entity     = "ENTITY"
        case Entities   = "ENTITIES"
        case NMToken    = "NMTOKEN"
        case NMTokens   = "NMTOKENS"
        case Notation   = "NOTATION"
        case Enumerated = "()"
    }

    public enum DefaultType: String, Codable {
        case Required = "#REQUIRED"
        case Implied  = "#IMPLIED"
        case Fixed    = "#FIXED"
    }
}
