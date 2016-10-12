//
//  OAuthManager.m
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "OAuthManager.h"
#import "DCTAuth.h"
#import "DCTAuthAccountStore.h"

#import "OAuthClient.h"
#import "OAuth1Client.h"
#import "OAuth2Client.h"

@interface OAuthManager()
  @property (nonatomic) NSArray *pendingClients;
  @property BOOL pendingAuthentication;
@end

@implementation OAuthManager

@synthesize callbackUrls = _callbackUrls;

RCT_EXPORT_MODULE(OAuthManager);

+ (instancetype)sharedManager {
    static OAuthManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self new];
    });
    return manager;
}

- (instancetype) init {
    self = [super init];
    if (self != nil) {
        _callbackUrls = [[NSArray alloc] init];
        _pendingClients = [[NSArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) didBecomeActive:(NSNotification *)notification
{
    NSLog(@"Application reopened: %@", @(self.pendingAuthentication));
    for (OAuthClient *client in _pendingClients) {
        [self removePending:client];
    }
}

/*
 Call this from your AppDelegate.h
 */
+ (BOOL)setupOAuthHandler:(UIApplication *)application
{
    OAuthManager *sharedManager = [OAuthManager sharedManager];
    DCTAuthPlatform *authPlatform = [DCTAuthPlatform sharedPlatform];
    
    [authPlatform setURLOpener: ^void(NSURL *URL, DCTAuthPlatformCompletion completion) {
        [sharedManager setPendingAuthentication:YES];
        [application openURL:URL];
        completion(YES);
    }];
    
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
    OAuthManager *manager = [OAuthManager sharedManager];
    NSString *strUrl = [manager stringHost:url];

    NSLog(@"Handling handleOpenUrl: %@", strUrl);
    
    if ([manager.callbackUrls indexOfObject:strUrl] != NSNotFound) {
        return [DCTAuth handleURL:url];
    }
    

    [manager clearPending];
    
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
    
    // Save the callback url for checking later
    NSMutableArray *arr = [_callbackUrls mutableCopy];
    NSString *callbackUrlStr = [config valueForKey:@"callback_url"];
    NSURL *callbackUrl = [NSURL URLWithString:callbackUrlStr];
    NSString *saveCallbackUrl = [self stringHost:callbackUrl];
    [arr addObject:saveCallbackUrl];
    _callbackUrls = [arr copy];
    
    // Convert objects of url type
    for (NSString *name in [config allKeys]) {
        if ([name rangeOfString:@"_url"].location != NSNotFound) {
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
RCT_EXPORT_METHOD(authorize:(NSString *)providerName
                  opts:(NSDictionary *) opts
                  callback:(RCTResponseSenderBlock)callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    NSMutableDictionary *cfg = [[manager getConfigForProvider:providerName] mutableCopy];
    
    NSString *appName = [cfg valueForKey:@"app_name"];
    
    NSString *callbackUrl;
    NSURL *storedCallbackUrl = [cfg objectForKey:@"callback_url"];
    
    if (storedCallbackUrl != nil) {
        callbackUrl = [storedCallbackUrl absoluteString];
    } else {
        callbackUrl = [NSString
                       stringWithFormat:@"%@://oauth-response/%@",
                       appName,
                       providerName];
    }
    
    NSString *version = [cfg valueForKey:@"auth_version"];
    [cfg addEntriesFromDictionary:opts];
    
    OAuthClient *client;
    
    if ([version isEqualToString:@"1.0"]) {
        // OAuth 1
        client = (OAuthClient *)[[OAuth1Client alloc] init];
    } else if ([version isEqualToString:@"2.0"]) {
        client = (OAuthClient *)[[OAuth2Client alloc] init];
    } else {
        NSLog(@"Provider number: %@", version);
        return callback(@[@{
                              @"status": @"error",
                              @"msg": @"Unknown provider"
                              }]);
    }

    // Store pending client
    
    [self addPending:client];
      _pendingAuthentication = YES;
    
    [client authorizeWithUrl:providerName
                         url:callbackUrl
                         cfg:cfg
     
                   onSuccess:^(DCTAuthAccount *account) {
                    NSLog(@"authorizeWithUrl: %@", account);
                       NSDictionary *accountResponse = [manager getAccountResponse:account cfg:cfg];
                       _pendingAuthentication = NO;
                       [manager removePending:client];
                       callback(@[[NSNull null], @{
                                      @"status": @"ok",
                                      @"response": accountResponse
                                      }]);
                   } onError:^(NSError *error) {
                       NSLog(@"Error in authorizeWithUrl: %@", error);
                       _pendingAuthentication = NO;
                       [manager removePending:client];
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
        [accountResponse setObject:cred forKey:@"credentials"];
    } else if ([version isEqualToString:@"2.0"]) {
        DCTOAuth2Credential *credential = account.credential;
        NSMutableDictionary *cred = [@{
                                       @"access_token": credential.accessToken,
                                       @"type": @(credential.type)
                                       } mutableCopy];
        if (credential.refreshToken != nil) {
            [cred setValue:credential.refreshToken forKey:@"refresh_token"];
        }
        [accountResponse setObject:cred forKey:@"credentials"];
    }
    return accountResponse;
}

- (void) clearPending
{
    OAuthManager *manager = [OAuthManager sharedManager];
    for (OAuthClient *client in manager.pendingClients) {
        [manager removePending:client];
    }
    manager.pendingClients = [NSArray array];
}

- (void) addPending:(OAuthClient *) client
{
    OAuthManager *manager = [OAuthManager sharedManager];
    NSMutableArray *newPendingClients = [manager.pendingClients mutableCopy];
    [newPendingClients addObject:client];
    manager.pendingClients = newPendingClients;
}

- (void) removePending:(OAuthClient *) client
{
    OAuthManager *manager = [OAuthManager sharedManager];
    NSUInteger idx = [manager.pendingClients indexOfObject:client];
    NSMutableArray *newPendingClients = [manager.pendingClients mutableCopy];
    [newPendingClients removeObjectAtIndex:idx];
    [client cancelAuthentication];
    manager.pendingClients = newPendingClients;
}

- (NSString *) stringHost:(NSURL *)url
{
    NSString *str;
    if (url.host != nil) {
        str = [NSString stringWithFormat:@"%@://%@%@", url.scheme, url.host, url.path];
    } else {
        str = [NSString stringWithFormat:@"%@%@", url.scheme, url.path];
    }
    
    if ([str hasSuffix:@"/"]) {
        str = [str substringToIndex:str.length - 1];
    }
    
    return str;
}

@end
