//
//  RemoteStashServer.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 30/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import Criollo
import os

protocol RemoteStashServerDelegate {
    func serverStarted(_ server : RemoteStashServer)
    func server(_ server : RemoteStashServer, received : RemoteStashItem)
    func serverLastItem( _ server : RemoteStashServer) -> RemoteStashItem?
}

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash", category: "server")

class RemoteStashServer : NSObject,NetServiceDelegate,NetServiceBrowserDelegate {
    
    struct Status : Codable, CustomStringConvertible {
        enum CodingKeys : String, CodingKey {
            case itemsCount = "items_count"
            case last = "last"
        }
        
        var description: String{
            let last = self.last?.description ?? "none"
            return "Status(itemsCount: \(self.itemsCount), last: \(last))"
        }
        
        let itemsCount : Int
        let last : RemoteStashItem.Status?
    }
    
    let serverUUID :UUID
    let delegate : RemoteStashServerDelegate
    let name : String
    
    private let worker : DispatchQueue
    private var port : Int
    private var httpServer : CRHTTPServer? = nil
    private var service : NetService? = nil
    
    init(delegate : RemoteStashServerDelegate, name : String? = nil) {
        self.serverUUID = UUID()
        self.delegate = delegate
        self.name = name ?? "\(UIDevice.current.name) RemoteStash"
        self.worker = DispatchQueue(label: "net.ro-z.worker")
        self.port = 0
    }

    //MARK: - start/stop
    
    func start() {
        self.findPort()
        self.startBroadcast()
        self.startServer()
    }
    
    func stop(){
        self.service?.stop()
        self.httpServer?.stopListening()
    }

    //MARK: - get network info
    
    func findPort() {
        let port = AddressAndPort.availablePort()
        self.port = port?.port ?? 0
    }
    
    
    //MARK: start server and netservices
    
    func startServer() {
        let httpServer = CRHTTPServer()
        self.httpServer = httpServer
        
        httpServer.isSecure = true
        // Certificate created with
        // openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout remotestash-key.pem -out remotestash-cert.pem
        httpServer.certificatePath = Bundle.main.path(forResource: "remotestash-cert", ofType: "pem")
        httpServer.certificateKeyPath = Bundle.main.path(forResource: "remotestash-key", ofType: "pem")
        
        httpServer.get("/status") {
            (req, res, next) in
            let itemStatus : RemoteStashItem.Status? = self.delegate.serverLastItem(self)?.status
            let status : Status = Status(itemsCount: itemStatus != nil ? 1 : 0, last: itemStatus)
            if let data = try? JSONEncoder().encode(status) {
                res.addValue("application/json", forHTTPHeaderField: "Content-Type")
                res.send(data)
            }
        }
        
        httpServer.get("/pull"){
            (req,res,next) in
            if let item = self.delegate.serverLastItem(self) {
                item.prepare(request: req, into: res)
            }
        }
        
        httpServer.get("/last"){
            (req,res,next) in
            if let item = self.delegate.serverLastItem(self) {
                item.prepare(request: req, into: res)
            }
        }
        
        httpServer.post("/push"){
            (req,res,next) in
            let item = RemoteStashItem(request: req, response: res)
            self.delegate.server(self, received: item)
            res.send(["success":1])
            logger.info("pushed \(item)")
        }
        
        if httpServer.startListening(nil, portNumber: UInt(self.port)) {
            logger.info("started listening on \(self.port)")
        }else{
            logger.error("failed to started listening on \(self.port)")
        }
    }
    
    func startBroadcast() {
        let name = self.name
        let service = NetService(domain: "local.", type: "_remotestash._tcp", name: name, port: Int32(self.port))
        let txtRecord = [
            "temporary" : "yes".data(using: .utf8) ?? Data(),
            "uuid" : self.serverUUID.uuidString.data(using: .utf8) ?? Data()
        ]
        service.setTXTRecord(NetService.data(fromTXTRecord: txtRecord ) )
        
        logger.info("Starting broadcast \(self.port) \(self.serverUUID)")
        
        self.service = service
        self.service?.publish()
    }
    
    //MARK: - netService
    
    func netServiceDidPublish(_ sender: NetService) {
        logger.info("Published \(sender)")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        logger.info("Stop \(sender)")
    }
    
}
