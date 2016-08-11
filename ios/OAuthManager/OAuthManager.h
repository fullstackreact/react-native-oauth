//
//  OAuthSwiftManager.h
//
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCTBridgeModule.h"
#import "RCTLinkingManager.h"

@interface OAuthManager : NSObject <RCTBridgeModule>

+ (BOOL)handleOpenUrl:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

@property (nonatomic, strong) NSDictionary *providerProperties;
@property (nonatomic, strong) NSDictionary *providerCredentials;

@end
