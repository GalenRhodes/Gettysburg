/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: DTDElement.swift
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

open class DTDElement: NodeImpl {
    //@f:0
    public override var nodeName:     String  { name.name.description }
    public override var localName:    String  { name.name.localName }
    public override var prefix:       String? { get { name.name.prefix } set { name.name.prefix = newValue } }
    public override var namespaceURI: String? { name.uri }

    public internal(set) var internalSubset: String              = ""
    public internal(set) var entities:       [EntityDeclNode]    = []
    public internal(set) var notations:      [NotationNode]      = []
    public internal(set) var elements:       [ElementDeclNode]   = []
    public internal(set) var attrs:          [AttributeDeclNode] = []
    public internal(set) var name:           NSName
    public internal(set) var publicId:       String?
    public internal(set) var systemId:       String?
    //@f:1

    init(ownerDocument: DocumentNode?, name: String, namespaceURI uri: String? = nil, publicId: String? = nil, systemId: String? = nil) {
        self.name = NSName(qName: name, uri: uri)
        super.init(ownerDocument: ownerDocument)
    }
}
