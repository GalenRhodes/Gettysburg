/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: StringPos.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/16/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
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

public struct StringPos: Hashable, Comparable {
    public let string: String
    public let pos:    DocPosition

    public init(string: String, line: Int, column: Int) {
        self.string = string
        pos = (line, column)
    }

    public init(string: String, pos: DocPosition) {
        self.string = string
        self.pos = pos
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
        hasher.combine(pos.line)
        hasher.combine(pos.column)
    }

    public static func == (lhs: StringPos, rhs: String) -> Bool { lhs.string == rhs }

    public static func == (lhs: String, rhs: StringPos) -> Bool { lhs == rhs.string }

    public static func == (lhs: StringPos, rhs: StringPos) -> Bool { ((lhs.pos.line == rhs.pos.line) && (lhs.pos.column == rhs.pos.column)) }

    public static func < (lhs: StringPos, rhs: StringPos) -> Bool { ((lhs.pos.line < rhs.pos.line) || ((lhs.pos.line == rhs.pos.line) && (lhs.pos.column < rhs.pos.column))) }
}
