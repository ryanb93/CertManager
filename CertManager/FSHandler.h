//
//  FSHandler.h
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LogInformation.h"
#import "DDFileReader.h"

@interface FSHandler : NSObject

+ (void)writeToPlist: (NSString*)fileName withData:(id)data;
+ (void)appendLogFile: (NSString*)fileName withLogInformation:(LogInformation *)info;
+ (void)clearLogFile: (NSString*)fileName;
+ (NSMutableArray *)readLogFile: (NSString *)fileName;
+ (NSMutableArray *)readArrayFromPlist: (NSString *)fileName;
+ (NSMutableDictionary *)readDictionaryFromPlist: (NSString *)fileName;

@end
