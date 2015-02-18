//
//  NSData+SHA1.m
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
//  Based on the answer of Dirk-Willem van Gulik at:
//  https://stackoverflow.com/questions/9749560/how-to-calculate-x-509-certificates-sha-1-fingerprint-in-c-c-objective-c
//
#import "NSData+SHA1.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (SHA1)

- (NSData *)sha1Digest
{
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([self bytes], (CC_LONG)[self length], result);
    return [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
}

- (NSString *)hexStringValue
{
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([self length] * 2)];
    const unsigned char *dataBuffer = [self bytes];
    for (int i = 0; i < [self length]; ++i)
    {
        [stringBuffer appendFormat:@"%02lx", (unsigned long)dataBuffer[i]];
    }
    NSString *value = [stringBuffer copy];
    return value;
}

- (NSString *)hexColonSeperatedStringValueWithCapitals:(BOOL)capitalize {
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([self length] * 3)];
    
    const unsigned char *dataBuffer = [self bytes];
    NSString * format = capitalize ? @"%02X" : @"%02x";
    for (int i = 0; i < [self length]; ++i)
    {
        if (i)
            [stringBuffer appendString:@":"];
        [stringBuffer appendFormat:format, (unsigned long)dataBuffer[i]];
    }
    
    return [stringBuffer copy];
}

@end
