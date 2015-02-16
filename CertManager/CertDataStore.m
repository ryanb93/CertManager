//
//  CertDataStore.m
//  CertManager
//
//  Created by Ryan Burke on 16/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CertDataStore.h"

@interface CertDataStore ()

@property (strong, atomic) NSMutableDictionary * certificates;
@property (strong, atomic) NSMutableArray      * trusted;
@property (strong, atomic) NSMutableArray      * untrusted;

@end

@implementation CertDataStore

- (id)init
{
 
    //Init the OTA Directory.
    self.trustStoreVersion = InitOTADirectory();
    
    //Create the array to hold the list of names.
    _titles = [[NSMutableArray alloc] init];
    //Create array to hold list of certificates.
    _certificates = [[NSMutableDictionary alloc] init];

    //Gets a reference to the current OTA PKI.
    SecOTAPKIRef ref = SecOTAPKICopyCurrentOTAPKIRef();
    
    //Dictionary of a hash in the Index file and an offset.
    NSDictionary *lookup = (__bridge NSDictionary *) SecOTAPKICopyAnchorLookupTable(ref);
    
    //Create an array to hold the values of the offsets.
    NSMutableArray *offsets = [[NSMutableArray alloc] init];
    
    //Loop through each value in the dictionary.
    for (NSString *value in lookup) {
        //For each String inside the array.
        for (NSString *nums in lookup[value]) {
            //Add the offset String to the offsets array.
            [offsets addObject:nums];
        }
    }
    
    //Use function from SecTrustServer to get certificates from offsets.
    NSMutableArray *certs = (__bridge NSMutableArray *) CopyCertsFromIndices((__bridge CFArrayRef) offsets);
    
    //Sort the data alphabetically.
    [certs sortUsingFunction:sortCerts context:nil];
    
    //Go through each certificate
    for (id cert in certs) {
        //Convert the certificate to a reference.
        SecCertificateRef certRef = (__bridge SecCertificateRef) cert;
        //Get the summary for the string.
        NSString *summary = (__bridge NSString *)(SecCertificateCopySubjectSummary(certRef));
        //Get the first character from the summary.
        NSString *first = [NSString stringWithFormat:@"%c", [summary characterAtIndex:0]];
        //If titles already contains this object don't add it.
        if(![_titles containsObject:first]) {
            [_titles addObject:first];
            _certificates[first] = [[NSMutableArray alloc] init];
        }
        //Add the certificate to the end of the array within the dictionary.
        [[_certificates valueForKey:first] addObject:cert];
    }
    
    
    
    return self;
    
}

NSInteger sortCerts(id id1, id id2, void *context)
{
    CFStringRef summary = SecCertificateCopySubjectSummary((__bridge SecCertificateRef)(id1));
    CFStringRef summary2 = SecCertificateCopySubjectSummary((__bridge SecCertificateRef)id2);
    return CFStringCompare(summary, summary2, kCFCompareCaseInsensitive);
}


- (NSInteger)numberOfTitles {
    return [_titles count];
}

- (NSInteger)numberOfCertificatesInSection:(NSInteger)section {
    return [_certificates[_titles[section]] count];
}

- (NSArray *)titleForCertificatesInSection:(NSInteger)section {
    return [_titles objectAtIndex:section];
}

- (NSString *)nameForCertificateWithTitle:(NSString *)title andOffset:(NSInteger)offset {
    SecCertificateRef cert = (__bridge SecCertificateRef)_certificates[title][offset];
    return (__bridge NSString *)(SecCertificateCopySubjectSummary(cert));
    
}

- (NSString *)issuerForCertificateWithTitle:(NSString *)title andOffset:(NSInteger)offset {
    SecCertificateRef cert = (__bridge SecCertificateRef)_certificates[title][offset];
    return [X509Wrapper CertificateGetIssuerName:cert];
}



@end