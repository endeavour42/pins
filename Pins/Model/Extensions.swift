//
//  Extensions.swift
//  Pins
//
//  Created by Mike on 12/08/2021.
//

import Foundation
import CoreLocation

extension URLResponse {
    
    var httpStatusCode: Int? {
        guard let resp = self as? HTTPURLResponse else {
            return nil
        }
        return resp.statusCode
    }

    var httpError: Error? {
        guard let code = httpStatusCode else {
            return nil
        }
        if code >= 200 && code < 300 {
            return nil
        }
        let userInfo: [String: Any] = [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: code)]
        return NSError(domain: "HTTP", code: code, userInfo: userInfo)
    }
}

extension URL: Identifiable {
    public var id: URL {
        self
    }
}

enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (a: Self, b: Self) -> Bool {
        a.latitude == b.latitude && a.longitude == b.longitude
    }
}
