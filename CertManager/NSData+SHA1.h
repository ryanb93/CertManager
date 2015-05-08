//
//  NSData_SHA1.h
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface NSData(SHA1)

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSData *sha1Digest;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *hexStringValue;

@end