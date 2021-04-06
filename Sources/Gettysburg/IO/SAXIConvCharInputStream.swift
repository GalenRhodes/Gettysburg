/*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXIConvCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 3/28/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

/*===============================================================================================================================================================================*/
/// `SAXParser` version of the <code>[SimpleIConvCharInputStream](http://galenrhodes.com/Rubicon/Classes/SimpleIConvCharInputStream.html)</code> that adds a number of features
/// needed by the `SAXParser`.
///
public class SAXIConvCharInputStream: SimpleIConvCharInputStream, SAXChildCharInputStream {
    public let baseURL:  URL
    public let url:      URL
    public let filename: String

    public init(inputStream: InputStream, url: URL) throws {
        (self.url, baseURL, filename) = try GetBaseURLAndFilename(url: url)
        let mis = ((inputStream as? MarkInputStream) ?? MarkInputStream(inputStream: inputStream, autoClose: true))
        let enc = try getCharacterEncoding(mis)
        super.init(inputStream: mis, encodingName: enc, autoClose: true)
    }
}

/*===============================================================================================================================================================================*/
/// The bytes that comprise the `UTF-32BE` ~Byte Order Mark~.
///
fileprivate let BOM32BE: [UInt8] = [ 0, 0, 0xfe, 0xff ]
/*===============================================================================================================================================================================*/
/// The bytes that comprise the `UTF-32LE` ~Byte Order Mark~.
///
fileprivate let BOM32LE: [UInt8] = [ 0xff, 0xfe, 0, 0 ]

/*===============================================================================================================================================================================*/
/// Determine the character encoding.
/// 
/// - Parameter istr: the input stream.
/// - Returns: The name of the character encoding.
/// - Throws: If an I/O error occurs or the encoding found is not supported.
///
fileprivate func getCharacterEncoding(_ istr: MarkInputStream) throws -> String { try getCharacterEncodingFromXMLDecl(istr, guessedEncoding: try guessCharacterEncoding(istr)) }

/*===============================================================================================================================================================================*/
/// Try to determine the character encoding from the first few bytes of the input stream. If it cannot determine then it defaults to `UTF-8`.
/// 
/// - Parameter inputStream: the input stream.
/// - Returns: The name of the character encoding.
/// - Throws: If an I/O error occurs.
///
fileprivate func guessCharacterEncoding(_ inputStream: MarkInputStream) throws -> String {
    if inputStream.streamStatus == .notOpen { inputStream.open() }
    inputStream.markSet()
    defer { inputStream.markReturn() }

    var buffer: [UInt8] = [ 0, 0, 0, 0 ]
    guard inputStream.read(&buffer, maxLength: 4) == 4 else { throw inputStream.streamError ?? StreamError.UnexpectedEndOfInput() }

    if buffer == BOM32BE || buffer == BOM32LE { return "UTF-32" }
    if buffer[0 ..< 2] == BOM32BE[2 ..< 4] || buffer[0 ..< 2] == BOM32LE[0 ..< 2] { return "UTF-16" }

    if buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0 { return "UTF-32BE" }
    if buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0 { return "UTF-32LE" }

    if buffer[0] == 0 && buffer[1] != 0 && buffer[2] == 0 && buffer[3] != 0 { return "UTF-16BE" }
    if buffer[0] != 0 && buffer[1] == 0 && buffer[2] != 0 && buffer[3] == 0 { return "UTF-16LE" }

    return "UTF-8"
}

/*===============================================================================================================================================================================*/
/// Attempt to read the XML Declaration from the input stream to determine the character encoding.
/// 
/// - Parameters:
///   - inputStream: the input stream.
///   - guessedEncoding: the character encoding guessed in the `guessCharacterEncoding(_:)` function.
/// - Returns: the character encoding found in the XML Declaration or the guessed encoding if the file does not have an XML Declaration or the XML Declaration does not specify the
///            encoding.
/// - Throws: If an I/O error occurs of the encoding found in the XML Declaration is not supported.
///
fileprivate func getCharacterEncodingFromXMLDecl(_ inputStream: MarkInputStream, guessedEncoding: String) throws -> String {
    inputStream.markSet()
    defer { inputStream.markReturn() }

    let charStream = IConvCharInputStream(inputStream: inputStream, encodingName: guessedEncoding, autoClose: false)

    charStream.open()
    defer { charStream.close() }

    let str = try charStream.readString(count: 6, errorOnEOF: false)

    if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
        let xmlDecl = try charStream.readUntil(found: "?>")

        if let regex = RegularExpression(pattern: "\\s(?:encoding)=\"([^\"]+)\"") {

            if let match = regex.firstMatch(in: xmlDecl), let enc = match[1].subString?.uppercased(), enc != guessedEncoding {
                let fin = getFinalEncoding(guessedEncoding: guessedEncoding, xmlDeclEncoding: enc)
                guard IConv.encodingsList.contains(fin) else { throw SAXError.UnsupportedCharacterEncoding(1, 1, description: "Unsupported Character Encoding: \(fin)") }
                return fin
            }
        }
    }

    return guessedEncoding
}

/*===============================================================================================================================================================================*/
/// Decide between the guessed encoding and the encoding found in the XML Declaration.
/// 
/// - Parameters:
///   - guessedEncoding: the guessed encoding.
///   - xmlDeclEncoding: the encoding found in the XML Declaration.
/// - Returns: the final encoding.
///
fileprivate func getFinalEncoding(guessedEncoding: String, xmlDeclEncoding: String) -> String {
    switch guessedEncoding {
        case "UTF-32", "UTF-32BE", "UTF-32LE": return (xmlDeclEncoding.hasPrefix("UTF-32") ? guessedEncoding : xmlDeclEncoding);
        case "UTF-16", "UTF-16BE", "UTF-16LE": return (xmlDeclEncoding.hasPrefix("UTF-16") ? guessedEncoding : xmlDeclEncoding);
        default: return xmlDeclEncoding
    }
}
