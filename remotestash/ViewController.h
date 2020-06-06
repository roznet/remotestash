//
//  ViewController.h
//  remotecopypaste
//
//  Created by Brice Rosenzweig on 14/05/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RemoteStashServer.h"
#import "RemoteStashClient.h"

@interface ViewController : UIViewController<RemoteStashServerDelegate,RemoteStashClientDelegate>


@end

