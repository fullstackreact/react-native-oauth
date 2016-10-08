//
//  OAuthManager.h
//
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCTBridgeModule.h"
#import "RCTLinkingManager.h"

static NSString *kAuthConfig = @"OAuthManager";

@interface OAuthManager : NSObject <RCTBridgeModule, UIWebViewDelegate>

+ (instancetype) sharedManager;
+ (BOOL)setupOAuthHandler:(UIApplication *)application;

+ (BOOL)handleOpenUrl:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

- (BOOL) _configureProvider:(NSString *) name andConfig:(NSDictionary *) config;

- (NSDictionary *) getConfigForProvider:(NSString *)name;

@property (nonatomic, strong) NSDictionary *providerConfig;

@end
