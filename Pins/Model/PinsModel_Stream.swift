//
//  PinsModel_Stream.swift
//  Pins
//
//  Created by Mike on 12/08/2021.
//

import Foundation

extension PinsModel {
    
    private var ruleEndpoint: String { "https://api.twitter.com/2/tweets/search/stream/rules" }
    
    private var streamEndpoint: String { "https://api.twitter.com/2/tweets/search/stream?tweet.fields=geo&expansions=author_id,geo.place_id&user.fields=profile_image_url" }

    @discardableResult
    private func newTask(isStream: Bool = false, method: HttpMethod = .get, endpoint: String, setContentType: Bool = true, body: Data? = nil, callback: ((Data?, URLResponse?, Error?) -> Void)?) -> URLSessionDataTask? {
        
        guard let url = URL(string: endpoint) else {
            delayedLastError = NSError(domain: "X", code: -1, userInfo: [NSLocalizedDescriptionKey : "bad url"])
            callback?(nil, nil, delayedLastError)
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if setContentType {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.addValue("Bearer \(securityToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        
        let task: URLSessionDataTask
        
        if isStream {
            request.timeoutInterval = 1000
            task = session.dataTask(with: request)
        } else {
            task = session.dataTask(with: request) { [self] data, response, error in
                if let err = error ?? response?.httpError {
                    delayedLastError = err
                } else if let data = data, !data.isEmpty {
                    #if DEBUG
                    print("\(String(describing: String(data: data, encoding: .utf8)))")
                    #endif
                    callback?(data, response, error)
                } else {
                    delayedLastError = NSError(domain: "X", code: -1, userInfo: [NSLocalizedDescriptionKey : "something went wrong"])
                }
            }
        }
        task.resume()
        return task
    }
    
    private func addRule(_ value: String, tag: String? = nil, callback: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let rule = AddRule(add: [.init(value: value, tag: tag)])
        do {
            let data = try JSONEncoder().encode(rule)
            newTask(method: .post, endpoint: ruleEndpoint, body: data, callback: callback)
        } catch {
            delayedLastError = error
            callback(nil, nil, error)
        }
    }
    
    private func listRules(callback: @escaping ([String]) -> Void) {
        newTask(endpoint: ruleEndpoint) { [self] data, response, error in
            if let data = data {
                do {
                    let rule = try JSONDecoder().decode(Rule.self, from: data)
                    let ids = rule.data?.map { $0.id }
                    callback(ids ?? [])
                } catch {
                    delayedLastError = error
                    callback([])
                }
            } else {
                callback([])
            }
        }
    }
    
    private func deleteRules(_ ids: [String], callback: @escaping (Data?, URLResponse?, Error?) -> Void) {
        if ids.isEmpty {
            callback(nil, nil, nil)
            return
        }
        let rule = DeleteRules(delete: .init(ids: ids))
        do {
            let data = try JSONEncoder().encode(rule)
            newTask(method: .post, endpoint: ruleEndpoint, body: data, callback: callback)
        } catch {
            delayedLastError = error
            callback(nil, nil, error)
        }
    }
    
    private func startStreamPrivate() {
        streamTask = newTask(isStream: true, endpoint: streamEndpoint, setContentType: false, callback: nil)
    }
    
    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
    }
    
    func startStream(_ value: String) {
        listRules { [self] ids in
            deleteRules(ids) { data, response, error in
                addRule(value) { data, response, error in
                    startStreamPrivate()
                }
            }
        }
    }
}

