/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: NamedNodes.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 10/19/21
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

open class NamedNodes: NonDocument {
//@f:0
    open override               var nodeName:     String  { nsName.description }
    open override               var prefix:       String? { get { nsName.prefix }    set { nsName.prefix = newValue }    }
    open internal(set) override var localName:    String  { get { nsName.localName } set { nsName.localName = newValue } }
    open internal(set) override var namespaceURI: String? { get { nsName.uri }       set { nsName.uri = newValue }       }
//@f:1

    var nsName: NSName

    init(ownerDocument: DocumentNode, qualifiedName: String, namespaceURI: String? = nil) throws {
        if let uri = namespaceURI {
            nsName = NSName(qName: qualifiedName, namespaceURI: uri)
        }
        else {
            nsName = NSName(name: qualifiedName)
        }
        super.init(ownerDocument: ownerDocument)
    }

    public override func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(namespaceURI, forKey: .namespaceURI)
        try c.encodeIfPresent(prefix, forKey: .prefix)
        try c.encode(localName, forKey: .localName)
        try c.encode(nodeName, forKey: .nodeName)
        try super.encode(to: encoder)
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let l = try c.decode(String.self, forKey: .localName)
        let p = try c.decodeIfPresent(String.self, forKey: .prefix)
        let u = try c.decodeIfPresent(String.self, forKey: .namespaceURI)
        nsName = NSName(localName: l, prefix: p, namespaceURI: u)
        try super.init(from: decoder)
    }
}
