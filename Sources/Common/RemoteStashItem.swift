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
        
        var formattedSize : String {
            return ByteCountFormatter.string(fromByteCount: Int64(self.size), countStyle: .file)
        }
        
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
    
    //MARK: - update with data
    
    func update( with other : RemoteStashItem) {
        self.content = other.content
        self.contentType = other.contentType
        self.encoding = other.encoding
        self.filename = other.filename
    }
    
    func update(text : String) {
        self.content = .string(text)
        self.contentType = "text/plain"
        self.encoding = .utf8
        self.filename = nil
        self.status = Status(size: content.size(), contentType: contentType, filename: nil)
    }

    //MARK: - load item
    
    static func loadItem(itemProvider : NSItemProvider,
                         uttype : UTType,
                         completion :  @escaping (RemoteStashItem?) -> Void,
                         convert : @escaping (NSSecureCoding)->RemoteStashItem?){
        itemProvider.loadItem(forTypeIdentifier: uttype.identifier){
            item, error in
            if let error = error {
                logger.error("Failed to load \(uttype.identifier) from provider \(error as NSError)")
                completion(nil)
                return
            }
            
            if let item = item, let stashitem = convert(item) {
                logger.info("provided \(uttype.identifier) \(stashitem)")
                completion(stashitem)
            }else{
                logger.error("Failed to convert to \(uttype.identifier) from \(type(of: item))")
                completion(nil)
            }
        }

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
                logger.info("found text provider of type \(itemProvider.registeredTypeIdentifiers)")
                textProviders.append(itemProvider)
            }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier){
                used = true
                logger.info("found image provider of type \(itemProvider.registeredTypeIdentifiers)")
                imageProviders.append(itemProvider)
            }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier){
                used = true
                logger.info("found file url provider of type \(itemProvider.registeredTypeIdentifiers)")
                fileProviders.append(itemProvider)
            }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier){
                used = true
                logger.info("found url provider of type \(itemProvider.registeredTypeIdentifiers)")
                urlProviders.append(itemProvider)
            }
            if !used {
                logger.info("no known provider found in types \(itemProvider.registeredTypeIdentifiers)")
            }
        }
        
        if let imageProvider = imageProviders.first {
            RemoteStashItem.loadItem(itemProvider: imageProvider,
                                     uttype: UTType.image,
                                     completion: completion){
                item in
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    var type = MimeType.mimeType(file: url)
                    var filename = url.lastPathComponent
                    if type == nil {
                        type = MimeType.imagejpeg
                    }
                    if url.pathExtension == "" {
                        filename = "\(filename).jpeg"
                    }
                    return RemoteStashItem(image: image, type: type ?? MimeType.imagejpeg, filename: filename)
                }else{
                    return nil
                }
            }
        }else if let textProvider = textProviders.first {
            RemoteStashItem.loadItem(itemProvider: textProvider,
                                     uttype: UTType.text,
                                     completion: completion){
                item in
                if let text = item as? String{
                    return RemoteStashItem(string: text)
                }
                return nil
            }
        }else if let urlProvider = urlProviders.first {
            RemoteStashItem.loadItem(itemProvider: urlProvider,
                                     uttype: UTType.url,
                                     completion: completion){
                item in
                if let url = item as? URL{
                    return RemoteStashItem(string: url.description)
                }
                return nil

            }
        }else if let fileProvider = fileProviders.first {
            RemoteStashItem.loadItem(itemProvider: fileProvider,
                                     uttype: UTType.fileURL,
                                     completion: completion){
                item in
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url) {
                    return RemoteStashItem(data: data,
                                           type: MimeType.mimeType(file: url) ?? MimeType.applicationoctetstream,
                                           filename: url.lastPathComponent)
                }
                return nil
            }
        }else{
            completion(nil)
        }

    }
    
    static func item( pasteBoard : UIPasteboard, completion : @escaping (RemoteStashItem?) -> Void) {
        if false && pasteBoard.hasImages || pasteBoard.hasStrings || pasteBoard.hasURLs {
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
        response.setValue(self.httpContentTypeHeader, forHTTPHeaderField: "Content-Type")
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
        var info = [ "\(self.contentType)" ]
        if let file = self.filename {
            info.append(file)
        }
        let desc = info.joined(separator: ", ")
        return "RemoteStashItem(\(desc))"
    }
}
