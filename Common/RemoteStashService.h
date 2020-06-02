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

@interface RemoteStashService : NSObject<NSNetServiceDelegate,NSURLSessionDelegate>

@property (nonatomic,retain) NSNetService * service;
@property (nonatomic,readonly) NSString * name;
@property (nonatomic,readonly) NSString * hostName;
@property (nonatomic,readonly) NSString * domain;
@property (nonatomic,readonly) NSString * shortHostName;
@property (nonatomic,readonly) BOOL isReady;

@property (nonatomic,readonly,nullable) RemoteStashItem * lastItem;

@property (nonatomic,retain,nullable) NSString * availableContentType;
@property (nonatomic,assign) NSUInteger availableItemsCount;

+(RemoteStashService*)serviceFor:(NSNetService*)service;

-(void)pushItem:(RemoteStashItem*)str completion:(nullable RemoteStashCompletionHandler)completion;
-(void)pullWithCompletion:(RemoteStashCompletionHandler)completion;
-(void)lastWithCompletion:(RemoteStashCompletionHandler)completion;

-(void)updateRemoteStatus:(RemoteStashCompletionHandler)completion;

@end

NS_ASSUME_NONNULL_END
