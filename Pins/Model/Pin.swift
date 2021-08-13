//
//  Pin.swift
//  Pins
//
//  Created by Mike on 12/08/2021.
//

import MapKit

class Pin: NSObject, MKAnnotation, Identifiable {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let imageUrl: URL?

    init(_ coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil, imageUrl: URL? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
    }
    
    public static func == (a: Pin, b: Pin) -> Bool {
        a.coordinate == b.coordinate && a.title == b.title && a.subtitle == b.subtitle && a.imageUrl == b.imageUrl
    }
}

extension Pin {
    convenience init?(_ event: StreamEvent) {
        guard let v = event.data.geo?.coordinates?.coordinates, v.count >= 2 else { return nil }
        self.init(CLLocationCoordinate2D(latitude: v[1], longitude: v[0]), title: event.author, imageUrl: event.profile_image_url)
    }
}

