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
    /*===========================================================================================================================================================================*/
    /// Returns `true` if the URL has a scheme. Otherwise it's not normalized.
    ///
    @inlinable public var isNormalized: Bool { (scheme != nil) }

    /*===========================================================================================================================================================================*/
    /// If a URL does not have a scheme then attempt to normalize it by making it relative to a given base URL. If a base URL is not given then the current working directory on
    /// the local filesystem is used.
    /// 
    /// - Parameter base: The base URL to use or `nil` to use the current working directory.
    /// - Returns: The normalized URL.
    /// - Throws: If the URL cannot be normalized or the given base URL is not normalized to begin with.
    ///
    public func normalize(relativeTo base: URL? = nil) throws -> URL {
        guard !isNormalized else { return try standardized.createBaseURL() }

        var strAbs = standardized.absoluteString

        if strAbs.hasPrefix("~/") { strAbs = "file://\(strAbs.standardizingPath)" }
        if strAbs.hasPrefix("/") { strAbs = "file://\(strAbs)" }

        guard let url = URL(string: strAbs, relativeTo: (base ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))) else {
            throw URLErrors.MalformedURL(description: strAbs)
        }

        return try url.createBaseURL()
    }

    /*===========================================================================================================================================================================*/
    /// This method gives the URL a base URL by separating the last path component from the rest of the path. So, for example, given the URL:
    /// ```
    ///     http://foo.bar.com/Users/jdoe/samples/document.xml?item=one#anAnchor
    /// ```
    /// This method will create a new URL object for `document.xml?item=one#anAnchor` that has a base URL of `http://foo.bar.com/Users/jdoe/samples/`. This is to make sure that
    /// the `baseURL` property returns a non-`nil` value.
    /// 
    /// - Returns: A new URL where the `baseURL` property does not return a `nil` value.
    /// - Throws: If the URL cannot be created.
    ///
    @inlinable public func createBaseURL() throws -> URL {
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
