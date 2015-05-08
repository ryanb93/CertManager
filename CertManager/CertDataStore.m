//
//  CertDataStore.m
//  CertManager
//
//  Created by Ryan Burke on 16/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import "CertDataStore.h"
#import "FSHandler.h"

@interface CertDataStore()

@property (strong, atomic) NSMutableDictionary *certificates;
@property (strong, atomic) NSMutableArray      *untrustedRoots;
@property (strong, atomic) NSMutableDictionary *untrustedCerts;

@end

/**
 * The CertDataStore is an encapsulation for references to the data store used by the application.
 * Here we manage a dictionary of untrusted certificates which is backed by values stored on the disk.
 */
@implementation CertDataStore

//The name of the plist to read from.
static NSString * const UNTRUSTED_ROOTS_PLIST = @"CertManagerUntrustedRoots";
static NSString * const UNTRUSTED_CERTS_PLIST = @"CertManagerUntrustedCerts";

/**
 *  Init method for the CertDataStore. Loads the root certificates using the Security framework.
 *
 *  @return A new CertDataStore object.
 */
- (instancetype)init
{
     
    //Init the OTA Directory.
    self.trustStoreVersion = InitOTADirectory();
    SecOTAPKIRef ref       = SecOTAPKICopyCurrentOTAPKIRef();

    //Set up our private data stores.
    _certificates = [[NSMutableDictionary alloc] init];
    _untrustedRoots = [FSHandler readArrayFromPlist:UNTRUSTED_ROOTS_PLIST];
    
    //Get the offsets for the certificates in the database index file.
    NSMutableArray *offsets = [[NSMutableArray alloc] init];
    NSDictionary *lookup    = (__bridge NSDictionary *) SecOTAPKICopyAnchorLookupTable(ref);
    for (NSString *value in lookup) {
        for (NSString *nums in lookup[value]) {
            [offsets addObject:nums];
        }
    }
    
    //Get an array of certificate references.
    CFArrayRef cfOffsets = (__bridge CFArrayRef) offsets;
    NSMutableArray *certs = (__bridge NSMutableArray *) CopyCertsFromIndices(cfOffsets);
    
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
        
        //If certificates already contains this object then create it.
        if(!_certificates[first]) {
            _certificates[first] = [[NSMutableArray alloc] init];
        }
        
        //Add the certificate to the end of the array within the dictionary.
        [[_certificates valueForKey:first] addObject:cert];
    }
    
    return self;
    
}

/**
 *  A function which compares the summary of the certificate.
 *
 *  @param certificate1     The first certificate.
 *  @param certificate2     The second certificate.
 *  @param context The context of the sort.
 *
 *  @return the result of the comparision between the summary of the certificates.
 */
NSInteger sortCerts(id certificate1, id certificate2, void *context)
{
    CFStringRef summary  = SecCertificateCopySubjectSummary((__bridge SecCertificateRef)(certificate1));
    CFStringRef summary2 = SecCertificateCopySubjectSummary((__bridge SecCertificateRef)certificate2);
    return CFStringCompare(summary, summary2, kCFCompareCaseInsensitive);
}

/**
 *  Returns a certificate for a title at an index.
 *
 *  @param title  The first letter of the certificate.
 *  @param offset The offset of the certificate.
 *
 *  @return The reference to the certificate.
 */
- (SecCertificateRef)rootCertificateWithTitle:(NSString *)title andOffSet:(NSInteger)offset {
    return (__bridge SecCertificateRef)(_certificates[title][offset]);
}

- (NSInteger)numberOfRootCertificatesForTitle:(NSString*)title {
    return [_certificates[title] count];
}


- (NSArray *)titlesForRootCertificates {
    return [_certificates allKeys];
}

/**
 *  Returns the summary name for a given certificate.
 *
 *  @param cert The certificate to get the name of.
 *
 *  @return The summary name.
 */
- (NSString *)nameForRootCertificate:(SecCertificateRef) cert  {
    return (__bridge NSString *)(SecCertificateCopySubjectSummary(cert));
}

/**
 *  Returns the issuer name for a given certificate.
 *
 *  @param cert The certificate to get the issuer of.
 *
 *  @return The issuer name.
 */
- (NSString *)issuerForRootCertificate:(SecCertificateRef) cert  {
    return [X509Wrapper issuerForCertificate:cert];
}

/**
 *  Returns if the certificate is trusted by CertManager.
 *
 *  @param cert The certificate to check the trust of.
 *
 *  @return If the certificate is trusted by CertManager. By default, true.
 */
- (BOOL)isTrustedForRootCertificate:(SecCertificateRef) cert {
    NSString* sha1 = [X509Wrapper sha1ForCertificate:cert];
    return ![_untrustedRoots containsObject:sha1];
}

/**
 *  Function which adds a certificate to the list of untrusted certificates.
 *
 *  @param cert The certificate to add.
 */
- (void)untrustRootCertificate:(SecCertificateRef) cert  {
    [_untrustedRoots addObject:[X509Wrapper sha1ForCertificate:cert]];
    [FSHandler writeToPlist:UNTRUSTED_ROOTS_PLIST withData:_untrustedRoots];
}

/**
 *  Function which removes a certificate to the list of untrusted certificates.
 *
 *  @param cert The certificate to remove.
 */
- (void)trustRootCertificate:(SecCertificateRef) cert {
    [_untrustedRoots removeObject:[X509Wrapper sha1ForCertificate:cert]];
    [FSHandler writeToPlist:UNTRUSTED_ROOTS_PLIST withData:_untrustedRoots];
}

-(void)reloadUntrustedRootCertificates {
    _untrustedRoots = [FSHandler readArrayFromPlist:UNTRUSTED_ROOTS_PLIST];
}

- (void)untrustNormalCertificate:(SecCertificateRef) cert {
    
    NSString *name = (__bridge NSString *)(SecCertificateCopySubjectSummary(cert));
    NSString *sha1 = [X509Wrapper sha1ForCertificate:cert];
    NSMutableDictionary *blockedCerts = [FSHandler readDictionaryFromPlist:UNTRUSTED_CERTS_PLIST];
    
    if(!blockedCerts[sha1]) {
        [blockedCerts setValue:name forKey:sha1];
    }
    [FSHandler writeToPlist:UNTRUSTED_CERTS_PLIST withData:blockedCerts];
}


@end