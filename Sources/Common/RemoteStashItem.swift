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
import os
import UniformTypeIdentifiers

fileprivate let logger = Logger(subsystem: "net.ro-z.remotestash", category: "item")


class RemoteStashItem {


    struct Status : Codable, CustomStringConvertible {
        enum CodingKeys : String, CodingKey {
            case contentType = "content-type"
            case size = "size"
            case filename = "filename"
        }

        
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
    
    var contentType : String
    var filename : String?
    var content : Content
    var encoding : String.Encoding?
    
    //MARK: http output
    
    var httpBody : Data {
        switch self.content {
        case .empty:
            return Data()
        case .data(let rv):
            return rv
        case .image(let img):
            if self.contentType == MimeType.imagejpeg {
                return img.jpegData(compressionQuality: 1.0) ?? Data()
            }else {
                return img.pngData() ?? Data()
            }
        case .string(let str):
            return str.data(using: self.encoding ?? String.Encoding.utf8) ?? Data()
        }
    }
    
    var httpContentTypeHeader : String {
        return self.contentType.httpContentType(encoding: self.encoding)
    }
    
    var activityItems : [Any] {
        switch self.content {
        case .empty:
            return []
        case .data(_):
            return []
        case .image(let img):
            return [img]
        case .string(let str):
            return [str]
        }
    }
    
    lazy var status : Status = Status(size: content.size(), contentType: contentType, filename: filename)
    
    //MARK: - Initializers
    
    
    init() {
        self.content = .empty
        self.contentType = MimeType.textplain
        self.encoding = nil
        self.filename = nil
    }
    
    init(image : UIImage, type : String = MimeType.imagepng, filename : String? = nil) {
        self.content = Content.image(image)
        self.contentType = type
        self.encoding = nil
        if let filename = filename {
            self.filename = filename
        }else{
            self.filename =  type == MimeType.imagepng ? "remotestashitem.png" : "remotestashitem.jpeg"
        }
    }
    init(string : String, type : String = MimeType.textplain, encoding : String.Encoding = .utf8){
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
        self.filename = url.lastPathComponent
        self.contentType = MimeType.mimeType(file: url) ?? MimeType.applicationoctetstream
        let data = try? Data(contentsOf: url)
        self.content = .data( data ?? Data() )
        self.encoding = encoding
    }
    
    convenience init(pasteboard : UIPasteboard) {
        logger.info("\(pasteboard.itemProviders)")
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
           let data = try? Data( contentsOf: file.temporaryFileURL){
            let encoding = String.Encoding.utf8
            if let reqtype = request.env["HTTP_CONTENT_TYPE"],
               let filetype = file.mimeType{
                if reqtype != filetype {
                    logger.info("different types received file \(filetype) and req \(reqtype)")
                }
            }
            self.init(data:data, type: file.mimeType ?? MimeType.applicationoctetstream,
                      encoding: encoding,
                      filename: file.temporaryFileURL.lastPathComponent  )
        }else{
            self.init()
        }
    }
    
    convenience init(data : Data, response : HTTPURLResponse) {
        self.init(data:data,
                  type: response.mimeType ?? MimeType.applicationoctetstream,
                  encoding: String.Encoding(iana: response.textEncodingName ?? "utf-8"),
                  filename: response.suggestedFilename )
    }
    
    func update( with other : RemoteStashItem){
        self.content = other.content
        self.contentType = other.contentType
        self.encoding = other.encoding
        self.filename = other.filename
    }

