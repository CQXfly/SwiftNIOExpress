//
//  Express.swift
//  SwiftNIOExpress
//
//  Created by fox on 2018/10/29.
//  Copyright © 2018 fox. All rights reserved.
//

import Foundation
import NIO
import NIOTransportServices
import NIOHTTP1
import Network

public func cors(allowOrigin origin: String)
    -> Middleware
{
    return { req, res, next in
        res["Access-Control-Allow-Origin"]  = origin
        res["Access-Control-Allow-Headers"] = "Accept, Content-Type"
        res["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        
        // we handle the options
        if req.header.method == .OPTIONS {
            res["Allow"] = "GET, OPTIONS"
            res.send("")
        }
        else { // we set the proper headers
            next()
        }
    }
}


open class IncomingMessage {
    
    public let header   : HTTPRequestHead
    public var userInfo = [ String : Any ]()
    
    init(header: HTTPRequestHead) {
        self.header = header
    }
}

public typealias Next = ( Any... ) -> Void

public typealias Middleware =
    ( IncomingMessage,
    ServerResponse,
    @escaping Next ) -> Void



fileprivate let paramDictKey =
"param"

/// A middleware which parses the URL query
/// parameters. You can then access them
/// using:
///
///     req.param("id")
///
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

open class Router {
    private var part : String = ""
    /// The sequence of Middleware functions.
    private var middleware = [ Middleware ]()
    
    /// Add another middleware (or many) to the list
    open func use(_ middleware: Middleware...) {
        self.middleware.append(contentsOf: middleware)
    }
    
    /// Request handler. Calls its middleware list
    /// in sequence until one doesn't call `next()`.
    func handle(request        : IncomingMessage,
                response       : ServerResponse,
                next upperNext : @escaping Next)
    {
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
        
        let state = State(middleware[middleware.indices],
                          request, response, upperNext)
        state.step()
    }
}

open class ServerResponse {
    
    public  var status         = HTTPResponseStatus.ok
    public  var headers        = HTTPHeaders()
    public  let channel        : Channel
    private var didWriteHeader = false
    private var didEnd         = false
    
    public init(channel: Channel) {
        self.channel = channel
    }
    
    /// An Express like `send()` function.
    open func send(_ s: String) {
        flushHeader()
        
        let utf8   = s.utf8
        var buffer = channel.allocator.buffer(capacity: utf8.count)
        buffer.write(bytes: utf8)
        
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        
        _ = channel.writeAndFlush(part)
            .mapIfError(handleError)
            .map { self.end() }
    }
    
    /// Check whether we already wrote the response header.
    /// If not, do so.
    func flushHeader() {
        guard !didWriteHeader else { return } // done already
        didWriteHeader = true
        
        let head = HTTPResponseHead(version: .init(major:1, minor:1),
                                    status: status, headers: headers)
        let part = HTTPServerResponsePart.head(head)
        _ = channel.writeAndFlush(part).mapIfError(handleError)
    }
    
    func handleError(_ error: Error) {
        print("ERROR:", error)
        end()
    }
    
    func end() {
        guard !didEnd else { return }
        didEnd = true
        _ = channel.writeAndFlush(HTTPServerResponsePart.end(nil))
            .map { self.channel.close() }
    }
}

public extension ServerResponse {
    
    /// A more convenient header accessor. Not correct for
    /// any header.
    public subscript(name: String) -> String? {
        set {
            assert(!didWriteHeader, "header is out!")
            if let v = newValue {
                headers.replaceOrAdd(name: name, value: v)
            }
            else {
                headers.remove(name: name)
            }
        }
        get {
            return headers[name].joined(separator: ", ")
        }
    }
}

import Foundation

public extension ServerResponse {
    
    /// Send a Codable object as JSON to the client.
    func json<T: Encodable>(_ model: T) {
        // create a Data struct from the Codable object
        let data : Data
        do {
            data = try JSONEncoder().encode(model)
        }
        catch {
            return handleError(error)
        }
        
        // setup JSON headers
        self["Content-Type"]   = "application/json"
        self["Content-Length"] = "\(data.count)"
        
        // send the headers and the data
        flushHeader()
        
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.write(bytes: data)
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        
        _ = channel.writeAndFlush(part)
            .mapIfError(handleError)
            .map { self.end() }
    }
}

public extension Router {
    
    /// Register a middleware which triggers on a `GET`
    /// with a specific path prefix.
    public func get(_ path: String = "",
                    middleware: @escaping Middleware)
    {
        use { req, res, next in
            guard req.header.method == .GET,
                req.header.uri.hasPrefix(self.part + path)
                else { return next() }
            
            middleware(req, res, next)
        }
    }
    
    public func post(_ path: String = "",
                     middleware: @escaping Middleware)
    {
        use { req, res, next in
            guard req.header.method == .POST,
                req.header.uri.hasPrefix(self.part + "/" + path)
                else { return next() }
            
            middleware(req, res, next)
        }
    }
}

public extension Router  {
    
    public func use(router:Router){
        let _ = router.middleware.map{
            self.middleware.append($0)
        }
    }
    
    public func use(_ part:String,router:Router){
        router.part = part
        use(router: router)
    }
}


open class Express : Router {
    
    override public init() {}
    
    let loopGroup =
        MultiThreadedEventLoopGroup(numThreads: System.coreCount)
    
    open func listen(_ port: Int) {
        let reuseAddrOpt = ChannelOptions.socket(
            SocketOptionLevel(SOL_SOCKET),
            SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: loopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddrOpt, value: 1)
            
            .childChannelInitializer { channel in
                channel.pipeline.addHTTPServerHandlers().then {
                    channel.pipeline.add(handler:
                        HTTPHandler(router: self))
                }
            }
            
            .childChannelOption(ChannelOptions.socket(
                IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,
                                value: 1)
        
        do {
            let serverChannel =
                try bootstrap.bind(host: "localhost", port: port)
                    .wait()
            print("Server running on:", serverChannel.localAddress!)
            
            try serverChannel.closeFuture.wait() // runs forever
        }
        catch {
            fatalError("failed to start server: \(error)")
        }
    }
    
    final class HTTPHandler : ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        
        let router : Router
        
        init(router: Router) {
            self.router = router
        }
        
        func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
            let reqPart = self.unwrapInboundIn(data)
            
            switch reqPart {
            case .head(let header):
                
                let req = IncomingMessage(header: header)
                let res = ServerResponse(channel: ctx.channel)
                //
                //                // trigger Router
                
                router.handle(request: req, response: res) {
                    (items : Any...) in // the final handler
                    res.status = .notFound
                    res.send("No middleware handled the request!")
                }
                
            // ignore incoming content to keep it micro :-)
            case .body, .end: break
            }
        }
    }
}


open class Express1 {
    //    override public init() {}
    let loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    open func listen(_ port: Int) {
        let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: loopGroup).serverChannelOption(ChannelOptions.backlog, value: 256).serverChannelOption(reuseAddrOpt, value: 1).childChannelInitializer { channel in
            channel.pipeline.configureHTTPServerPipeline(first: false, withPipeliningAssistance: true, withServerUpgrade: nil, withErrorHandling: true).then{
                channel.pipeline.add(handler: HTTP1ServerHandler())
            }
        }
        
        do {
            let serverChannel = try bootstrap.bind(host: "localhost", port: port).wait()
            print("server running on: \(serverChannel.localAddress!) ")
            try serverChannel.closeFuture.wait()
        } catch {
            
        }
    }
}


final class HTTP1ServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        
        guard case .head = part else {
            return
        }
        
        let responseHeaders = HTTPHeaders([("server", "nio-transport-services"), ("content-length", "0")])
        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: responseHeaders)
        ctx.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
        ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}
