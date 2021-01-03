//
//  RemoteStashMimeTypes.h
//  remotestash
//
//  Created by Brice Rosenzweig on 27/09/2020.
//  Copyright © 2020 Brice Rosenzweig. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RemoteStashMimeTypes : NSObject

+(NSString*)mimeTypeForExtension:(NSString*)extension;

@end

NS_ASSUME_NONNULL_END
