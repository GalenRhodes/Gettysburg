/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: NodeMap.swift
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

public typealias NodeMapElement = (nodeName: String, node: Node)

public protocol NodeMap: Hashable, BidirectionalCollection where Element == NodeMapElement, Index == Int {
    var isReadOnly: Bool { get }

    subscript(nodeName: String) -> Node? { get set }
}

struct EmptyNodeMap: NodeMap {

    let startIndex: Int  = 0
    let endIndex:   Int  = 0
    let isReadOnly: Bool = true

    subscript(nodeName: String) -> Node? {
        get { nil }
        set { fatalError("Node map is read-only.") }
    }

    subscript(position: Int) -> NodeMapElement { fatalError("Index out of bounds.") }

    func index(before i: Int) -> Int { fatalError("Index out of bounds.") }

    func index(after i: Int) -> Int { fatalError("Index out of bounds.") }

    func hash(into hasher: inout Hasher) { hasher.combine(2113) }

    static func == (lhs: EmptyNodeMap, rhs: EmptyNodeMap) -> Bool { true }
}
