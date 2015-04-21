//
//  NSString+SHA1.m
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "NSString+SHA1.h"

@implementation NSString (SHA1)

- (BOOL) isSHA1 {
    NSString *regex = @"^[a-fA-F0-9]{40}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [predicate evaluateWithObject:self];
}

@end