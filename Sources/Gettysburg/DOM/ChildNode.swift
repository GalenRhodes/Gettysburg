/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: ChildNode.swift
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

open class ChildNode: NodeImpl {
    var _nextSibling:     ChildNode?  = nil
    var _previousSibling: ChildNode?  = nil
    var _parentNode:      ParentNode? = nil

    public override var parentNode:      Node? { _parentNode }
    public override var nextSibling:     Node? { _nextSibling }
    public override var previousSibling: Node? { _previousSibling }

    override init(ownerDocument: DocumentNode) { super.init(ownerDocument: ownerDocument) }

    public override func isEqualTo(_ other: Node) -> Bool { super.isEqualTo(other) }

    public override func hash(into hasher: inout Hasher) { super.hash(into: &hasher) }
}
