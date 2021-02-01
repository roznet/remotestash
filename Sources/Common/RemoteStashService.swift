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

class RemoteStashService : NSObject,NetServiceDelegate,URLSessionTaskDelegate {
    
    static let kNotificationNewServiceDiscovered = Notification.Name("kNotificationNewServiceDiscovered")
    
    typealias ResolvedHandler = (RemoteStashService) -> Void
    typealias CompletionHandler = (RemoteStashService,RemoteStashItem?) -> Void
    
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
        NotificationCenter.default.post(name: RemoteStashService.kNotificationNewServiceDiscovered, object: self)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        if let handler = self.resolvedHandler {
            handler(self)
        }
    }
    func request(path : String, method : String = "GET") -> URLRequest?{
        // first see if we have an ipv4 address
        for address in self.addresses {
            if address.ipv4 {
                if let url = address.url(path:path) {
                    var rv = URLRequest(url: url)
                    rv.httpMethod = method
                    return rv
                }
            }
        }
        // if not ipv4 take the first one that works
        for address in self.addresses {
            if let url = address.url(path: path) {
                var rv = URLRequest(url: url)
                rv.httpMethod = method
                return rv
            }
        }
        return nil
    }
    
    func startTask(request : URLRequest, completion : @escaping CompletionHandler){
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
                completion(self,nil)
            }
        }
        self.task?.resume()
    }
    
    func pushItem(item : RemoteStashItem, completion : @escaping CompletionHandler){
        guard var request = self.request(path: "push", method: "POST") else { return }
        request.httpBody = item.httpBody
        request.addValue(item.httpContentTypeHeader, forHTTPHeaderField: "Content-Type")
        self.startTask(request: request, completion: completion)
    }
    
    func pullItem(completion: @escaping CompletionHandler){
        guard let request = self.request(path: "pull") else { return }
        self.startTask(request: request, completion: completion)
    }
    
    func status(completion: @escaping CompletionHandler){
        guard let request = self.request(path: "status") else { return }
        self.startTask(request: request, completion: completion)
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
