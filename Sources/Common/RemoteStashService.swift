//
//  RemoteStashService.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 31/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import os

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash", category: "service")

extension Notification.Name {
    static let remoteStashNewServiceDiscovered = Notification.Name( "remoteStashNewServiceDiscovered" )
}

class RemoteStashService : NSObject,NetServiceDelegate,URLSessionTaskDelegate {
      
    typealias ResolvedHandler = (RemoteStashService) -> Void
    typealias ItemHandler = (RemoteStashService,RemoteStashItem?) -> Void
    typealias StatusHandler = (RemoteStashService,RemoteStashServer.Status?) -> Void

    var addresses : [AddressAndPort] = []
    var items : [RemoteStashItem] = []
    
    let service : NetService
    
    var properties : [String:String] = [:]
    var serverUUID : UUID? = nil
    var temporary : Bool = true
    
    var ready : Bool {
        return self.serverUUID != nil && self.addresses.count > 0
    }
    
    var name : String { return self.service.name }
    var hostName : String? { return self.service.hostName }
    
    let resolvedHandler : ResolvedHandler?
    
    var request : URLRequest? = nil
    var session : URLSession? = nil
    var task : URLSessionDataTask? = nil
    
    override var description: String{
        var info : [String] = [ self.name ]
        if let h = self.hostName {
            info.append(h)
        }
        if let a = self.address,
           let u = a.url(path: nil){
            info.append(u.absoluteString)
        }
        let desc = info.joined(separator: ",")
        return "RemoteStashService(\(desc))"
    }
    
    var address : AddressAndPort? {
        // first see if we have an ipv4 address
        for address in self.addresses {
            if address.ipv4 && address.url(path: nil) != nil{
                return address
            }
        }
        // if not ipv4 take the first one that works
        for address in self.addresses {
            if address.url(path: nil) != nil {
                return address
            }
        }
        return nil
    }


    init(service : NetService, resolved : ResolvedHandler?) {
        self.service = service
        self.resolvedHandler = resolved
        
        super.init()
        
        self.session = URLSession(configuration: URLSession.shared.configuration, delegate: self, delegateQueue: nil)
        self.service.delegate = self
        self.service.resolve(withTimeout: 5.0)
    }
    
    func same(as other: RemoteStashService) -> Bool{
        return self.serverUUID != nil && self.serverUUID == other.serverUUID
    }
    
    //MARK: - NetService Delegate
        
    func netServiceDidResolveAddress(_ sender: NetService) {
        self.properties = [:]
        
        guard let senderAddresses = sender.addresses else { return }
        
        for data in senderAddresses {
            data.withUnsafeBytes { (pointer : UnsafeRawBufferPointer) -> Void in
                let sockaddrPtr : UnsafeBufferPointer<sockaddr> = pointer.bindMemory(to: sockaddr.self)
                
                let ipAndPort = AddressAndPort(ptr: sockaddrPtr)
                self.addresses.append(ipAndPort)
            }
        }
        
        if let data = sender.txtRecordData() {
            let txtRecord = NetService.dictionary(fromTXTRecord: data)
            for (key,val) in txtRecord {
                if let str = String(data: val, encoding: .utf8) {
                    self.properties[key] = str
                    if key == "uuid" {
                        self.serverUUID = UUID(uuidString: str)
                    }
                    if key == "temporary" {
                        self.temporary = str.starts(with: "y")
                    }
                }
            }
        }
        
        if let handler = self.resolvedHandler {
            handler(self)
        }
        NotificationCenter.default.post(name: Notification.Name.remoteStashNewServiceDiscovered, object: self)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        if let handler = self.resolvedHandler {
            handler(self)
        }
    }
    
    
    func request(path : String, method : String = "GET") -> URLRequest?{
        if let address = self.address,
           let url = address.url(path:path){
            var rv = URLRequest(url: url)
            rv.httpMethod = method
            return rv
        }
        return nil
    }
    
    func startTask(request : URLRequest, completion : @escaping ItemHandler){
        guard let session = self.session else { completion(self,nil); return }
        self.request = request
        
        self.task = session.dataTask(with: request) {
            (data,response,error) in
            if let response = response as? HTTPURLResponse,
               let data = data{
                let item = RemoteStashItem(data: data, response: response)
                self.items.append(item)
                completion(self,item)
            }else{
                let url = request.url?.absoluteString ?? "NoURL"
                logger.error("task failed \(url)")
                completion(self,nil)
            }
        }
        self.task?.resume()
    }
    
    func pushItem(item : RemoteStashItem?, completion : @escaping ItemHandler){
        guard let item = item, var request = self.request(path: "push", method: "POST") else { return }
        request.httpBody = item.httpBody
        request.addValue(item.httpContentTypeHeader, forHTTPHeaderField: "Content-Type")
        if let filename = item.filename {
            request.addValue("attachment; filename=\"\(filename)\"", forHTTPHeaderField: "Content-Disposition")
        }
        request.addValue("myheader", forHTTPHeaderField: "x-remotestash")
        self.startTask(request: request, completion: completion)
    }
    
    func pullItem(completion: @escaping ItemHandler){
        guard let request = self.request(path: "pull") else { return }
        self.startTask(request: request, completion: completion)
    }

    func lastItem(completion: @escaping ItemHandler){
        guard let request = self.request(path: "last") else { return }
        self.startTask(request: request, completion: completion)
    }

    func status(completion: @escaping StatusHandler){
        guard let request = self.request(path: "status") else { return }
        self.startTask(request: request){
            (service,item) in
            if  let content = item?.content,
                case let RemoteStashItem.Content.data(data) = content,
                let status = try? JSONDecoder().decode(RemoteStashServer.Status.self, from: data){
                completion(self,status)
            }else{
                completion(self,nil)
            }

        }
    }
    
    //MARK: - URLSession Delegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust,
           let certPath = Bundle.main.path(forResource: "remotestash-cert", ofType: "der"),
           let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
           let cert = SecCertificateCreateWithData(nil, certData as CFData),
           let remoteCert = SecTrustGetCertificateAtIndex(trust, 0) {
            SecTrustSetAnchorCertificates(trust, [cert] as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust, false)
            
            // First Check if just exactly the same certificate
            let remoteCertData = SecCertificateCopyData(remoteCert) as Data
            if remoteCertData == certData {
                completionHandler(.useCredential,URLCredential(trust: trust))
            }else {
                // Else check if pass trust
                var trustResult : SecTrustResultType = SecTrustResultType.invalid
                SecTrustGetTrustResult(trust, &trustResult)
                if trustResult == .unspecified || trustResult == .proceed {
                    completionHandler(.useCredential,URLCredential(trust: trust))
                }else{
                    completionHandler(.cancelAuthenticationChallenge,nil)
                }
            }
        }else{
            completionHandler(.cancelAuthenticationChallenge,nil)
        }
    }
}

extension RemoteStashService  {
    static func ==(lhs: RemoteStashService, rhs: RemoteStashService) -> Bool {
        return lhs.serverUUID == rhs.serverUUID
    }
    
    @objc override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? RemoteStashService else {
            return false
        }
        return self == object
    }
}

