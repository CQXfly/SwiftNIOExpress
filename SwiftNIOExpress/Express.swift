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





