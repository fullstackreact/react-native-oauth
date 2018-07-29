//
//  OAuthManager.m
//  Created by Ari Lerner on 5/31/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <SafariServices/SafariServices.h>

#import "OAuthManager.h"
#import "DCTAuth.h"
#import "DCTAuthAccountStore.h"

#import "OAuthClient.h"
#import "OAuth1Client.h"
#import "OAuth2Client.h"
#import "XMLReader.h"

@interface OAuthManager()
@property (nonatomic) NSArray *pendingClients;
@property BOOL pendingAuthentication;
@end

@implementation OAuthManager

@synthesize callbackUrls = _callbackUrls;

static NSString *const AUTH_MANAGER_TAG = @"AUTH_MANAGER";
static OAuthManager *manager;
static dispatch_once_t onceToken;
static SFSafariViewController *safariViewController = nil;

RCT_EXPORT_MODULE(OAuthManager);

// Run on a different thread
- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("io.fullstack.oauth", DISPATCH_QUEUE_SERIAL);
}

+ (instancetype)sharedManager {
    dispatch_once(&onceToken, ^{
        manager = [self new];
    });
    return manager;
}

+ (void) reset {
    onceToken = nil;
    manager = nil;
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
    // TODO?
}

/*
 Call this from your AppDelegate.h
 */
