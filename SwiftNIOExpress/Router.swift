//
//  Router.swift
//  SwiftNIOExpress
//
//  Created by fox on 2018/10/31.
//  Copyright © 2018 fox. All rights reserved.
//

import Foundation


protocol RouterProtocol {
    var part: String {get set}
    var middleware: [Middleware] {get set}
    mutating func use(_ middleware: Middleware...)
    mutating func handle(request        : IncomingMessage,
                response       : ServerResponse,
                next upperNext : @escaping Next)
    
}

extension RouterProtocol {
//    private var part : String = ""
    /// The sequence of Middleware functions.
//    private var middleware = [ Middleware ]()
    
    /// Add another middleware (or many) to the list
    public mutating func use(_ middleware: Middleware...) {
        self.middleware.append(contentsOf: middleware)
    }
    
    /// Request handler. Calls its middleware list
    /// in sequence until one doesn't call `next()`.
    func handle(request        : IncomingMessage,
                response       : ServerResponse,
                next upperNext : @escaping Next)
    {
        
        let state = State(middleware[middleware.indices],
                          request, response, upperNext)
        state.step()
    }
}


extension RouterProtocol {
    
    /// Register a middleware which triggers on a `GET`
    /// with a specific path prefix.
    public mutating func get(_ path: String = "",
                    middleware: @escaping Middleware)
    {
        let selfPointer = UnsafeMutablePointer(&self)
        use { req, res, next in
            guard req.header.method == .GET,
                req.header.uri.hasPrefix(selfPointer.pointee.part + path)
                else { return next() }
            
            middleware(req, res, next)
        }
    }
    
    public mutating func post(_ path: String = "",
                     middleware: @escaping Middleware)
    {
        let selfPointer = UnsafeMutablePointer(&self)
        use { req, res, next in
            guard req.header.method == .POST,
                req.header.uri.hasPrefix(selfPointer.pointee.part + path)
                else { return next() }
            
            middleware(req, res, next)
        }
    }
}

extension RouterProtocol  {
    
    public mutating func use(router:Router){
        let _ = router.middleware.map{
            self.middleware.append($0)
        }
    }
    
    public mutating func use(_ part:String,router:inout Router){
        router.part = part
        use(router: router)
    }
}


final class State {
    var stack    : ArraySlice<Middleware>
    let request  : IncomingMessage
    let response : ServerResponse
    var next     : Next?
    
    init(_ stack    : ArraySlice<Middleware>,
         _ request  : IncomingMessage,
         _ response : ServerResponse,
         _ next     : @escaping Next)
    {
        self.stack    = stack
        self.request  = request
        self.response = response
        self.next     = next
    }
    
    func step(_ args : Any...) {
        if let middleware = stack.popFirst() {
            middleware(request, response, self.step)
        }
        else {
            next?(); next = nil
        }
    }
}


open class Router: RouterProtocol {
    var part: String = ""
    
    var middleware: [Middleware] = [Middleware]()
    
    
}
