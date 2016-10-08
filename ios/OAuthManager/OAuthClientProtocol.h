//
//  OAuthClientProtocol.h
//  OAuthManager
//
//  Created by Ari Lerner on 10/8/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#ifndef OAuthClientProtocol_h
#define OAuthClientProtocol_h

#import "OAuthManagerConstants.h"

@protocol OAuthClientProtocol <NSObject>

- (void) authorizeWithUrl:(NSString *)providerName
                      url:(NSString *) url
                      cfg:(NSDictionary *)cfg
                onSuccess:(AuthManagerCompletionBlock) onSuccess
                  onError:(AuthManagerErrorBlock) onError;

- (void) reauthenticateWithHandler:(NSString *) providerName
                               cfg:(NSDictionary *)cfg
                         onSuccess:(AuthManagerCompletionBlock) onSuccess
                           onError:(AuthManagerErrorBlock) onError;

@end

#endif /* OAuthClientProtocol_h */
