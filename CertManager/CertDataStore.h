//
//  CertDataStore.h
//  CertManager
//
//  Created by Ryan Burke on 16/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <Securityd/OTATrustUtilities.h>
#import <Securityd/SecTrustServer.h>
#import "X509Wrapper.h"

@interface CertDataStore : NSObject

@property (assign ,atomic) int trustStoreVersion;

- (SecCertificateRef)rootCertificateWithTitle:(NSString *)title andOffSet:(NSInteger)offset;
- (NSArray *)titlesForRootCertificates;
- (NSInteger)numberOfRootCertificatesForTitle:(NSString*)title;
- (NSString*)nameForRootCertificate:	(SecCertificateRef) cert;
- (NSString*)issuerForRootCertificate:	(SecCertificateRef) cert;
- (BOOL)isTrustedForRootCertificate:	(SecCertificateRef) cert;
- (void)untrustRootCertificate:			(SecCertificateRef) cert;
- (void)trustRootCertificate:			(SecCertificateRef) cert;
- (void)untrustNormalCertificate:		(SecCertificateRef) cert;
- (void)reloadUntrustedRootCertificates;

@end
