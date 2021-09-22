/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: DocumentNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/11/21
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

open class DocumentNode: NodeImpl {
    //@f:0
    public override var nodeType:      NodeTypes    { .Document }
    public override var ownerDocument: DocumentNode { self      }
    public          var strict:        Bool         = false

    private         let uuid:          String       = UUID().uuidString
    //@f:1

    public override init() { super.init() }

    public override func isEqualTo(_ other: Node) -> Bool { self === other }

    public override func hash(into hasher: inout Hasher) { hasher.combine(uuid) }

    public override func cloneNode(deep: Bool) -> Self { super.cloneNode(deep: deep) }
}
