//
//  Utils.swift
//  PryvApiSwiftKit
//
//  Created by Sara Alemanno on 03.06.20.
//  Copyright © 2020 Pryv. All rights reserved.
//

import Foundation

class Utils {
    private let regexAPIandToken = "/(.+):\\/\\/(.+)@(.+)/gm"
    private let regexSchemaAndPath = "/(.+):\\/\\/(.+)/gm"
    
    init() {
        
    }

    /// Returns the token and the endpoint from an API endpoint
    /// - Parameter apiEndpoint
    /// - Returns: a tuple containing the endpoint and the token (optionnal)
    public func extractTokenAndEndpoint(apiEndpoint: String) -> (String, String?) {
        var apiEp = apiEndpoint
        if !apiEp.hasSuffix("/") {
            apiEp += "/" // add a trailing '/' to end point if missing
        }
        
        let res = regexExec(pattern: regexAPIandToken, string: apiEp)
        if !res.isEmpty { // has token
            return (endpoint: res[1] + "://" + res[3], token: res[2])
        }
        
        let res2 = regexExec(pattern: regexSchemaAndPath, string: apiEp)
        if res2.isEmpty {
          print("Problem occurred when extracting the endpoint: cannot find endpoint, invalid URL format")
        }

        return (endpoint: res2[1] + "://" + res2[2], token: nil)
    }
    
    /// Constructs the API endpoint from the endpoint and the token
    /// - Parameters:
    ///   - endpoint
    ///   - token (optionnal)
    /// - Returns: API Endpoint
    public func buildPryvApiEndPoint(endpoint: String, token: String?) -> String? {
        var ep = endpoint
        if !ep.hasSuffix("/") { 
          ep += "/" // add a trailing '/' to end point if missing
        }
        
        if let token = token {
            var res = regexExec(pattern: regexSchemaAndPath, string: ep)
            if !res[2].hasSuffix("/") {
              res[2] += "/"
            }
            return res[1] + "://" + token + "@" + res[2]
        }
        
        return ep
    }
    
    /// Reproduces the behavior of regex.exec() in javascript to split the string according to a given pattern
    /// - Parameters:
    ///   - pattern
    ///   - string
    /// - Returns: an array of the ordered elements in string that match with the pattern
    private func regexExec(pattern: String, string: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = string as NSString
        
        guard let matches = regex.firstMatch(in: string, range: NSMakeRange(0, nsString.length)) else { return [] }
        var result = [String]()
        
        for i in 1..<matches.numberOfRanges {
            result.append(nsString.substring(with: matches.range(at: i)))
        }
        
        return result
    }
    
}