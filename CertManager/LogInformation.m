//
//  LogInformation.m
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "LogInformation.h"

@implementation LogInformation

- (instancetype)initWithApplication:(NSString *)app certficateName:(NSString *)cert time:(NSString *)time {
    self = [super init];
    if (self) {
        _application = [app copy];
        _certificateName = [cert copy];
        _time = [time copy];
    }
    return self;
}

- (instancetype)initWithDescription:(NSString *)description {
    NSArray *split = [description componentsSeparatedByString:@","];
    if(split.count == 3) {
        self = [self initWithApplication:split[0] certficateName:split[1] time:split[2]];
    }
    return self;
}

-(NSString *) description {
    return [NSString stringWithFormat:@"%@,%@,%@", _application, _certificateName, _time];
}

@end
