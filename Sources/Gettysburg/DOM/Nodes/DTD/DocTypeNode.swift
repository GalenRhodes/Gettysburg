/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeNode.swift
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

open class DocTypeNode: ChildNode {
    //@f:0
    public override      var nodeType:       NodeTypes           { .DocType }
    public internal(set) var internalSubset: String              = ""
    public internal(set) var entities:       [EntityDeclNode]    = []
    public internal(set) var notations:      [NotationNode]      = []
    public internal(set) var elements:       [ElementDeclNode]   = []
    public internal(set) var attrs:          [AttributeDeclNode] = []
    public internal(set) var name:           NSName
    public internal(set) var publicId:       String?
    public internal(set) var systemId:       String?
    //@f:1

    init(ownerDocument: DocumentNode?, name: String, publicId: String?, systemId: String?, internalSubset: String) {
        self.name = NSName(name: name)
        self.internalSubset = internalSubset
        self.publicId = publicId
        self.systemId = systemId
        super.init(ownerDocument: ownerDocument)
    }

    init(ownerDocument: DocumentNode?, qName: String, namespaceURI: String, publicId: String?, systemId: String?, internalSubset: String) {
        self.name = NSName(qName: qName, uri: namespaceURI)
        self.internalSubset = internalSubset
        self.publicId = publicId
        self.systemId = systemId
        super.init(ownerDocument: ownerDocument)
    }
}
