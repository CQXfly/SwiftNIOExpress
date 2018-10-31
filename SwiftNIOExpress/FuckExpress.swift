//
//  FuckExpress.swift
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

protocol App {
    
    var loopGroup: MultiThreadedEventLoopGroup {get set}
    
    func listen(port: Int)
}

extension App {
    func listen(port: Int) {
        let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: loopGroup).serverChannelOption(ChannelOptions.backlog, value: 256).serverChannelOption(reuseAddrOpt, value: 1).childChannelInitializer { channel in
            channel.pipeline.configureHTTPServerPipeline(first: false, withPipeliningAssistance: true, withServerUpgrade: nil, withErrorHandling: true).then{_ in
                channel.pipeline.add(handler: HTTP1ServerHandler(router: self as! Middle))
                }.then{
                    channel.pipeline.add(handler: HTTP1ServerOutHandler())
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


protocol Middle {
    var middlewares:[(IncomingMessage,ServerResponse)->()] {get set}
    mutating func use(_ middleware:@escaping (IncomingMessage,ServerResponse)->())
    mutating func handler(req: IncomingMessage,res: ServerResponse)
}

extension Middle {
    mutating func use(_ middleware: @escaping (IncomingMessage,ServerResponse)->()) {
        self.middlewares.append(middleware)
    }
    
    mutating func handler(req: IncomingMessage,res: ServerResponse) {
        var arr = self.middlewares[self.middlewares.indices]
        
        while arr.count > 0 {
            guard var a = arr.popFirst() else {
                break
            }
            
            a(req,res)
            
        }
        
    }
}


protocol Router1: Middle {
    
    var part: String {get set}
    
    mutating func get(_ part: String, _ middleware: @escaping (IncomingMessage, ServerResponse) -> ())
    func post()
}

extension Router1 {
    mutating func get(_ path: String, _ middleware: @escaping (IncomingMessage, ServerResponse) -> ()) {
        
        let selfPointer = UnsafeMutablePointer(&self)
        use { (req, res) in
            guard req.header.method == .GET,
                req.header.uri.hasPrefix(selfPointer.pointee.part + path)
                else { return }
            
            middleware(req,res)
        }
    }
}

open class FuckExpress: App, Router1 {
    var part: String = ""
    
    func post() {
        
    }
    

    var middlewares: [(IncomingMessage, ServerResponse) -> ()] = []
    
    var loopGroup: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
}



