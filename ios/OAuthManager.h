//
//  OAuthSwiftManager.h
//  war
//
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RCTBridgeModule.h"

@interface OAuthManager : NSObject <RCTBridgeModule>

@property (nonatomic, strong) NSDictionary *providerProperties;

@end
