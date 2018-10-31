//
//  IncomingMessage.swift
//  SwiftNIOExpress
//
//  Created by fox on 2018/10/31.
//  Copyright © 2018 fox. All rights reserved.
//

import Foundation
import NIO
import NIOTransportServices
import NIOHTTP1
import Network

fileprivate let paramDictKey =
"param"

open class IncomingMessage {
    
    public let header   : HTTPRequestHead
    public var userInfo = [ String : Any ]()
    
    init(header: HTTPRequestHead) {
        self.header = header
    }
}


public extension IncomingMessage {
    
    /// Access query parameters, like:
    ///
    ///     let userID = req.param("id")
    ///     let token  = req.param("token")
    ///
    func param(_ id: String) -> String? {
        return (userInfo[paramDictKey]
            as? [ String : String ])?[id]
    }
}


public
func querystring(req  : IncomingMessage,
                 res  : ServerResponse,
                 next : @escaping Next)
{
    // use Foundation to parse the `?a=x`
    // parameters
    if let queryItems = URLComponents(string: req.header.uri)?.queryItems {
        req.userInfo[paramDictKey] =
            Dictionary(grouping: queryItems, by: { $0.name })
                .mapValues { $0.compactMap({ $0.value })
                    .joined(separator: ",") }
    }
    
    // pass on control to next middleware
    next()
}
