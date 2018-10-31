//
//  ViewController.swift
//  SwiftNIOExpress
//
//  Created by fox on 2018/10/29.
//  Copyright © 2018 fox. All rights reserved.
//

import UIKit


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        test()
//        gosky()
        
    }
    
    
    func test() {
        var app = FuckExpress()
        
        
        app.use { (req, res) in
            print("11111")
//            res.send("hahahha")
        }
        
        app.use { (req, res) in
            print(req)
            print(res)
            
            print("2222222")
//            res.send("i'm ok")
        }
        
        
        app.get("/a", {req,res in
            print("3333333")
            res.send("\(req.header)")
        })
        
        app.listen(port: 3000)
    }
    
    
    func gosky() {
        var app = Express()
        app.use(querystring)
        app.use { (req, res, next) in
            print("1",req.userInfo)
            next()
        }
        
        app.get("/var") { (req, res, next) in
            res.send("fuck your")
        }
        
        var r = Router()
        r.get("/router") { (req, res, next) in
            
            res.send("router is ok")
        }
        
        
        r.post("/hi") { (req, res, next) in
            res.send("hello")
        }
        app.use("/s", router: &r)
        
        app.listen(8989)
    }

}

