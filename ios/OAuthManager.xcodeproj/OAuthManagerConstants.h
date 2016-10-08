//
//  OAuthManagerConstants.h
//  OAuthManager
//
//  Created by Ari Lerner on 10/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#ifndef OAuthManagerConstants_h
#define OAuthManagerConstants_h

#import "DCTAuthAccount.h"

enum _runtime_error
{
    E_UNKNOWN_PROVIDER = 0,
    E_PROVIDER_NOT_CONFIGURED = 1,
    E_ACCOUNT_NOT_AUTHORIZED = 2
} runtime_error_t;

#define QUICK_ERROR(error_code, error_description) [NSError errorWithDomain:NSStringFromClass([self class]) code:error_code userInfo:[NSDictionary dictionaryWithObject:error_description forKey:NSLocalizedDescriptionKey]];

typedef void(^AuthManagerCompletionBlock)(DCTAuthAccount *account);
typedef void(^AuthManagerErrorBlock)(NSError *error);

#endif /* OAuthManagerConstants_h */
