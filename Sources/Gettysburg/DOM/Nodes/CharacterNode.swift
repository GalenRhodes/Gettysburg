/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: CharacterNode.swift
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

open class CharacterNode: ChildNode {
    //@f:0
    public          var data:        String
    public override var nodeValue:   String? { get { data } set { data = ((newValue == nil) ? "" : newValue!) } }
    public override var textContent: String  { get { data } set { data = newValue } }
    //@f:1

    init(ownerDocument: DocumentNode, content: String) {
        data = content
        super.init(ownerDocument: ownerDocument)
    }

    public override func isEqualTo(_ other: Node) -> Bool {
        guard let o = (other as? CharacterNode) else { return false }
        return data == o.data
    }

    public override func hash(into hasher: inout Hasher) { hasher.combine(data) }
}

open class CommentNode: CharacterNode {
    public override var nodeType: NodeTypes { .Comment }

    override init(ownerDocument: DocumentNode, content: String) { super.init(ownerDocument: ownerDocument, content: content) }
}

open class TextNode: CharacterNode {
    public override var nodeType: NodeTypes { .Text }

    override init(ownerDocument: DocumentNode, content: String) { super.init(ownerDocument: ownerDocument, content: content) }
}

open class CDataSectionNode: TextNode {
    public override var nodeType: NodeTypes { .CDataSection }

    override init(ownerDocument: DocumentNode, content: String) { super.init(ownerDocument: ownerDocument, content: content) }
}
