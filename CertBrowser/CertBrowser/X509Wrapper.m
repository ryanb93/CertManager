//
//  X509Wrapper.m
//  CertManager
//
//  Created by Ryan Burke on 13/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import "X509Wrapper.h"

@implementation X509Wrapper

/**
 *  https://stackoverflow.com/questions/8850524/seccertificateref-how-to-get-the-certificate-information
 */
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

+(NSDate *) CertificateGetExpiryDate:(SecCertificateRef) cert
{
    
    NSData *certificateData                   = (__bridge NSData *) SecCertificateCopyData(cert);
    const unsigned char *certificateDataBytes = (const unsigned char *)[certificateData bytes];
    X509 *certificateX509                     = d2i_X509(NULL, &certificateDataBytes, [certificateData length]);
    
    NSDate *expiryDate = nil;
    
    if (certificateX509 != NULL) {
        ASN1_TIME *certificateExpiryASN1 = X509_get_notAfter(certificateX509);
        if (certificateExpiryASN1 != NULL) {
            ASN1_GENERALIZEDTIME *certificateExpiryASN1Generalized = ASN1_TIME_to_generalizedtime(certificateExpiryASN1, NULL);
            if (certificateExpiryASN1Generalized != NULL) {
                unsigned char *certificateExpiryData = ASN1_STRING_data(certificateExpiryASN1Generalized);
                
                // ASN1 generalized times look like this: "20131114230046Z"
                //                                format:  YYYYMMDDHHMMSS
                //                               indices:  01234567890123
                //                                                   1111
                // There are other formats (e.g. specifying partial seconds or
                // time zones) but this is good enough for our purposes since
                // we only use the date and not the time.
                //
                // (Source: http://www.obj-sys.com/asn1tutorial/node14.html)
                
                NSString *expiryTimeStr = [NSString stringWithUTF8String:(char *)certificateExpiryData];
                NSDateComponents *expiryDateComponents = [[NSDateComponents alloc] init];
                
                expiryDateComponents.year   = [[expiryTimeStr substringWithRange:NSMakeRange(0, 4)] intValue];
                expiryDateComponents.month  = [[expiryTimeStr substringWithRange:NSMakeRange(4, 2)] intValue];
                expiryDateComponents.day    = [[expiryTimeStr substringWithRange:NSMakeRange(6, 2)] intValue];
                expiryDateComponents.hour   = [[expiryTimeStr substringWithRange:NSMakeRange(8, 2)] intValue];
                expiryDateComponents.minute = [[expiryTimeStr substringWithRange:NSMakeRange(10, 2)] intValue];
                expiryDateComponents.second = [[expiryTimeStr substringWithRange:NSMakeRange(12, 2)] intValue];
                
                NSCalendar *calendar = [NSCalendar currentCalendar];
                expiryDate = [calendar dateFromComponents:expiryDateComponents];
                
            }
        }
    }
    
    return expiryDate;
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

