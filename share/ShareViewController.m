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
        [self reloadConfigurationItems];
    }];
}

- (void)didSelectPost {
    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
    // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
    
    
    NSLog(@"%@", @(self.extensionContext.inputItems.count));
    
    NSItemProvider * urlProvider = nil;
    
    for (NSExtensionItem * item in self.extensionContext.inputItems) {
        for (NSItemProvider * provider in item.attachments) {
            NSLog( @"%@", provider.registeredTypeIdentifiers );
            if ([provider hasItemConformingToTypeIdentifier:@"public.url"]) {
                urlProvider = provider;
            }
            
        }
    }
    
    if (urlProvider) {
        [urlProvider loadItemForTypeIdentifier:@"public.url"
                                        options:nil
                              completionHandler:^(NSURL *url, NSError *error) {
            // Do what you want to do with url
            NSLog(@"got url %@", url);
            [self.client.currentService pushString:url.description completion:^(RemoteStashService*service){
                NSLog(@"Done posting");
                [self.extensionContext completeRequestReturningItems:@[]
                                                   completionHandler:nil];
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
            [rv addObject:item];
        }
    }
    return rv;
}

@end
