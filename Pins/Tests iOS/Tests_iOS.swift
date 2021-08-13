//
//  Tests_iOS.swift
//  Tests iOS
//
//  Created by Mike on 12/08/2021.
//

import XCTest
import CoreLocation

class Tests_iOS: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
    
    private var model: PinsModel {
        PinsModel.singleton
    }
    
    private func handleEvent(_ event: StreamEvent) {
        let data = try! JSONEncoder().encode(event)
        handleEventData(data)
    }
    
    private func handleEventData(_ data: Data) {
        model.handleEventData(data)
    }

    func test_event_noGeo() {
        let event = StreamEvent(data: .init(id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }
    
    func test_event_emptyGeo() {
        let event = StreamEvent(data: .init(author_id: nil, geo: Geo(), id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }
    
    func test_event_nilCoordinates() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: nil), id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }
    
    func test_event_emptyCoordinates() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: .init()), id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }
    
    func test_event_nilCoordinates2() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: .init(coordinates: nil)), id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }

    func test_event_emptyCoordinates2() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: .init(coordinates: [])), id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }
    
    func test_event_notEnoughCoordinates() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: .init(coordinates: [1])), id: "123", text: "hello"))
        XCTAssertNil(Pin(event))
    }
    
    func test_event_tooManyCoordinates() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: .init(coordinates: [1, 2, 3])), id: "123", text: "hello"))
        let pin = Pin(.init(latitude: 2, longitude: 1))
        XCTAssert(Pin(event)! == pin)
    }
    
    func test_event_justEnoughCoordinates() {
        let event = StreamEvent(data: .init(author_id: nil, geo: .init(coordinates: .init(coordinates: [1, 2])), id: "123", text: "hello"))
        let pin = Pin(.init(latitude: 2, longitude: 1))
        XCTAssert(Pin(event)! == pin)
    }
    
    func test_event_wrongAuthor() {
        let event = StreamEvent(data: .init(author_id: "user", geo: Geo(coordinates: .init(coordinates: [1, 2])), id: "id", text: "text"), includes: .init(users: [.init(id: "otherUser", name: "name", profile_image_url: "https://some.url", username: "username")]))
        let pin = Pin(.init(latitude: 2, longitude: 1), title: nil, subtitle: nil, imageUrl: nil)
        XCTAssert(Pin(event)! == pin)
    }
    
    func test_event_goodAuthor() {
        let event = StreamEvent(data: .init(author_id: "user", geo: Geo(coordinates: .init(coordinates: [1, 2])), id: "id", text: "text"), includes: .init(users: [.init(id: "user", name: "name", profile_image_url: "https://some.url", username: "username")]))
        let pin = Pin(.init(latitude: 2, longitude: 1), title: nil, subtitle: nil, imageUrl: .init(string: "https://some.url"))
        XCTAssert(Pin(event)! == pin)
    }
    
    func test_handleEvent_withCoords() {
        let event = StreamEvent(data: .init(author_id: "user", geo: Geo(coordinates: .init(coordinates: [1, 2])), id: "id", text: "text"), includes: .init(users: [.init(id: "user", name: "name", profile_image_url: "https://some.url", username: "username")]))

        let eventCount = model.eventCount
        let pinCount = model.pins.count
        
        model.delayedLastError = nil
        
        handleEvent(event)
        
        XCTAssertEqual(model.eventCount, eventCount + 1)
        XCTAssertEqual(model.pins.count, pinCount + 1)
        XCTAssert(model.pins.last! == Pin(event)!)
        XCTAssert(model.delayedLastError == nil)
    }
    
    func test_handleEvent_withNoCoords() {
        let event = StreamEvent(data: .init(author_id: "user", geo: Geo(), id: "id", text: "text"), includes: .init(users: [.init(id: "user", name: "name", profile_image_url: "https://some.url", username: "username")]))

        let eventCount = model.eventCount
        let pinCount = model.pins.count
        
        model.delayedLastError = nil
        
        handleEvent(event)
        
        XCTAssertEqual(model.eventCount, eventCount + 1)
        XCTAssertEqual(model.pins.count, pinCount)
        XCTAssert(model.delayedLastError == nil)
    }

    func test_handleEvent_emptyData() {
        let eventCount = model.eventCount
        let pinCount = model.pins.count
        
        model.delayedLastError = nil
        
        handleEventData(Data())
        
        XCTAssertEqual(model.eventCount, eventCount)
        XCTAssertEqual(model.pins.count, pinCount)
        XCTAssert(model.delayedLastError != nil)
    }

    func test_handleEvent_bogusData2() {
        let eventCount = model.eventCount
        let pinCount = model.pins.count
        
        model.delayedLastError = nil
        
        handleEventData("hello".data(using: .utf8)!)
        
        XCTAssertEqual(model.eventCount, eventCount)
        XCTAssertEqual(model.pins.count, pinCount)
        XCTAssert(model.delayedLastError != nil)
    }
    
    func test_handleEvent_bogusData3() {
        let eventCount = model.eventCount
        let pinCount = model.pins.count
        
        let data = Data([0xDE, 0xAD, 0xBE, 0x0F, 0x00, 0x83])
        XCTAssertNil(String(data: data, encoding: .utf8))
        
        model.delayedLastError = nil
        
        handleEventData(data)
        
        XCTAssertEqual(model.eventCount, eventCount)
        XCTAssertEqual(model.pins.count, pinCount)
        XCTAssert(model.delayedLastError != nil)
    }

    func test_usageCap() {
        let usageCap = UsageCap(account_id: 1, product_name: "prod", title: "title", period: "period", scope: "scope", detail: "xxx", type: "type")
        let data = try! JSONEncoder().encode(usageCap)
        
        let eventCount = model.eventCount
        let pinCount = model.pins.count

        model.delayedLastError = nil
        
        handleEventData(data)
        
        XCTAssertEqual(model.eventCount, eventCount)
        XCTAssertEqual(model.pins.count, pinCount)
        XCTAssert(model.delayedLastError != nil)
    }

    /*
     // was experimenting here with a different endpoint ("recent")
     
    private func checkResponse(_ results: ThingSearchResults) {
        let data = try! JSONEncoder().encode(results)
        
        model.handleSearchResult(data: data, searchText: "", maxItemCount: 0, page: nil, currentCallCount: 0, maxCallCount: 0) { things, newPage in
            XCTAssertEqual(things, results.data)
            XCTAssertEqual(newPage, results.meta?.next_token)
        }
    }
    
    func test_bogusJson() {
        model.handleSearchResult(data: "bogus json".data(using: .utf8)!, searchText: "", maxItemCount: 0, page: nil, currentCallCount: 0, maxCallCount: 0) { things, newPage in
            XCTAssertNil(things)
            XCTAssertNil(newPage)
        }
    }
    
    func test_emptyResults() {
        let results = ThingSearchResults()
        checkResponse(results)
    }
    
    func test_someResults() {
        let results = ThingSearchResults(data: [.init(id: "123", text: "hello", geo: .init(coordinates: .init(coordinates: [1, 2, 3])))])
        checkResponse(results)
    }
    func test_someResults2() {
        let results = ThingSearchResults(data: [.init(id: "123", text: "hello", geo: .init(coordinates: .init(coordinates: [1])))])
        checkResponse(results)
    }
    func test_someResults_nilCoordinates() {
        let results = ThingSearchResults(data: [.init(id: "123", text: "hello", geo: .init(coordinates: nil))])
        checkResponse(results)
    }
    func test_someResults_nilGeo() {
        let results = ThingSearchResults(data: [.init(id: "123", text: "hello", geo: nil)])
        checkResponse(results)
    }

    func test_newPage() {
        let results = ThingSearchResults(meta: .init(next_token: "newPage"))
        checkResponse(results)
    }
    
    func test_resultsCount() {
        let results = ThingSearchResults(meta: .init(result_count: 123))
        checkResponse(results)
    }
    
    func test_isSearching() {
        let results = ThingSearchResults(data: [.init(id: "123", text: "hello", geo: .init(coordinates: .init(coordinates: [1, 2, 3])))])
        let data = try! JSONEncoder().encode(results)
        
        XCTAssert(!model.isSearching)
        model.handleSearchResult(data: data, searchText: "", maxItemCount: 0, page: nil, currentCallCount: 0, maxCallCount: 0) { [self] things, newPage in
            XCTAssert(!model.isSearching)
        }
    }
    
    func test_calculatePins_normal() {
        let pins = model.calculatePins([.init(geo: .init(coordinates: .init(coordinates: [1, 2]))), .init(geo: .init(coordinates: .init(coordinates: [3, 4])))])
        XCTAssertEqual(pins.count, 2)
        XCTAssertEqual(pins[0].coordinate.longitude, 1)
        XCTAssertEqual(pins[0].coordinate.latitude, 2)
        XCTAssertEqual(pins[1].coordinate.longitude, 3)
        XCTAssertEqual(pins[1].coordinate.latitude, 4)
    }
    
    func test_calculatePins_mixedResults() {
        let pins = model.calculatePins([.init(geo: .init(coordinates: .init(coordinates: [1, 2]))), .init(geo: .init())])
        XCTAssertEqual(pins.count, 1)
        XCTAssertEqual(pins[0].coordinate.longitude, 1)
        XCTAssertEqual(pins[0].coordinate.latitude, 2)
    }

    func test_calculatePins_tooManyCoordinates() {
        let pins = model.calculatePins([.init(geo: .init(coordinates: .init(coordinates: [1, 2, 3])))])
        XCTAssertEqual(pins.count, 1)
        let pin = pins[0]
        XCTAssertEqual(pin.coordinate.longitude, 1)
        XCTAssertEqual(pin.coordinate.latitude, 2)
    }
    
    func test_calculatePins_notEnoughCoordinates() {
        let pins = model.calculatePins([.init(geo: .init(coordinates: .init(coordinates: [1])))])
        XCTAssert(pins.isEmpty)
    }
    
    func test_calculatePins_emptyCoordinates() {
        let pins = model.calculatePins([.init(geo: .init(coordinates: .init(coordinates: [])))])
        XCTAssert(pins.isEmpty)
    }
    
    func test_calculatePins_nilCoordinates() {
        let pins = model.calculatePins([.init(geo: .init(coordinates: .init()))])
        XCTAssert(pins.isEmpty)
    }
    
    func test_calculatePins_nilCoordinates2() {
        let pins = model.calculatePins([.init(geo: .init())])
        XCTAssert(pins.isEmpty)
    }
    func test_calculatePins_nilCoordinates3() {
        let pins = model.calculatePins([.init()])
        XCTAssert(pins.isEmpty)
    }
    func test_calculatePins_emptyCoordinates4() {
        let pins = model.calculatePins([])
        XCTAssert(pins.isEmpty)
    }
     */
}
