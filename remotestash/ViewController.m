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

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (nonatomic,retain) RemoteStashServer * server;
@property (nonatomic,retain) RemoteStashClient * client;
@property (weak, nonatomic) IBOutlet UILabel *connectedTo;
@property (weak, nonatomic) IBOutlet UILabel *received;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.client = [[RemoteStashClient alloc] init];

}

- (IBAction)send:(id)sender {
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
