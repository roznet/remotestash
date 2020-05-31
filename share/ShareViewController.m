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
    NSItemProvider * urlProvider = nil;
    NSItemProvider * jpegProvider = nil;
    
    for (NSExtensionItem * item in self.extensionContext.inputItems) {
        for (NSItemProvider * provider in item.attachments) {
            if ([provider hasItemConformingToTypeIdentifier:@"public.url"]) {
                urlProvider = provider;
            }
            if( [provider hasItemConformingToTypeIdentifier:@"public.jpeg"]){
                jpegProvider = provider;
            }
        }
    }
    
    if (urlProvider) {
        [urlProvider loadItemForTypeIdentifier:@"public.url"
                                        options:nil
                              completionHandler:^(NSURL *url, NSError *error) {
            // Do what you want to do with url
            [self.client.currentService pushString:url.description completion:^(RemoteStashService*service){
                NSLog(@"Done posting");
                dispatch_async( dispatch_get_main_queue(), ^(){
                    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems
                                                       completionHandler:nil];

                });
            }];
        }];
    }else if (jpegProvider){
        [jpegProvider loadItemForTypeIdentifier:@"public.jpeg" options:nil completionHandler:^(NSURL * url, NSError * error){
            UIImage * image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
            [self.client.currentService pushImage:image completion:^(RemoteStashService*service){
                dispatch_async( dispatch_get_main_queue(), ^(){
                    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems
                                                       completionHandler:nil];

                });
            }];
        }];
    }else{
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    }
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
