//
//  RemoteStashItem.h
//  remotestash
//
//  Created by Brice Rosenzweig on 02/06/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;
@class CRRequest;
@class CRResponse;

NS_ASSUME_NONNULL_BEGIN

@interface RemoteStashItem : NSObject

@property (nonatomic,readonly,nullable) UIImage * asImage;
@property (nonatomic,readonly,nullable) NSString * asString;
@property (nonatomic,readonly,nullable) NSDictionary * asJson;

+(instancetype)itemFromData:(NSData*)data andResponse:(NSHTTPURLResponse*)response;
+(instancetype)itemFromRequest:(CRRequest*)req andResponse:(CRResponse*)response;
+(instancetype)itemWithImage:(UIImage*)image;
+(instancetype)itemWithString:(NSString*)str;
+(instancetype)itemFromPasteBoard:(UIPasteboard*)pasteboard;
+(void)itemFromExtensionContext:(NSExtensionContext*)extensionContext completion:(void(^)(RemoteStashItem*))completion;

-(void)prepareURLRequest:(NSMutableURLRequest*)request;
-(void)prepareFor:(CRRequest*)req intoResponse:(CRResponse *)res;

@end

NS_ASSUME_NONNULL_END
