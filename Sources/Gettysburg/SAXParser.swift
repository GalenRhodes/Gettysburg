/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 10, 2021
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
import Chadakoin

open class SAXParser {
    //@f:0
    public var url:                URL          { lock.withLock { inputStream.docPosition.url      } }
    public var baseURL:            URL          { lock.withLock { inputStream.baseURL              } }
    public var filename:           String       { lock.withLock { inputStream.filename             } }
    public var docPosition:        TextPosition { lock.withLock { inputStream.docPosition.position } }
    public var delegate:           SAXDelegate? { lock.withLock { _delegates.last                  } }

    public var allowedURIPrefixes: [String]     { get { lock.withLock { _allowedURIPrefixes } } set { lock.withLock { _allowedURIPrefixes = newValue } } }

    let lock:        Conditional        = Conditional()
    var inputStream: SAXCharInputStream
    //@f:1

    public init(url: URL, tabSize: Int8 = 4, delegate: SAXDelegate? = nil, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil) throws {
        inputStream = try SAXIConvCharInputStream(url: url, tabSize: tabSize, options: options, authenticate: authenticate)
    }

    public init(fileAtPath path: String, tabSize: Int8 = 4, delegate: SAXDelegate? = nil) throws {
        inputStream = try SAXIConvCharInputStream(fileAtPath: path, tabSize: tabSize)
    }

    public init(data: Data, url: URL? = nil, tabSize: Int8 = 4, delegate: SAXDelegate? = nil) throws {
        inputStream = try SAXIConvCharInputStream(data: data, url: url, tabSize: tabSize)
    }

    public init(string: String, url: URL? = nil, tabSize: Int8 = 4, delegate: SAXDelegate? = nil) {
        inputStream = SAXStringCharInputStream(string: string, url: url, tabSize: tabSize)
    }

    private var _allowedURIPrefixes: [String]      = []
    private var _delegates:          [SAXDelegate] = []
}
