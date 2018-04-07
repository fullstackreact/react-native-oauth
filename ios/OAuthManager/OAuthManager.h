//
//  OAuthManager.h
//
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<React/RCTBridgeModule.h>)
  #import <React/RCTBridgeModule.h>
#else
  #import "RCTBridgeModule.h"
#endif

#if __has_include("RCTLinkingManager.h")
    #import "RCTLinkingManager.h"
#else
    #import <React/RCTLinkingManager.h>
#endif



@class OAuthClient;

static NSString *kAuthConfig = @"OAuthManager";

@interface OAuthManager : NSObject <RCTBridgeModule, UIWebViewDelegate>

+ (instancetype) sharedManager;
+ (BOOL)setupOAuthHandler:(UIApplication *)application;

+ (BOOL)handleOpenUrl:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

- (BOOL) _configureProvider:(NSString *) name andConfig:(NSDictionary *) config;
- (NSDictionary *) getConfigForProvider:(NSString *)name;

@property (nonatomic, strong) NSDictionary *providerConfig;
@property (nonatomic, strong) NSArray *callbackUrls;

@end
