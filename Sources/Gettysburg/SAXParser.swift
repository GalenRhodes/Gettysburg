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
    public var xmlVersion:         String       { lock.withLock { xmlDecl.version                  } }
    public var xmlEncoding:        String       { lock.withLock { xmlDecl.encoding                 } }
    public var xmlStandalone:      Bool         { lock.withLock { xmlDecl.standalone               } }
    public var docPosition:        TextPosition { lock.withLock { inputStream.docPosition.position } }

    public var delegate:           SAXDelegate  { get { lock.withLock { _delegate           } } set { lock.withLock { _delegate = newValue           } } }
    public var allowedURIPrefixes: [String]     { get { lock.withLock { _allowedURIPrefixes } } set { lock.withLock { _allowedURIPrefixes = newValue } } }

    let lock:          MutexLock          = MutexLock()
    var alreadyParsed: Bool               = false
    var xmlDecl:       XMLDecl            = XMLDecl(version: "1.0", encoding: "", standalone: true)
    var inputStream:   SAXCharInputStream { _inputStreams.last! }
    //@f:1

    public init(url: URL, tabSize: Int8 = 4, delegate: SAXDelegate, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil) throws {
        _delegate = delegate
        _inputStreams = [ try SAXIConvCharInputStream(url: url, tabSize: tabSize, options: options, authenticate: authenticate) ]
        _inputStreams[0].open()
        xmlDecl.encoding = _inputStreams[0].encodingName
    }

    public init(fileAtPath path: String, tabSize: Int8 = 4, delegate: SAXDelegate) throws {
        _delegate = delegate
        _inputStreams = [ try SAXIConvCharInputStream(fileAtPath: path, tabSize: tabSize) ]
        _inputStreams[0].open()
        xmlDecl.encoding = _inputStreams[0].encodingName
    }

    public init(data: Data, url: URL? = nil, tabSize: Int8 = 4, delegate: SAXDelegate) throws {
        _delegate = delegate
        _inputStreams = [ try SAXIConvCharInputStream(data: data, url: url, tabSize: tabSize) ]
        _inputStreams[0].open()
        xmlDecl.encoding = _inputStreams[0].encodingName
    }

    public init(string: String, url: URL? = nil, tabSize: Int8 = 4, delegate: SAXDelegate) {
        _delegate = delegate
        _inputStreams = [ SAXStringCharInputStream(string: string, url: url, tabSize: tabSize) ]
        _inputStreams[0].open()
        xmlDecl.encoding = _inputStreams[0].encodingName
    }

    deinit { _inputStreams[0].close() }

    open func parse() throws {
        try lock.withLock {
            guard !alreadyParsed else { throw SAXError.AlreadyParsed() }
            alreadyParsed = true
        }
        do {
            try processXMLDecl()
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

    func pushInputStream(inputStream: SAXCharInputStream) {
        lock.withLock {
            _inputStreams <+ inputStream
            inputStream.open()
        }
    }

    func popInputStream(close: Bool = true) -> SAXCharInputStream? {
        lock.withLock {
            guard _inputStreams.count > 1 else { return nil }
            let stream = _inputStreams.popLast()!
            if close { stream.close() }
            return stream
        }
    }

    private var _delegate:           SAXDelegate
    private var _allowedURIPrefixes: [String]             = []
    private var _inputStreams:       [SAXCharInputStream] = []
}
