//
//  OAuthClient.m
//  OAuthManager
//
//  Created by Ari Lerner on 10/8/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OAuthClient.h"

@implementation OAuthClient

- (void) authorizeWithUrl:(NSString *)providerName
                      url:(NSString *) url
                      cfg:(NSDictionary *)cfg
                onSuccess:(AuthManagerCompletionBlock) onSuccess
                  onError:(AuthManagerErrorBlock) onError
{
    NSLog(@"Not implemented in here. Wrong class!");
}

- (void) reauthenticateWithHandler:(NSString *) providerName
                               cfg:(NSDictionary *)cfg
                         onSuccess:(AuthManagerCompletionBlock) onSuccess
                           onError:(AuthManagerErrorBlock) onError
{
    NSLog(@"Not implemented in here. Wrong class!");
}

- (void) cancelAuthentication
{
  if (_account != nil) {
    [_account cancelAuthentication];
  }
}

#pragma mark - Helpers

- (void) savePendingAccount:(DCTAuthAccount *) account
{
  _account = account;
}

- (void) clearPendingAccount
{
    NSLog(@"called clearPendingAccount: %@", _account);
    [_account cancelAuthentication];
    _account = nil;
}

- (void (^)(DCTAuthResponse *response, NSError *error)) getHandler:(DCTAuthAccount *) account
                                                         onSuccess:(AuthManagerCompletionBlock) onSuccess
                                                           onError:(AuthManagerErrorBlock) onError
{
    return ^(DCTAuthResponse *response, NSError *error) {
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
    };
}


@end
