#import <Security/Security.h>
#import <Security/SecureTransport.h>
#import <substrate.h>
#import "NSData+SHA1.h"

#define KEYS @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist"


static BOOL LOCKED = NO;

static NSMutableArray *untrustedRoots;

// Hook SSLHandshake()
static OSStatus (*original_SSLHandshake)(
	SSLContextRef context
);

static OSStatus replaced_SSLHandshake(
	SSLContextRef context
) {

	NSLog(@"Untrusted Roots: %@", untrustedRoots);

	SecTrustRef trustRef = NULL;

	SSLCopyPeerTrust(context, &trustRef);
	CFIndex count = SecTrustGetCertificateCount(trustRef);


	SSLConnectionRef *connection = NULL;
	SSLGetConnection (context, connection);

	NSLog(@"SSLConnectionRef: %@", *connection);


	NSLog(@"Certificate Count: %li", count);

	//For each certificate in the certificate chain.
	for (CFIndex i = 0; i < count; i++)
	{
		//Get a reference to the certificate.
		SecCertificateRef certRef = SecTrustGetCertificateAtIndex(trustRef, i);

		CFStringRef certSummary = SecCertificateCopySubjectSummary(certRef);

		//Convert the certificate to a data object.
		CFDataRef certData = SecCertificateCopyData(certRef);
		//Convert the CFData to NSData and get the SHA1.
		NSData * out = [[NSData dataWithBytes:CFDataGetBytePtr(certData) length:CFDataGetLength(certData)] sha1Digest];
		//Convert the SHA1 data object to a hex String.
		NSString *sha1 = [out hexStringValue];

		//If the SHA1 of this certificate is in our blocked list.
		if([untrustedRoots containsObject:sha1]) {
			NSLog(@"-------UNTRUSTED ROOT FOUND-------");
			NSLog(@"BLOCKED ROOT CA: %@", (NSString *)certSummary);
			NSLog(@"----------------------------------");
			LOCKED = YES;
            //Return the failure.
			return errSSLUnknownRootCert;
		}
	}

	if(LOCKED && count == 0) {
		NSLog(@"Recieved one of those handshakes with no certificates");
		return errSSLUnknownRootCert;
	}

	LOCKED = NO;

	NSLog(@"Didn't contain any blocked certificates");


	if(trustRef) {
		CFRelease(trustRef);
	}

	return original_SSLHandshake(context);
}

%ctor {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSArray *arr = [[NSArray alloc] initWithContentsOfFile:KEYS];
	untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];

	MSHookFunction((void *) SSLHandshake,(void *)  replaced_SSLHandshake, (void **) &original_SSLHandshake);
	NSLog(@"CertHook running. Waiting for SSL connections.");

	[pool drain];
}