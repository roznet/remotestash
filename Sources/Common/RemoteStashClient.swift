//
//  RemoteStashClient.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 31/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import os

@objc protocol RemoteStashClientDelegate {
    func remoteStashClient( _ client : RemoteStashClient, add service : RemoteStashService)
    func remoteStashClient( _ client : RemoteStashClient, shouldAdd service : RemoteStashService) -> Bool
}

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash", category: "client")

class RemoteStashClient : NSObject,NetServiceBrowserDelegate{
    
    
    let delegate : RemoteStashClientDelegate
    let browser : NetServiceBrowser
    
    var services : [RemoteStashService] = []
    
    var service : RemoteStashService? {
        if self.currentServiceIndex < 0 || self.currentServiceIndex >= self.services.count {
            return self.services.last
        }
        return self.services[self.currentServiceIndex]
    }
    
    private var pendingServices : [RemoteStashService] = []
    private var currentServiceIndex : Int = -1
    
    init(delegate: RemoteStashClientDelegate) {
        self.delegate = delegate
        self.browser = NetServiceBrowser()
        
        super.init()
        self.browser.delegate = self
        self.browser.searchForServices(ofType: "_remotestash._tcp", inDomain: "")
    }
    
    deinit {
        self.browser.stop()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let pending = RemoteStashService(service: service ) { one in
            if one.ready {
                let same = self.services.filter { $0.same(as:one) }
                if same.count != 0 {
                    logger.info("Discovered \(one), but already added")
                }else if !self.delegate.remoteStashClient(self, shouldAdd: one){
                    logger.info("Discovered \(one), but should not add")
                }else{
                    logger.info("Discovered \(one), added")
                    if self.currentServiceIndex < 0 {
                        self.currentServiceIndex = self.services.count
                    }
                    self.services.append(one)
                    self.delegate.remoteStashClient(self, add: one)
                }
            }else {
                logger.error("Failed to resolve \(service)")
            }
        }
        self.pendingServices.append(pending)
    }
    
    
}
