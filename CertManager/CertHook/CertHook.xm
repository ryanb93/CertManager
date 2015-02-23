#import <Security/Security.h>
#import <Security/SecureTransport.h>
#import <BulletinBoard/BulletinBoard.h>
#import <substrate.h>
#import <notify.h>

#import "NSData+SHA1.h"

#pragma mark - External Interfaces

@interface SBBulletinBannerController : NSObject
	+ (SBBulletinBannerController *)sharedInstance;
	- (void)observer:(id)observer addBulletin:(BBBulletinRequest *)bulletin forFeed:(int)feed;
@end

#pragma mark - CertHook

@interface CertHook : NSObject
+ (id)sharedInstance;
- (BOOL)blockedSHA1:(NSString *)sha1;

@property (strong, nonatomic) NSMutableArray *untrustedRoots;

@end

@implementation CertHook

static CertHook *instance = nil;

+ (id)sharedInstance
{
	if(instance == nil) {
		instance = [[self alloc] init];
	}
	return instance;
}

void blockedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	NSLog(@"Blocked Callback detected: \n\t name: %@ \n\t userInfo:%@", name, userInfo);
	//Create a bulletin request.
    BBBulletinRequest *bulletin      = [[BBBulletinRequest alloc] init];
    bulletin.recordID                = @"ac.uk.surrey.rb00166.certmanager";
    bulletin.bulletinID              = @"ac.uk.surrey.rb00166.certmanager";
    bulletin.sectionID               = @"ac.uk.surrey.rb00166.certmanager";
    bulletin.title                   = @"Connection Blocked by CertManager";
    //bulletin.message                 = (__bridge NSString*)CFDictionaryGetValue(userInfo, "summary");
    bulletin.date                    = [NSDate date];
    SBBulletinBannerController *ctrl = [objc_getClass("SBBulletinBannerController") sharedInstance];
	[ctrl observer:nil addBulletin:bulletin forFeed:0];
}

void updateCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	NSLog(@"Blocked Callback detected: \n\t name: %@ \n\t object:%@", name, object);
	[instance updateRoots];
}

- (void)updateRoots {
	NSString *roots     = @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist";
	NSArray *arr        = [[NSArray alloc] initWithContentsOfFile:roots];
	_untrustedRoots = [[NSMutableArray alloc] initWithArray:arr];
}


- (BOOL)blockedSHA1:(NSString *)sha1 {
	return [_untrustedRoots containsObject: sha1];
}

@end

#pragma mark - SpringBoard hooks

%hook SpringBoard

- (id)init {

	CFNotificationCenterRef notification = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(notification, (__bridge const void *)([CertHook sharedInstance]), blockedCallback, CFSTR("ac.uk.surrey.rb00166.CertManager-cert_blocked"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	return %orig();
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
		if([[CertHook sharedInstance] blockedSHA1:sha1]) {

            //NSString *summary = (__bridge NSString *) SecCertificateCopySubjectSummary(certRef);

			NSLog(@"--------BLOCKED CERTIFICATE---------");

			//Send a notification to the user.
			//NSDictionary *dic = [[NSDictionary alloc] initWithObjectsAndKeys:summary, @"summary", nil];
			//CFStringRef message = (CFStringRef)"ac.uk.surrey.rb00166.CertManager-cert_blocked";
			//CFDictionaryRef dictionary = (__bridge CFDictionaryRef) dic;

            NSLog(@"--------NOTIFICATION ABOUT TO BE SENT---------");
			CFNotificationCenterRef notification = CFNotificationCenterGetDarwinNotifyCenter();
            NSLog(@"--------NOTIFICATION: %@---------", notification);
			CFNotificationCenterPostNotification(notification, CFSTR("ac.uk.surrey.rb00166.CertManager-cert_blocked"), NULL, NULL, YES);

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

#pragma mark - Constructor

%ctor {

	[[CertHook sharedInstance] updateRoots];

	CFNotificationCenterRef notification = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(notification, (__bridge const void *)([CertHook sharedInstance]), updateCallback, CFSTR("ac.uk.surrey.rb00166.CertManager-settings_changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);


	MSHookFunction((void *) SSLHandshake,(void *)  hooked_SSLHandshake, (void **) &original_SSLHandshake);

}