    static func item(itemProviders : [NSItemProvider], completion : @escaping (RemoteStashItem?) -> Void){
        var imageProviders : [NSItemProvider] = []
        var textProviders : [NSItemProvider] = []
        var urlProviders : [NSItemProvider] = []
        var fileProviders : [NSItemProvider] = []
        
        for itemProvider in itemProviders {
            var used = false
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                used = true
                logger.info("used text provider of type \(itemProvider.registeredTypeIdentifiers)")
                textProviders.append(itemProvider)
            }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier){
                used = true
                logger.info("used image provider of type \(itemProvider.registeredTypeIdentifiers)")
                imageProviders.append(itemProvider)
            }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier){
                used = true
                logger.info("used file url provider of type \(itemProvider.registeredTypeIdentifiers)")
                fileProviders.append(itemProvider)
            }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier){
                used = true
                logger.info("used url provider of type \(itemProvider.registeredTypeIdentifiers)")
                urlProviders.append(itemProvider)
            }
            if !used {
                logger.info("Unused provider of type \(itemProvider.registeredTypeIdentifiers)")
            }
        }
        
        if let imageProvider = imageProviders.first {
            imageProvider.loadItem(forTypeIdentifier: UTType.image.identifier){
                item, error in
                if let error = error {
                    logger.error("Failed to convert image \(error as NSError)")
                }
                
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    logger.info("got image \(url)")
                    completion(RemoteStashItem(image: image, type: MimeType.mimeType(file: url) ?? MimeType.imagejpeg, filename: url.lastPathComponent))
                }else{
                    logger.error("Failed to convert image from \(type(of: item))")
                    completion(nil)
                }
            }
        }else if let textProvider = textProviders.first {
            textProvider.loadItem(forTypeIdentifier: UTType.text.identifier){
                item, error in
                if let error = error {
                    logger.error("Failed to convert text \(error as NSError)")
                }
                
                if let text = item as? String{
                    completion(RemoteStashItem(string: text))
                }else{
                    logger.error("Failed to convert text from \(type(of: item))")
                    completion(nil)
                }
            }
        }else if let urlProvider = urlProviders.first {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier){
                item, error in
                if let error = error {
                    logger.error("Failed to convert text \(error as NSError)")
                }
                
                if let url = item as? URL{
                    logger.info( "got \(url.lastPathComponent) with ext: \(url.pathExtension)" )
                    completion(RemoteStashItem(string: url.description))
                }else{
                    completion(nil)
                }
            }
        }else if let fileProvider = fileProviders.first {
            fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.description){
                item, error in
                if let error = error {
                    logger.error("Failed to convert file \(error as NSError)")
                }
                
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url) {
                    logger.info( "got \(url.lastPathComponent) with ext: \(url.pathExtension)" )
                    completion(RemoteStashItem(data: data, type: MimeType.mimeType(file: url) ?? MimeType.imagejpeg, filename: url.lastPathComponent))
                }else{
                    completion(nil)
                }
            }
        }else{
            completion(nil)
        }

    }
    
    static func item( pasteBoard : UIPasteboard, completion : @escaping (RemoteStashItem?) -> Void) {
        if pasteBoard.hasImages || pasteBoard.hasStrings || pasteBoard.hasURLs {
            completion(RemoteStashItem(pasteboard: pasteBoard))
        }else{
            if pasteBoard.itemProviders.count > 0 {
                item(itemProviders: pasteBoard.itemProviders, completion: completion)
            }else{
                completion(RemoteStashItem(pasteboard: pasteBoard))
            }
        }
    }
    
    static func item( extensionContext : NSExtensionContext,  completion : @escaping (RemoteStashItem?) -> Void){
        guard let extensionItems = extensionContext.inputItems as? [NSExtensionItem]
        else {
            return
        }
        
        var itemProviders : [NSItemProvider] = []
        
        for extensionItem in extensionItems {
            if let attachmentsItemProviders = extensionItem.attachments  {
                for itemProvider in attachmentsItemProviders {
                    itemProviders.append(itemProvider)
                }
            }
        }
        return self.item(itemProviders: itemProviders, completion: completion)
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
    
    func update(text : String){
        self.content = .string(text)
        self.contentType = "text/plain"
        self.encoding = .utf8
        self.filename = nil
    }
    
}

extension RemoteStashItem : CustomStringConvertible {
    var description: String {
        var info = [ "\(self.contentType)", "\(self.content.size())" ]
        if let file = self.filename {
            info.append(file)
        }
        let desc = info.joined(separator: ", ")
        return "RemoteStashItem(\(desc))"
    }
}
