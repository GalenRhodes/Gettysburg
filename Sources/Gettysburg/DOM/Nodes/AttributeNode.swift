/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: AttributeNode.swift
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

open class AttributeNode: NodeImpl {
    //@f:0
    public var name:        String { _name.name.description }
    public var value:       String
    public var isSpecified: Bool

    public override var nodeType:     NodeTypes { .Attribute }
    public override var nodeName:     String    { _name.name.description }
    public override var namespaceURI: String?   { _name.uri }
    public override var localName:    String    { _name.name.localName }
    public override var prefix:       String?   { get { _name.name.prefix } set { _name.name.prefix = newValue } }
    public override var textContent:  String    { get { value } set { value = newValue } }
    public override var nodeValue:    String?   { get { value } set { value = (newValue == nil ? "" : newValue!) } }

    private var _name: NSName
    //@f:1

    init(ownerDocument: DocumentNode?, name: NSName, value: String, isSpecified: Bool = true) {
        self._name = name
        self.value = value
        self.isSpecified = isSpecified
        super.init(ownerDocument: ownerDocument)
    }

    public override func cloneNode(deep: Bool) -> Self { super.cloneNode(deep: deep) as! Self }

    public override func isEqualTo(_ other: Node) -> Bool {
        guard let a = (other as? AttributeNode) else { return false }
        return name == a.name && value == a.value && isSpecified == a.isSpecified
    }

    public override func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(value)
        hasher.combine(isSpecified)
    }
}
