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

public class NodeMap<T>: BidirectionalCollection, Hashable, Codable where T: Node {

    public typealias Index = Int
    public typealias Element = T

    public var startIndex: Int { nodes.startIndex }
    public var endIndex:   Int { nodes.endIndex }

    private var nodes: [T] = []

    init() {}

    public required init(from decoder: Decoder) throws {
        var l = try decoder.unkeyedContainer()
        while !l.isAtEnd { nodes <+ try l.decode(T.self) }
    }

    public subscript(position: Int) -> T { nodes[position] }
    public subscript(nodeName: String) -> T? { first { $0.nodeName == nodeName } }
    public subscript(localName: String, namespaceURI: String) -> T? { first { $0.localName == localName && $0.namespaceURI == namespaceURI } }

    public func index(before i: Int) -> Int { nodes.index(before: i) }

    public func index(after i: Int) -> Int { nodes.index(after: i) }

    public func encode(to encoder: Encoder) throws {
        var l = encoder.unkeyedContainer()
        try forEach { try l.encode($0) }
    }

    public func hash(into hasher: inout Hasher) { forEach { hasher.combine($0) } }

    public static func == (lhs: NodeMap<T>, rhs: NodeMap<T>) -> Bool {
        if lhs === rhs { return true }
        guard lhs.count == rhs.count else { return false }
        for i in (0 ..< lhs.count) { guard rhs.firstIndex(where: { $0 == lhs[i] }) != nil else { return false } }
        return true
    }
}
