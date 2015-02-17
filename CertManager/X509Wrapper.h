//
//  X509Wrapper.h
//  CertManager
//
//  Created by Ryan Burke on 13/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenSSL/x509.h>

@interface X509Wrapper : NSObject
    +(NSString *) CertificateGetIssuerName:(SecCertificateRef)cert;
    +(NSString *) CertificateGetSHA1:(SecCertificateRef)cert;
@end