//
//  LogInformation.h
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LogInformation : NSObject
    
- (instancetype)initWithApplication:(NSString *)app certficateName:(NSString *)cert time:(NSString *)time NS_DESIGNATED_INITIALIZER;

@property (strong, atomic) NSString* application;
@property (strong, atomic) NSString* certificateName;
@property (strong, atomic) NSString* time;

@end
