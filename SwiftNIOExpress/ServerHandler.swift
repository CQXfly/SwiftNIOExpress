//
//  ServerHandler.swift
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

final class HTTP1ServerOutHandler: ChannelOutboundHandler {
    
    typealias OutboundIn = HTTPServerResponsePart
    
    
    func read(ctx: ChannelHandlerContext) {
        ctx.read()
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        
        ctx.write(data, promise: promise)
        
    }
    
    
}

final class HTTP1ServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    
    var router : Middle
    
    init(router: Middle) {
        self.router = router
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        
        print(part)
        
//        guard case .head = part else {
//            return
//        }
        
        
        switch part {
        case .head(let head):
            let req = IncomingMessage(header: head)
            let res = ServerResponse(channel: ctx.channel)
            self.router.handler(req: req, res: res)
        default:
            break  
        }
        
//        let responseHeaders = HTTPHeaders([("server", "nio-transport-services"), ("content-length", "0")])
//        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: responseHeaders)
//        ctx.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
//        ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}
