//
//  RemoteStashClient.h
//  remotestash
//
//  Created by Brice Rosenzweig on 22/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@class RemoteStashService;

@interface RemoteStashClient : NSObject<NSNetServiceBrowserDelegate,UITableViewDataSource>

@property (nonatomic,nullable,readonly) RemoteStashService * currentService;
@property (nonatomic,readonly) NSArray<RemoteStashService*>*services;

@end

NS_ASSUME_NONNULL_END
