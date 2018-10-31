# SwiftNIOExpress

* 参照Node Express 框架的swift 实现 基于 SwiftNIO

Express 中 设计一个简易WebApp 可以这样做 
```
let app = Express()
// 路由
app.get('/', function(req, res) {
  res.send('hello world');
});

// 中间件
app.get('/', function (req, res) {
  res.send('Hello World!');
});

app.listen(3000)

```

所以我们也准备实现一个这样的框架，先定一个小目标 路由， 中间件 这两个可以实现。

废话少说 我们先实现这个 `app.listen(3000)`


定义如下协议
```
protocol App {
    
    var loopGroup: MultiThreadedEventLoopGroup {get set}
    
    func listen(port: Int)
}
```

* loopGroup SwiftNIO 中处理I/O 的基本单元是 `eventloop` 所以我们的app 必须要有这个玩意； `eventloop` 由 `eventloopGroup` 管理调度。
* listen() 实现该方法 我们即可 监听端口，处理请求。

- 这里好好说下listen()
  ```
  {
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
  ```
  稍作解析， 启动器`ServerBootstrap` 会去初始化我们的socket。 了解swiftnio的人应该很清楚的明白，这里建立了 channelPipline 同时接受 channelHandler 去处理 I/O. 
  重点说下 `channel.pipline.add` 这里是添加了 channelHandler 来处理事件。 我们可以添加 inhandler 与 outhandle 可以去处理一个完整的I/O 流。
  
  该协议扩展实现了 listen 函数 所以我们很轻松的可以 遵循 app 协议，去实现一个Express 类。
  ```
  open class FuckExpress: App {
  } 
  ```
  至此 完成 app.listen() 调试 inhandler 中的channelRead 可以看到一个请求。
  
  
  中间件
  > 中间件 可以理解为 这样的模型 `(incommingMessage, response) -> ()`. 对于 请求，会去在中间件中过一遍，每个中间件可以处理某种具体的共性业务逻辑，如 检查用户权限，ip 限流 cors。。。 
  
  实现 这样的接口 `app.use(middleware)`
  
  定义协议
  ```
  protocol Middle {
    var middlewares:[(IncomingMessage,ServerResponse)->()] {get set}
    mutating func use(_ middleware:@escaping (IncomingMessage,ServerResponse)->())
    mutating func handler(req: IncomingMessage,res: ServerResponse)
  }
  ```
  
  在这可能会疑惑 handler 是干啥的？明显 中间件是被存储起来的，handler 的操作无非是去做一个循环数组中的中间件 顺序执行。
  
  给出实现
  ```
      mutating func handler(req: IncomingMessage,res: ServerResponse) {
        var arr = self.middlewares[self.middlewares.indices]
        
        while arr.count > 0 {
            guard let a = arr.popFirst() else {
                break
            }
            a(req,res)
        }
        
    }
  ```
  
  那么handler是在哪里执行的呢？ 显然 我们的app 应该是有一个 middler 实例 供调用 handler方法。
  从上面的描述我们应该清楚，最适合 做这个事情的显然就是  channelread 方法。
  ```
  func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        print(part)
        switch part {
        case .head(let head):
            let req = IncomingMessage(header: head)
            let res = ServerResponse(channel: ctx.channel)
            self.router.handler(req: req, res: res)
        default:
            break  
        }
    }
  ```
  
  这样 我们可以做到 添加中间件的功能。
  
  一鼓作气 继续做下去，该实现一个路由
  
  ```
  app.get('/hi',middleware)
  
  let r = router()
  
  r.get('/hello', middleware)
  
  app.use('/a',r)
  
  ```
  
  我们可以知道 这个 路由一定是遵循 Middle协议了
  
  ```
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
  ```
  
 amazing 到了这儿 你就该发现 你的这个简易Express 已经可以运行了。
 
 
 ```
     func test() {
        var app = FuckExpress()
        
        
        app.use { (req, res) in
            print("11111")

        }
        
        app.use { (req, res) in
            print(req)
            print(res)
            
            print("2222222")

        }
        
        
        app.get("/a", {req,res in
            print("3333333")
            res.send("\(req.header)")
        })
        
        app.listen(port: 3000)
    }
 ```
 
 当然 到了这儿只是抛砖引玉，还有更好的实现大家可以讨论。同时本demo中有一个稍微完善的实现， 
 

 参考资料 ![swiftnio express](http://www.alwaysrightinstitute.com/microexpress-nio/)
  
 


