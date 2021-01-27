/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXTools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/27/21
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
#if os(Windows)
    import WinSDK
#endif

/*===============================================================================================================================================================================*/
/// Compares the suffix array to the end of the source array to see if they are the same.
///
/// - Parameters:
///   - sfx: the suffix array.
///   - src: the source array.
/// - Returns: `true` if the last sfx.count elements of the source array are the same as the suffix array. If the length of the source array (src.count) is less than the length of
///            the suffix array (sfx.count) then the return value will be `false`.
///
@inlinable func cmpSuffix<T: Equatable>(suffix sfx: [T], source src: [T]) -> Bool {
    let mcount = sfx.count
    let ccount = src.count
    let q      = (ccount - mcount)
    guard ccount >= mcount else { return false }
    for x: Int in (0 ..< mcount) { guard sfx[x] == src[q + x] else { return false } }
    return true
}

/*===============================================================================================================================================================================*/
/// Compares the prefix array to the beginning of the source array to see if they are the same.
///
/// - Parameters:
///   - pfx: the prefix array.
///   - src: the source array.
/// - Returns: `true` if the last pfx.count elements of the source array are the same as the prefix array. If the length of the source array (src.count) is less than the length of
///            the prefix array (pfx.count) then the return value will be `false`.
///
@inlinable func cmpPrefix<T: Equatable>(prefix pfx: [T], source src: [T]) -> Bool {
    let cc = pfx.count
    guard src.count >= cc else { return false }
    for i in (0 ..< cc) { guard pfx[i] == src[i] else { return false } }
    return true
}
