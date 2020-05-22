//
//  RemoteStashClient.m
//  remotestash
//
//  Created by Brice Rosenzweig on 22/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashClient.h"

@interface RemoteStashClient ()
@property (nonatomic,retain) NSNetServiceBrowser * browser;
@property (nonatomic,retain) NSArray<NSNetService*>*services;
@end

@implementation RemoteStashClient

-(RemoteStashClient*)init{
    self = [super init];
    if( self ){
        self.browser = [[NSNetServiceBrowser alloc] init];
        self.browser.delegate = self;
        self.services = @[];
        [self.browser searchForServicesOfType:@"_remotestash._tcp" inDomain:@""];
    }
    return self;
}

-(void)dealloc{
    [self.browser stop];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser
          didFindService:(NSNetService *)service
              moreComing:(BOOL)moreComing{
    NSLog(@"discovered %@", service);
    self.services = [self.services arrayByAddingObject:service];
    service.delegate = self;
    
    [service resolveWithTimeout:5.0];
}

-(void)netServiceDidResolveAddress:(NSNetService *)sender{
    NSLog(@"resolved %@", sender);
}
-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *,NSNumber *> *)errorDict{
    NSLog(@"failed to resolve %@", sender);
}
@end
