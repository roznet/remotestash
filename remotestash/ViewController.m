//
//  ViewController.m
//  remotecopypaste
//
//  Created by Brice Rosenzweig on 14/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import "ViewController.h"
#import "RemoteStashServer.h"
#import "RemoteStashClient.h"
#import "RemoteStashService.h"
#import "AppDelegate.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (nonatomic,retain) RemoteStashServer * server;
@property (nonatomic,retain) RemoteStashClient * client;
@property (weak, nonatomic) IBOutlet UILabel *connectedTo;
@property (weak, nonatomic) IBOutlet UILabel *received;
@property (weak, nonatomic) IBOutlet UITableView *serviceTableView;
@property (weak, nonatomic) IBOutlet UIImageView *imagePreview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.client = [[RemoteStashClient alloc] init];
    self.serviceTableView.dataSource = self.client;
    
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationNewServiceDiscovered object:nil queue:nil usingBlock:^(NSNotification * notification){
        NSLog(@"Notified new service");
        [self update];
        [self.serviceTableView reloadData];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationApplicationEnteredForeground object:nil queue:nil usingBlock:^(NSNotification*notification){
        [self update];
    }];
    
    [self update];
}

-(void)update{
    NSLog(@"update");
    UIPasteboard * pasteboard = [UIPasteboard generalPasteboard];
    if ([pasteboard hasStrings]){
        self.textField.text = pasteboard.string;
        self.imagePreview.image = nil;
    }else if( [pasteboard hasURLs] ){
        NSURL * url = pasteboard.URL;
        self.textField.text = url.description;
        self.imagePreview.image = nil;
    }else if( [pasteboard hasImages] ){
        self.textField.text = @"Image";
        self.imagePreview.image = pasteboard.image;
    }
    
    if( self.client.currentService ){
        self.connectedTo.text = [self.client.currentService name];
    }else{
        self.connectedTo.text = @"Not Connected";
    }
}
       
-(void)viewWillDisappear:(BOOL)animated{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
}
- (IBAction)push:(id)sender {
    [self update];
    UIPasteboard * pasteboard = [UIPasteboard generalPasteboard];
    if ([pasteboard hasStrings]){
        [[self.client currentService] pushString:pasteboard.string completion:^(RemoteStashService*service){
            NSLog(@"Done with %@", service);
        }];
    }
}


- (IBAction)pull:(id)sender {
    NSLog(@"pull");
    
    [[self.client currentService] pullWithCompletion:^(RemoteStashService*service){
        NSString * got = service.lastPullString;
        if( got ){
            dispatch_async(dispatch_get_main_queue(), ^(){
                self.received.text = got;
                [UIPasteboard generalPasteboard].string = got;
            });
        }
    }];
}
#pragma mark - remote client

-(void)connectedTo:(GCDAsyncSocket*)socket{
    dispatch_async(dispatch_get_main_queue(), ^(){
            self.connectedTo.text = [socket connectedHost];
    });
    
}
-(void)disconnected{
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.connectedTo.text = @"Disconnected";
    });
}
-(void)received:(NSString*)str{
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.received.text = str;
    });
}

@end
