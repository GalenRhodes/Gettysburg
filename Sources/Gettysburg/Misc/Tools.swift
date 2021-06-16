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

/*===============================================================================================================================================================================*/
/// Get a URL for the current working directory.
///
/// - Returns: the current working directory as a URL.
///
@inlinable func GetCurrDirURL() -> URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true) }

/*===============================================================================================================================================================================*/
/// Get a URL for the given filename.  If the filename is relative it will be made absolute relative to the current working directory.
///
/// - Parameter filename: the filename.
/// - Returns: the filename as an absolute URL.
///
@inlinable func GetFileURL(filename: String) -> URL { URL(fileURLWithPath: filename, relativeTo: GetCurrDirURL()) }

/*===============================================================================================================================================================================*/
/// Get a `URL` for it's given string form. The difference between this function and calling the <code>[foundation class
/// URL's](https://developer.apple.com/documentation/foundation/url)</code> constructor
/// <code>[`URL(string:)`](https://developer.apple.com/documentation/foundation/url/3126806-init)</code> is that this function will throw an error if the URL is malformed rather
/// than returning `nil` and if the URL is relative and `nil` is passed for the `relativeTo` base URL then it will use the current working directory.
///
/// - Parameters:
///   - string: the string containing the URL.
///   - relativeTo: If the URL defined by the given string is relative then...
/// - Returns: the URL.
/// - Throws: if the URL is malformed.
///
@inlinable func GetURL(string: String, relativeTo: URL? = nil) throws -> URL {
    guard let url = URL(string: string, relativeTo: (relativeTo ?? GetCurrDirURL())) else { throw SAXError.getMalformedURL(description: string) }
    return url
}

/*===============================================================================================================================================================================*/
/// Print out an array of strings to STDOUT. Used for debugging.
///
/// - Parameter strings: the array of strings.
///
@usableFromInline func PrintArray(_ strings: [String?]) {
    #if DEBUG
        var idx = 0
        for s in strings {
            if let s = s { print("\(idx++)> \"\(s)\"") }
            else { print("\(idx++)> NIL") }
        }
    #endif
}

/*===============================================================================================================================================================================*/
/// Given a URL, get the Base URL and the filename.
///
/// - Parameter url: the URL.
/// - Returns: a tuple with the given URL, the Base URL, and the filename. If the given URL was relative then it is made absolute with respect to the current working directory.
/// - Throws: if the URL is malformed.
///
@inlinable func GetBaseURLAndFilename(url: URL) throws -> (URL, URL, String) {
    let burl     = try GetURL(string: url.absoluteString)
    let baseURL  = burl.deletingLastPathComponent()
    let filename = burl.lastPathComponent
    return (burl, baseURL, filename)
}

let UTF32BEBOM: [UInt8] = [ 0, 0, 0xfe, 0xff ]
let UTF32LEBOM: [UInt8] = [ 0xff, 0xfe, 0, 0 ]
let UTF16BEBOM: [UInt8] = [ 0xfe, 0xff ]
let UTF16LEBOM: [UInt8] = [ 0xff, 0xfe ]
let UTF8BOM:    [UInt8] = [ 0xef, 0xbb, 0xbf ]

/*===============================================================================================================================================================================*/
/// Determin the encoding used in a file by sampling the bytes and/or reading the XML Declaration.
///
/// - Parameter inputStream: The MarkInputStream.
/// - Returns: The encoding name.
/// - Throws: If an  I/O error occurs or the encoding is not supported.
///
@usableFromInline func getEncodingName(inputStream: MarkInputStream) throws -> String {
    nDebug(.In, "Mark Count: \(inputStream.markCount)")
    defer { nDebug(.Out, "Mark Count: \(inputStream.markCount)") }
    return try _getEncodingName(inputStream: inputStream)
}

@usableFromInline func _getEncodingName(inputStream: MarkInputStream) throws -> String {
    var buffer: [UInt8] = [ 0, 0, 0, 0 ]

    inputStream.open()
    inputStream.markSet()
    defer { inputStream.markReturn() }
    guard inputStream.read(&buffer, maxLength: 4) == 4 else { throw SAXError.getUnexpectedEndOfInput(description: "Not enough data to determine the character encoding.") }

    if buffer == UTF32BEBOM {
        inputStream.markUpdate()
        return "UTF-32BE"
    }
    else if buffer == UTF32LEBOM {
        inputStream.markUpdate()
        return "UTF-32LE"
    }
    else if buffer[0 ..< 2] == UTF16BEBOM {
        inputStream.markUpdate()
        return "UTF-16BE"
    }
    else if buffer[0 ..< 2] == UTF16LEBOM {
        inputStream.markUpdate()
        return "UTF-16LE"
    }
    else if buffer[0 ..< 3] == UTF8BOM {
        inputStream.markUpdate()
        return "UTF-8"
    }
    else {
        inputStream.markReset()
        return try hardGuess(guessEncodingName(buffer), inputStream)
    }
}

