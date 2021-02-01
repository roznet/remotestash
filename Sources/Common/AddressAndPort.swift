//
//  AddressAndPort.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 31/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation

struct AddressAndPort : CustomStringConvertible{
    
    #if targetEnvironment(simulator)
    static let wifiInterface = "en1"
    #else
    static let wifiInterface = "en0"
    #endif
    

    
    let ip : String
    let port : Int
    let family : sa_family_t
    
    var ipv4 : Bool {
        return family == sa_family_t(AF_INET)
    }
    
    var description: String {
        var familydesc = "\(family)"
        if self.ipv4 {
            familydesc = "ipv4"
        }else {
            familydesc = "ipv6"
        }
        return "\(ip):\(port) \(familydesc)"
    }
    
    func url(path : String) -> URL? {
        if family == AF_INET6 {
            return URL(string: "https://[\(ip)]:\(port)/\(path)" )
        }else {
            return URL(string: "https://\(ip):\(port)/\(path)" )
        }
    }
    
    init( ptr : UnsafeBufferPointer<sockaddr> ){
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var service  = [CChar](repeating: 0, count: Int(NI_MAXSERV))
        
        if getnameinfo(ptr.baseAddress,
                       socklen_t(ptr.count),
                       &hostname, socklen_t(hostname.count),
                       &service, socklen_t(service.count),
                       NI_NUMERICHOST|NI_NUMERICSERV) == 0 {
            self.port = (String(cString: service) as NSString).integerValue
            self.ip = String(cString: hostname)
            self.family = ptr.baseAddress?.pointee.sa_family ?? sa_family_t(AF_INET)
        }else{
            self.port = 0
            self.ip = "0.0.0.0"
            self.family = sa_family_t(AF_INET)
        }
    }
    
    static func availablePort() -> AddressAndPort? {
        let socket = SocketPort()
        var rv : AddressAndPort? = nil
        socket.address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Void in
            let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
            rv = AddressAndPort(ptr: sockaddrPtr)
        }
        socket.invalidate()
        return rv

    }
    
    static func availableAddresses() -> [AddressAndPort] {
        var addresses : [AddressAndPort] = []
        
        var ifaddrPtr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0,
              let ifaddr = ifaddrPtr
        else {
            return addresses
        }
        
        for ifptr in sequence(first: ifaddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == AF_INET || family == AF_INET6 {
                let name = String(cString: interface.ifa_name)
                if name == AddressAndPort.wifiInterface {
                    let sockaddrPtr = UnsafeBufferPointer<sockaddr>(start: interface.ifa_addr, count: Int(interface.ifa_addr.pointee.sa_len))
                    addresses.append( AddressAndPort(ptr: sockaddrPtr) )
                }
            }
        }
        freeifaddrs(ifaddr)
        return addresses
    }

}
