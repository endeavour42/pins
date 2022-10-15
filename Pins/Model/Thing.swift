 //
//  Thing.swift
//  Pins
//
//  Created by Mike on 12/08/2021.
//

import Foundation

struct Geo: Codable, Equatable {
    struct Coordinates: Codable, Equatable {
        var coordinates: [Double]? = nil
    }
    var coordinates: Coordinates? = nil
}

struct User: Codable, Equatable {
    let id: String
    let name: String
    let profile_image_url: String
    let username: String
}

struct StreamEvent: Codable, Equatable {
    struct StreamData: Codable, Equatable {
        var author_id: String? = nil
        var geo: Geo? = nil
        var id: String
        var text: String
    }
    struct Includes: Codable, Equatable {
        var users: [User]
    }
    let data: StreamData
    var includes: Includes? = nil
    
    var author: String? {
        // TODO
        nil
    }
    
    var profile_image_url: URL? {
        guard let string = (includes?.users.first { $0.id == data.author_id })?.profile_image_url else {
            return nil
        }
        return URL(string: string)
    }
}

struct AddRule: Codable {
    struct Rule: Codable {
        let value: String
        var tag: String? = nil
    }
    let add: [Rule]
}

struct DeleteRules: Codable {
    struct Rule: Codable {
        let ids: [String]
    }
    let delete: Rule
}

struct Rule: Codable {
    struct RuleData: Codable {
        let id: String
        let value: String
        let tag: String?
    }
    let data: [RuleData]?
}

struct UsageCap: Codable {
    let account_id: Int?
    let product_name: String?
    let title: String   // UsageCapExceeded, ConnectionException
    let period: String? // Monthly
    let scope: String?  // Product
    let detail: String  // Usage cap exceeded: Monthly product cap
    let type: String   // https://api.twitter.com/2/problems/usage-capped
}

