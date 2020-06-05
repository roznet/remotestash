//
//  RemoteStashItem.m
//  remotestash
//
//  Created by Brice Rosenzweig on 02/06/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashItem.h"
@import Criollo;

@interface RemoteStashItem ()
@property (nonatomic,retain) NSData * data;
@property (nonatomic,retain) NSString * textEncodingName;
@property (nonatomic,retain) NSString * contentType;
@end

@implementation RemoteStashItem

+(instancetype)itemFromData:(NSData*)data andResponse:(NSHTTPURLResponse*)response{
    RemoteStashItem * rv = [[RemoteStashItem alloc] init];
    if( rv ){
        rv.data = data;
        rv.textEncodingName = response.textEncodingName;
        rv.contentType = response.MIMEType;
        if( rv.textEncodingName == nil && [rv.contentType hasPrefix:@"text/"] ){
            rv.textEncodingName = @"utf-8";
        }
    }
    return rv;
}
+(instancetype)itemFromRequest:(CRRequest*)req andResponse:(CRResponse*)response{
    RemoteStashItem * rv = nil;
    if( req.files.count == 1 ){
        CRUploadedFile * file = req.files.allValues.firstObject;
        rv = [[RemoteStashItem alloc] init];
        if( rv ){
            rv.data = [NSData dataWithContentsOfURL:file.temporaryFileURL];
            rv.contentType = file.mimeType;
            rv.textEncodingName = file.attributes[@"charset"];
            if( rv.textEncodingName == nil && [rv.contentType hasPrefix:@"text/"] ){
                rv.textEncodingName = @"utf-8";
            }
        }
    }
    return rv;
}
+(instancetype)itemWithImage:(UIImage*)image{
    RemoteStashItem * rv = [[RemoteStashItem alloc] init];
    if( rv ){
        rv.textEncodingName = nil;
        rv.contentType = @"image/jpeg";
        rv.data = UIImageJPEGRepresentation(image,1.0);
    }
    return rv;
}

+(instancetype)itemWithString:(NSString*)str{
    RemoteStashItem * rv = [[RemoteStashItem alloc] init];
    if( rv ){
        rv.textEncodingName = @"utf-8";
        rv.contentType = @"text/plain";
        rv.data = [str dataUsingEncoding:NSUTF8StringEncoding];
    }
    return rv;
}

+(instancetype)itemFromPasteBoard:(UIPasteboard*)pasteboard{
    if ([pasteboard hasStrings]){
        return [RemoteStashItem itemWithString:pasteboard.string];
    }else if( [pasteboard hasURLs] ){
        NSURL * url = pasteboard.URL;
        return [RemoteStashItem itemWithString:url.description];
    }else if( [pasteboard hasImages] ){
        return [RemoteStashItem itemWithImage:pasteboard.image];
    }
    return nil;
}

+(void)itemFromExtensionContext:(NSExtensionContext*)extensionContext completion:(void(^)(RemoteStashItem*))completion{
    NSItemProvider * urlProvider = nil;
    NSItemProvider * jpegProvider = nil;
    
    for (NSExtensionItem * item in extensionContext.inputItems) {
        for (NSItemProvider * provider in item.attachments) {
            if ([provider hasItemConformingToTypeIdentifier:@"public.url"]) {
                urlProvider = provider;
            }
            if( [provider hasItemConformingToTypeIdentifier:@"public.jpeg"]){
                jpegProvider = provider;
            }
        }
    }
    
    if (urlProvider) {
        [urlProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler:^(NSURL *url, NSError *error) {
            completion([RemoteStashItem itemWithString:url.description]);
        }];
    }else if (jpegProvider){
        [jpegProvider loadItemForTypeIdentifier:@"public.jpeg" options:nil completionHandler:^(NSURL * url, NSError * error){
            UIImage * image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
            RemoteStashItem * item = [RemoteStashItem itemWithImage:image];
            completion(item);
        }];
    }else{
        completion(nil);
    }
}
#pragma mark - getter

-(UIImage*)asImage{
    if( [self.contentType hasPrefix:@"image/"] ){
        return [UIImage imageWithData:self.data];
    }
    return nil;
}
-(NSString * )asString{
    if( [self.contentType hasPrefix:@"image/"] ){
        return nil;
    }
    if( self.data && self.textEncodingName){
        NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)self.textEncodingName));
        return [[NSString alloc] initWithData:self.data encoding:encoding];
    }
    return nil;
}
-(NSDictionary*)asJson{
    if( [self.contentType hasPrefix:@"application/json"] && self.data ){
        NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:self.data options:NSJSONReadingAllowFragments error:nil];
        return [dict isKindOfClass:[NSDictionary class]]?dict:nil;
    }
    return nil;
}

#pragma mark - url request

-(NSString*)contentTypeWithEncoding{
    NSString * type = self.contentType;
    if( self.textEncodingName ){
        type = [NSString stringWithFormat:@"%@; charset=%@", type, self.textEncodingName];
    }
    return type;
}

-(void)prepareURLRequest:(NSMutableURLRequest*)request{
    request.HTTPBody = self.data;
    NSString * type = [self contentTypeWithEncoding];
    [request addValue:type forHTTPHeaderField:@"Content-type"];
}

#pragma mark - server response

-(void)prepareFor:(CRRequest*)req intoResponse:(CRResponse *)res{
    [res setValue:[self contentTypeWithEncoding] forHTTPHeaderField:@"Content-Type"];
    [res sendData:self.data];
}

@end
