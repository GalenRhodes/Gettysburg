//
//  GettysburgTests.swift
//  GettysburgTests
//
//  Created by Galen Rhodes on 11/7/20.
//

import XCTest
import Rubicon
@testable import Gettysburg

class GettysburgTests: XCTestCase {

    let testDataDir: String = "Tests/GettysburgTests/TestData"

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testInitURL1() throws {
        let istr = InputStream(data: Data())
        let sax  = try SAXParser(inputStream: istr, url: nil, handler: SAXTestHandler())

        print("--------------------------------------------------------------------------------")
        print("      URL: \"\(sax.url.absoluteString)\"")
        print(" Base URL: \"\(sax.baseURL.absoluteString)\"")
        print("File Name: \"\(sax.filename)\"")
    }

    func testInitURL2() throws {
        let istr = InputStream(data: Data())
        let sax  = try SAXParser(inputStream: istr, url: URL(string: "http://galenrhodes/swift.xml"), handler: SAXTestHandler())

        print("--------------------------------------------------------------------------------")
        print("      URL: \"\(sax.url.absoluteString)\"")
        print(" Base URL: \"\(sax.baseURL.absoluteString)\"")
        print("File Name: \"\(sax.filename)\"")
    }

    func testInitURL3() throws {
        let istr = InputStream(data: Data())
        let sax  = try SAXParser(inputStream: istr, url: URL(string: "swift.xml", relativeTo: URL(string: "http://galenrhodes")), handler: SAXTestHandler())

        print("--------------------------------------------------------------------------------")
        print("      URL: \"\(sax.url.absoluteString)\"")
        print(" Base URL: \"\(sax.baseURL.absoluteString)\"")
        print("File Name: \"\(sax.filename)\"")
    }

    func testInitURL4() throws {
        let istr = InputStream(data: Data())
        let sax  = try SAXParser(inputStream: istr, url: URL(string: "swift.xml"), handler: SAXTestHandler())

        print("--------------------------------------------------------------------------------")
        print("      URL: \"\(sax.url.absoluteString)\"")
        print(" Base URL: \"\(sax.baseURL.absoluteString)\"")
        print("File Name: \"\(sax.filename)\"")
    }

    func testInitURL5() throws {
        let names: [String] = [ "UTF-8", "UTF-16BE", "UTF-16BE_ext", "UTF-32LE", "WINDOWS-1252" ]

        for name in names {
            let fname = "Tests/GettysburgTests/TestData/Test_\(name).xml"
            let url   = GetFileURL(filename: fname)

            guard let istr = InputStream(url: url) else { throw SAXError.MalformedURL(url.absoluteString) }
            let sax = try SAXParser(inputStream: istr, url: URL(string: fname), handler: SAXTestHandler())

            print("================================================================================")
            print("      URL: \"\(sax.url.absoluteString)\"")
            print(" Base URL: \"\(sax.baseURL.absoluteString)\"")
            print("File Name: \"\(sax.filename)\"")
            try sax.createCharStream()
            print("--------------------------------------------------------------------------------")
            print("          URL: \"\(sax.url.absoluteString)\"")
            print("     Base URL: \"\(sax.baseURL.absoluteString)\"")
            print("    File Name: \"\(sax.filename)\"")
            print("File Encoding: \"\(sax.charStream.encodingName)\"")
        }
    }

    func testParse() throws {
        print("--------------------------------------------------------------------------------")
        let name  = "UTF-8"
        let fname = "Tests/GettysburgTests/TestData/Test_\(name).xml"
        let url   = GetFileURL(filename: fname)
        guard let istr = InputStream(url: url) else { throw SAXError.MalformedURL(url.absoluteString) }
        let sax = try SAXParser(inputStream: istr, url: url, handler: SAXTestHandler())
        try sax.parse()
    }

    func testDocTypeRegex() throws {
        let pattern = "\\A\\s*(\(rxNamePattern))\\s+(SYSTEM|PUBLIC)\\s+([\"'])(.*?)\\3(?:\\s+([\"'])(.*?)\\5)?\\s*\\z"
        let tests   = [
            " Person SYSTEM \"Test_UTF-16LE_ext.dtd\"",
            "Person SYSTEM \"Test_UTF-16LE_ext.dtd\"",
            " Person PUBLIC \"publicID\" \"Test_UTF-16LE_ext.dtd\"",
            "Person PUBLIC \"publicID\" \"Test_UTF-16LE_ext.dtd\"",

            " Person SYSTEM \"'Test_UTF-16LE_ext.dtd'\"",
            "Person SYSTEM \"'Test_UTF-16LE_ext.dtd'\"",
            " Person PUBLIC \"'publicID'\" \"Test_UTF-16LE_ext.dtd\"",
            "Person PUBLIC \"publicID\" \"'Test_UTF-16LE_ext.dtd'\"",
            "Person PUBLIC \"'publicID'\" \"'Test_UTF-16LE_ext.dtd'\"",

            " Person SYSTEM 'Test_UTF-16LE_ext.dtd'",
            "Person SYSTEM 'Test_UTF-16LE_ext.dtd'",
            " Person PUBLIC 'publicID' \"Test_UTF-16LE_ext.dtd\"",
            "Person PUBLIC 'publicID' \"Test_UTF-16LE_ext.dtd\"",
            " Person PUBLIC \"publicID\" 'Test_UTF-16LE_ext.dtd'",
            "Person PUBLIC \"publicID\" 'Test_UTF-16LE_ext.dtd'",
            " Person PUBLIC 'publicID' 'Test_UTF-16LE_ext.dtd'",
            "Person PUBLIC 'publicID' 'Test_UTF-16LE_ext.dtd'",

            " Person SYSTEM '\"Test_UTF-16LE_ext.dtd\"'",
            "Person SYSTEM '\"Test_UTF-16LE_ext.dtd\"'",
            " Person PUBLIC '\"publicID\"' \"'Test_UTF-16LE_ext.dtd'\"",
            "Person PUBLIC '\"publicID\"' \"'Test_UTF-16LE_ext.dtd'\"",
            " Person PUBLIC \"'publicID'\" '\"Test_UTF-16LE_ext.dtd\"'",
            "Person PUBLIC \"'publicID'\" '\"Test_UTF-16LE_ext.dtd\"'",
            " Person PUBLIC '\"publicID\"' '\"Test_UTF-16LE_ext.dtd\"'",
            "Person PUBLIC '\"publicID\"' '\"Test_UTF-16LE_ext.dtd\"'",
        ]

        for aTest in tests {
            if let rx = RegularExpression(pattern: pattern, options: [ .anchorsMatchLines ]) {
                if let match = rx.firstMatch(in: aTest) {
                    print("======================================================================")
                    var idx = 0
                    for grp in match {
                        print("Group \(idx++)> \"\(grp.subString ?? "NIL")\"")
                    }
                }
            }
        }
    }

    //    func testPerformanceExample() throws {
    //        // This is an example of a performance test case.
    //        self.measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
}
