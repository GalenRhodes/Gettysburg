/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: URLSessionTesterAction.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 16, 2021
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

class URLSessionTesterAction {

    let config:   URLSessionConfiguration
    let session:  URLSession
    let url:      URL
    var isDone:   Bool       = false
    let delegate: MyDelegate = MyDelegate()

    init(url: URL) throws {
        self.url = url
        self.config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    func fooBar(_ msg: String) -> Void {
        print("ERROR: \(msg)", to: &ErrOutput.out)
        isDone = true
    }

    func run() throws {
//        let dataTask = session.dataTask(with: url) { (data: Data?, response: URLResponse?, error: Error?) -> Void in
//            self.lock.withLock {
//                defer { self.lock.broadcast() }
//                if let error = error { return self.fooBar(error.localizedDescription) }
//                guard let response = response else { return self.fooBar("No response") }
//                guard let httpResponse = response as? HTTPURLResponse else { return self.fooBar(response.debugDescription) }
//                guard (200 ... 299).contains(httpResponse.statusCode) else { return self.fooBar("Bad response: \(httpResponse.statusCode)") }
//
//                print(" Status: \(httpResponse.statusCode)", to: &ErrOutput.out)
//                var first = true
//                for (key, value) in httpResponse.allHeaderFields {
//                    if first {
//                        print("Headers:", to: &ErrOutput.out)
//                        first = false
//                    }
//                    print("    \(key.description.padding(toLength: 18, withPad: " ", startingAt: 0)) = \(value)", to: &ErrOutput.out)
//                }
//
//                guard let data = data else { return self.fooBar("No Data!") }
//                guard let str = String(data: data, encoding: .utf8) else { return self.fooBar("Could not convert to UTF-8") }
//                print(str, to: &StdOutput.out)
//                self.isDone = true
//            }
//        }
        let dataTask = session.dataTask(with: url)
        dataTask.resume()
        delegate.lock.withLock { while delegate.inputStream == nil { delegate.lock.broadcastWait() } }
        delegate.inputStream.open()

        var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 1024)
        var data:  Data    = Data()

        var cc = delegate.inputStream.read(&bytes, maxLength: 1024)
        while cc > 0 {
            data.append(&bytes, count: cc)
            cc = delegate.inputStream.read(&bytes, maxLength: 1024)
        }

        if cc < 0 { print("ERROR: \(delegate.inputStream.streamError ?? StreamError.UnknownError())", to: &ErrOutput.out) }

        delegate.inputStream.close()

        guard let str = String(data: data, encoding: .utf8) else { throw StreamError.UnknownError(description: "Could not convert byte data to UTF-8") }
        print(str, to: &StdOutput.out)
        print("DONE: \(delegate.streamTask.state.rawValue)", to: &ErrOutput.out)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    class MyDelegate: NSObject, URLSessionDataDelegate, URLSessionStreamDelegate {
        let lock                               = Conditional()
        var inputStream: InputStream!          = nil
        var streamTask:  URLSessionStreamTask! = nil

        func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
            print("Did become Streams...", to: &ErrOutput.out)
            lock.withLock {
                self.inputStream = inputStream
                outputStream.close()
            }
        }

        func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
            print("Read closed for...", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
            print("Write closed for...", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
            print("Better route discovered for...", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void) {
            print("Did receive response - with completion handler", to: &ErrOutput.out)
            print("   MIME TYPE: \(response.mimeType ?? "")", to: &ErrOutput.out)
            print("CONTENT TYPE: \(response.textEncodingName ?? "")", to: &ErrOutput.out)
            handler(.becomeStream)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
            print("Did become download task", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
            print("Did become stream task.", to: &ErrOutput.out)
            self.streamTask = streamTask
            self.streamTask.captureStreams()
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            print("Did receive \(data.count) bytes of data", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
            print("Will cache response", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            print("Will perform http redirection", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            print("Did receive task authentication challange", to: &ErrOutput.out)
            completionHandler(.performDefaultHandling, nil)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            print("Did finish collecting metrics", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            print("Did complete with error: \(error ?? StreamError.UnknownError())", to: &ErrOutput.out)
        }

        func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            print("Did become invalid with error: \(error ?? StreamError.UnknownError())", to: &ErrOutput.out)
        }

        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            print("Did Finish events", to: &ErrOutput.out)
        }
    }

    struct ErrOutput: TextOutputStream {
        static var out: ErrOutput = ErrOutput()

        func write(_ string: String) { outputLock.withLock { FileHandle.standardError.write(string.data(using: .utf8)!) } }
    }

    struct StdOutput: TextOutputStream {
        static var out: StdOutput = StdOutput()

        func write(_ string: String) { outputLock.withLock { FileHandle.standardOutput.write(string.data(using: .utf8)!) } }
    }
}

let outputLock: MutexLock = MutexLock()
