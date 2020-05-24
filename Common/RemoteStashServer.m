//
//  RemoteCopyClient.m
//  remotecopypaste
//
//  Created by Brice Rosenzweig on 14/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashServer.h"
#include <arpa/inet.h>
@interface RemoteStashServer ()
@property (nonatomic,retain) NSNetService * service;
@property (nonatomic,retain) GCDAsyncSocket * socket;
@property (nonatomic,retain) GCDAsyncSocket * clientSocket;
@property (nonatomic,retain) dispatch_queue_t worker;
@end

@implementation RemoteStashServer

+(RemoteStashServer*)client{
    RemoteStashServer * rv =[[RemoteStashServer alloc] init];
    if( rv ){
        [rv startBroadCast];
    }
    return rv;
}

-(void)startBroadCast{
    dispatch_queue_t queue = dispatch_queue_create("net.ro-z.worker", DISPATCH_QUEUE_SERIAL);
    self.worker = queue;

    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.worker];
    [self.socket acceptOnPort:0 error:nil];
    NSString * name = [NSString stringWithFormat:@"%@ CopyPaste", [[UIDevice currentDevice] name]];
    self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_remotecopypaste._tcp" name:name port:self.socket.localPort];
    [self.service publish];
}

#pragma mark - NetService

-(void)netServiceDidPublish:(NSNetService *)sender{
}

#pragma mark - Socket

-(void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    self.clientSocket = newSocket;
    if( self.delegate){
        [self.delegate connectedTo:self.clientSocket];
    }
    [self.clientSocket readDataToLength:sizeof(int64_t) withTimeout:-1 tag:1];
    
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    if( tag == 1){
        int64_t length = 0;
        [data getBytes:&length length:sizeof(length)];
        [self.clientSocket readDataToLength:length withTimeout:-1 tag:2];
    }
    else if( tag == 2){
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if( self.delegate){
            [self.delegate received:str];
        }
        [self.clientSocket readDataToLength:sizeof(int64_t) withTimeout:-1 tag:1];
    }
}
-(void)sendString:(NSString*)str{
    if( self.clientSocket ){
        NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];
        int64_t length = data.length;
        [self.clientSocket writeData:[NSData dataWithBytes:&length length:sizeof(length)] withTimeout:-1 tag:10];
        [self.clientSocket writeData:data withTimeout:-1 tag:11];
    }
}
@end
