//
//  OAuthSwiftManager.m
//  war
//
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OAuthManager.h"

@import OAuthSwift;

@implementation OAuthManager

RCT_EXPORT_MODULE(OAuthManager);

- (NSDictionary *) _defaultTwitterConfig
{
    return @{
             @"requestTokenUrl": @"https://api.twitter.com/oauth/request_token",
             @"authorizeUrl":    @"https://api.twitter.com/oauth/authorize",
             @"accessTokenUrl":  @"https://api.twitter.com/oauth/access_token"
             };
}

- (NSDictionary *) providerConfigs
{
  return @{
        @"twitter": [self _defaultTwitterConfig]
    };
}

- (OAuth1Swift *) oauth1Instance:(NSString *) provider
{
    OAuth1Swift *inst = nil;

    if (self.providerProperties == nil) {
        return nil;
    }

    NSDictionary *providerCfg = [self.providerProperties valueForKey:provider];

    if ([provider isEqualToString:@"twitter"]) {
        NSString *consumerKey = [providerCfg valueForKey:@"consumerKey"];
        NSString *consumerSecret = [providerCfg valueForKey:@"consumerSecret"];

        inst = [[OAuth1Swift alloc] initWithConsumerKey:consumerKey
                                         consumerSecret:consumerSecret
                                        requestTokenUrl:[providerCfg valueForKey:@"requestTokenUrl"]
                                           authorizeUrl:[providerCfg valueForKey:@"authorizeUrl"]
                                         accessTokenUrl:[providerCfg valueForKey:@"accessTokenUrl"]];
    }

    return inst;
}

RCT_EXPORT_METHOD(providers:(RCTResponseSenderBlock)callback)
{

  NSDictionary *props = [self providerConfigs];
  if (props != nil) {
    callback(@[[NSNull null], props]);
  } else {
    NSDictionary *err = @{
                          @"providers": @"There was a major problem. We're investigating"
                          };
    callback(@[err]);
  }
}

RCT_EXPORT_METHOD(configureProvider:
                  (NSString *)providerName
                  props:(NSDictionary *)props
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject)
{
    if (self.providerProperties == nil) {
        self.providerProperties = [[NSDictionary alloc] init];
    }

    NSMutableDictionary *currentConfig = [self.providerProperties mutableCopy];
    NSMutableDictionary *combinedAttributes;
    if ([providerName isEqualToString:@"twitter"]) {

        NSLog(@"Configuring twitter: %@ with %@", providerName, props);
        NSString *consumerKey = [props valueForKey:@"consumer_key"];
        NSString *consumerSecret = [props valueForKey:@"consumer_secret"];

        NSDictionary *twitterCfg = [self _defaultTwitterConfig];
        NSDictionary *twitterProps = @{
                                       @"consumerKey": consumerKey,
                                       @"consumerSecret": consumerSecret,
                                       };

        combinedAttributes = [NSMutableDictionary dictionaryWithCapacity:20];
        [combinedAttributes addEntriesFromDictionary:twitterCfg];
        [combinedAttributes addEntriesFromDictionary:twitterProps];
    } else {
        return reject(@"Provider not handled", [NSString stringWithFormat:@"%@ not handled yet", providerName], nil);
    }

    [currentConfig setObject:combinedAttributes forKey:providerName];
    self.providerProperties = currentConfig;
    resolve(nil);
}

RCT_EXPORT_METHOD(authorizeWithCallbackURL:
                  (NSString *)provider
                  url:(NSString *)strUrl
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejector:(RCTPromiseRejectBlock)reject)
{

    OAuth1Swift *inst = [self oauth1Instance:provider];
    if (inst == nil) {
        return reject(@"No provider",
                      [NSString stringWithFormat:@"Provider %@ not configured", provider],
                      nil);
    }

    NSURL *url = [NSURL URLWithString:strUrl];

    if (url == nil) {
        return reject(@"No url",
                      [NSString stringWithFormat:@"Url %@ not passed", strUrl],
                      nil);
    }

    NSLog(@"url: %@ and %@", strUrl, inst);
    [inst authorizeWithCallbackURL:url
                           success: ^(OAuthSwiftCredential *cred, NSURLResponse *resp, NSDictionary *params) {
                               NSLog(@"Success: %@, %@, %@ with %@", cred.oauth_token,
                                     cred.oauth_token_secret,
                                     cred.oauth_token_expires_at,
                                     params);
                               NSMutableDictionary *props = [[NSMutableDictionary alloc] initWithCapacity:20];
                               NSMutableDictionary *creds = [@{
                                                               @"oauth_token": cred.oauth_token,
                                                               @"oauth_token_secret": cred.oauth_token_secret
                                                               } mutableCopy];

                               // TODO: Could do this a LOT better...
                               if (cred.oauth_token_expires_at != nil) {
                                   [creds setValue:cred.oauth_token_expires_at forKey:@"oauth_token_expires_at"];
                               }
                               if (cred.oauth_refresh_token != nil) {
                                   [creds setValue:cred.oauth_refresh_token forKey:@"oauth_refresh_token"];
                               }

                               [props setValue:creds forKey:@"credentials"];
                               NSLog(@"props: %@", props);

                               if (params != nil) {
                                   [props setValue:params forKey:@"params"];
                               }
                               NSLog(@"props: %@", props);

                               resolve(props);
                           }
                           failure:^(NSError *err) {
                               NSLog(@"failure: %@", err);
                               reject(@"Error", @"There was an error handling callback", err);
                           }];
}

@end
