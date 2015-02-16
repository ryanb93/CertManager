//
//  CertDataStore.h
//  CertManager
//
//  Created by Ryan Burke on 16/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Securityd/OTATrustUtilities.h>
#import <Securityd/SecTrustServer.h>
#import "X509Wrapper.h"

#ifndef CertManager_CertDataStore_h
#define CertManager_CertDataStore_h

@interface CertDataStore : NSObject

- (int)trustStoreVersion;
- (NSInteger)numberOfCertificates;
- (NSInteger)numberOfCertificatesInSection:(NSInteger)section;
- (NSString *)titleForCertificatesInSection:(NSInteger)section;

- (NSString *)nameForCertificateWithTitle:(NSString *)title andOffset:(NSInteger)offset;
- (NSString *)issuerForCertificateWithTitle:(NSString *)title andOffset:(NSInteger)offset;

@property (atomic) int trustStoreVersion;
@property (strong, atomic) NSMutableArray * titles;

@end


#endif