@usableFromInline func hardGuess(_ encodingName: String, _ inputStream: MarkInputStream) throws -> String {
    // NOTE: At this point the encoding is only guessed at.  We'll need to look for an XML Declaration element to hopefully give us more information.
    nDebug(.None, "Taking a hard guess starting out with: \"\(encodingName)\"")
    let _inputStream = SimpleIConvCharInputStream(inputStream: inputStream, encodingName: encodingName, autoClose: false)
    nDebug(.None, "Create SimpleIConvCharInputStream...")
    _inputStream.open()
    nDebug(.None, "Opened SimpleIConvCharInputStream...")
    defer { _inputStream.close() }

    var chars: [Character] = []
    guard try _inputStream.read(chars: &chars, maxLength: 6) == 6 else { return encodingName }
    nDebug(.None, "Read the first 6 characters: \"\(String(chars))\"")
    guard chars.matches(pattern: "<\\?(?i:xml)\\s") else { return encodingName }

    // We have an XML Declaration element.  Read it, parse it, determine the encoding.
    repeat {
        guard let _ch = try _inputStream.read() else { return encodingName }
        chars <+ _ch
        if _ch == ">" {
            guard chars[chars.endIndex - 2] == "?" else { return encodingName }
            break
        }
    } while true

    // Now let's see if it contains the encoding.
    guard let m = GetRegularExpression(pattern: "\\sencoding=\"([^\"]+)\"").firstMatch(in: String(chars)), let enc = m[1].subString else { return encodingName }
    // We definitely got an encoding name, now let's see if we support it.
    let uEnc = enc.uppercased()
    guard IConv.encodingsList.contains(uEnc) else { throw SAXError.getUnknownEncoding(description: "Uknown encoding: \(enc)") }
    return uEnc
}

@usableFromInline func guessEncodingName(_ buffer: [UInt8]) -> String {
    if (buffer[0] == 0 && buffer[1] != 0) || (buffer[2] == 0 && buffer[3] != 0) { return "UTF-16BE" }
    else if (buffer[0] != 0 && buffer[1] == 0) || (buffer[2] != 0 && buffer[3] == 0) { return "UTF-16LE" }
    else if (buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0) { return "UTF-32BE" }
    else if (buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0) { return "UTF-32LE" }
    else { return "UTF-8" }
}

@usableFromInline struct ItemStore<T> {
    @usableFromInline var items: [String: T]   = [:]
    @usableFromInline let lock:  ReadWriteLock = ReadWriteLock()

    init() {}

    @inlinable subscript(key: String) -> T? {
        get { lock.withReadLock { items[key] } }
        set { lock.withWriteLock { items[key] = newValue } }
    }
}

@usableFromInline var regexStore: ItemStore<RegularExpression> = ItemStore<RegularExpression>()

extension RegularExpression.Options {
    @inlinable var name: Character {
        switch self {
            case .caseInsensitive:            return "i"
            case .allowCommentsAndWhitespace: return "x"
            case .dotMatchesLineSeparators:   return "s"
            case .anchorsMatchLines:          return "m"
            case .useUnicodeWordBoundaries:   return "w"
            case .ignoreMetacharacters:       return "c"
            case .useUnixLineSeparators:      return "u"
        }
    }

    @inlinable static func optionsString(_ options: [Self]) -> String {
        var out: String = "("
        for o in options { out.append(o.name) }
        out.append(")")
        return out
    }
}

@inlinable func GetRegularExpression(pattern: String, options: [RegularExpression.Options] = []) -> RegularExpression {
    let key = "\(RegularExpression.Options.optionsString(options))Ð\(pattern)"
    if let rx = regexStore[key] { return rx }
    var err: Error? = nil
    guard let rx = RegularExpression(pattern: pattern, options: options, error: &err) else { fatalError("Invalid REGEX Pattern: \(err!.localizedDescription)") }
    regexStore[key] = rx
    return rx
}

extension Array where Element == Character {

    @inlinable public func matches(pattern: String) -> Bool {
        let str: String                    = String(self)
        let m:   [RegularExpression.Match] = GetRegularExpression(pattern: pattern).matches(in: str)
        return ((m.count == 1) && (str.fullRange == m[0].range))
    }
}

@inlinable func GetExternalFile(parentStream: SAXCharInputStream, url: URL) throws -> String { try GetExternalFile(position: parentStream.position, url: url) }

@usableFromInline func GetExternalFile(position: TextPosition = (0, 0), url: URL) throws -> String {
    guard let byteInputStream = InputStream(url: url) else { throw SAXError.MalformedURL(position: position, description: url.absoluteString) }
    let charInputStream = try SAXIConvCharInputStream(inputStream: byteInputStream, url: url)
    var buffer: [Character] = []
    _ = try charInputStream.read(chars: &buffer, maxLength: Int.max)
    return String(buffer)
}

@inlinable func GetPosition(from str: String, range: Range<String.Index>, startingAt pos: TextPosition) -> TextPosition {
    var p = pos
    str[range].forEach { ch in textPositionUpdate(ch, pos: &p, tabWidth: 4) }
    return p
}

@inlinable func AdvancePosition(from str: String, range: Range<String.Index>, position pos: inout TextPosition) { pos = GetPosition(from: str, range: range, startingAt: pos) }
