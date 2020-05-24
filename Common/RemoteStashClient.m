//
//  RemoteStashClient.m
//  remotestash
//
//  Created by Brice Rosenzweig on 22/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "RemoteStashClient.h"
#import "RemoteStashService.h"

@interface RemoteStashClient ()
@property (nonatomic,retain) NSNetServiceBrowser * browser;
@property (nonatomic,retain) NSArray<RemoteStashService*>*services;
@property (nonatomic,assign) NSInteger currentServiceIndex;
@end

@implementation RemoteStashClient

-(RemoteStashClient*)init{
    self = [super init];
    if( self ){
        self.browser = [[NSNetServiceBrowser alloc] init];
        self.browser.delegate = self;
        self.services = @[];
        [self.browser searchForServicesOfType:@"_remotestash._tcp" inDomain:@""];
        self.currentServiceIndex = -1;
    }
    return self;
}

-(void)dealloc{
    [self.browser stop];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser
          didFindService:(NSNetService *)service
              moreComing:(BOOL)moreComing{
    self.services = [self.services arrayByAddingObject:[RemoteStashService serviceFor:service]];
    if( self.currentServiceIndex == -1 && self.services.count > 0){
        self.currentServiceIndex = 0;
    }
}

-(RemoteStashService*)currentService{
    if( self.currentServiceIndex == -1 || self.currentServiceIndex >= self.services.count){
        return nil;
    }else{
        return self.services[self.currentServiceIndex];
    }
}


- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath{
    UITableViewCell * cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"servicecell"];
    cell.textLabel.text = self.services[indexPath.row].name;
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.services.count;
}


@end
