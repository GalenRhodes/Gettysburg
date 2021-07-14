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
        let u: URL
        if let url = url { u = URL(string: url.absoluteString, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))! }
        else { u = bogusURL() }
        self.docPosition = DocPosition(url: u, line: 1, column: 1, tabSize: tabSize)
        let results = try getEncodingName(url: u)
        self.inputStream = SimpleIConvCharInputStream(inputStream: results.1, encodingName: results.0, autoClose: true)
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

func getEncodingName(url: URL) throws -> (String, InputStream) {
    guard let byteStream = MarkInputStream(url: url) else { throw StreamError.FileNotFound(description: url.absoluteString) }
    byteStream.open()

    do {
        byteStream.markSet()
        defer { byteStream.markDelete() }

        var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 4)

        let res = byteStream.read(&bytes, maxLength: 4)
        if res < 0 { throw byteStream.streamError ?? StreamError.UnknownError() }
        if res < 4 { throw StreamError.UnexpectedEndOfInput() }

        if bytes == [ 0x00, 0x00, 0xfe, 0xff ] { return ("UTF-32BE", byteStream) }
        if bytes == [ 0xff, 0xfe, 0x00, 0x00 ] { return ("UTF-32LE", byteStream) }
        if bytes == [ 0xdd, 0x73, 0x66, 0x73 ] { return ("UTF-EBCDIC", byteStream) }
        if bytes == [ 0x84, 0x31, 0x95, 0x33 ] { return ("GB-18030", byteStream) }
        _ = byteStream.markBackup()
        if bytes[0 ..< 3] == [ 0xef, 0xbb, 0xbf ] { return ("UTF-8", byteStream) }
        if bytes[0 ..< 3] == [ 0x2b, 0x2f, 0x76 ] { return ("UTF-7", byteStream) }
        if bytes[0 ..< 3] == [ 0xf7, 0x64, 0x4c ] { return ("UTF-1", byteStream) }
        if bytes[0 ..< 3] == [ 0x0E, 0xFE, 0xFF ] { return ("SCSU", byteStream) }
        if bytes[0 ..< 3] == [ 0xFB, 0xEE, 0x28 ] { return ("BOCU-1", byteStream) }
        _ = byteStream.markBackup()
        if bytes[0 ..< 2] == [ 0xfe, 0xff ] { return ("UTF-16BE", byteStream) }
        if bytes[0 ..< 2] == [ 0xff, 0xfe ] { return ("UTF-16LE", byteStream) }
        byteStream.markReset()

        // We'll do this the hard way.  We'll start out assuming UTF-8
        do {
            defer { byteStream.markReset() }
            let charStream = SimpleIConvCharInputStream(inputStream: byteStream, encodingName: "UTF-8", autoClose: false)
            charStream.open()
            defer { charStream.close() }

            var buffer: [Character] = []

            guard try charStream.read(chars: &buffer, maxLength: 5) == 5 else { throw StreamError.UnexpectedEndOfInput() }
            guard String(buffer).lowercased() == "<?xml" else { return ("UTF-8", byteStream) }

            while let ch = try charStream.read() {
                buffer <+ ch
                if buffer.last(count: 2) == [ "?", ">" ] {
                    let decl = String(buffer)
                    if RegularExpression(pattern: "^\\<\\?xml\\s")?.firstMatch(in: decl) != nil {
                        if let m = RegularExpression(pattern: "\\sencoding=((?:\"[^\"]+\")|(?:'[^']+'))(?:\\s|\\?)")?.firstMatch(in: decl), let enc = m[1].subString {
                            return (enc, byteStream)
                        }
                    }
                    // This is the default case...
                    return ("UTF-8", byteStream)
                }
            }

            throw StreamError.UnexpectedEndOfInput()
        }
    }
    catch let err {
        byteStream.close()
        throw err
    }
}
