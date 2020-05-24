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

@protocol RemoteCopyDelegate <NSObject>

-(void)connectedTo:(GCDAsyncSocket*)socket;
-(void)disconnected;
-(void)received:(NSString*)str;

@end

@interface RemoteStashServer : NSObject<NSNetServiceDelegate,NSNetServiceBrowserDelegate,GCDAsyncSocketDelegate>
@property (nonatomic,retain) NSObject<RemoteCopyDelegate>*delegate;

+(RemoteStashServer*)client;
-(void)sendString:(NSString*)str;
@end

NS_ASSUME_NONNULL_END
