/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ExperimentTests.swift
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

import XCTest
import Foundation
import CoreFoundation
import Rubicon
@testable import Gettysburg

public class ExperimentTests: XCTestCase {

    public override func setUpWithError() throws {}

    public override func tearDownWithError() throws {}

    func testURLs_2() throws {
        let strURL = "http://goober/Test_UTF-8.xml"
        guard let url = URL(string: strURL) else { throw URLErrors.MalformedURL(description: strURL) }
        guard let fil = try? InputStream.getInputStream(url: url, authenticate: { _ in .UseDefault }) else { throw StreamError.FileNotFound(description: strURL) }


        guard let str = String(fromInputStream: fil, encoding: .utf8) else { throw StreamError.UnknownError() }
        print("      Cookies: \(fil.property(forKey: .httpCookiesKey) ?? "")")
        print("      Headers: \(fil.property(forKey: .httpHeadersKey) ?? "")")
        print("  Status Code: \(fil.property(forKey: .httpStatusCodeKey) ?? "")")
        print("  Status Text: \(fil.property(forKey: .httpStatusTextKey) ?? "")")
        print("    MIME Type: \(fil.property(forKey: .mimeTypeKey) ?? "")")
        print("Text Encoding: \(fil.property(forKey: .textEncodingNameKey) ?? "")")
        print("")
        print(str)
    }

    func testURLs_1() throws {
        let urls: [String] = [
            "galen.html",
            "./galen.html",
            "../galen.html",
            "http://foo.com/Projects/galen.html",
            "http://foo.com/Projects/galen.html?bar=foo",
            "http://foo.com/Projects/galen.html#bar",
            "http://foo.com/Projects/galen.html?bar=foo#bar",
            "http://foo.com:8080/Projects/galen.html",
            "http://foo.com:8080/Projects/galen.html?bar=foo",
            "http://foo.com:8080/Projects/galen.html#bar",
            "http://foo.com:8080/Projects/galen.html?bar=foo#bar",
            "http://foo.com/Projects/./galen.html",
            "http://foo.com/Projects/../galen.html",
            "file:///Users/grhodes/Projects/test.swift",
            "file:///Users/grhodes/Projects/./test.swift",
            "file:///Users/grhodes/Projects/../test.swift",
            "file://Users/grhodes/Projects/test.swift",
            "file://Users/grhodes/Projects/./test.swift",
            "file://Users/grhodes/Projects/../test.swift",
            "jdbc://bossman:8080",
            "/galen.html",
            "~/galen.html",
            "~galen.html",
        ]

        for urlString in urls {
            if let url = URL(string: urlString)?.standardized {
                print("-------------------------------------------------------")
                print("  String: \"\(urlString)\"")
                print("     URL: \"\(url)\"")
                print(" BaseURL: \"\(url.baseURL?.absoluteString ?? "")\"")
                print("  Scheme: \"\(url.scheme ?? "")\"")
                print("    Host: \"\(url.host ?? "")\"")
                print("    Port: \"\(url.port ?? 80)\"")
                print("    Path: \"\(url.path)\"")
                print("   Query: \"\(url.query ?? "")\"")
                print("Fragment: \"\(url.fragment ?? "")\"")
                print(" Is File: \(url.isFileURL)")
                print("        : \"\(url.absoluteString)\"")
                print("        : \"\(url.relativeString)\"")
                print("        : \"\(url.standardizedFileURL)\"")
            }
            else {
                print("Malformed URL: \"\(urlString)\"")
            }
        }

        print("============================================================================================")

        // let bu = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        // let bu = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let bu = URL(fileURLWithPath: "/Users/grhodes", isDirectory: true)

        for urlString in urls {
            if let url = URL(string: urlString, relativeTo: bu)?.standardized {
                print("-------------------------------------------------------")
                print("  String: \"\(urlString)\"")
                print("     URL: \"\(url)\"")
                print(" BaseURL: \"\(url.baseURL?.absoluteString ?? "")\"")
                print("  Scheme: \"\(url.scheme ?? "")\"")
                print("    Host: \"\(url.host ?? "")\"")
                print("    Port: \"\(url.port ?? 80)\"")
                print("    Path: \"\(url.path)\"")
                print("   Query: \"\(url.query ?? "")\"")
                print("Fragment: \"\(url.fragment ?? "")\"")
                print(" Is File: \(url.isFileURL)")
                print("        : \"\(url.absoluteString)\"")
                print("        : \"\(url.relativeString)\"")
                print("        : \"\(url.standardizedFileURL)\"")
            }
            else {
                print("Malformed URL: \"\(urlString)\"")
            }
        }
    }
}
