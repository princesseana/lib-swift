//
//  Connection.swift
//  PryvApiSwiftKit
//
//  Created by Sara Alemanno on 03.06.20.
//  Copyright © 2020 Pryv. All rights reserved.
//

import Foundation

public class Connection {
    private let utils = Utils()
    
    private var apiEndpoint: String
    private var endpoint: String
    private var token: String?
    
    /// Creates a connection object from the api endpoint
    /// - Parameter apiEndpoint
    init(apiEndpoint: String) {
        self.apiEndpoint = apiEndpoint
        (self.endpoint, self.token) = utils.extractTokenAndEndpoint(apiEndpoint: apiEndpoint) ?? ("", nil)
    }
    
    // MARK: - public library
    
    /// Getter for the field `apiEndpoint`
    /// - Returns: the api endpoint given in the constructor
    public func getApiEndpoint() -> String {
        return apiEndpoint
    }
    
    /// Issue a [Batch call](https://api.pryv.com/reference/#call-batch)
    /// - Parameter APICalls: array of method calls in json formatted string
    /// - Returns: array of results matching each method call in order
    public func api(APICalls: String, handleResults: [Int: (([String: Any]) -> ())]? = nil) -> [[String: Any]]? {
        guard let url = URL(string: apiEndpoint) else { print("problem encountered: cannot access register url \(apiEndpoint)") ; return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(APICalls.utf8)
        
        var events: [[String: Any]]? = nil // array of json objects corresponding to events
        let group = DispatchGroup()
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let _ = error, data == nil { print("problem encountered when requesting login") ; group.leave() ; return }
            
            guard let callBatchResponse = data, let jsonResponse = try? JSONSerialization.jsonObject(with: callBatchResponse), let dictionary = jsonResponse as? [String: Any] else { print("problem encountered when parsing the call batch response") ; group.leave() ; return }
            
            let results = dictionary["results"] as? [[String: [String: Any]]]
            events = results?.map { result in
                result["event"] ?? [String: Any]()
            }
            
            group.leave()
        }
        
        group.enter()
        task.resume()
        group.wait()
        
        guard let callbacks = handleResults, let result = events else { return events }
        
        for (i, callback) in callbacks {
            if i >= result.count { print("problem encountered when applying the callback \(i): index out of bounds") ; return result }
            callback(result[i])
        }
        
        return result
    }
    
    /// Add Data Points to HFEvent (flatJSON format) as described in the [reference API](https://api.pryv.com/reference/#add-hf-series-data-points)
    /// - Parameters:
    ///   - eventId
    ///   - fields
    ///   - points
    public func addPointsToHFEvent(eventId: String, fields: [String], points: [[Any]]) {
        let payload: [String: Any] = [
            "format": "flatJSON",
            "fields": fields,
            "points": points
        ]
        let string = apiEndpoint.hasSuffix("/") ? apiEndpoint + "events/\(eventId)/series" : apiEndpoint + "/events/\(eventId)/series"
        guard let url = URL(string: string) else { print("problem encountered: cannot access register url \(string)") ; return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let _ = error, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 { print("problem encountered when requesting to add a high frequency event") ; return }
        }
        
        task.resume()
    }
    
    /// Create an event with attached file
    /// - Parameters:
    ///   - event
    ///   - filePath
    /// - Returns: the created event
    public func createEventWithFile(event: [String: Any], filePath: String) -> [String: Any]? {
        // TODO: convert file into formdata and call createeventwithformdata
        return nil
    }
    
    /// Create an event with attached file encoded as [multipart/form-data content](https://developer.mozilla.org/en-US/docs/Web/API/FormData/FormData)
    /// - Parameters:
    ///   - event: json formatted dictionnary corresponding to the new event to create
    ///   - parameters: the string parameters for the add attachement(s) request
    ///   - files: the attachement(s) to add
    /// - Returns: the newly created event with attachment(s) corresponding to `parameters` and `files`
    public func createEventWithFormData(event: [String: Any], parameters: [String: String]?, files: [Media]?) -> [String: Any]? {
        var event = sendCreateEventRequest(payload: event)
        guard let eventId = event?["id"] as? String else { print("problem encountered when creating the event") ; return nil }
    
        let boundary = "Boundary-\(UUID().uuidString)"
        let httpBody = createData(with: boundary, from: parameters, and: files)
        event = addAttachmentToEvent(eventId: eventId, boundary: boundary, httpBody: httpBody)
        
        return event
    }
    
    // MARK: - private helpers functions for the library
        
    /// Send an `events.create` request
    /// - Parameter payload: json formatted dictionnary corresponding to the new event to create
    /// - Returns: the newly created event
    private func sendCreateEventRequest(payload: [String: Any]) -> [String: Any]? {
        let string = apiEndpoint.hasSuffix("/") ? apiEndpoint + "events" : apiEndpoint + "/events"
        guard let url = URL(string: string) else { print("problem encountered: cannot access register url \(string)") ; return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        var result: [String: Any]? = nil
        let group = DispatchGroup()
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let _ = error, data == nil { print("problem encountered when requesting event") ; group.leave() ; return }
            
            guard let eventResponse = data, let jsonResponse = try? JSONSerialization.jsonObject(with: eventResponse), let dictionary = jsonResponse as? [String: Any] else { print("problem encountered when parsing the event response") ; group.leave() ; return }
            
            result = dictionary["event"] as? [String: Any]
            group.leave()
        }
        
        group.enter()
        task.resume()
        group.wait()
        
        return result
    }
    
    /// Send a request to add an attachment to an existing event with id `eventId`
    /// - Parameters:
    ///   - eventId
    ///   - boundary: the boundary corresponding to the attachement to add
    ///   - httpBody: the data corresponding to the attachement to add
    /// - Returns: the event with id `eventId` with an attachement
    private func addAttachmentToEvent(eventId: String, boundary: String, httpBody: Data) -> [String: Any]? {
        var result: [String: Any]? = nil
        
        let string = apiEndpoint.hasSuffix("/") ? apiEndpoint + "events/\(eventId)" : apiEndpoint + "/events/\(eventId)"
        guard let url = URL(string: string) else { print("problem encountered: cannot access register url \(string)") ; return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        let group = DispatchGroup()
        let task = URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let _ = error, data == nil { print("problem encountered when requesting event from form data") ; group.leave() ; return }
            
            guard let eventResponse = data, let jsonResponse = try? JSONSerialization.jsonObject(with: eventResponse), let dictionary = jsonResponse as? [String: Any] else { print("problem encountered when parsing the event response") ; group.leave() ; return }
            
            result = dictionary["event"] as? [String: Any]
            group.leave()
        }
        
        group.enter()
        task.resume()
        group.wait()
        
        return result
    }
    
    
    /// Create `Data` from the `parameters` and the `files` encoded as [multipart/form-data content](https://developer.mozilla.org/en-US/docs/Web/API/FormData/FormData)
    /// - Parameters:
    ///   - boundary: the boundary of the multipart/form-data content
    ///   - parameters: the string parameters
    ///   - files: the attachement(s)
    /// - Returns: the data as `Data` corresponding with `boundary`, `parameters` and `files`
    private func createData(with boundary: String, from parameters: [String: String]?, and files: [Media]?) -> Data {
        var body = Data()
        
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(value)\r\n")
            }
        }
        
        if let files = files {
            for item in files {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(item.key)\"; filename=\"\(item.filename)\"\r\n")
                body.append("Content-Type: \(item.mimeType)\r\n\r\n")
                body.append(item.data)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        return body
    }
    
}
