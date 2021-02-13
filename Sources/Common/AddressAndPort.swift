//
//  AddressAndPort.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 31/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import os

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash", category: "AddressAndPort")

struct AddressAndPort : CustomStringConvertible{
    
    #if targetEnvironment(simulator)
    static let wifiInterface = "en0"
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
        if self.ipv4 {
            return "AddressAndPort(ipv4 \(ip):\(port))"
        }else {
            return "AddressAndPort(ipv6 [\(ip)]:\(port))"
        }
    }
    
    func url(path : String?) -> URL? {
        
        let route = (path != nil) ? "/\(path!)" : ""
        
        if family == AF_INET6 {
            return URL(string: "https://[\(ip)]:\(port)\(route)" )
        }else {
            return URL(string: "https://\(ip):\(port)\(route)" )
        }
    }
    
    /// Extract AddressAndPort from a socket
    /// - Parameters:
    ///   - ptr: Pointer to a buffer sockaddr, typically either an underlying sockaddr_in or sockaddr_in6
    ///   - port: optional port to override value from the socket if only the ip address is of interest
    init( ptr : UnsafeBufferPointer<sockaddr>, port: Int? = nil ){
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var service  = [CChar](repeating: 0, count: Int(NI_MAXSERV))
        
        if getnameinfo(ptr.baseAddress,
                       socklen_t(ptr.count),
                       &hostname, socklen_t(hostname.count),
                       &service, socklen_t(service.count),
                       NI_NUMERICHOST|NI_NUMERICSERV) == 0 {
            self.port = port ?? (String(cString: service) as NSString).integerValue
            var ip = String(cString: hostname)
            if ip.contains("%"),
               let base = ip.split(separator: "%").first { // Remove %en0 and other interface tag
                ip = String(base)
            }
            self.ip = ip
            self.family = ptr.baseAddress?.pointee.sa_family ?? sa_family_t(AF_INET)
        }else{
            self.port = 0
            self.ip = "0.0.0.0"
            self.family = sa_family_t(AF_INET)
        }
    }
    
    /// Will open and immediately close an ipv4 UDP socket to find an avaialble port
    /// - Returns: free port number
    static func availablePort() -> AddressAndPort? {
        var rv : AddressAndPort? = nil
        
        // Create the c structure and get the size with MemoryLayout
        var addr = sockaddr_in()
        var size : socklen_t = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = in_addr(s_addr: INADDR_ANY)
        addr.sin_port = 0
        // Use UDP socket so it can close immediately and release the port
        let sockfd = socket(AF_INET,SOCK_DGRAM,0)
        
        // Now we want to do the equivalent of c typecast:
        //    sockaddr_in * addr
        //    bind( (sockaddr*)&addr, ... )
        
        // First convert the structure memory to Data
        var data = Data(bytes: &addr, count: Int(size))
        // Then create a memory buffer with the Data object
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) -> Void in
            // finally cast the pointer to the buffer as a sockaddr
            let ptr = pointer.bindMemory(to: sockaddr.self)
            // Pass the sockaddr pointer to bind (the point actually points to a sockaddr_in)
            let bindrv = bind(sockfd, ptr.baseAddress, size)
            if bindrv == 0 {
                let namerv = getsockname(sockfd, ptr.baseAddress, &size)
                if namerv == 0 {
                    rv = AddressAndPort(ptr: UnsafeBufferPointer<sockaddr>(ptr) )
                }else{
                    logger.error("getsockname failed with error \(namerv)")
                }
            }else{
                logger.error("bind socket failed with error \(bindrv)")
            }
        }
        close(sockfd)
        
        return rv
    }
    
    static func availableAddresses(_ port : Int? = nil) -> [AddressAndPort] {
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
                    addresses.append( AddressAndPort(ptr: sockaddrPtr, port: port) )
                }
            }
        }
        freeifaddrs(ifaddr)
        return addresses
    }

}
