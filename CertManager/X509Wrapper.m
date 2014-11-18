//
//  X509Wrapper.m
//  CertManager
//
//  Created by Ryan Burke on 13/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import "X509Wrapper.h"

@implementation X509Wrapper

+(NSString *) CertificateGetIssuerName:(X509 *)certificateX509
{
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
                    issuer = [NSString stringWithUTF8String:(char *)issuerName];
                }
            }
        }
    }
    
    return issuer;
}

+(int) CertificateGetTrusted:(X509 *)certificateX509 {
    int trusted = -1;
    if (certificateX509 != NULL) {
        trusted = X509_check_trust(certificateX509, X509_TRUST_DEFAULT, 0);
    }
    return trusted;
}


@end

