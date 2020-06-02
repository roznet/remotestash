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

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser didRemoveService:(nonnull NSNetService *)service moreComing:(BOOL)moreComing{
    NSMutableArray * newServices = [NSMutableArray array];

    // build new array without removed service
    for (RemoteStashService * rservice in self.services) {
        if( ![rservice.service isEqual:service] ){
            [newServices addObject:rservice];
        }
    }
    self.services = newServices;
    if( self.currentServiceIndex < 0 || self.currentServiceIndex >= self.services.count){
        self.currentServiceIndex = 0;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNewServiceDiscovered object:self.currentService];
    
    
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser
          didFindService:(NSNetService *)service
              moreComing:(BOOL)moreComing{
    self.services = [self.services arrayByAddingObject:[RemoteStashService serviceFor:service]];
    if( self.currentServiceIndex == -1 && self.services.count > 0){
        self.currentServiceIndex = 0;
    }
}
-(void)selectServiceWithName:(NSString*)name{
    for (NSUInteger current=0; current<self.services.count; current++) {
        if( [self.services[current].name isEqualToString:name] ){
            self.currentServiceIndex = current;
            break;
        }
    }
}

-(RemoteStashService*)currentService{
    if( self.currentServiceIndex == -1 || self.currentServiceIndex >= self.services.count){
        if( self.services.count > 0){
            return self.services.firstObject;
        }else{
            return nil;
        }
    }else{
        return self.services[self.currentServiceIndex];
    }
}


- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath{
    UITableViewCell * cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"servicecell"];
    cell.textLabel.text = self.services[indexPath.row].name;
    cell.detailTextLabel.text = self.services[indexPath.row].shortHostName;

    if( indexPath.row == self.currentServiceIndex ){
        cell.textLabel.font = [UIFont systemFontOfSize:16. weight:UIFontWeightBold];
    }else{
        cell.textLabel.font = [UIFont systemFontOfSize:16. weight:UIFontWeightRegular];
    }
    
    
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.services.count;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    self.currentServiceIndex = indexPath.row;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNewServiceDiscovered object:self];
    [tableView reloadData];
}
@end
