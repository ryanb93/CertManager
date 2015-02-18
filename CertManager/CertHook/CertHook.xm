#import <Security/SecureTransport.h>
#import <substrate.h>

#define KEYS @"/private/var/mobile/Library/Preferences/CertManagerTrustedRoots.plist"


// Hook SSLHandshake()
static OSStatus (*original_SSLHandshake)(
	SSLContextRef context
);

static OSStatus replaced_SSLHandshake(
	SSLContextRef context
) {
	NSLog(@"Keys: %@", KEYS);
	NSArray *arr = [[NSArray alloc] initWithContentsOfFile:KEYS];
	NSMutableArray  *trustedRoots = [[NSMutableArray alloc] initWithArray:arr];
	NSLog(@"Trusted: %@", trustedRoots);

	//SSLSetTrustedRoots(context, trustedRoots, YES);

	return original_SSLHandshake(context);
}

%ctor {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSLog(@"CertHook running. Waiting for SSL connections.");
	MSHookFunction((void *) SSLHandshake,(void *)  replaced_SSLHandshake, (void **) &original_SSLHandshake);

	[pool drain];
}