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

- (NSData *)sha1Digest;
- (NSString *)hexColonSeperatedStringValueWithCapitals:(BOOL)capitalize;
- (NSString *)hexStringValue;

@end