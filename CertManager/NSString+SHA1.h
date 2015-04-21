//
//  NSString+SHA1.h
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
// isSHA1 reference: https://coderwall.com/p/qkgjbw/nsstring-sha1-verification by Max Kramer

#import <Foundation/Foundation.h>

@interface NSString(SHA1)

- (BOOL) isSHA1;

@end