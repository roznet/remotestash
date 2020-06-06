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
@property (nonatomic,retain) NSArray<RemoteStashService*>*pendingServices;
@property (nonatomic,retain) NSArray<RemoteStashService*>*services;
@property (nonatomic,assign) NSInteger currentServiceIndex;
@end

@implementation RemoteStashClient

+(RemoteStashClient*)clientWithDelegate:(NSObject<RemoteStashClientDelegate>*)delegate{
    RemoteStashClient* rv = [[RemoteStashClient alloc] init];
    if( rv ){
        rv.delegate = delegate;
        rv.browser = [[NSNetServiceBrowser alloc] init];
        rv.browser.delegate = rv;
        rv.pendingServices = @[];
        rv.services = @[];
        [rv.browser searchForServicesOfType:@"_remotestash._tcp" inDomain:@""];
        rv.currentServiceIndex = -1;
    }
    return rv;
}

-(void)dealloc{
    [self.browser stop];
}

-(void)resolvedRemoteStashService:(RemoteStashService *)service{
    BOOL shouldAdd = true;
    
    for (RemoteStashService * rservice in self.services) {
        if( [rservice.serverUUID isEqual:service.serverUUID] ){
            shouldAdd = false;
        }
    }
    
    if( [self.delegate respondsToSelector:@selector(remoteStashClient:shouldAddService:)]){
        shouldAdd = [self.delegate remoteStashClient:self shouldAddService:service];
    }
    if( shouldAdd ){
        self.services = [self.services arrayByAddingObject:service];
        if( self.currentServiceIndex == -1 && self.pendingServices.count > 0){
            self.currentServiceIndex = 0;
        }
        if( self.services[self.currentServiceIndex].temporary ){
            for( NSUInteger i=0;i<self.services.count;++i){
                if( !self.services[i].temporary ){
                    self.currentServiceIndex = i;
                    break;
                }
            }
        }
        
        if( [self.delegate respondsToSelector:@selector(remoteStashClient:didAddService:)]){
            [self.delegate remoteStashClient:self didAddService:service];
        }
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser
          didFindService:(NSNetService *)service
              moreComing:(BOOL)moreComing{
    RemoteStashService * toAdd = [RemoteStashService serviceFor:service withDelegate:self];
    self.pendingServices = [self.pendingServices arrayByAddingObject:toAdd];
}

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser
        didRemoveService:(nonnull NSNetService *)service
              moreComing:(BOOL)moreComing{
    NSMutableArray * newServices = [NSMutableArray array];

    RemoteStashService * removed = nil;
    
    // build new array without removed service
    for (RemoteStashService * rservice in self.pendingServices) {
        if( ![rservice.service isEqual:service] ){
            [newServices addObject:rservice];
        }else{
            removed = rservice;
        }
    }
    self.services = newServices;
    if( self.currentServiceIndex < 0 || self.currentServiceIndex >= self.pendingServices.count){
        self.currentServiceIndex = 0;
    }

    if( removed != nil && [self.delegate respondsToSelector:@selector(remoteStashClient:didRemoteService:)]){
        [self.delegate remoteStashClient:self didRemoteService:removed];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNewServiceDiscovered object:self.currentService];
}

-(void)selectServiceWithName:(NSString*)name{
    for (NSUInteger current=0; current<self.pendingServices.count; current++) {
        if( [self.pendingServices[current].name isEqualToString:name] ){
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
    if( [self.delegate respondsToSelector:@selector(remoteStashClient:selectedRemoteService:)]){
        [self.delegate remoteStashClient:self selectedRemoteService:self.currentService];
    }
}
@end
