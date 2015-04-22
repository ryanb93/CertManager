#import <BulletinBoard/BulletinBoard.h>
#import <notify.h>
#import <Security/SecureTransport.h>
#import <Security/Security.h>
#import <substrate.h>
#import <rocketbootstrap.h>
#import <UIKit/UIApplication.h>

#import "../NSData+SHA1.h"
#import "../LogInformation.h"
#import "../FSHandler.h"

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

#pragma mark - Constants

static NSString* const UNTRUSTED_ROOTS_PLIST      = @"/private/var/mobile/Library/Preferences/CertManagerUntrustedRoots.plist";
static NSString* const UNTRUSTED_CERTS_PLIST      = @"/private/var/mobile/Library/Preferences/CertManagerUntrustedCerts.plist";
static NSString* const LOG_FILE      			  = @"uk.ac.surrey.rb00166.CertManager.log";
static NSString* const MESSAGING_CENTER     	  = @"uk.ac.surrey.rb00166.CertManager";
static NSString* const BLOCKED_NOTIFICATION       = @"certificateWasBlocked";

static NSArray *untrustedRoots;
static NSArray *untrustedCerts;

#pragma mark - Callback Methods

/**
 *  Function that is called when a certificate has been blocked by the system.
 *  Here we send a message to the messaging center for listeners to act on.
 *
 *  @param summary The summary name of the certificate blocked.
 */
static void certificateWasBlocked(NSString *process, NSString *summary) {
	
    //Get a reference to the message center and pass to rocketbootstrap.
	CPDistributedMessagingCenter *center = [%c(CPDistributedMessagingCenter) centerNamed:MESSAGING_CENTER];
	rocketbootstrap_distributedmessagingcenter_apply(center);
	
    //Create a dictionary to post with the message.
    NSDictionary *sumDict = [NSDictionary dictionaryWithObjectsAndKeys: summary, @"summary", process, @"process", nil];

    //Send a message using the center.
	[center sendMessageName:BLOCKED_NOTIFICATION userInfo:sumDict];
}

/**
 *  Updates the array containing the list of untrusted root certificates. Reads the plist from disk and loads it into memory.
 */
static void updateRoots() {
    //Load the plist into an array.
    untrustedRoots = [[NSMutableArray alloc] initWithContentsOfFile:UNTRUSTED_ROOTS_PLIST];
    untrustedCerts = [[NSMutableArray alloc] initWithArray:[[[NSDictionary alloc] initWithContentsOfFile:UNTRUSTED_CERTS_PLIST] allKeys]];
}

/**
 *  Callback function for when an update roots notification is recieved by the tweak.
 */
static void updateRootsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	updateRoots();
}

#pragma mark - SpringBoard Hooks

%hook SpringBoard

/**
 *  Override for when SpringBoard launches. Here we attach a message center server to listen for messages posted by
 *  the functions in SecureTransport.
 *
 *  @return SpringBoard object.
 */
- (id)init {
    //Get a reference to the messaging center and pass it to rocketbootstrap.
	CPDistributedMessagingCenter *center = [%c(CPDistributedMessagingCenter) centerNamed:MESSAGING_CENTER];
	rocketbootstrap_distributedmessagingcenter_apply(center);
    //Run the center on this thread.
	[center runServerOnCurrentThread];
    //Register a listener for when a certificate has been blocked.
	[center registerForMessageName:BLOCKED_NOTIFICATION target:self selector:@selector(handleMessageNamed:userInfo:)];
    //Return the original function.
	return %orig;
}

/**
 *  Function called for when a message has been received. Here we post a local notification to the user,
 *  alerting them that a certificate has been blocked by CertManager.
 *
 *  @param name     The name of the alert.
 *  @param userInfo A dictionary object containing data about the certificate which was blocked.
 */
