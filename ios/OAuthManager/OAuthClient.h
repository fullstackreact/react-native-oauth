//
//  OAuthClient.h
//  OAuthManager
//
//  Created by Ari Lerner on 10/8/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OAuthClientProtocol.h"
#import "DCTAuth.h"

@interface OAuthClient : NSObject <OAuthClientProtocol>

- (void) cancelAuthentication;
- (void) savePendingAccount:(DCTAuthAccount *) account;
- (void) clearPendingAccount;

@property (nonatomic, strong) DCTAuthAccount *account;

@end