+ (BOOL)setupOAuthHandler:(UIApplication *)application
{
    OAuthManager *sharedManager = [OAuthManager sharedManager];
    DCTAuthPlatform *authPlatform = [DCTAuthPlatform sharedPlatform];
    
    [authPlatform setURLOpener: ^void(NSURL *URL, DCTAuthPlatformCompletion completion) {
        // [sharedManager setPendingAuthentication:YES];
        if ([SFSafariViewController class] != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                safariViewController = [[SFSafariViewController alloc] initWithURL:URL];
                UIViewController *viewController = application.keyWindow.rootViewController;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController presentViewController:safariViewController animated:YES completion: nil];
                });
            });
        } else {
            [application openURL:URL];
        }
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
    
    if ([manager.callbackUrls indexOfObject:strUrl] != NSNotFound) {
        if(safariViewController != nil) {
            [safariViewController dismissViewControllerAnimated:YES completion:nil];
        }
        return [DCTAuth handleURL:url];
    }
    
    // [manager clearPending];
    
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
    NSString *saveCallbackUrl = [[self stringHost:callbackUrl] lowercaseString];
    
    if ([arr indexOfObject:saveCallbackUrl] == NSNotFound) {
        [arr addObject:saveCallbackUrl];
        _callbackUrls = [arr copy];
        NSLog(@"Saved callback url: %@ in %@", saveCallbackUrl, _callbackUrls);
    }
    
    
    // Convert objects of url type
    for (NSString *name in [config allKeys]) {
        if ([name rangeOfString:@"_url"].location != NSNotFound) {
            // This is a URL representation
            NSString *urlStr = [config valueForKey:name];
            NSURL *url = [NSURL URLWithString:urlStr];
            [objectProps setObject:url forKey:name];
        } else {
            NSString *str = [NSString stringWithString:[config valueForKey:name]];
            [objectProps setValue:str forKey:name];
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

#pragma mark OAuth

// TODO: Remove opts
RCT_EXPORT_METHOD(getSavedAccounts:(NSDictionary *) opts
                  callback:(RCTResponseSenderBlock) callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    DCTAuthAccountStore *store = [manager accountStore];
    
    NSSet *accounts = [store accounts];
    NSMutableArray *respAccounts = [[NSMutableArray alloc] init];
    for (DCTAuthAccount *account in [accounts allObjects]) {
        NSString *providerName = account.type;
        NSMutableDictionary *cfg = [[manager getConfigForProvider:providerName] mutableCopy];
        NSMutableDictionary *acc = [[manager getAccountResponse:account cfg:cfg] mutableCopy];
        [acc setValue:providerName forKey:@"provider"];
        [respAccounts addObject:acc];
    }
    callback(@[[NSNull null], @{
                   @"status": @"ok",
                   @"accounts": respAccounts
                   }]);
}

// TODO: Remove opts
RCT_EXPORT_METHOD(getSavedAccount:(NSString *)providerName
                  opts:(NSDictionary *) opts
                  callback:(RCTResponseSenderBlock)callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    NSMutableDictionary *cfg = [[manager getConfigForProvider:providerName] mutableCopy];
    
    DCTAuthAccount *existingAccount = [manager accountForProvider:providerName];
    if (existingAccount != nil) {
        if ([existingAccount isAuthorized]) {
            NSDictionary *accountResponse = [manager getAccountResponse:existingAccount cfg:cfg];
            callback(@[[NSNull null], @{
                           @"status": @"ok",
                           @"provider": providerName,
                           @"response": accountResponse
                           }]);
            return;
        } else {
            DCTAuthAccountStore *store = [manager accountStore];
            [store deleteAccount:existingAccount];
            NSDictionary *errResp = @{
                                      @"status": @"error",
                                      @"response": @{
                                              @"msg": @"Account not authorized"
                                              }
                                      };
            callback(@[errResp]);
        }
    } else {
        NSDictionary *errResp = @{
                                  @"status": @"error",
                                  @"response": @{
                                          @"msg": @"No saved account"
                                          }
                                  };
        callback(@[errResp]);
    }
}

RCT_EXPORT_METHOD(deauthorize:(NSString *) providerName
                  callback:(RCTResponseSenderBlock) callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    DCTAuthAccountStore *store = [manager accountStore];
    
    DCTAuthAccount *existingAccount = [manager accountForProvider:providerName];
    if (existingAccount != nil) {
        [store deleteAccount:existingAccount];
        callback(@[[NSNull null], @{
                       @"status": @"ok"
                       }]);
    } else {
        NSDictionary *resp = @{
                               @"status": @"error",
                               @"msg": [NSString stringWithFormat:@"No account found for %@", providerName]
                               };
        callback(@[resp]);
    }
}

/**
 * authorize with url
 * provider, url, scope, state, params
 **/
RCT_EXPORT_METHOD(authorize:(NSString *)providerName
                  opts:(NSDictionary *) opts
                  callback:(RCTResponseSenderBlock)callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    [manager clearPending];
    NSMutableDictionary *cfg = [[manager getConfigForProvider:providerName] mutableCopy];
    
    DCTAuthAccount *existingAccount = [manager accountForProvider:providerName];
    NSString *clientID = ((DCTOAuth2Credential *) existingAccount).clientID;
    if (([providerName isEqualToString:@"google"] && existingAccount && clientID != nil)
        || (![providerName isEqualToString:@"google"] && existingAccount != nil)) {
        if ([existingAccount isAuthorized]) {
            NSDictionary *accountResponse = [manager getAccountResponse:existingAccount cfg:cfg];
            callback(@[[NSNull null], @{
                           @"status": @"ok",
                           @"provider": providerName,
                           @"response": accountResponse
                           }]);
            return;
        } else {
            DCTAuthAccountStore *store = [manager accountStore];
            [store deleteAccount:existingAccount];
        }
    }
    
    NSString *callbackUrl;
    NSURL *storedCallbackUrl = [cfg objectForKey:@"callback_url"];
    
    if (storedCallbackUrl != nil) {
        callbackUrl = [storedCallbackUrl absoluteString];
    } else {
        NSString *appName = [cfg valueForKey:@"app_name"];
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
        return callback(@[@{
                              @"status": @"error",
                              @"msg": @"Unknown provider"
                              }]);
    }
    
    // Store pending client
    
    [manager addPending:client];
    _pendingAuthentication = YES;
    
    NSLog(@"Calling authorizeWithUrl: %@ with callbackURL: %@\n %@", providerName, callbackUrl, cfg);
    
    [client authorizeWithUrl:providerName
                         url:callbackUrl
                         cfg:cfg
                   onSuccess:^(DCTAuthAccount *account) {
                       NSLog(@"on success called with account: %@", account);
                       NSDictionary *accountResponse = [manager getAccountResponse:account cfg:cfg];
                       _pendingAuthentication = NO;
                       [manager removePending:client];
                       [[manager accountStore] saveAccount:account]; // <~
                       
                       callback(@[[NSNull null], @{
                                      @"status": @"ok",
                                      @"response": accountResponse
                                      }]);
                   } onError:^(NSError *error) {
                       NSLog(@"Error in authorizeWithUrl: %@", error);
                       _pendingAuthentication = NO;
                       callback(@[@{
                                      @"status": @"error",
                                      @"msg": [error localizedDescription],
                                      @"userInfo": error.userInfo
                                      }]);
                       [manager removePending:client];
                   }];
}

RCT_EXPORT_METHOD(makeRequest:(NSString *)providerName
                  urlOrPath:(NSString *) urlOrPath
                  opts:(NSDictionary *) opts
                  callback:(RCTResponseSenderBlock)callback)
{
    OAuthManager *manager = [OAuthManager sharedManager];
    NSMutableDictionary *cfg = [[manager getConfigForProvider:providerName] mutableCopy];
    
    DCTAuthAccount *existingAccount = [manager accountForProvider:providerName];
    if (existingAccount == nil) {
        NSDictionary *errResp = @{
                                  @"status": @"error",
                                  @"msg": [NSString stringWithFormat:@"No account found for %@", providerName]
                                  };
        callback(@[errResp]);
        return;
    }
    
    NSDictionary *creds = [self credentialForAccount:providerName cfg:cfg];
    
    // If we have the http in the string, use it as the URL, otherwise create one
    // with the configuration
    NSURL *apiUrl;
    if ([urlOrPath hasPrefix:@"http"]) {
        apiUrl = [NSURL URLWithString:urlOrPath];
    } else {
        NSURL *apiHost = [cfg objectForKey:@"api_url"];
        apiUrl  = [NSURL URLWithString:[[apiHost absoluteString] stringByAppendingString:urlOrPath]];
    }
    
    // If there are params
    NSMutableArray *items = [NSMutableArray array];
    NSDictionary *params = [opts objectForKey:@"params"];
    if (params != nil) {
        for (NSString *key in params) {
            
            NSString *value = [params valueForKey:key];
            
            if ([value isEqualToString:@"access_token"]) {
                value = [creds valueForKey:@"access_token"];
            }
            
            NSURLQueryItem *item = [NSURLQueryItem queryItemWithName:key value:value];
            
            if (item != nil) {
                [items addObject:item];
            }
        }
    }
    
    NSString *methodStr = [opts valueForKey:@"method"];
    
    DCTAuthRequestMethod method = [manager getRequestMethodByString:methodStr];
    
    DCTAuthRequest *request =
    [[DCTAuthRequest alloc]
     initWithRequestMethod:method
     URL:apiUrl
     items:items];
    
    // Allow json body in POST / PUT requests
    NSDictionary *body = [opts objectForKey:@"body"];
    if (body != nil) {
        NSMutableArray *items = [NSMutableArray array];
        
        for (NSString *key in body) {
            NSString *value = [body valueForKey:key];
            
            DCTAuthContentItem *item = [[DCTAuthContentItem alloc] initWithName:key value:value];
            
            if(item != nil) {
                [items addObject: item];
            }
        }
        
        DCTAuthContent *content = [[DCTAuthContent alloc] initWithEncoding:NSUTF8StringEncoding
                                                                      type:DCTAuthContentTypeJSON
                                                                     items:items];
        [request setContent:content];
    }
    
    // If there are headers
    NSDictionary *headers = [opts objectForKey:@"headers"];
    if (headers != nil) {
        NSMutableDictionary *existingHeaders = [request.HTTPHeaders mutableCopy];
        for (NSString *header in headers) {
            [existingHeaders setValue:[headers valueForKey:header] forKey:header];
        }
        request.HTTPHeaders = existingHeaders;
    }
    
    request.account = existingAccount;
    
    [request performRequestWithHandler:^(DCTAuthResponse *response, NSError *error) {
        if (error != nil) {
            NSDictionary *errorDict = @{
                                        @"status": @"error",
                                        @"msg": [error localizedDescription]
                                        };
            callback(@[errorDict]);
        } else {
            NSInteger statusCode = response.statusCode;
            NSData *rawData = response.data;
            NSDictionary *headers = response.HTTPHeaders;
            
            NSError *err;
            NSArray *data;

            
            
            // Check if returned data is a valid JSON
            // != nil returned if the rawdata is not a valid JSON
            if ((data = [NSJSONSerialization JSONObjectWithData:rawData
                                                        options:kNilOptions
                                                          error:&err]) == nil) {
                // Resetting err variable.
                err = nil;
                
                // Parse XML
                data = [XMLReader dictionaryForXMLData:rawData
                                               options:XMLReaderOptionsProcessNamespaces
                                                 error:&err];
            }
            if (err != nil) {
                NSDictionary *errResp = @{
                                          @"status": @"error",
                                          @"msg": [NSString stringWithFormat:@"JSON parsing error: %@", [err localizedDescription]]
                                          };
                callback(@[errResp]);
            } else {
                
                NSDictionary *resp = @{
                                       @"status": @(statusCode),
                                       @"data": data != nil ? data : @[],
                                       @"headers": headers,
                                       };
                callback(@[[NSNull null], resp]);
            }
        }
    }];
}

#pragma mark - private

- (DCTAuthAccount *) accountForProvider:(NSString *) providerName
{
    DCTAuthAccountStore *store = [self accountStore];
    NSSet *accounts = [store accountsWithType:providerName];
    if ([accounts count] == 0) {
        return nil;
    } else {
        NSArray *allAccounts = [accounts allObjects];
        if ([allAccounts count] == 0) {
            return nil;
        } else {
            return [allAccounts lastObject];
        }
    }
}

- (NSDictionary *) credentialForAccount:(NSString *)providerName
                                    cfg:(NSDictionary *)cfg
{
    DCTAuthAccount *account = [self accountForProvider:providerName];
    if (!account) {
        return nil;
    }
    
    NSString *version = [cfg valueForKey:@"auth_version"];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    if ([version isEqualToString:@"1.0"]) {
        DCTOAuth1Credential *credentials = [account credential];
        
        if (credentials) {
            if (credentials.oauthToken) {
                NSString *token = credentials.oauthToken;
                [dict setObject:token forKey:@"access_token"];
            }
            
            if (credentials.oauthTokenSecret) {
                NSString *secret = credentials.oauthTokenSecret;
                [dict setObject:secret forKey:@"access_token_secret"];
            }
        }
        
    } else if ([version isEqualToString:@"2.0"]) {
        DCTOAuth2Credential *credentials = [account credential];
        
        if (credentials) {
            if (credentials.accessToken) {
                NSString *token = credentials.accessToken;
                [dict setObject:token forKey:@"access_token"];
            }
        }
    }
    
    return dict;
}

- (DCTAuthRequestMethod) getRequestMethodByString:(NSString *) method
{
    if ([method compare:@"get" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodGET;
    } else if ([method compare:@"post" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodPOST;
    } else if ([method compare:@"put" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodPUT;
    } else if ([method compare:@"delete" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodDELETE;
    } else if ([method compare:@"head" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodHEAD;
    } else if ([method compare:@"options" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodOPTIONS;
    } else if ([method compare:@"patch" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodPATCH;
    } else if ([method compare:@"trace" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return DCTAuthRequestMethodTRACE;
    } else {
        return DCTAuthRequestMethodGET;
    }
}

- (NSDictionary *) getAccountResponse:(DCTAuthAccount *) account
                                  cfg:(NSDictionary *)cfg
{
    NSArray *ignoredCredentialProperties = @[@"superclass", @"hash", @"description", @"debugDescription"];
    NSString *version = [cfg valueForKey:@"auth_version"];
    NSMutableDictionary *accountResponse = [@{
                                              @"authorized": @(account.authorized),
                                              @"uuid": account.identifier
                                              } mutableCopy];
    
    if ([version isEqualToString:@"1.0"]) {
        DCTOAuth1Credential *credential = account.credential;
        if (credential != nil) {
            NSDictionary *cred = @{
                                   @"access_token": credential.oauthToken,
                                   @"access_token_secret": credential.oauthTokenSecret
                                   };
            [accountResponse setObject:cred forKey:@"credentials"];
        }
    } else if ([version isEqualToString:@"2.0"]) {
        DCTOAuth2Credential *credential = account.credential;
        if (credential != nil) {
            
            NSMutableDictionary *cred = [self dictionaryForCredentialKeys: credential];
            
            DCTOAuth2Account *oauth2Account = (DCTOAuth2Account *) account;
            if (oauth2Account.scopes) {
                [cred setObject:oauth2Account.scopes forKey:@"scopes"];
            }
            
            [accountResponse setObject:cred forKey:@"credentials"];
        }
    }
    [accountResponse setValue:[account identifier] forKey:@"identifier"];
    if (account.userInfo != nil) {
        [accountResponse setObject:[account userInfo] forKey:@"user_info"];
    }
    
    return accountResponse;
}

- (NSDictionary *) dictionaryForCredentialKeys:(NSObject *) credential
{
    NSArray *ignoredCredentialProperties = @[@"superclass", @"hash", @"description", @"debugDescription"];
    unsigned int count = 0;
    NSMutableDictionary *cred = [NSMutableDictionary new];
    objc_property_t *properties = class_copyPropertyList([credential class], &count);
    
    for (int i = 0; i < count; i++) {
        
        NSString *key = [NSString stringWithUTF8String:property_getName(properties[i])];
        if ([ignoredCredentialProperties containsObject:key]) {
            NSLog(@"Ignoring credentials key: %@", key);
        } else {
            id value = [credential valueForKey:key];
            
            if (value == nil) {
                
            } else if ([value isKindOfClass:[NSNumber class]]
                       || [value isKindOfClass:[NSString class]]
                       || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSMutableArray class]]) {
                // TODO: extend to other types
                [cred setObject:value forKey:key];
            } else if ([value isKindOfClass:[NSObject class]]) {
                [cred setObject:[value dictionary] forKey:key];
            } else {
                NSLog(@"Invalid type for %@ (%@)", NSStringFromClass([self class]), key);
            }
        }
    }
    return cred;
}

- (void) clearPending
{
    OAuthManager *manager = [OAuthManager sharedManager];
    for (OAuthClient *client in manager.pendingClients) {
        [manager removePending:client];
    }
    manager.pendingClients = [NSArray array];
    _pendingAuthentication = NO;
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
    [client clearPendingAccount];
    OAuthManager *manager = [OAuthManager sharedManager];
    NSUInteger idx = [manager.pendingClients indexOfObject:client];
    if ([manager.pendingClients count] <= idx) {
        NSMutableArray *newPendingClients = [manager.pendingClients mutableCopy];
        [newPendingClients removeObjectAtIndex:idx];
        manager.pendingClients = newPendingClients;
    }
}

- (DCTAuthAccountStore *) accountStore
{
    NSString *name = [NSString stringWithFormat:@"%@", AUTH_MANAGER_TAG];
    return [DCTAuthAccountStore accountStoreWithName:name];
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

