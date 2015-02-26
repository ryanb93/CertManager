//
//  X509Wrapper.m
//  CertManager
//
//  Created by Ryan Burke on 13/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import "X509Wrapper.h"

@implementation X509Wrapper

+(NSString *) CertificateGetIssuerName:(SecCertificateRef) cert
{
    NSData *certificateData                   = (__bridge NSData *) SecCertificateCopyData(cert);
    const unsigned char *certificateDataBytes = (const unsigned char *)[certificateData bytes];
    X509 *certificateX509                     = d2i_X509(NULL, &certificateDataBytes, [certificateData length]);
    
    NSString *issuer = nil;
    if (certificateX509 != NULL) {
        X509_NAME *issuerX509Name = X509_get_issuer_name(certificateX509);
        
        if (issuerX509Name != NULL) {
            int nid = OBJ_txt2nid("O"); // organization
            int index = X509_NAME_get_index_by_NID(issuerX509Name, nid, -1);
            
            X509_NAME_ENTRY *issuerNameEntry = X509_NAME_get_entry(issuerX509Name, index);
            
            if (issuerNameEntry) {
                ASN1_STRING *issuerNameASN1 = X509_NAME_ENTRY_get_data(issuerNameEntry);
                
                if (issuerNameASN1 != NULL) {
                    unsigned char *issuerName = ASN1_STRING_data(issuerNameASN1);
                    issuer = @((char *)issuerName);
                }
            }
        }
    }
    
    return issuer;
}

+(NSString *) CertificateGetType:(SecCertificateRef) cert {
    
    NSData *certificateData                   = (__bridge NSData *) SecCertificateCopyData(cert);
    const unsigned char *certificateDataBytes = (const unsigned char *)[certificateData bytes];
    X509 *certificateX509                     = d2i_X509(NULL, &certificateDataBytes, [certificateData length]);
    
    return [NSString stringWithFormat:@"%i", X509_certificate_type(certificateX509, nil)];
    
    
    
}

+(NSString *) CertificateGetSHA1:(SecCertificateRef)cert {
    CFDataRef data = SecCertificateCopyData(cert);
    NSData * out = [[NSData dataWithBytes:CFDataGetBytePtr(data) length:CFDataGetLength(data)] sha1Digest];
    CFRelease(data);
    NSString *sha1 = [out hexStringValue];
    return sha1;
}



@end

