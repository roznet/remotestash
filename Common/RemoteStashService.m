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
        
        RemoteAddressAndPort * addressAndPort = self.addresses.firstObject;
        NSString * url = [NSString stringWithFormat:@"https://%@:%@/%@", addressAndPort.ip, @(addressAndPort.port), path];
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

-(void)pushImage:(UIImage*)img completion:(RemoteStashCompletionHandler)completion{
    NSMutableURLRequest * request = [self mutableRequest:@"push"];
    if( request ){
        request.HTTPBody = UIImageJPEGRepresentation(img, 1.0);
        request.HTTPMethod = @"POST";
        [request addValue:@"image/jpeg" forHTTPHeaderField:@"Content-type"];
        self.request = request;
        [self startTask:completion];
    }
}

-(void)pushString:(NSString *)str completion:(RemoteStashCompletionHandler)completion{
    NSMutableURLRequest * request = [self mutableRequest:@"push"];
    if( request ){
        request.HTTPBody = [str dataUsingEncoding:NSUTF8StringEncoding];
        request.HTTPMethod = @"POST";
        [request addValue:@"text/html" forHTTPHeaderField:@"Content-type"];
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

-(NSString*)contentType{
    return self.response.allHeaderFields[@"Content-Type"];
}
-(UIImage*)lastPullImage{
    if( [self.contentType hasPrefix:@"image/"] ){
        return [UIImage imageWithData:self.data];
    }
    
    return nil;
}
-(NSString * )lastPullString{
    if( [self.contentType hasPrefix:@"image/"] ){
        return nil;
    }
    if( self.data ){
        NSStringEncoding encoding = self.response.textEncodingName ? CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)self.response.textEncodingName)) : NSUTF8StringEncoding;
        return [[NSString alloc] initWithData:self.data encoding:encoding];
    }
    return nil;
}
-(NSDictionary*)lastPullJson{
    if( ! [self.contentType hasPrefix:@"application/json"] ){
        return nil;
    }
    if( self.data ){
        NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:self.data options:NSJSONReadingAllowFragments error:nil];
        return [dict isKindOfClass:[NSDictionary class]]?dict:nil;
    }
    return nil;

}
-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler{
    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
}

@end
