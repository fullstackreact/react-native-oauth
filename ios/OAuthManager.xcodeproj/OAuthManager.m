//
//  OAuthManager.m
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "OAuthManager.h"
#import "DCTAuth.h"

#import "OAuthClient.h"
#import "OAuth1Client.h"
#import "OAuth2Client.h"

@implementation OAuthManager

RCT_EXPORT_MODULE(OAuthManager);

+ (instancetype)sharedManager {
    static OAuthManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self new];
    });
    return manager;
}

/*
 Call this from your AppDelegate.h
 */
+ (BOOL)setupOAuthHandler:(UIApplication *)application
              andDelegate:(UIResponder *)delegate
                     view:(UIView *)rootView
{
    OAuthManager *sharedManager = [OAuthManager sharedManager];
    DCTAuthPlatform *authPlatform = [DCTAuthPlatform sharedPlatform];
    
    authPlatform.URLOpener = ^void(NSURL *URL, DCTAuthPlatformCompletion completion) {
        [application openURL:URL];
        completion(YES);
    };
    
    
    // Check for plist file
    NSString *path = [[NSBundle mainBundle] pathForResource:kAuthConfig ofType:@"plist"];
    if (path != nil) {
        // plist exists
        NSDictionary *initialConfig = [NSDictionary dictionaryWithContentsOfFile:path];
        for (NSString *name in [initialConfig allKeys]) {
            NSDictionary *cfg = [initialConfig objectForKey:name];
            [sharedManager _configureProvider:name andConfig:cfg];
        }
    } else {
        [sharedManager setProviderConfig:[NSDictionary dictionary]];
    }
    
    return YES;
}

+ (BOOL)handleOpenUrl:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([url.host isEqualToString:@"oauth-response"]) {
        return [DCTAuth handleURL:url];
    }
    
    return [RCTLinkingManager application:application openURL:url
                        sourceApplication:sourceApplication annotation:annotation];
}

- (BOOL) _configureProvider:(NSString *)providerName andConfig:(NSDictionary *)config
{
    if (self.providerConfig == nil) {
        self.providerConfig = [[NSDictionary alloc] init];
    }
    
    NSMutableDictionary *providerCfgs = [self.providerConfig mutableCopy];
    
    NSMutableDictionary *objectProps = [[NSMutableDictionary alloc] init];
    
    // Convert objects of url type
    for (NSString *name in [config allKeys]) {
        if ([name rangeOfString:@"url"].location != NSNotFound) {
            // This is a URL representation
            NSString *urlStr = [config valueForKey:name];
            NSURL *url = [NSURL URLWithString:[urlStr
                                               stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            [objectProps setObject:url forKey:name];
        } else {
            NSString *str = [NSString stringWithString:[config valueForKey:name]];
            NSString *escapedStr = [str
                                    stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
            [objectProps setValue:[escapedStr copy] forKey:name];
        }
    }
    
    [providerCfgs setObject:objectProps forKey:providerName];
    
    self.providerConfig = providerCfgs;
    
    return YES;
}

- (NSDictionary *) getConfigForProvider:(NSString *)name
{
    return [self.providerConfig objectForKey:name];
}

/**
 * configure provider
 *
 * @param {string} providerName - name of the provider we are configuring
 * @param [object] props - properties to set on the configuration object
 */
RCT_EXPORT_METHOD(configureProvider:
                  (NSString *)providerName
                  props:(NSDictionary *)props
                  callback:(RCTResponseSenderBlock)callback)
{
    OAuthManager *sharedManager = [OAuthManager sharedManager];
    
    if ([sharedManager _configureProvider:providerName andConfig:props]) {
        callback(@[[NSNull null], @{
                       @"status": @"ok"
                       }]);
    } else {
        // Error?
        callback(@[@{
                       @"status": @"error"
                       }]);
    }
}

#pragma mark OAuth1.0
/**
 * authorize with url
 * provider, url, scope, state, params
 **/
RCT_EXPORT_METHOD(authorizeWithAppName:(NSString *)providerName
                  appName:(NSString *) appName
                  opts:(NSDictionary *) opts
                  callback:(RCTResponseSenderBlock)callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    NSMutableDictionary *cfg = [[manager getConfigForProvider:providerName] mutableCopy];
    
    NSString *callbackUrl = [NSString
                             stringWithFormat:@"%@://oauth-response/%@",
                             appName,
                             providerName];
    
    NSString *version = [cfg valueForKey:@"auth_version"];
    [cfg addEntriesFromDictionary:opts];
    
    OAuthClient *client;
    
    if ([version isEqualToString:@"1.0"]) {
        // OAuth 1
        client = (OAuthClient *)[[OAuth1Client alloc] init];
    } else if ([version isEqualToString:@"2.0"]) {
        client = (OAuthClient *)[[OAuth2Client alloc] init];
    } else {
        return callback(@[@{
                              @"status": @"error",
                              @"msg": @"Unknown provider"
                              }]);
    }
    
    [client authorizeWithUrl:providerName
                         url:callbackUrl
                         cfg:cfg
     
                   onSuccess:^(DCTAuthAccount *account) {
                       NSDictionary *accountResponse = [self getAccountResponse:account cfg:cfg];
                       callback(@[[NSNull null], @{
                                      @"status": @"ok",
                                      @"response": accountResponse
                                      }]);
                   } onError:^(NSError *error) {
                       NSLog(@"Error in authorizeWithUrl: %@", error);
                       callback(@[@{
                                      @"status": @"error",
                                      @"msg": [error localizedDescription]
                                      }]);
                   }];
}

#pragma mark - private

- (NSDictionary *) getAccountResponse:(DCTAuthAccount *) account
                                  cfg:(NSDictionary *)cfg
{
    NSString *version = [cfg valueForKey:@"auth_version"];
    NSMutableDictionary *accountResponse = [@{
                                      @"authorized": @(account.authorized),
                                      @"uuid": account.identifier
                                    } mutableCopy];
    
    if ([version isEqualToString:@"1.0"]) {
        DCTOAuth1Credential *credential = account.credential;
        NSDictionary *cred = @{
                               @"oauth_token": credential.oauthToken,
                               @"oauth_secret": credential.oauthTokenSecret
                               };
        [accountResponse addEntriesFromDictionary:@{@"credentials": cred}];
    } else if ([version isEqualToString:@"2.0"]) {
        DCTOAuth2Credential *credential = account.credential;
        NSDictionary *cred = @{
                               @"access_token": credential.accessToken,
                               @"refresh_token": credential.refreshToken,
                               @"type": @(credential.type)
                               };
        [accountResponse addEntriesFromDictionary:@{@"credentials": cred}];
    }
    return accountResponse;
}

@end
