//
//  OAuth2Client.m
//  OAuthManager
//
//  Created by Ari Lerner on 10/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OAuth2Client.h"
#import "OAuthManager.h"
#import "DCTAuth.h"

static NSString *TAG = @"OAuth2Client";

@implementation OAuth2Client

- (void) authorizeWithUrl:(NSString *)providerName
                           url:(NSString *) url
                           cfg:(NSDictionary *)cfg
                     onSuccess:(AuthManagerCompletionBlock) onSuccess
                       onError:(AuthManagerErrorBlock) onError
{
    if (cfg == nil) {
        NSError *err = QUICK_ERROR(E_PROVIDER_NOT_CONFIGURED, @"provider not configured");
        onError(err);
        return;
    }
    
    DCTOAuth2Account *account = [self getAccount:providerName cfg:cfg];
    account.callbackURL = [NSURL URLWithString:url];

    NSLog(@"authorize ----> %@ %@", cfg, account);
    
    [account authenticateWithHandler:^(NSArray *responses, NSError *error) {
        [self clearPendingAccount];
        if (error != nil) {
            onError(error);
            return;
        }
        
        if (!account.authorized) {
            NSError *err = QUICK_ERROR(E_ACCOUNT_NOT_AUTHORIZED, @"account not authorized");
            onError(err);
            return;
        }
        
        onSuccess(account);
    }];
}

- (void) reauthenticateWithHandler:(NSString *) providerName
                               cfg:(NSDictionary *)cfg
                         onSuccess:(AuthManagerCompletionBlock) onSuccess
                           onError:(AuthManagerErrorBlock) onError
{
    DCTOAuth2Account *account = [self getAccount:providerName cfg:cfg];
    [account reauthenticateWithHandler:^(DCTAuthResponse *response, NSError *error) {
        NSLog(@"Reauthenticating...");
        if (error != nil) {
            onError(error);
            return;
        }
        
        if (!account.authorized) {
            NSError *err = QUICK_ERROR(E_ACCOUNT_NOT_AUTHORIZED, @"account not authorized");
            onError(err);
            return;
        }
        
        onSuccess(account);
    }];
}

#pragma mark - private

- (DCTOAuth2Account *) getAccount:(NSString *)providerName
                              cfg:(NSDictionary *)cfg
{
    DCTOAuth2Account *account;
    // Required
    NSURL *authorize_url = [cfg objectForKey:@"authorize_url"];
    NSString *scopeStr = [cfg valueForKey:@"scopes"];
    NSArray *scopes = [scopeStr componentsSeparatedByString:@","];
    // Optional
    
    NSURL *access_token_url = [cfg objectForKey:@"access_token_url"];
    NSString *clientID = [cfg valueForKey:@"client_id"];
    NSString *clientSecret = [cfg valueForKey:@"client_secret"];
    NSString *username = [cfg valueForKey:@"username"];
    NSString *password = [cfg valueForKey:@"password"];
    
    if (access_token_url != nil) {
        account = [[DCTOAuth2Account alloc] initWithType:providerName
                                            authorizeURL:authorize_url
                                          accessTokenURL:access_token_url
                                                clientID:clientID
                                            clientSecret:clientSecret
                                                  scopes:scopes];
    } else {
        account = [[DCTOAuth2Account alloc] initWithType:providerName
                                            authorizeURL:authorize_url
                                                clientID:clientID
                                            clientSecret:clientSecret
                                                username:username
                                                password:password
                                                  scopes:scopes];
    }

    [super savePendingAccount:account];
    
    return account;
}

@end
