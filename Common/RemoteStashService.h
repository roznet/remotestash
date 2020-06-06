//
//  RemoteStashService.h
//  remotestash
//
//  Created by Brice Rosenzweig on 23/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

extern NSString * kNotificationNewServiceDiscovered;

@class RemoteStashService;
@class RemoteStashItem;

typedef void(^RemoteStashCompletionHandler)(RemoteStashService*service);

@protocol RemoteStashServiceDelegate <NSObject>
-(void)resolvedRemoteStashService:(RemoteStashService*)service;
@end

@interface RemoteStashService : NSObject<NSNetServiceDelegate,NSURLSessionDelegate>

@property (nonatomic,retain) NSNetService * service;
@property (nonatomic,readonly) NSString * name;
@property (nonatomic,readonly) NSString * hostName;
@property (nonatomic,readonly) NSString * domain;
@property (nonatomic,readonly) NSString * shortHostName;
@property (nonatomic,readonly) BOOL isReady;
@property (nonatomic,retain) NSDictionary<NSString*,NSString*>*properties;
@property (nonatomic,readonly) NSUUID * serverUUID;
@property (nonatomic,readonly,nullable) RemoteStashItem * lastItem;
@property (nonatomic,readonly) BOOL temporary;

@property (nonatomic,retain,nullable) NSString * availableContentType;
@property (nonatomic,assign) NSUInteger availableItemsCount;

@property (nonatomic,retain) NSObject<RemoteStashServiceDelegate>*delegate;

+(RemoteStashService*)serviceFor:(NSNetService*)service withDelegate:(NSObject<RemoteStashServiceDelegate>*)delegate;

-(void)pushItem:(RemoteStashItem*)str completion:(nullable RemoteStashCompletionHandler)completion;
-(void)pullWithCompletion:(RemoteStashCompletionHandler)completion;
-(void)lastWithCompletion:(RemoteStashCompletionHandler)completion;

-(void)updateRemoteStatus:(RemoteStashCompletionHandler)completion;

@end

NS_ASSUME_NONNULL_END
