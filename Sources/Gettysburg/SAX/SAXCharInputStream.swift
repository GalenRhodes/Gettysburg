/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 13, 2021
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
import Rubicon

public protocol SAXCharInputStream: SimpleCharInputStream {
    var baseURL:     URL { get }
    var filename:    String { get }
    var docPosition: DocPosition { get }
    var markCount:   Int { get }

    func markSet()

    func markRelease()

    func markReturn()

    func markUpdate()

    func markBackup(count: Int) -> Int
}

public class SAXIConvCharInputStream: SAXCharInputStream {
    //@f:0
    public private(set)      var docPosition:       DocPosition
    public private(set) lazy var baseURL:           URL           = { docPosition.url.baseURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true) }()
    public private(set) lazy var filename:          String        = { docPosition.url.lastPathComponent }()
    public                   var markCount:         Int           = 0
    public                   var isEOF:             Bool          { (buffer.isNotEmpty && inputStream.isEOF) }
    public                   var hasCharsAvailable: Bool          { (buffer.isNotEmpty || inputStream.hasCharsAvailable) }
    public                   var encodingName:      String        { (inputStream.encodingName) }
    public                   var streamError:       Error?        { error }
    public                   var streamStatus:      Stream.Status { ((error == nil) ? status : .error) }

    private let inputStream: SimpleIConvCharInputStream
    private var status:      Stream.Status              = .notOpen
    private var error:       Error?                     = nil
    private var buffer:      [Character]                = []
    //@f:1

    public init(inputStream: InputStream, url: URL? = nil, tabSize: Int8 = 4) throws {
        let u = (url ?? bogusURL())

        let enc = try getEncodingName(url: u)
        guard let byteStream = InputStream(url: u) else { throw StreamError.FileNotFound(description: u.absoluteString) }

        self.inputStream = SimpleIConvCharInputStream(inputStream: byteStream, encodingName: enc)
        self.docPosition = DocPosition(url: u, line: 1, column: 1, tabSize: tabSize)
    }

    public func markSet() {}

    public func markRelease() {}

    public func markReturn() {}

    public func markUpdate() {}

    public func markBackup(count: Int) -> Int { fatalError("markBackup(count:) has not been implemented") }

    public func read() throws -> Character? { fatalError("read() has not been implemented") }

    public func peek() throws -> Character? { fatalError("peek() has not been implemented") }

    public func append(to chars: inout [Character], maxLength: Int) throws -> Int { fatalError("append(to:maxLength:) has not been implemented") }

    public func open() {}

    public func close() {}

    public func lock() {}

    public func unlock() {}

    public func withLock<T>(_ body: () throws -> T) rethrows -> T { fatalError("withLock(_:) has not been implemented") }
}
