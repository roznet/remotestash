//
//  ShareViewController.h
//  share
//
//  Created by Brice Rosenzweig on 17/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import "RemoteStashClient.h"

@interface ShareViewController : SLComposeServiceViewController<RemoteStashClientDelegate>

@end
