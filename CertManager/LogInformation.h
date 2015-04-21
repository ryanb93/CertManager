//
//  LogInformation.h
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LogInformation : NSObject
    
- (id)initWithApplication:(NSString *)app peer:(NSString *)peer certficateName:(NSString *)cert time:(NSDate *)time;


@property (strong, atomic) NSString* application;
@property (strong, atomic) NSString* peerName;
@property (strong, atomic) NSString* certificateName;
@property (strong, atomic) NSDate* time;

@end
