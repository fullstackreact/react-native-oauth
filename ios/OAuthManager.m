//
//  OAuthSwiftManager.m
//  war
//
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OAuthManager.h"

@import OAuthSwift;

typedef NSMutableDictionary *(^CustomSuccessHandler)(OAuthSwiftCredential *, NSURLResponse *, NSDictionary *, NSMutableDictionary*);
typedef void (^OAuthHandler)(OAuthSwiftCredential *, NSURLResponse *, NSDictionary *);
typedef OAuthHandler (^OAuthSuccessHandler)(OAuthSwiftCredential *, NSURLResponse *, NSDictionary *);
typedef void (^OAuthErrorHandler)(NSError *);

@implementation OAuthManager

RCT_EXPORT_MODULE(OAuthManager);

/*
 Call this from your AppDelegate.h
 */
+ (BOOL)handleOpenUrl:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([url.host isEqualToString:@"oauth-callback"]) {
        NSLog(@"Open from url: %@", url);
        [OAuthSwift handleOpenURL:url];
    }

    return [RCTLinkingManager application:application openURL:url
                        sourceApplication:sourceApplication annotation:annotation];
}

// TODO: Move below
- (OAuthHandler) makeHandler:(CustomSuccessHandler)handler
                providerName:(NSString *)providerName
                    resolver:(RCTPromiseResolveBlock)resolve
                    rejector:(RCTPromiseRejectBlock)reject
{
    return ^(OAuthSwiftCredential *cred, NSURLResponse *resp, NSDictionary *params) {
        NSMutableDictionary *props = [[NSMutableDictionary alloc] initWithCapacity:20];

        [props setValue:providerName forKey:@"providerName"];
        [props setValue:cred.oauth_token forKey:@"oauth_token"];
        [props setValue:cred.oauth_token_secret forKey:@"oauth_token_secret"];

        if (cred.oauth_token_expires_at != nil) {
            [props setValue:cred.oauth_token_expires_at forKey:@"oauth_token_expires_at"];
        }
        if (cred.oauth_refresh_token != nil) {
            [props setValue:cred.oauth_refresh_token forKey:@"oauth_refresh_token"];
        }

        if (handler) {
            NSMutableDictionary *customProps = handler(cred, resp, params, props);
            [props addEntriesFromDictionary:customProps];
        }

        NSLog(@"Handling success with: %@", cred);

        resolve(props);
    };
}

- (NSDictionary *) defaultProviderConfiguration
{
    return @{
             @"twitter":
                 @{
                     @"requestTokenUrl": @"https://api.twitter.com/oauth/request_token",
                     @"authorizeUrl":    @"https://api.twitter.com/oauth/authorize",
                     @"accessTokenUrl":  @"https://api.twitter.com/oauth/access_token"
                     },
             @"facebook":
                 @{
                     @"authorizeUrl":   @"https://www.facebook.com/dialog/oauth",
                     @"accessTokenUrl": @"https://graph.facebook.com/oauth/access_token",
                     @"responseType":   @"token"
                     }
             };
}

- (NSDictionary *) getDefaultProviderConfig:(NSString *) providerName
{
    return [[self defaultProviderConfiguration] objectForKey:providerName];
}

- (NSDictionary *) getProviderConfig:(NSString *)providerName
{
    if (self.providerProperties == nil) {
        return nil;
    }
    NSDictionary *providerCfg = [self.providerProperties objectForKey:providerName];

    return providerCfg;
}

- (id) oauthInstance:(NSString *) providerName
{
    NSLog(@"oauthInstance for: %@ %@", providerName, self.providerProperties);
    if (self.providerProperties == nil) {
        return nil;
    }

    NSDictionary *providerCfg = [self getProviderConfig:providerName];
    NSString *consumerKey = [providerCfg valueForKey:@"consumerKey"];
    NSString *consumerSecret = [providerCfg valueForKey:@"consumerSecret"];

    if ([providerName isEqualToString:@"twitter"]) {
        return [[OAuth1Swift alloc] initWithConsumerKey:consumerKey
                                         consumerSecret:consumerSecret
                                        requestTokenUrl:[providerCfg valueForKey:@"requestTokenUrl"]
                                           authorizeUrl:[providerCfg valueForKey:@"authorizeUrl"]
                                         accessTokenUrl:[providerCfg valueForKey:@"accessTokenUrl"]];
    } else if ([providerName isEqualToString:@"facebook"]) {
        return [[OAuth2Swift alloc] initWithConsumerKey:consumerKey
                                         consumerSecret:consumerSecret
                                           authorizeUrl:[providerCfg valueForKey:@"authorizeUrl"]
                                         accessTokenUrl:[providerCfg valueForKey:@"accessTokenUrl"]
                                           responseType:[providerCfg valueForKey:@"responseType"]];
    } else {
        NSLog(@"Provider (%@) not handled", providerName);
        return nil;
    }
}

