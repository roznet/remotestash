//
//  RemoteStashService.m
//  remotestash
//
//  Created by Brice Rosenzweig on 23/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashService.h"
#import <arpa/inet.h>

NSString * kNotificationNewServiceDiscovered = @"kNotificationNewServiceDiscovered";

@interface RemoteAddressAndPort : NSObject
@property (nonatomic,retain) NSString * ip;
@property (nonatomic,assign) int port;
@property (nonatomic,assign) sa_family_t family;
@end

@implementation RemoteAddressAndPort
@end

@interface RemoteStashService ()
@property (nonatomic,retain) NSURLSession * session;
@property (nonatomic,retain) NSArray<RemoteAddressAndPort*>*addresses;
@property (nonatomic,retain) NSURLRequest * request;
@property (nonatomic,retain) NSURLSessionDataTask * task;
@property (nonatomic,retain) NSData * data;
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

-(NSString*)name{
    return self.service.name;
}

-(void)netServiceDidResolveAddress:(NSNetService *)sender{
    NSLog(@"resolved %@", sender);
    
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
    NSLog(@"failed to resolve %@", sender);
}

-(void)pushString:(NSString *)str completion:(RemoteStashCompletionHandler)completion{
    if( self.session == nil){
        self.session = [NSURLSession sessionWithConfiguration:[[NSURLSession sharedSession] configuration]
                                                     delegate:self
                                                delegateQueue:nil];
    }
    
    if( self.addresses.count > 0){
        RemoteAddressAndPort * addressAndPort = self.addresses.firstObject;
        NSString * url = [NSString stringWithFormat:@"https://%@:%@/push", addressAndPort.ip, @(addressAndPort.port)];
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        request.HTTPBody = [str dataUsingEncoding:NSUTF8StringEncoding];
        request.HTTPMethod = @"POST";
        [request addValue:@"text/html" forHTTPHeaderField:@"Content-type"];
        self.request = request;
        self.task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse*response,NSError*error){
            NSLog(@"Done %@ %@", response, error);
        }];
        [self.task resume];
        
    }
}

-(void)pullWithCompletion:(RemoteStashCompletionHandler)completion{
    if( self.session == nil){
        self.session = [NSURLSession sessionWithConfiguration:[[NSURLSession sharedSession] configuration]
                                                     delegate:self
                                                delegateQueue:nil];
    }
    if( self.addresses.count > 0){
        RemoteAddressAndPort * addressAndPort = self.addresses.firstObject;
        NSString * url = [NSString stringWithFormat:@"https://%@:%@/last", addressAndPort.ip, @(addressAndPort.port)];
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        self.request = request;
        self.task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse*response,NSError*error){
            NSLog(@"Done %@ %@", response, error);
            self.data = data;
            if( [response isKindOfClass:[NSHTTPURLResponse class]]){
                self.response = (NSHTTPURLResponse*)response;
            }else{
                self.response = nil;
            }
            completion(self);
        }];
        [self.task resume];
    }
}

-(NSString * )lastPullString{
    if( self.data ){
        NSStringEncoding encoding = self.response.textEncodingName ? CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)self.response.textEncodingName)) : NSUTF8StringEncoding;
        return [[NSString alloc] initWithData:self.data encoding:encoding];
    }
    return nil;
}

-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler{
    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
}

@end
