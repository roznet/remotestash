//
//  remotestashTests.swift
//  remotestashTests
//
//  Created by Brice Rosenzweig on 01/02/2021.
//

import Foundation
import XCTest
@testable import RemoteStash
import os
import UniformTypeIdentifiers

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash", category: "test")

class remotestashTests: XCTestCase,RemoteStashServerDelegate,RemoteStashClientDelegate {
    

    let stringPayload : String = "Hello World en français"
    let imagePayload : UIImage? = nil
    
    var server : RemoteStashServer? = nil
    var client : RemoteStashClient? = nil
    
    var gotService : XCTestExpectation? = nil
    var gotItem : XCTestExpectation? = nil
    
    let serverName : String = "__remoteStash__test__"
    
    var items : [RemoteStashItem] = []
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAddresses() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let add = AddressAndPort.availableAddresses()
        // Find 1 ipv4 at least
        let ipv4 = add.filter { $0.ipv4 }
        XCTAssertNotEqual(ipv4.count, 0)
        
        let avai = AddressAndPort.availablePort()
        XCTAssertNotEqual(avai?.port, 0)
    }
    
    func testItem() throws {
        if let image = UIImage(named: "702-share") {
            let imageitem = RemoteStashItem(image: image, type: "image/png", filename: "702-share.png")
            print( "\(imageitem.httpContentTypeHeader)" )
            
            let stringitem = RemoteStashItem(string: "hello world" )
            print( "\(stringitem.httpContentTypeHeader)" )

            
        }else{
            // failed to setup
            XCTAssertTrue(false)
        }
        
    }
    
    //MARK: - server test
    func testServer() throws {
        self.server  = RemoteStashServer(delegate: self, name: self.serverName)
        self.client = RemoteStashClient(delegate: self)
        
        let gotService = XCTestExpectation(description: "got client")
        let gotItem = XCTestExpectation(description: "got item")
        self.gotService = gotService
        self.gotItem = gotItem
        self.server?.start()
        
        wait(for: [gotService,gotItem], timeout: 3600.0)
    }

    func remoteStashClient(_ client: RemoteStashClient, shouldAdd service: RemoteStashService) -> Bool {
        return true
    }

    func remoteStashClient(_ client: RemoteStashClient, add service: RemoteStashService) {
        if service.name == self.serverName {
            self.gotService?.fulfill()
            remoteStatus(service: service)
        }else{
            logger.info("Skipping other service \(service)")
        }
    }
    
    func remoteStatus(service : RemoteStashService){
        service.status {
            _, status in
            XCTAssertNotNil(status)
            if  let status = status {
                XCTAssertEqual(status.itemsCount,0)
            }
            DispatchQueue.global(qos: .background).async {
                self.remotePush(service: service)
            }
        }
    }
    
    func remotePush(service: RemoteStashService){
        
        let item = RemoteStashItem(string: self.stringPayload, type: "text/plain", encoding: .utf8)
        service.pushItem(item: item) {
            _, item in
            if  let content = item?.content,
                case let RemoteStashItem.Content.data(data) = content,
                let status = try? JSONDecoder().decode(RemoteStashServer.Status.self, from: data){
                logger.info("push got \(status)")
            }
            DispatchQueue.global(qos: .background).async {
                self.remotePull(service: service)
            }

        }

    }
    
    func remotePull(service: RemoteStashService){
        service.pullItem {
            _, item in
            XCTAssertNotNil(item)
            if let item = item,
               case let RemoteStashItem.Content.string(str) = item.content{
                XCTAssertEqual(str, self.stringPayload)
            }else{
                XCTAssertTrue(false)
            }
            DispatchQueue.global(qos: .background).async {
                self.remoteFinished(service: service)
            }
        }
    }
    
    func remoteFinished(service: RemoteStashService){
        self.gotItem?.fulfill()
    }
    
    func serverStarted(_ server: RemoteStashServer) {
    }
    
    func server(_ server: RemoteStashServer, received: RemoteStashItem) {
        self.items.append(received)
    }
    
    func serverLastItem(_ server: RemoteStashServer) -> RemoteStashItem? {
        return self.items.last
    }
}
