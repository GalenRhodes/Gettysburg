/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: NonDocument.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 10/12/21
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

open class NonDocument: Node {
    open override var ownerDocument: DocumentNode {
        get { _ownerDocument }
        set {}
    }

    let _ownerDocument: DocumentNode

    public init(ownerDocument: DocumentNode) {
        self._ownerDocument = ownerDocument
        super.init()
    }

    public required init(from decoder: Decoder) throws {
        _ownerDocument = try decoder.container(keyedBy: CodingKeys.self).decode(DocumentNode.self, forKey: .OwnerDocument)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(_ownerDocument, forKey: .OwnerDocument)
        try super.encode(to: encoder)
    }
}
