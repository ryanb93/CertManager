//
//  LogInformation.m
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "LogInformation.h"

@implementation LogInformation

- (instancetype)initWithApplication:(NSString *)app peer:(NSString *)peer certficateName:(NSString *)cert time:(NSDate *)time {
    self = [super init];
    if (self) {
        _application = [app copy];
        _peerName = [peer copy];
        _certificateName = [cert copy];
        _time = [time copy];
    }
    return self;
}

-(NSString *) description {
    return [NSString stringWithFormat:@"%@,%@,%@,%@", _application, _peerName, _certificateName, _time];
}

@end
