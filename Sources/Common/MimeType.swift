//
//  RemoteStashMimeTypes.swift
//  remotestash
//
//  Created by Brice Rosenzweig on 30/01/2021.
//  Copyright © 2021 Brice Rosenzweig. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

typealias MimeType = String

extension String.Encoding {
    init(iana: String){
        self.init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(iana as CFString) ) )
    }
    
    var iana : String {
        return CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(self.rawValue)) as String
    }
}

extension MimeType {
    static let texturi = "text/uri-list"
    static let textplain = "text/plain"
    static let texthtml = "text/html"
    static let imagejpeg = "image/jpeg"
    static let imagepng = "image/png"
    static let applicationoctetstream = "application/octet-stream"
    static let applicationjson = "application/json"

    func isText(type: String) -> Bool {
        return self.starts(with: "text/")
    }
    
    func isImage(type: String) -> Bool {
        return self.starts(with: "image/")
    }
    
    func httpContentType(encoding: String.Encoding? = nil) -> String{
        if let encoding = encoding {
            let iana = encoding.iana
            return "\(self); charset=\(iana)"
        }
        return self
    }
    func typeAndEncoding() -> (MimeType,String.Encoding?) {
        let split = self.split(separator: ";")
        guard let mime = split.first else { return (self,nil) }
        var encoding : String.Encoding? = nil
        if split.count > 1 {
            let attr = split[1]
            if attr.starts(with: " charset=") {
                let charset = String(attr.dropFirst(" charset=".count))
                encoding = String.Encoding(iana:charset)
            }
        }
        return (MimeType(mime),encoding)
    }
    static func mimeType(file: URL) -> MimeType? {
        let fileExtension : String = file.pathExtension.lowercased()
        let uttype = UTType(filenameExtension: fileExtension)
        return uttype?.preferredMIMEType;
    }
}
