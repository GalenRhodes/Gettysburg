//
//  main.swift
//  URLSessionTester
//
//  Created by Galen Rhodes on 7/16/21.
//

import Foundation
import Rubicon
import ArgumentParser

enum URLErrors: Error {
    case MalformedURL(description: String)
}

class URLSessionTester: ParsableCommand {

    @Option(name: .shortAndLong, help: "The URL of the file to fetch.") public var url: String

    required init() {}

    func run() throws {
        guard let url = URL(string: self.url) else { throw URLErrors.MalformedURL(description: self.url) }
        try URLSessionTesterAction(url: url).run()
    }
}

DispatchQueue.main.async {
    URLSessionTester.main()
    exit(0)
}
dispatchMain()
