/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DOMText.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 12, 2021
 *
  * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided
 * that the above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*****************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public class DOMText: DOMNode {
    public override var nodeType: NodeType { .Text }

    public override var textContent: String {
        get { _content }
        set { _content = newValue }
    }

    var _content: String

    init(owningDocument: DOMDocument, name: String, content: String) {
        _content = content
        super.init(owningDocument: owningDocument, qName: name)
    }

    convenience init(owningDocument: DOMDocument, content: String) { self.init(owningDocument: owningDocument, name: "#text", content: content) }
}

public class DOMCData: DOMText {
    public override var nodeType: NodeType { .CData }

    convenience init(owningDocument: DOMDocument, content: String) { self.init(owningDocument: owningDocument, name: "#cdata-section", content: content) }
}

public class DOMComment: DOMText {
    public override var nodeType: NodeType { .Comment }

    convenience init(owningDocument: DOMDocument, content: String) { self.init(owningDocument: owningDocument, name: "#comment", content: content) }
}
