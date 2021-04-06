/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Tools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
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

public typealias KVPair = (key: String, value: String)
public typealias XMLDeclData = (version: String?, encoding: String?, standalone: Bool?)

/*===============================================================================================================================================================================*/
/// Get a URL for the current working directory.
/// 
/// - Returns: the current working directory as a URL.
///
func GetCurrDirURL() -> URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true) }

/*===============================================================================================================================================================================*/
/// Get a URL for the given filename.  If the filename is relative it will be made absolute relative to the current working directory.
/// 
/// - Parameter filename: the filename.
/// - Returns: the filename as an absolute URL.
///
func GetFileURL(filename: String) -> URL { URL(fileURLWithPath: filename, relativeTo: GetCurrDirURL()) }

/*===============================================================================================================================================================================*/
/// Get a URL for it's given string form. The difference between this function and calling the <code>[foundation class
/// URL's](https://developer.apple.com/documentation/foundation/url)</code> constructor
/// <code>[`URL(string:)`](https://developer.apple.com/documentation/foundation/url/3126806-init)</code> is that this function will throw an error if the URL is malformed rather
/// than returning `nil` and if the URL is relative it will make it an absolute file URL relative to the current working directory.
/// 
/// - Parameter string: the string containing the URL.
/// - Returns: the URL.
/// - Throws: if the URL is malformed.
///
func GetURL(string: String) throws -> URL {
    guard let url = URL(string: string, relativeTo: GetCurrDirURL()) else { throw SAXError.MalformedURL(string) }
    return url
}

/*===============================================================================================================================================================================*/
/// Print out an array of strings to STDOUT. Used for debugging.
/// 
/// - Parameter strings: the array of strings.
///
func PrintArray(_ strings: [String?]) {
    #if DEBUG
        var idx = 0
        for s in strings {
            if let s = s { print("\(idx++)> \"\(s)\"") }
            else { print("\(idx++)> NIL") }
        }
    #endif
}

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Get a URL for it's given string form. The difference between this method and calling the <code>[foundation class
    /// URL's](https://developer.apple.com/documentation/foundation/url)</code> constructor
    /// <code>[`URL(string:)`](https://developer.apple.com/documentation/foundation/url/3126806-init)</code> is that this function will throw an error if the URL is malformed
    /// rather than returning `nil` and if the URL is relative it will make it absolute relative to the base URL of the current document being parsed.
    /// 
    /// - Parameter string: the string containing the URL.
    /// - Returns: the URL.
    /// - Throws: if the URL is malformed.
    ///
    func getParserURL(string: String, sourceCharStream chStream: SAXCharInputStream) throws -> URL {
        guard let url = URL(string: string, relativeTo: chStream.baseURL) else { throw SAXError.MalformedURL(charStream, url: string) }
        return url
    }

    /*===========================================================================================================================================================================*/
    /// Skip over the XML Declaration if it exists.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the same <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if an I/O error occurs.
    ///
    func skipOverXmlDeclaration(_ chStream: SAXCharInputStream) throws -> SAXCharInputStream {
        chStream.open()
        chStream.markSet()

        let str = try chStream.readString(count: 6)

        guard try str.matches(pattern: XML_DECL_PREFIX_PATTERN) else {
            chStream.markReturn()
            return chStream
        }

        chStream.markDelete()

        if var lch: Character = try chStream.read() {
            while let ch = try chStream.read() {
                if ch == ">" && lch == "?" { return chStream }
                lch = ch
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }
}

/*===============================================================================================================================================================================*/
/// Given a URL, get the Base URL and the filename.
/// 
/// - Parameter url: the URL.
/// - Returns: a tuple with the given URL, the Base URL, and the filename. If the given URL was relative then it is made absolute with respect to the current working directory.
/// - Throws: if the URL is malformed.
///
func GetBaseURLAndFilename(url: URL) throws -> (URL, URL, String) {
    let burl     = try GetURL(string: url.absoluteString)
    let baseURL  = burl.deletingLastPathComponent()
    let filename = burl.lastPathComponent
    return (burl, baseURL, filename)
}
