#import <BulletinBoard/BulletinBoard.h>
#import <notify.h>
#import <Security/SecureTransport.h>
#import <Security/Security.h>
#import <substrate.h>
#import <rocketbootstrap.h>
#import <UIKit/UIApplication.h>

#import "NSData+SHA1.h"

#define ROCKETBOOTSTRAP_LOAD_DYNAMIC

#pragma mark - External Interfaces

static NSMutableArray *untrustedRoots;


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

static void certificateWasBlocked(NSString *summary) {
	NSLog(@"--------certificateWasBlocked---------");
	CPDistributedMessagingCenter *messagingCenter = [%c(CPDistributedMessagingCenter) centerNamed:@"uk.ac.surrey.rb00166.certmanger"];


void* handle = dlopen("/usr/lib/librocketbootstrap.dylib", RTLD_LAZY);
if(handle)
{
void (*rocketbootstrap_distributedmessagingcenter_apply)(CPDistributedMessagingCenter*);
rocketbootstrap_distributedmessagingcenter_apply = (void(*)(CPDistributedMessagingCenter*))dlsym(handle, "rocketbootstrap_distributedmessagingcenter_apply");
rocketbootstrap_distributedmessagingcenter_apply(messagingCenter);
}

	[messagingCenter sendMessageName:@"certificateWasBlocked" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
summary, @"certificate",
nil]];

}

static void updateRoots() {
	NSLog(@"--------updateRoots---------");
	NSString *roots     = @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist";
	NSArray *arr        = [[NSArray alloc] initWithContentsOfFile:roots];
	NSLog(@"--------arr---------\n%@", arr);
	untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];
	NSLog(@"--------_untrustedRoots---------\n%@", untrustedRoots);
}

#pragma mark - SpringBoard hooks

%hook Springboard

- (id)init {
	NSLog(@"--------HOOK INIT METHOD---------");
	self = %orig;
	CPDistributedMessagingCenter *center = [%c(CPDistributedMessagingCenter) centerNamed:@"uk.ac.surrey.rb00166.CertManager"];
void* handle = dlopen("/usr/lib/librocketbootstrap.dylib", RTLD_LAZY);
if(handle)
{
void (*rocketbootstrap_distributedmessagingcenter_apply)(CPDistributedMessagingCenter*);
rocketbootstrap_distributedmessagingcenter_apply = (void(*)(CPDistributedMessagingCenter*))dlsym(handle, "rocketbootstrap_distributedmessagingcenter_apply");
rocketbootstrap_distributedmessagingcenter_apply(center);
}
	[center runServerOnCurrentThread];
	[center registerForMessageName:@"certificateWasBlocked" target:self selector:@selector(handleMessageNamed:withUserInfo:)];
	return self;
}

%new
- (void)handleMessageNamed:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
	NSLog(@"--------showBulletin---------");
	//Create a bulletin request.
	BBBulletinRequest *bulletin      = [[BBBulletinRequest alloc] init];
	bulletin.recordID                = @"uk.ac.surrey.rb00166.certmanager";
	bulletin.bulletinID              = @"uk.ac.surrey.rb00166.certmanager";
	bulletin.sectionID               = @"uk.ac..surrey.rb00166.certmanager";
	bulletin.title                   = @"Connection Blocked by CertManager";
	//bulletin.message                 = (__bridge NSString*)CFDictionaryGetValue(userInfo, "summary");
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

			NSLog(@"--------BLOCKED CERTIFICATE---------");
            NSLog(@"--------NOTIFICATION ABOUT TO BE SENT---------");

			certificateWasBlocked(summary);

			NSLog(@"--------NOTIFICATION SENT---------");

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

static void reloadPrefsNotification(CFNotificationCenterRef center,
	void *observer,
	CFStringRef name,
	const void *object,
	CFDictionaryRef userInfo) {
	updateRoots();
}

#pragma mark - Constructor

%ctor {
	%init;

	CFNotificationCenterRef reload = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(reload, NULL, &reloadPrefsNotification,
	CFSTR("uk.ac.surrey.rb00166.certmanager/reload"), NULL, 0);

	updateRoots();

	MSHookFunction((void *) SSLHandshake,(void *)  hooked_SSLHandshake, (void **) &original_SSLHandshake);
}