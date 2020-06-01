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

typedef void(^RemoteStashCompletionHandler)(RemoteStashService*service);

@interface RemoteStashService : NSObject<NSNetServiceDelegate,NSURLSessionDelegate>

@property (nonatomic,retain) NSNetService * service;
@property (nonatomic,readonly) NSString * name;
@property (nonatomic,retain) NSString * hostname;
@property (nonatomic,readonly) BOOL isReady;
@property (nonatomic,readonly,nullable) NSString * lastPullString;
@property (nonatomic,readonly,nullable) UIImage * lastPullImage;
@property (nonatomic,readonly,nullable) NSDictionary * lastPullJson;
@property (nonatomic,retain,nullable) NSString * lastContentType;
@property (nonatomic,assign) NSUInteger lastItemsCount;

+(RemoteStashService*)serviceFor:(NSNetService*)service;

-(void)pushString:(NSString*)str completion:(nullable RemoteStashCompletionHandler)completion;
-(void)pushImage:(UIImage*)img completion:(RemoteStashCompletionHandler)completion;
-(void)pullWithCompletion:(RemoteStashCompletionHandler)completion;
-(void)lastWithCompletion:(RemoteStashCompletionHandler)completion;

-(void)updateRemoteStatus:(RemoteStashCompletionHandler)completion;

@end

NS_ASSUME_NONNULL_END