RCT_EXPORT_METHOD(providers:(RCTResponseSenderBlock)callback)
{

    NSDictionary *props = [self defaultProviderConfiguration];
    if (props != nil) {
        callback(@[[NSNull null], props]);
    } else {
        NSDictionary *err = @{
                              @"providers": @"There was a major problem. We're investigating"
                              };
        callback(@[err]);
    }
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
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject)
{
    if (self.providerProperties == nil) {
        self.providerProperties = [[NSDictionary alloc] init];
    }

    NSDictionary *defaultProviderConfig = [self getDefaultProviderConfig:providerName];

    if (defaultProviderConfig == nil) {
        return reject(@"Provider not handled", [NSString stringWithFormat:@"%@ not handled yet", providerName], nil);
    }

    NSMutableDictionary *globalCurrentConfig = [self.providerProperties mutableCopy];
    NSMutableDictionary *currentProviderConfig = [globalCurrentConfig objectForKey:providerName];

    if (currentProviderConfig == nil) {
        currentProviderConfig = [[NSMutableDictionary alloc] init];
    }
//    NSMutableDictionary *mutableCurrentConfig = [self.providerProperties mutableCopy];
//    NSMutableDictionary *currentConfig = [mutableCurrentConfig objectForKey:providerName];
//    if (currentConfig == nil) {
//        currentConfig = [[NSMutableDictionary alloc] init];
//    }

    NSMutableDictionary *combinedAttributes = [NSMutableDictionary dictionaryWithCapacity:20];
    [combinedAttributes addEntriesFromDictionary:defaultProviderConfig];
    [combinedAttributes addEntriesFromDictionary:currentProviderConfig];

    NSString *consumerKey = [props valueForKey:@"consumer_key"];
    NSString *consumerSecret = [props valueForKey:@"consumer_secret"];

    NSDictionary *providerProps = @{
                                    @"consumerKey": consumerKey,
                                    @"consumerSecret": consumerSecret
                                    };
    [combinedAttributes addEntriesFromDictionary:providerProps];

    [globalCurrentConfig setObject:combinedAttributes forKey:providerName];
    self.providerProperties = globalCurrentConfig;

    resolve(nil);
}

RCT_EXPORT_METHOD(authorizeWithCallbackURL:
                  (NSString *)provider
                  url:(NSString *)strUrl
                  scope:(NSString *)scope
                  state:(NSString *)state
                  params:(NSDictionary *)params
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject)
{
    NSURL *url = [NSURL URLWithString:strUrl];

    if (url == nil) {
        return reject(@"No url",
                      [NSString stringWithFormat:@"Url %@ not passed", strUrl],
                      nil);
    }

    // Handle OAuth
    id oauthInstance = [self oauthInstance:provider];
    if (oauthInstance == nil) {
        return reject(@"No provider",
                      [NSString stringWithFormat:@"Provider %@ not configured", provider],
                      nil);
    }

    CustomSuccessHandler customSuccessHandler;
    OAuthErrorHandler errorHandler = ^(NSError *err) {
        NSLog(@"failure: %@", err);
        reject(@"Error", @"There was an error handling callback", err);
    };

    // OAuth 1.0
    if ([provider isEqualToString:@"twitter"])
    {
        customSuccessHandler = ^(OAuthSwiftCredential *cred, NSURLResponse *resp, NSDictionary *params, NSMutableDictionary *dict) {
            return dict;
        };
        OAuthHandler successHandler = [self makeHandler:customSuccessHandler
                                           providerName:provider
                                               resolver:resolve
                                               rejector:reject];

        [oauthInstance authorizeWithCallbackURL:url
                                        success:successHandler
                                        failure:errorHandler];

    } else if ([provider isEqualToString:@"facebook"])
    {
        customSuccessHandler = ^(OAuthSwiftCredential *cred, NSURLResponse *resp, NSDictionary *parms, NSMutableDictionary *dict) {
            NSLog(@"Success handler called in facebook: %@, %@", cred, resp);
            return dict;
        };
        if ([state isEqualToString:@""]) {
            state = provider;
        }

        OAuthHandler successHandler = [self makeHandler:customSuccessHandler
                                           providerName:provider
                                               resolver:resolve
                                               rejector:reject];

        NSLog(@"Facebook authorize called: %@, %@, %@, %@, %@, %@", url, scope, state, params, successHandler, errorHandler);
        OAuth2Swift *inst = oauthInstance;
        NSLog(@"inst: %@", inst);
        [inst authorizeWithCallbackURL:url
                                 scope:scope
                                 state:state
                                params:params
                               success:successHandler
                               failure:errorHandler];
    }
}

@end
