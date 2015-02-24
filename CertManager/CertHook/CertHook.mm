#import <BulletinBoard/BulletinBoard.h>
#import <notify.h>
#import <Security/SecureTransport.h>
#import <Security/Security.h>
#import <substrate.h>
#import <rocketbootstrap.h>
#import <UIKit/UIApplication.h>

#import "NSData+SHA1.h"

#pragma mark - External Interfaces

@interface SBBulletinBannerController : NSObject
	+ (SBBulletinBannerController *)sharedInstance;
	- (void)observer:(id)observer addBulletin:(BBBulletinRequest *)bulletin forFeed:(int)feed;
@end

@interface CPDistributedMessagingCenter : NSObject
+ (id)centerNamed:(id)arg1;
- (void)runServerOnCurrentThread;
- (void)registerForMessageName:(id)arg1 target:(id)arg2 selector:(SEL)arg3;
- (BOOL)sendMessageName:(id)arg1 userInfo:(id)arg2;
@end

#pragma mark - Callbacks

static NSMutableArray *untrustedRoots;

/**
 *  Function that is called when a certificate has been blocked by the system.
 *  Here we send a message to the messaging center for listeners to act on.
 *
 *  @param summary The summary name of the certificate blocked.
 */
static void certificateWasBlocked(NSString *summary) {

	CPDistributedMessagingCenter *center;
	center = [%c(CPDistributedMessagingCenter) centerNamed:@"uk.ac.surrey.rb00166.certmanager"];
	rocketbootstrap_distributedmessagingcenter_apply(center);

    NSString *process     = [[NSProcessInfo processInfo] processName];
    NSDictionary *sumDict = [NSDictionary dictionaryWithObjectsAndKeys: summary, @"summary", process, @"process", nil];

	[center sendMessageName:@"certificateWasBlocked" userInfo:sumDict];

}

/**
 *  Updates the array containing the list of untrusted root certificates. Reads the plist from disk and loads it into memory.
 */
static void updateRoots() {
	NSString *roots     = @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist";
	NSArray *arr        = [[NSArray alloc] initWithContentsOfFile:roots];
	untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];
}

/**
*  Callback function for when an update roots notification is recieved by the tweak.
*
*  @param center
*  @param observer
*  @param name
*  @param object
*  @param userInfo
*/
static void updateRootsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	updateRoots();
}

#pragma mark - SpringBoard hooks

%hook SpringBoard

- (id)init {
	CPDistributedMessagingCenter *center;
	center = [%c(CPDistributedMessagingCenter) centerNamed:@"uk.ac.surrey.rb00166.certmanager"];
	rocketbootstrap_distributedmessagingcenter_apply(center);
	[center runServerOnCurrentThread];
	[center registerForMessageName:@"certificateWasBlocked" target:self selector:@selector(handleMessageNamed:userInfo:)];
	return %orig;
}

%new
- (void)handleMessageNamed:(NSString *)name userInfo:(NSDictionary *)userInfo {

	//Create a bulletin request.
	BBBulletinRequest *bulletin      = [[BBBulletinRequest alloc] init];
	bulletin.recordID                = @"uk.ac.surrey.rb00166.certmanager";
	bulletin.bulletinID              = @"uk.ac.surrey.rb00166.certmanager";
	bulletin.sectionID               = @"uk.ac..surrey.rb00166.certmanager";
	bulletin.title                   = @"Certificate Blocked.";
	bulletin.subtitle 				 = [userInfo objectForKey:@"process"];
    bulletin.message                 = [userInfo objectForKey:@"summary"];
	bulletin.date                    = [NSDate date];
	SBBulletinBannerController *ctrl = [objc_getClass("SBBulletinBannerController") sharedInstance];
	[ctrl observer:nil addBulletin:bulletin forFeed:0];
}

%end

#pragma mark - SecureTransport hooks

static BOOL LOCKED = NO;

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
    
    
    size_t len;
    SSLGetPeerDomainNameLength(context, &len);

    
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
			certificateWasBlocked(summary);

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

	return original_SSLHandshake(context);
}

#pragma mark - Constructor

%ctor {
	%init;

	CFNotificationCenterRef reload = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(reload, NULL, &updateRootsNotification, CFSTR("uk.ac.surrey.rb00166.certmanager/reload"), NULL, 0);

	updateRoots();

	MSHookFunction((void *) SSLHandshake,(void *)  hooked_SSLHandshake, (void **) &original_SSLHandshake);
}