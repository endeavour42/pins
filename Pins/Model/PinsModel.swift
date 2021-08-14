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
        lastImageUrls = urls.reversed()
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
        /// update: json format doesn't allow control symbols (symbols less than 0x20). but that's in strings only!
        /// \r and \n can be used as JSON whitespace. the algorithm that merely looks at "\r\n" sequence and considers
        /// those symbols to mean event separator is technically wrong. one solution that springs to mind - a custom JSON parser.
        /// or a dependency on the (unwritten?) rule that \r\n sequence will not happen in the source material other than for the separators.
        /// TBC
        
        guard let string = String(data: data, encoding: .utf8) else {
            delayedLastError = NSError(domain: "X", code: -1, userInfo: [NSLocalizedDescriptionKey : "not utf8"])
            return
        }
        
        let components = string.components(separatedBy: "\r\n")
        
        for eventString in components {
            guard let eventData = eventString.data(using: .utf8) else {
                delayedLastError = NSError(domain: "X", code: -1, userInfo: [NSLocalizedDescriptionKey : "not utf8"])
                return
            }
            if !eventData.isEmpty {
                handleEventData(eventData)
                #if DEBUG
                    print("eventString: \(eventString)")
                #endif
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        delayedLastError = error
    }
}
