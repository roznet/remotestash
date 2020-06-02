//
//  RemoteCopyClient.m
//  remotecopypaste
//
//  Created by Brice Rosenzweig on 14/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashServer.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#if TARGET_IPHONE_SIMULATOR
#define TypeEN    "en1"
#else
#define TypeEN    "en0"
#endif


@import Criollo;

@interface RemoteStashServer ()
@property (nonatomic,retain) NSNetService * service;
@property (nonatomic,retain) GCDAsyncSocket * socket;
@property (nonatomic,retain) dispatch_queue_t worker;
@property (nonatomic,retain) CRHTTPServer * httpServer;
@property (nonatomic,assign) int port;
@end

@implementation RemoteStashServer

+(RemoteStashServer*)server:(NSObject<RemoteStashServerDelegate>*)delegate{
    RemoteStashServer * rv =[[RemoteStashServer alloc] init];
    if( rv ){
        rv.delegate = delegate;
        [rv startBroadCast];
    }
    return rv;
}

-(void)startHttpServer{
    self.httpServer = [[CRHTTPServer alloc] init];
    self.httpServer.isSecure = YES;
    
    self.httpServer.certificatePath = [NSBundle.mainBundle pathForResource:@"remotestash-ios-cert" ofType:@"pem"];
    self.httpServer.certificateKeyPath = [NSBundle.mainBundle pathForResource:@"remotestash-ios-key" ofType:@"pem"];

    [self.httpServer get:@"/status" block:^(CRRequest*req, CRResponse * res, CRRouteCompletionBlock next){
        NSData * data = [NSJSONSerialization dataWithJSONObject:@{@"items_count":@0} options:NSJSONWritingSortedKeys error:nil];
        if( data ){
            [res setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            [res sendData:data];
        }
    }];
    [self.httpServer startListening:nil portNumber:self.port];
    if( [self getIPAddresses].count > 0){
        NSLog(@"https://%@:%@", [self getIPAddresses].firstObject, @(self.port));
    }
}

-(NSArray<NSString*>*)getIPAddresses{
    NSMutableArray * rv = [NSMutableArray array];
    
    char buffer[MAX(INET6_ADDRSTRLEN,INET_ADDRSTRLEN)];
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET || temp_addr->ifa_addr->sa_family == AF_INET6) {
                
                NSString * iname = [NSString stringWithUTF8String:temp_addr->ifa_name];
                
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([iname isEqualToString:@TypeEN]) {
                    if (temp_addr->ifa_addr->sa_family == AF_INET) {
                        struct sockaddr_in *in_addr = (struct sockaddr_in*) temp_addr->ifa_addr;
                        inet_ntop(AF_INET, &in_addr->sin_addr, buffer, (socklen_t)sizeof(buffer));
                        address = [NSString stringWithUTF8String:buffer];
                        [rv addObject:address];
                    }/* ignore IPV6
                      else { // AF_INET6
                        struct sockaddr_in6 *in6_addr = (struct sockaddr_in6*) temp_addr->ifa_addr;
                        inet_ntop(AF_INET6, &in6_addr->sin6_addr, buffer, (socklen_t)sizeof(buffer));
                    }*/
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return rv;
}

-(void)startBroadCast{
    dispatch_queue_t queue = dispatch_queue_create("net.ro-z.worker", DISPATCH_QUEUE_SERIAL);
    self.worker = queue;

    // Find a free port number
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.worker];
    [self.socket acceptOnPort:0 error:nil];
    self.port = self.socket.localPort;
    [self.socket disconnect];
    self.socket = nil;
    
    NSString * name = [NSString stringWithFormat:@"%@ RemoteStash", [[UIDevice currentDevice] name]];
    self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_remotestash._tcp" name:name port:self.port];
    [self.service publish];
    [self startHttpServer];
}

#pragma mark - NetService

-(void)netServiceDidPublish:(NSNetService *)sender{
}

#pragma mark - Socket

-(void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
}
@end
