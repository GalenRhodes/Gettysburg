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
    open override var nodeName:     String { nsName.name.description }
    open override var namespaceURI: String? { nsName.uri }
    open override var localName:    String { nsName.name.localName }
    open override var prefix:       String? {
        get { nsName.name.prefix }
        set { nsName.name.prefix = newValue }
    }

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
}