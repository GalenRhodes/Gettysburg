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
    public var xmlVersion:         String       { lock.withLock { xmlDecl.version.rawValue         } }
    public var xmlEncoding:        String       { lock.withLock { xmlDecl.encoding                 } }
    public var xmlStandalone:      Bool         { lock.withLock { xmlDecl.standalone == .yes       } }
    public var docPosition:        TextPosition { lock.withLock { inputStream.docPosition.position } }

    public let delegate:           SAXDelegate
    public var allowedURIPrefixes: [String]     { get { lock.withLock { _allowedURIPrefixes } } set { lock.withLock { _allowedURIPrefixes = newValue } } }

    let lock:          MutexLock          = MutexLock()
    var alreadyParsed: Bool               = false
    var xmlDecl:       XMLDecl            = XMLDecl(version: .v1_0, encoding: "UTF-8", standalone: .yes)
    var inputStream:   SAXCharInputStream { _inputStreams.last! }
    //@f:1

    public init(url: URL, tabSize: Int8 = 4, delegate: SAXDelegate, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil) throws {
        self.delegate = delegate
        xmlDecl.encoding = _pushInputStream(inputStream: try SAXIConvCharInputStream(url: url, tabSize: tabSize, options: options, authenticate: authenticate)).encodingName
    }

    public init(fileAtPath path: String, tabSize: Int8 = 4, delegate: SAXDelegate) throws {
        self.delegate = delegate
        xmlDecl.encoding = _pushInputStream(inputStream: try SAXIConvCharInputStream(fileAtPath: path, tabSize: tabSize)).encodingName
    }

    public init(data: Data, url: URL? = nil, tabSize: Int8 = 4, delegate: SAXDelegate) throws {
        self.delegate = delegate
        xmlDecl.encoding = _pushInputStream(inputStream: try SAXIConvCharInputStream(data: data, url: url, tabSize: tabSize)).encodingName
    }

    public init(string: String, url: URL? = nil, tabSize: Int8 = 4, delegate: SAXDelegate) {
        self.delegate = delegate
        xmlDecl.encoding = _pushInputStream(inputStream: SAXStringCharInputStream(string: string, url: url, tabSize: tabSize)).encodingName
    }

    deinit {
        for s in _inputStreams { s.close() }
        _inputStreams.removeAll()
    }

    open func parse() throws {
        try lock.withLock {
            guard !alreadyParsed else { throw SAXError.AlreadyParsed() }
            alreadyParsed = true
        }
        do {
            if let xd = try XMLDecl(charStream: inputStream) { xmlDecl = xd }
        }
        catch let e {
            guard delegate.handleError(self, error: e) else { throw e }
        }
    }

    /// Process the document's XML Decl.
    ///
    /// - Throws: If an I/O error occurs or the XML Decl is malformed.
    ///
    func processXMLDecl() throws {
    }

    func processProcessingInstruction() throws {
        inputStream.markSet()
        defer { inputStream.markReturn() }

        var chars: [Character] = []
        let pos:   DocPosition = inputStream.docPosition

        guard (try inputStream.read(chars: &chars, maxLength: 3) == 3) && (chars[..<2] == [ "<", "?" ]) else { return }
        guard chars[2].isXmlNameStartChar else { inputStream.markBackup(); throw SAXError.MalformedProcInst(position: inputStream.docPosition, description: "Invalid character: \(chars[2])") }

        try readToEndOfProcInst(chars: &chars)

        let rx  = RegularExpression(pattern: RX_PROC_INST)!
        let str = String(chars)

        guard let match = rx.firstMatch(in: str), let a = match[1].subString, let b = match[2].subString else {
            throw SAXError.MalformedProcInst(position: pos, description: "Malformed processing instruction: \(str)")
        }

        delegate.processingInstruction(self, target: a, data: b)
    }

    private func readToEndOfProcInst(chars: inout [Character]) throws {
        try inputStream.append(to: &chars) { ($0.last(count: 2) == [ "?", ">" ] ? SuffixOption.Keep : nil) }
        inputStream.markUpdate()
    }

    func pushInputStream(inputStream: SAXCharInputStream) { lock.withLock { _ = _pushInputStream(inputStream: inputStream) } }

    func popInputStream(close: Bool = true) -> SAXCharInputStream? {
        lock.withLock {
            guard _inputStreams.count > 1 else { return nil }
            let stream = _inputStreams.popLast()!
            if close { stream.close() }
            return stream
        }
    }

    @discardableResult private func _pushInputStream(inputStream: SAXCharInputStream) -> SAXCharInputStream {
        _inputStreams <+ inputStream
        inputStream.open()
        return inputStream
    }

    private var _allowedURIPrefixes: [String]             = []
    private var _inputStreams:       [SAXCharInputStream] = []
}
