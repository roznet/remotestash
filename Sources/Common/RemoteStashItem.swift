//
//  RemoteStashItem.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 30/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import MobileCoreServices
import Criollo

extension String.Encoding {
    
    init(inia: String){
        self.init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(inia as CFString) ) )
    }
}

class RemoteStashItem {
    struct Status : Codable, CustomStringConvertible {
        let size : Int
        let contentType : String
        let filename : String?
        
        var description: String {
            let file = filename ?? "nil"
            return "Status(size: \(size), contentType: \(contentType), filename: \(file)"
        }
    }
    
    enum Content {
        case image(UIImage)
        case string(String)
        case data(Data) // data and content-type
        case empty
        
        func size() -> Int {
            switch self {
            case .empty:
                return 0
            case .string(let str):
                return str.count
            case .data(let data):
                return data.count
            case .image(let image):
                return image.pngData()?.count ?? 0
            }
        }
        
    }
    
    let contentType : String
    let filename : String?
    let content : Content
    let encoding : String.Encoding?
    
    var httpBody : Data {
        switch self.content {
        case .empty:
            return Data()
        case .data(let rv):
            return rv
        case .image(let img):
            if self.contentType == "image/jpeg" {
                return img.jpegData(compressionQuality: 1.0) ?? Data()
            }else {
                return img.pngData() ?? Data()
            }
        case .string(let str):
            return str.data(using: self.encoding ?? String.Encoding.utf8) ?? Data()
        }
    }
    
    var httpContentTypeHeader : String {
        return self.contentType
    }
    
    lazy var status : Status = Status(size: content.size(), contentType: contentType, filename: filename)
    
    init() {
        self.content = .empty
        self.contentType = "text/plain"
        self.encoding = nil
        self.filename = nil
    }
    
    init(image : UIImage, type : String = "image/png", filename : String? = nil) {
        self.content = Content.image(image)
        self.contentType = type
        self.encoding = nil
        self.filename = filename
    }
    init(string : String, type : String = "text/plain", encoding : String.Encoding = .utf8){
        self.content = Content.string(string)
        self.contentType = type
        self.encoding = encoding
        self.filename = nil
    }
    
    init(data : Data, type : String, encoding : String.Encoding? = nil, filename : String? = nil){
        self.contentType = type
        self.encoding = encoding
        self.filename = filename
        if type.starts(with: "text/") {
            if let str = String(data: data, encoding: encoding ?? .utf8){
                self.content = .string(str)
            }else{
                self.content = .data(data)
            }
        }else if( type.starts(with: "image/")){
            if let img = UIImage(data: data) {
                self.content = .image(img)
            }else{
                self.content = .data(data)
            }
        }else{
            self.content = .data(data)
        }
    }
    
    init(url : URL, type : String? = nil, encoding : String.Encoding = .utf8){
        let ext = url.pathExtension
        self.filename = url.lastPathComponent
        self.contentType = RemoteStashItem.mimeType(fileExtension: ext) ?? "application/octet"
        let data = try? Data(contentsOf: url)
        self.content = .data( data ?? Data() )
        self.encoding = encoding
    }
    
    convenience init(pasteboard : UIPasteboard) {
        if pasteboard.hasStrings {
            self.init(string: pasteboard.string ?? "")
        }else if pasteboard.hasURLs {
            if let url = pasteboard.url {
                if url.isFileURL {
                    self.init(url:url)
                }else{
                    self.init(string: url.description)
                }
            }else{
                self.init()
            }
        }else if pasteboard.hasImages {
            if let image = pasteboard.image {
                self.init(image:image)
            }else{
                self.init()
            }
        }else{
            self.init()
        }
    }
    
    convenience init(request : CRRequest, response : CRResponse) {
        if let file : CRUploadedFile = request.files?.values.first,
           let data = try? Data( contentsOf: file.temporaryFileURL) {
            self.init(data:data, type: file.mimeType ?? "application/octet",
                      encoding: String.Encoding.utf8,
                      filename: file.temporaryFileURL.lastPathComponent  )
        }else{
            self.init()
        }
    }
    
    convenience init(data : Data, response : HTTPURLResponse) {
        self.init(data:data,
                  type: response.mimeType ?? "application/octet",
                  encoding: String.Encoding(inia: response.textEncodingName ?? "utf-8"),
                  filename: response.suggestedFilename )
    }
    
    static func item(from extensionContext : NSExtensionContext,  completion : @escaping (RemoteStashItem?) -> Void){
        guard let extensionItems = extensionContext.inputItems as? [NSExtensionItem]
        else {
            return
        }
        var imageProviders : [NSItemProvider] = []
        var textProviders : [NSItemProvider] = []
        var urlProviders : [NSItemProvider] = []
        
        for extensionItem in extensionItems {
            if let itemProviders = extensionItem.attachments  {
                for itemProvider in itemProviders {
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                        textProviders.append(itemProvider)
                    }
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String){
                        imageProviders.append(itemProvider)
                    }
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String){
                        urlProviders.append(itemProvider)
                    }
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String){
                        textProviders.append(itemProvider)
                    }
                }
            }
        }
        if let imageProvider = imageProviders.first {
            imageProvider.loadItem(forTypeIdentifier: kUTTypeImage as String){
                item, _ in
                if let image = item as? UIImage {
                    completion(RemoteStashItem(image: image))
                }else{
                    completion(nil)
                }
            }
        }else if let textProvider = textProviders.first {
            textProvider.loadItem(forTypeIdentifier: kUTTypeText as String){
                item, _ in
                if let text = item as? String{
                    completion(RemoteStashItem(string: text))
                }else if let text = item as? URL{
                    completion(RemoteStashItem(string: text.description))
                }else{
                    completion(nil)
                }
            }
        }else{
            completion(nil)
        }
    }
    
    func prepare(request : CRRequest, into response : CRResponse){
        response.setValue(self.contentType, forHTTPHeaderField: "Content-Type")
        switch self.content {
        case .string(let str):
            response.send(str)
        case .image(let image):
            if self.contentType.contains("png"){
                if let data = image.pngData() {
                    response.send(data)
                }
            }else{
                if let data = image.jpegData(compressionQuality: 1.0) {
                    response.send(data)
                }
            }
        case .data(let data):
            response.send(data)
        default:
            // do nothing
            break
        }
    }
    
    
}

extension RemoteStashItem : CustomStringConvertible {
    var description: String {
        return "RemoteStashItem(\(self.contentType))"
    }
}