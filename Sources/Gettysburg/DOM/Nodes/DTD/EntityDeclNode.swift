/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: EntityDeclNode.swift
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

open class EntityDeclNode: DTDExternal {
    //@f:0
    public override var nodeType:      NodeTypes { .EntityDecl }
    public          var inputEncoding: String
    public          var notationName:  String?
    public          var xmlEncoding:   String?
    public          var xmlVersion:    String?
    public          var value:         String?
    //@f:1

    init(ownerDocument: DocumentNode?, qName: String, namespaceURI: String, value: String?, publicId: String?, systemId: String?, notationName: String?, inputEncoding: String, xmlEncoding: String?, xmlVersion: String?) {
        self.inputEncoding = inputEncoding
        self.notationName = notationName
        self.xmlEncoding = xmlEncoding
        self.xmlVersion = xmlVersion
        self.value = value
        super.init(ownerDocument: ownerDocument, qName: qName, namespaceURI: namespaceURI, publicId: publicId, systemId: systemId)
    }

    init(ownerDocument: DocumentNode?, name: String, value: String?, publicId: String?, systemId: String?, notationName: String?, inputEncoding: String, xmlEncoding: String?, xmlVersion: String?) {
        self.inputEncoding = inputEncoding
        self.notationName = notationName
        self.xmlEncoding = xmlEncoding
        self.xmlVersion = xmlVersion
        self.value = value
        super.init(ownerDocument: ownerDocument, name: name, publicId: publicId, systemId: systemId)
    }
}