%new
- (void)handleMessageNamed:(NSString *)name userInfo:(NSDictionary *)userInfo {
    
    //If a certificate has been blocked.
    if([name isEqualToString:BLOCKED_NOTIFICATION]) {
        
        //Extract data from the dictionary.
        NSString *process = [userInfo objectForKey:@"process"];
        NSString *summary = [userInfo objectForKey:@"summary"];
        
		//Create a bulletin request.
		BBBulletinRequest *bulletin      = [[BBBulletinRequest alloc] init];
        bulletin.sectionID 				 =  @"uk.ac.surrey.rb00166.CertManager";
        bulletin.title                   =  @"Certificate Blocked";
    	bulletin.message                 = [NSString stringWithFormat:@"%@ attempted to make a connection using certificate: %@", process, summary];
        bulletin.date                    = [NSDate date];
		SBBulletinBannerController *ctrl = [%c(SBBulletinBannerController) sharedInstance];
		[ctrl observer:nil addBulletin:bulletin forFeed:2];
    }
}

%end

#pragma mark - SecureTransport hooks

/**
 *  A reference to the original SSLHandshake method.
 *
 *  @param original_SSLHandshake Pointer to the method.
 *
 *  @return The original SSLHandshake result code.
 */
static OSStatus (* original_SSLHandshake)(SSLContextRef context);


static NSString* BLOCKED_PEER = NULL;

/**
 *  The override SSLHandshake method.
 *
 *  @param context The SSL context object that was sent to the original.
 *
 *  @return SSL result code.
 */
static OSStatus hooked_SSLHandshake(SSLContextRef context) {
        
	SecTrustRef trustRef = NULL;    
	SSLCopyPeerTrust(context, &trustRef);
    size_t len;
    SSLGetPeerDomainNameLength(context, &len);
    char peerName[len];
    SSLGetPeerDomainName(context, peerName, &len);

    NSString *peer = [[NSString alloc] initWithCString:peerName encoding:NSUTF8StringEncoding];
    
     if(BLOCKED_PEER) {
         if([peer isEqualToString:BLOCKED_PEER]) {
             //We just blocked this peer, fail again.
             return errSSLClosedAbort;
         }
     }
    
    CFIndex count = SecTrustGetCertificateCount(trustRef);

     SecCertificateRef blockedCert = NULL;

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
		NSString *sha1 = [[out hexStringValue] lowercaseString];
        
		//If the SHA1 of this certificate is in our blocked list.
		if([untrustedRoots containsObject:sha1]) {
            NSString *summary = (__bridge NSString *) SecCertificateCopySubjectSummary(certRef);
            NSString *process = [[NSProcessInfo processInfo] processName];
			certificateWasBlocked(process, summary);
            BLOCKED_PEER = peer;
            //Log this block and write to disk.
            LogInformation *info = [[LogInformation alloc] initWithApplication:process peer:peer certficateName:summary time:[NSDate date]];
            [FSHandler writeToLogFile:LOG_FILE withLogInformation:info];
            //Return the failure.
            return errSSLClosedAbort;
		}
        else if([untrustedCerts containsObject:sha1]) {
             blockedCert = SecTrustGetCertificateAtIndex(trustRef, i);
        }
        
        if(i == count - 1) {
         	if(blockedCert != NULL) {
             NSString *summary = (__bridge NSString *) SecCertificateCopySubjectSummary(blockedCert);
             NSString *process = [[NSProcessInfo processInfo] processName];
             certificateWasBlocked(process, summary);
             BLOCKED_PEER = peer;
             //Log this block and write to disk.
             LogInformation *info = [[LogInformation alloc] initWithApplication:process peer:peer certficateName:summary time:[NSDate date]];
             [FSHandler writeToLogFile:LOG_FILE withLogInformation:info];
             //Return the failure.
             return errSSLClosedAbort;
         }
         }
        
	}
     BLOCKED_PEER = NULL;

	return original_SSLHandshake(context);
}

#pragma mark - Constructor

%ctor {
    
    @autoreleasepool {
		%init;

		CFNotificationCenterRef reload = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(reload, NULL, &updateRootsNotification, CFSTR("uk.ac.surrey.rb00166.CertManager/reload"), NULL, 0);

		updateRoots();

		MSHookFunction((void *) SSLHandshake,(void *)  hooked_SSLHandshake, (void **) &original_SSLHandshake);
    }
}