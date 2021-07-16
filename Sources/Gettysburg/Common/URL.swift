/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: URL.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 15, 2021
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

public enum URLErrors: Error {
    case MalformedURL(description: String)
}

extension URL {
    @inlinable public var isRelative: Bool { (scheme == nil) }

    public func normalize(relativeTo base: URL? = nil) throws -> URL {
        guard scheme == nil else { return try standardized._makeRelative() }

        var strAbs = standardized.absoluteString

        if strAbs.hasPrefix("~/") { strAbs = "file://\(strAbs.standardizingPath)" }
        if strAbs.hasPrefix("/") { strAbs = "file://\(strAbs)" }

        guard let url = URL(string: strAbs, relativeTo: (base ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))) else {
            throw URLErrors.MalformedURL(description: strAbs)
        }

        return try url._makeRelative()
    }

    private func _makeRelative() throws -> URL {
        let s = (scheme ?? "")
        let h = (host ?? "")
        let p = (((port == nil) || (h == "")) ? "" : ":\(port!)")
        let d = path.deletingLastPathComponent
        let f = path.lastPathComponent
        let q = ((query == nil) ? "" : "?\(query!)")
        let a = ((fragment == nil) ? "" : "#\(fragment!)")

        guard let u = URL(string: "\(f)\(q)\(a)", relativeTo: URL(string: "\(s)://\(h)\(p)\(d)")) else { throw URLErrors.MalformedURL(description: absoluteString) }
        return u
    }
}
