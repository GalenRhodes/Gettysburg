/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Utils.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 11, 2021
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

public let FileMan: FileManager = FileManager.default

@inlinable public func < <T>(lhs: T?, rhs: T?) -> Bool where T: Comparable {
    if let lhs = lhs, let rhs = rhs { return lhs < rhs }
    if lhs == nil && rhs == nil { return false }
    return lhs == nil
}

@inlinable public func == <C1, C2>(lhs: C1, rhs: C2) -> Bool where C1: Collection, C2: Collection, C1.Element == C2.Element, C1.Element: Equatable {
    guard lhs.count == rhs.count else { return false }
    var lIdx = lhs.startIndex
    var rIdx = rhs.startIndex

    while lIdx < lhs.endIndex {
        guard lhs[lIdx] == rhs[rIdx] else { return false }
        lhs.formIndex(after: &lIdx)
        rhs.formIndex(after: &rIdx)
    }

    return true
}
