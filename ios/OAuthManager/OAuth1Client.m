//
//  OAuth1Client.m
//  OAuthManager
//
//  Created by Ari Lerner on 10/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OAuth1Client.h"
#import "OAuthManager.h"
#import "DCTAuth.h"

static NSString *TAG = @"OAuth1Client";

@implementation OAuth1Client

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
    
    DCTOAuth1Account *account = [self getAccount:providerName cfg:cfg];
    account.callbackURL = [NSURL URLWithString:url];
    
    __weak id client = self;
    [account authenticateWithHandler:^(NSArray *responses, NSError *error) {
        [client clearPendingAccount];

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
    return;
}

#pragma mark - Private

- (DCTOAuth1Account *) getAccount:(NSString *)providerName
                            cfg:(NSDictionary *)cfg
{
    NSURL *request_token_url = [cfg objectForKey:@"request_token_url"];
    NSURL *authorize_url = [cfg objectForKey:@"authorize_url"];
    NSURL *access_token_url = [cfg objectForKey:@"access_token_url"];
    NSString *key = [cfg valueForKey:@"consumer_key"];
    NSString *secret = [cfg valueForKey:@"consumer_secret"];
    
    NSString *signatureTypeStr = [cfg valueForKey:@"signatureType"];
    NSString *parameterTransmisionStr = [cfg valueForKey:@"parameterTransmission"];
    
    DCTOAuth1SignatureType signatureType = DCTOAuth1SignatureTypeHMAC_SHA1;
    DCTOAuth1ParameterTransmission parameterTransmission = DCTOAuth1ParameterTransmissionAuthorizationHeader;
    
    if (signatureTypeStr != nil &&
        [signatureTypeStr compare:@"plaintext" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        signatureType = DCTOAuth1SignatureTypePlaintext;
    }
    
    if (parameterTransmisionStr != nil &&
        [parameterTransmisionStr compare:@"query_string" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        parameterTransmission = DCTOAuth1ParameterTransmissionURLQuery;
    }
    
    DCTOAuth1Account *account = [[DCTOAuth1Account alloc] initWithType:providerName
                                     requestTokenURL:request_token_url
                                        authorizeURL:authorize_url
                                      accessTokenURL:access_token_url
                                         consumerKey:key
                                      consumerSecret:secret
                                       signatureType:signatureType
                               parameterTransmission:parameterTransmission];

    [self savePendingAccount:account];
    return account;
}

@end
