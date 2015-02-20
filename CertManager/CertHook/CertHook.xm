#import <Security/Security.h>
#import <Security/SecureTransport.h>
#import <substrate.h>
#import "NSData+SHA1.h"

#define KEYS @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist"


static BOOL LOCKED = NO;

// Hook SSLHandshake()
static OSStatus (*original_SSLHandshake)(
	SSLContextRef context
);

static OSStatus replaced_SSLHandshake(
	SSLContextRef context
) {
	NSArray *arr = [[NSArray alloc] initWithContentsOfFile:KEYS];
	NSMutableArray  *untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];

	NSLog(@"Untrusted Roots: %@", untrustedRoots);

	SecTrustRef trustRef = NULL;

	SSLCopyPeerTrust(context, &trustRef);
	CFIndex count = SecTrustGetCertificateCount(trustRef);

	NSLog(@"Certificate Count: %li", count);

	for (CFIndex i = 0; i < count; i++)
	{
		SecCertificateRef certRef = SecTrustGetCertificateAtIndex(trustRef, i);
		CFStringRef certSummary = SecCertificateCopySubjectSummary(certRef);
		CFDataRef certData = SecCertificateCopyData(certRef);
		NSData * out = [[NSData dataWithBytes:CFDataGetBytePtr(certData) length:CFDataGetLength(certData)] sha1Digest];
		NSString *sha1 = [out hexStringValue];
		if([untrustedRoots containsObject:sha1]) {
			NSLog(@"-------UNTRUSTED ROOT FOUND-------");
			NSLog(@"BLOCKED ROOT CA: %@", (NSString *)certSummary);
			NSLog(@"----------------------------------");
			LOCKED = YES;
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

	NSLog(@"CertHook running. Waiting for SSL connections.");
	MSHookFunction((void *) SSLHandshake,(void *)  replaced_SSLHandshake, (void **) &original_SSLHandshake);

	[pool drain];
}