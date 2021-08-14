//
//  PinsModel.swift
//  Pins
//
//  Created by Mike on 12/08/2021.
//

import Foundation
import MapKit
import SwiftUI

class PinsModel: NSObject, ObservableObject {
    static let singleton = PinsModel()
    var session: URLSession!
    var streamTask: URLSessionDataTask?
    private var oneShotTimer: Timer?
    private var errorSetCount = 0
    private var accumulatedData = Data()
    private let separator = Data([0x0d, 0x0a])

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        config.timeoutIntervalForRequest = 2
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    @Published var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 360))
    @Published var pins: [Pin] = []
    @Published var lastImageUrls: [URL] = []
    @Published var eventCount = 0
    
    @Published var lastError: Error? {
        didSet {
            if let error = lastError {
                print("Error: \(error)")
            }
        }
    }
    
    var delayedLastError: Error? {
        didSet {
            errorSetCount += 1
            let errorVersion = errorSetCount
            let newValue = delayedLastError
            
            if newValue == nil && oldValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                    if errorVersion == errorSetCount {
                        lastError = newValue
                    }
                }
            } else {
                lastError = newValue
            }
        }
    }

    private func addPin(_ pin: Pin) {
        pins.append(pin)
        var urls = pins.compactMap { $0.imageUrl }
        let n = urls.count
        if n > 10 {
            urls = Array(urls.dropFirst(n - 10))
        }
        lastImageUrls = urls
    }
    

    var searchString: String = "" {
        didSet {
            if searchString == oldValue { return }
            
            oneShotTimer?.invalidate()
            oneShotTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [self] _ in
                stopStream()
                pins = []
                lastImageUrls = []
                eventCount = 0
                accumulatedData = Data()
                if searchString == "" { return }
                startStream(searchString)
            }
        }
    }
    
    func handleEventData(_ eventData: Data) {
        do {
            let event = try JSONDecoder().decode(StreamEvent.self, from: eventData)
            eventCount += 1
            if let pin = Pin(event) {
                addPin(pin)
            }
        } catch {
            let usageCap = try? JSONDecoder().decode(UsageCap.self, from: eventData)
            if let usageCap = usageCap {
                delayedLastError = NSError(domain: "X", code: -1, userInfo: [NSLocalizedDescriptionKey : usageCap.detail])
            } else {
                delayedLastError = error
            }
        }
    }
}

extension PinsModel: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        /// NOTE: the comment below is no longer valid and is for historical purposes only. the proper solution is implemented down below after this comment.
        /// see the git history if you are interested to see the original code, which was working but was fragile and not entirely correct.
        ///
        /// ===================== CUT =====================
        /// TODO: this is a preliminary code.
        ///
        /// the sream format is "event \r\n event \r\n .."
        /// the problem is that with TCP the received data chunks can be of arbitrary size and not necessary holding the whole number of events or even the whole single event.
        /// the other potential problem is what happen with \r\n sequence present in the messages themselves
        /// also what's not ideal here is Data -> String -> Data conversion
        /// ideally the JSON decoding step shall allow decoding fragments and return the length it "consumed"
        ///
        /// notes to future self:
        /// - investigate if JSONSerialization.ReadingOptions.allowFragments can help
        /// - investigate if JSONSerialization.jsonObject(with stream: InputStream) can help
        /// - investigate if web sockets could help (are they supported on the server?)
        /// - investigate if network framework can help as it simplifies buffering issues (scan till the next \r\n is still needed)
        ///
        /// ok for now for the test app but for the real app all this needs to be addressed
        ///
        /// update1
        /// update: json format doesn't allow control symbols (symbols less than 0x20).
        /// so \r\n (0d0a) symbols are good separators indeed as they can not appear in the content strings.
        /// to avoid the Data -> String -> Data trip i can use Data().firstIndex(of: 0x0d) + 0x0a
        /// or Data().range(of: crlfData) where crlfData = Data([0x0D, 0x0A])
        /// then split data on the event separators. the further complication is that \r and \n symbols might
        /// appear in different data blocks (this is TCP). all in all the algorithm here shall be something like so:
        /// - append received data chunk into an accumulated data variable
        /// - loop {
        ///   - scan the accumulated data from the start and look for the first 0d0a sequence
        ///   - if not found - nothing to do, break from loop
        ///   - if found - "cut" the event out from the accumulated data along with its trailing 0d0a sequence
        ///   - process the event
        /// - } loop until there is no more 0d0a sequences in the accumulated data
        ///
        /// so it is important to look not at the individual chunks as they arrive but at the whole accumulated data.
        /// this is TBD
        ///
        /// update2: json format doesn't allow control symbols (symbols less than 0x20). but that's in strings only!
        /// \r and \n can be used as JSON whitespace. the algorithm that merely looks at "\r\n" sequence and considers
        /// those symbols to mean event separator is technically wrong. one solution that springs to mind - a custom JSON parser.
        /// or a dependency on the (unwritten?) rule that \r\n sequence will not happen in the source material other than for the separators.
        /// TBC
        ///
        /// update3: from the docs: "Your client should use the \r\n character to break activities apart as they are read in from the stream." this looks like a solid guarantee to me that there won't be a sequence of \r\n within the individual json messages (used as a whitespace).
        /// this makes the algorithm outlined in "update1" workable and there is no need for a custom json parser.
        /// note there are other types of messages (keep-alive and system)
        /// https://developer.twitter.com/en/docs/tutorials/consuming-streaming-data
        ///
        /// TODO
        ///
        /// update4. implemented
        /// ===================== CUT =====================

        accumulatedData.append(contentsOf: data)

        while true {
            guard let separatorRange = accumulatedData.range(of: separator) else {
                break
            }
            let packetRange = accumulatedData.startIndex ..< separatorRange.endIndex
            let eventRange = accumulatedData.startIndex ..< separatorRange.startIndex
            let eventData = accumulatedData.subdata(in: eventRange)
            accumulatedData.removeSubrange(packetRange)
            if !eventData.isEmpty {
                handleEventData(eventData)
                #if DEBUG
                    print(String(data: eventData, encoding: .utf8) ?? "not utf8?")
                #endif
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        delayedLastError = error
    }
}
