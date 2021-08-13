//
//  ContentView.swift
//  Pins
//
//  Created by Mike on 12/08/2021.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @ObservedObject private var model = PinsModel.singleton
    
    var body: some View {
        ZStack {
            VStack {
                #if os(iOS)
                TextField("search", text: $model.searchString)
                    .padding(4)
                    .border(Color.secondary, width: 1)
                    .padding()
                #else
                TextField("search", text: $model.searchString)
                    .padding()
                #endif
                VStack {
                    Text("found \(model.pins.count) locations for '\(model.searchString)', from \(model.eventCount) events")
                    
                    #if compiler(>=5.5)
                        if #available(iOS 15.0, macOS 12.0, *) {
                            HStack {
                                ForEach(model.lastImageUrls) { url in
                                    AsyncImage(url: url).frame(width: 32, height: 32)
                                }
                            }
                        }
                    #endif
                }
                .padding()
                Map(coordinateRegion: $model.region, annotationItems: model.pins) { pin in
                    MapPin(coordinate: pin.coordinate, tint: .red)
                }
            }
            if let error = model.lastError {
                Text(error.localizedDescription)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    .padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
