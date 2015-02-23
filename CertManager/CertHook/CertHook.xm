#import <Security/Security.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UILocalNotification.h>
#import <Security/SecureTransport.h>
#import <substrate.h>
#import "NSData+SHA1.h"
#import <notify.h>
#import <BulletinBoard/BulletinBoard.h>
#import <rocketbootstrap.h>


#define KEYS @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist"


@interface SBBulletinBannerController : NSObject
	+ (SBBulletinBannerController *)sharedInstance;
	- (void)observer:(id)observer addBulletin:(BBBulletinRequest *)bulletin forFeed:(int)feed;
@end

static BOOL LOCKED = NO;

static NSMutableArray *untrustedRoots;

@interface CPDistributedMessagingCenter : NSObject
+ (id)centerNamed:(id)arg1;
- (void)runServerOnCurrentThread;
- (void)registerForMessageName:(id)arg1 target:(id)arg2 selector:(SEL)arg3;
- (void)sendMessageName:(NSString *)string userInfo:(NSDictionary *)dict;
@end

@interface CertHook : NSObject
- (NSDictionary *)handleMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userInfo;
@end

@implementation CertHook

- (NSDictionary *)handleMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userinfo {

//Create a bulletin request.
BBBulletinRequest *bulletin = [[BBBulletinRequest alloc] init];
bulletin.recordID           = @"ac.uk.surrey.rb00166.certmanager";
bulletin.bulletinID         = @"ac.uk.surrey.rb00166.certmanager";
bulletin.sectionID          = @"ac.uk.surrey.rb00166.certmanager";
bulletin.title              = @"Connection Blocked by CertManager";
bulletin.message            = [userinfo objectForKey:@"summary"];
bulletin.date               = [NSDate date];
bulletin.defaultAction 		= [BBAction actionWithLaunchBundleID:@"ac.uk.surrey.rb00166.certmanager"
callblock:nil];


SBBulletinBannerController *ctrl = [objc_getClass("SBBulletinBannerController") sharedInstance];

[ctrl observer:nil addBulletin:bulletin forFeed:0];

return nil;

}

@end

%hook SpringBoard

- (id)init {

	CertHook *hooker = [[CertHook alloc] init];

	CPDistributedMessagingCenter *c = [%c(CPDistributedMessagingCenter) centerNamed:@"ac.uk.surrey.rb00166.CertManager"];
	rocketbootstrap_distributedmessagingcenter_apply(c);
	[c runServerOnCurrentThread];
	[c registerForMessageName:@"cert_blocked" target:hooker selector:@selector(handleMessageNamed:withUserInfo:)];

	return %orig();
}

%end



/**
 *  A reference to the original SSLHandshake method.
 *
 *  @param original_SSLHandshake Pointer to the method.
 *
 *  @return The original SSLHandshake result code.
 */
static OSStatus (* original_SSLHandshake)(SSLContextRef context);

/**
 *  The override SSLHandshake method.
 *
 *  @param context The SSL context object that was sent to the original.
 *
 *  @return SSL result code.
 */
static OSStatus hooked_SSLHandshake(SSLContextRef context) {

    //Create an empty trust reference object.
	SecTrustRef trustRef = NULL;
    //Get the trust object based on the SSL context.
	SSLCopyPeerTrust(context, &trustRef);
    
    CFIndex count = SecTrustGetCertificateCount(trustRef);
    
	//For each certificate in the certificate chain.
	for (CFIndex i = 0; i < count; i++)
	{
		//Get a reference to the certificate.
		SecCertificateRef certRef = SecTrustGetCertificateAtIndex(trustRef, i);
        
		//Convert the certificate to a data object.
		CFDataRef certData = SecCertificateCopyData(certRef);
        
		//Convert the CFData to NSData and get the SHA1.
		NSData * out = [[NSData dataWithBytes:CFDataGetBytePtr(certData) length:CFDataGetLength(certData)] sha1Digest];
        
		//Convert the SHA1 data object to a hex String.
		NSString *sha1 = [out hexStringValue];

		//If the SHA1 of this certificate is in our blocked list.
		if([untrustedRoots containsObject:sha1]) {
			
            NSString *summary = (__bridge NSString *) SecCertificateCopySubjectSummary(certRef);
//            notify_post("ac.uk.surrey.rb00166.CertManager.cert_blocked");

			NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:summary, @"summary", nil];



            CPDistributedMessagingCenter *c = [%c(CPDistributedMessagingCenter) centerNamed:@"ac.uk.surrey.rb00166.CertManager"];
            rocketbootstrap_distributedmessagingcenter_apply(c);
            [c sendMessageName:@"cert_blocked" userInfo:dic];
            
            
			NSLog(@"-------UNTRUSTED ROOT FOUND-------");
			NSLog(@"BLOCKED ROOT CA: %@", summary);
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
	NSArray *arr = [[NSArray alloc] initWithContentsOfFile:KEYS];
	untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];

	int notifyToken;
	notify_register_dispatch("ac.uk.surrey.rb00166.CertManager.settings_changed",
		&notifyToken,
		dispatch_get_main_queue(), ^(int t) {
			NSArray *arr = [[NSArray alloc] initWithContentsOfFile:KEYS];
			untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];
	});

	MSHookFunction((void *) SSLHandshake,(void *)  hooked_SSLHandshake, (void **) &original_SSLHandshake);

}