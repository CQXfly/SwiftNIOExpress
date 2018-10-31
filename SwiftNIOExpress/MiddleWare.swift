//
//  MiddleWare.swift
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


public typealias Next = ( Any... ) -> Void

public typealias Middleware =
    ( IncomingMessage,
    ServerResponse,
    @escaping Next ) -> Void
