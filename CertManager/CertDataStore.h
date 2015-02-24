//
//  CertDataStore.h
//  CertManager
//
//  Created by Ryan Burke on 16/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <Security/SecureTransport.h>
#import <Securityd/OTATrustUtilities.h>
#import <Securityd/SecTrustServer.h>
#import "X509Wrapper.h"

#ifndef CertManager_CertDataStore_h
#define CertManager_CertDataStore_h

@interface CertDataStore : NSObject

- (int)trustStoreVersion;

- (SecCertificateRef)certificateWithTitle:(NSString *)title andOffSet:(NSInteger)offset;

- (NSArray *)titlesForCertificates;

- (NSInteger)numberOfCertificatesForTitle:(NSString*)title;

- (NSString*)nameForCertificate:	(SecCertificateRef) cert;
- (NSString*)issuerForCertificate:	(SecCertificateRef) cert;
- (BOOL)isTrustedForCertificate:	(SecCertificateRef) cert;
- (void)untrustCertificate:			(SecCertificateRef) cert;
- (void)trustCertificate:			(SecCertificateRef) cert;

@property (assign ,atomic) int trustStoreVersion;

@end


#endif
