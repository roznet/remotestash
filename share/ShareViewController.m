//
//  ShareViewController.m
//  share
//
//  Created by Brice Rosenzweig on 17/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "ShareViewController.h"
#import "RemoteStashClient.h"
#import "RemoteStashService.h"
#import "RemoteStashItem.h"

@interface ShareViewController ()
@property (nonatomic,retain) RemoteStashClient * client;
@end

@implementation ShareViewController

- (BOOL)isContentValid {
    // Do validation of contentText and/or NSExtensionContext attachments here
    return YES;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    self.client = [[RemoteStashClient alloc] init];
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationNewServiceDiscovered
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification*notification){
        NSLog(@"Got services");
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self reloadConfigurationItems];
        });
    }];
}

- (void)didSelectPost {
    [RemoteStashItem itemFromExtensionContext:self.extensionContext completion:^(RemoteStashItem*item){
        [self.client.currentService pushItem:item completion:^(RemoteStashService*service){
            dispatch_async( dispatch_get_main_queue(), ^(){
                [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems
                                                   completionHandler:nil];
            });
        }];
    }];
}

- (NSArray *)configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    NSMutableArray * rv = [NSMutableArray array];
    if( self.client.services.count){
        for (RemoteStashService * service in self.client.services) {
            SLComposeSheetConfigurationItem * item = [[SLComposeSheetConfigurationItem alloc] init];
            item.title = service.name;
            item.value = service.name;
            item.tapHandler = ^(){
                NSLog(@"select %@", service.name);
            };
            [rv addObject:item];

        }
    }
    return rv;
}

@end
