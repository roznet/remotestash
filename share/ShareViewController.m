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
    self.client = [RemoteStashClient clientWithDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationNewServiceDiscovered
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification*notification){
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

-(void)remoteStashClient:(RemoteStashClient *)client didAddService:(RemoteStashService *)service{
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self reloadConfigurationItems];
    });
}

- (NSArray *)configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    NSMutableArray * rv = [NSMutableArray array];
    if( self.client.pendingServices.count){
        RemoteStashService * service = self.client.currentService;
        SLComposeSheetConfigurationItem * item = [[SLComposeSheetConfigurationItem alloc] init];
        item.title = @"RemoteStash";
        item.value = service.name;
        item.tapHandler = ^(){
            [self pushServiceSelectionController];
        };
        [rv addObject:item];
    }
    return rv;
}

-(void)pushServiceSelectionController{
    UITableViewController * tvc = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    tvc.tableView.dataSource = self.client;
    tvc.tableView.delegate = self.client;
    [self.navigationController pushViewController:tvc animated:YES];
}

#pragma mark - RemoteStashClient

-(void)remoteStashClient:(RemoteStashClient *)client selectedRemoteService:(RemoteStashService *)service{
    [self.navigationController popViewControllerAnimated:YES];
    [self reloadConfigurationItems];
}

@end
