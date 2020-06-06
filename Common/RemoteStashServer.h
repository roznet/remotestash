//
//  RemoteCopyClient.h
//  remotecopypaste
//
//  Created by Brice Rosenzweig on 14/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CocoaAsyncSocket;

NS_ASSUME_NONNULL_BEGIN
@class RemoteStashServer;
@class RemoteStashItem;

@protocol RemoteStashServerDelegate <NSObject>
-(void)remoteStashServerStarted:(RemoteStashServer*)server;
-(void)remoteStashServer:(RemoteStashServer*)server receivedItem:(RemoteStashItem*)item;
-(RemoteStashItem*)lastItemForRemoteStashServer:(RemoteStashServer*)server;
@end

@interface RemoteStashServer : NSObject<NSNetServiceDelegate,NSNetServiceBrowserDelegate,GCDAsyncSocketDelegate>
@property (nonatomic,retain,nullable) NSObject<RemoteStashServerDelegate>*delegate;
@property (nonatomic,readonly) NSUUID * serverUUID;

+(RemoteStashServer*)server:(NSObject<RemoteStashServerDelegate>*)delegate;

@end

NS_ASSUME_NONNULL_END
