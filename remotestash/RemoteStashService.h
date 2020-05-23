//
//  RemoteStashService.h
//  remotestash
//
//  Created by Brice Rosenzweig on 23/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * kNotificationNewServiceDiscovered;

@class RemoteStashService;

typedef void(^RemoteStashCompletionHandler)(RemoteStashService*service);

@interface RemoteStashService : NSObject<NSNetServiceDelegate,NSURLSessionDelegate>

@property (nonatomic,retain) NSNetService * service;
@property (nonatomic,readonly) NSString * name;

@property (nonatomic,readonly,nullable) NSString * lastPullString;

+(RemoteStashService*)serviceFor:(NSNetService*)service;

-(void)pushString:(NSString*)str completion:(nullable RemoteStashCompletionHandler)completion;
-(void)pullWithCompletion:(RemoteStashCompletionHandler)completion;
@end

NS_ASSUME_NONNULL_END
