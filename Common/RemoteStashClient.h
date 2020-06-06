//
//  RemoteStashClient.h
//  remotestash
//
//  Created by Brice Rosenzweig on 22/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "RemoteStashService.h"

NS_ASSUME_NONNULL_BEGIN

@class RemoteStashClient;

@protocol RemoteStashClientDelegate <NSObject>
@optional
-(BOOL)remoteStashClient:(RemoteStashClient*)client shouldAddService:(RemoteStashService*)service;
-(void)remoteStashClient:(RemoteStashClient*)client didAddService:(RemoteStashService*)service;
-(void)remoteStashClient:(RemoteStashClient*)client didRemoteService:(RemoteStashService*)service;
-(void)remoteStashClient:(RemoteStashClient*)client selectedRemoteService:(RemoteStashService*)service;
@end


@interface RemoteStashClient : NSObject<NSNetServiceBrowserDelegate,UITableViewDataSource,UITableViewDelegate,RemoteStashServiceDelegate>

@property (nonatomic,retain,nullable) NSObject<RemoteStashClientDelegate>*delegate;
@property (nonatomic,nullable,readonly) RemoteStashService * currentService;
@property (nonatomic,readonly) NSArray<RemoteStashService*>*pendingServices;

+(RemoteStashClient*)clientWithDelegate:(nullable NSObject<RemoteStashClientDelegate>*)delegate;
-(void)selectServiceWithName:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
