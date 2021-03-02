/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTD.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/23/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

open class SAXDTD: Hashable {
    @inlinable public var entities:   [SAXDTDEntity] { _entities }
    @inlinable public var notations:  [SAXDTDNotation] { _notations }
    @inlinable public var attributes: [SAXDTDAttribute] { _attributes }
    @inlinable public var elements:   [SAXDTDElement] { _elements }

    @usableFromInline var _entities:   [SAXDTDEntity]    = []
    @usableFromInline var _notations:  [SAXDTDNotation]  = []
    @usableFromInline var _attributes: [SAXDTDAttribute] = []
    @usableFromInline var _elements:   [SAXDTDElement]   = []

    @usableFromInline init() {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_entities)
        hasher.combine(_notations)
        hasher.combine(_attributes)
        hasher.combine(_elements)
    }

    public static func == (lhs: SAXDTD, rhs: SAXDTD) -> Bool {
        if lhs === rhs { return true }
        if type(of: lhs) != type(of: rhs) { return false }
        return lhs._entities == rhs._entities && lhs._notations == rhs._notations && lhs._attributes == rhs._attributes && lhs._elements == rhs._elements
    }
}
