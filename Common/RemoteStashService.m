//
//  RemoteStashService.m
//  remotestash
//
//  Created by Brice Rosenzweig on 23/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashService.h"
#import <arpa/inet.h>
#import "RemoteStashItem.h"

NSString * kNotificationNewServiceDiscovered = @"kNotificationNewServiceDiscovered";

@interface RemoteAddressAndPort : NSObject
@property (nonatomic,retain) NSString * ip;
@property (nonatomic,assign) int port;
@property (nonatomic,assign) sa_family_t family;
@end

@implementation RemoteAddressAndPort
-(NSString*)description{
    return [NSString stringWithFormat:@"%@:%@ %@", self.ip, @(self.port), self.family == AF_INET ? @"ipv4": @"ipv6"];
}
@end

@interface RemoteStashService ()
@property (nonatomic,retain) NSURLSession * session;
@property (nonatomic,retain) NSArray<RemoteAddressAndPort*>*addresses;
@property (nonatomic,retain) NSURLRequest * request;
@property (nonatomic,retain) NSURLSessionDataTask * task;
@property (nonatomic,retain,nullable) RemoteStashItem * lastItem;
@property (nonatomic,retain) NSHTTPURLResponse * response;
@end

@implementation RemoteStashService

+(RemoteStashService*)serviceFor:(NSNetService*)service{
    RemoteStashService * rv = [[RemoteStashService alloc] init];
    if( rv ){
        rv.service = service;
        service.delegate = rv;        
        [service resolveWithTimeout:5.0];

    }
    return rv;
}
-(NSString*)description{
    return [NSString stringWithFormat:@"<%@: %@ %@>", NSStringFromClass([self class]), self.service.name, self.hostName ?: @"Not Resolved" ];
}
-(NSString*)name{
    return self.service.name;
}
-(NSString*)hostName{
    return self.service.hostName;
}
-(NSString*)shortHostName{
    NSString * rv = self.hostName;
    NSString * suffix = [NSString stringWithFormat:@".%@", self.service.domain];
    if( [rv hasSuffix:suffix]){
        rv = [rv substringToIndex:(rv.length-suffix.length)];
    }
    return rv;
}


-(BOOL)isReady{
    return self.addresses.count > 0;
}

-(void)netServiceDidResolveAddress:(NSNetService *)sender{
    
    NSMutableArray * found = [NSMutableArray array];
    
    char addressBuffer[INET6_ADDRSTRLEN];
    for (NSData * data in sender.addresses) {
        typedef union {
            struct sockaddr sa;
            struct sockaddr_in ipv4;
            struct sockaddr_in6 ipv6;
        } ip_socket_address;

        ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];

        if (socketAddress && (socketAddress->sa.sa_family == AF_INET || socketAddress->sa.sa_family == AF_INET6))
        {
            const char *addressStr = inet_ntop(
                    socketAddress->sa.sa_family,
                    (socketAddress->sa.sa_family == AF_INET ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
                    addressBuffer,
                    sizeof(addressBuffer));

            int port = ntohs(socketAddress->sa.sa_family == AF_INET ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);

            NSString * address = [[NSString alloc] initWithCString:addressStr encoding:NSUTF8StringEncoding];
            RemoteAddressAndPort * holder = [[RemoteAddressAndPort alloc] init];
            holder.ip = address;
            holder.port = port;
            holder.family = socketAddress->sa.sa_family;
            [found addObject:holder];
        }
    }
    self.addresses = found;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNewServiceDiscovered object:self];
}

-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *,NSNumber *> *)errorDict{
}

-(NSMutableURLRequest*)mutableRequest:(NSString*)path{
    if( self.addresses.count > 0){
        
        RemoteAddressAndPort * ipv4 = nil;
        RemoteAddressAndPort * ipv6 = nil;
        
        for (RemoteAddressAndPort * ap in self.addresses) {
            if( ipv4 == nil && ap.family == AF_INET){
                ipv4 = ap;
            }
            if( ipv6 == nil && ap.family == AF_INET6){
                ipv6 = ap;
            }
            if( ipv4 && ipv6){
                break;
            }
        }
        
        NSString * useHost = ipv4.ip;
        int port = ipv4.port;
        if( useHost == nil){
            useHost = [NSString stringWithFormat:@"[%@]", ipv6.ip];
            port = ipv6.port;
        }
        
        NSString * url = [NSString stringWithFormat:@"https://%@:%@/%@", useHost, @(port), path];
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        return request;
    }
    return nil;
}

-(void)startTask:(RemoteStashCompletionHandler)completion{
    if( self.session == nil){
        self.session = [NSURLSession sessionWithConfiguration:[[NSURLSession sharedSession] configuration]
                                                     delegate:self
                                                delegateQueue:nil];
    }

    self.task = [self.session dataTaskWithRequest:self.request completionHandler:^(NSData * data, NSURLResponse*response,NSError*error){
        if( [response isKindOfClass:[NSHTTPURLResponse class]]){
            self.response = (NSHTTPURLResponse*)response;
            self.lastItem = [RemoteStashItem itemFromData:data andResponse:self.response];
        }else{
            self.response = nil;
            self.lastItem = nil;
        }
        completion(self);
    }];
    [self.task resume];
}

-(void)pushItem:(RemoteStashItem*)item completion:(RemoteStashCompletionHandler)completion{
    NSMutableURLRequest * request = [self mutableRequest:@"push"];
    if( request ){
        request.HTTPMethod = @"POST";
        [item prepareURLRequest:request];
        
        self.request = request;
        [self startTask:completion];
    }
}

-(void)pullWithCompletion:(RemoteStashCompletionHandler)completion{
    NSMutableURLRequest * request = [self mutableRequest:@"pull"];
    if( request ){
        self.request = request;
        [self startTask:completion];
    }
}

-(void)lastWithCompletion:(RemoteStashCompletionHandler)completion{
    NSMutableURLRequest * request = [self mutableRequest:@"last"];
    if( request ){
        self.request = request;
        [self startTask:completion];
    }
}
-(void)statusWithCompletion:(RemoteStashCompletionHandler)completion{
    NSMutableURLRequest * request = [self mutableRequest:@"status"];
    if( request ){
        self.request = request;
        [self startTask:completion];
    }
}

-(void)updateRemoteStatus:(RemoteStashCompletionHandler)completion{
    [self statusWithCompletion:^(RemoteStashService*service){
        NSDictionary * last = service.lastItem.asJson;
        self.availableContentType = last[@"last"][@"content-type"];
        self.availableItemsCount = [last[@"items_count"] doubleValue];
        completion(self);
    }];
}

-(NSString*)contentType{
    return self.response.allHeaderFields[@"Content-Type"];
}
-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler{
    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
}

@end
