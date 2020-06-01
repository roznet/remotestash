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
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (nonatomic,retain) RemoteStashServer * server;
@property (nonatomic,retain) RemoteStashClient * client;
@property (weak, nonatomic) IBOutlet UILabel *connectedTo;
@property (weak, nonatomic) IBOutlet UILabel *received;
@property (weak, nonatomic) IBOutlet UITableView *serviceTableView;
@property (weak, nonatomic) IBOutlet UIImageView *imagePreview;
@property (weak, nonatomic) IBOutlet UIButton *shareButton;
@property (nonatomic,retain) UIImage * lastPullImage;
@property (nonatomic,retain) NSString * lastPullString;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.client = [[RemoteStashClient alloc] init];
    self.serviceTableView.dataSource = self.client;
    self.serviceTableView.delegate = self.client;
    
    UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(textViewDone:)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.textView.inputAccessoryView = keyboardToolbar;
    self.shareButton.imageView.tintColor = [UIColor systemBlueColor];
}

-(void)textViewDone:(UITextView*)view{
    [UIPasteboard generalPasteboard].string = self.textView.text;
    [self.textView resignFirstResponder];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationNewServiceDiscovered object:nil queue:nil usingBlock:^(NSNotification * notification){
        [self.client.currentService updateRemoteStatus:^(RemoteStashService*service){
            [self update];
        }];
        [self update];
        [self.serviceTableView reloadData];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationApplicationEnteredForeground object:nil queue:nil usingBlock:^(NSNotification*notification){
        [self update];
    }];
    
    [self update];
}

-(void)update{
    dispatch_async(dispatch_get_main_queue(), ^(){
        UIPasteboard * pasteboard = [UIPasteboard generalPasteboard];
        if ([pasteboard hasStrings]){
            self.textView.text = pasteboard.string;
            self.imagePreview.image = nil;
            self.textView.hidden = false;
            self.imagePreview.hidden = true;
            self.received.text = NSLocalizedString(@"Text", @"Received Text");
        }else if( [pasteboard hasURLs] ){
            NSURL * url = pasteboard.URL;
            self.textView.text = url.description;
            self.imagePreview.image = nil;
            self.textView.hidden = false;
            self.imagePreview.hidden = true;
            self.received.text = NSLocalizedString(@"URL", @"Received Text");
        }else if( [pasteboard hasImages] ){
            self.textView.text = nil;
            self.imagePreview.image = pasteboard.image;
            self.textView.hidden = true;
            self.imagePreview.hidden = false;
            self.received.text = NSLocalizedString(@"Image", @"Received Text");
        }
        
        if( self.client.currentService ){
            NSString * content = self.client.currentService.lastContentType;
            if( content ){
                content = [NSString stringWithFormat:@", next: %@", content];
            }else{
                content = @"";
            }
            
            NSString * message = [NSString stringWithFormat:@"%@ items %@", @(self.client.currentService.lastItemsCount), content];
            self.connectedTo.text = message;
                
        }else{
            self.connectedTo.text = @"Not Connected";
        }
        [self.serviceTableView reloadData];
    });
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

-(void)processResponseFromService:(RemoteStashService*)service{
    NSString * got = service.lastPullString;
    if( got ){
        self.lastPullString = got;
        self.lastPullImage = nil;
        dispatch_async(dispatch_get_main_queue(), ^(){
            self.textView.text = got;
            [UIPasteboard generalPasteboard].string = got;
            [self update];
        });
    }else{
        UIImage * image = service.lastPullImage;
        if( image ){
            self.lastPullString = nil;
            self.lastPullImage = image;
            dispatch_async(dispatch_get_main_queue(), ^(){
                self.textView.text = nil;
                self.imagePreview.image = image;
                [UIPasteboard generalPasteboard].image = image;
                [self update];
            });
        }
    }
}

- (IBAction)share:(id)sender {
    NSArray * items = nil;
    
    if( self.lastPullImage ){
        items = @[ self.lastPullImage];
    }else if (self.lastPullString){
        items = @[ self.lastPullString];
    }
    if( items ){
        UIActivityViewController * avc = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        
        [self presentViewController:avc animated:YES completion:^(){
            
        }];
    }
}

- (IBAction)last:(id)sender {
    [[self.client currentService] lastWithCompletion:^(RemoteStashService*service){
        [self processResponseFromService:service];
    }];
}

- (IBAction)pull:(id)sender {
    [[self.client currentService] pullWithCompletion:^(RemoteStashService*service){
        [self processResponseFromService:service];
        [self.client.currentService updateRemoteStatus:^(RemoteStashService*service){
            [self update];
        }];
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
