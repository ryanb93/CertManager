#import <BulletinBoard/BulletinBoard.h>
#import <notify.h>
#import <rocketbootstrap.h>
#import "../theos/include/substrate.h"


#pragma mark - External Interfaces

@interface SBBulletinBannerController : NSObject
    + (SBBulletinBannerController *)sharedInstance;
    - (void)observer:(id)observer addBulletin:(BBBulletinRequest *)bulletin forFeed:(int)feed;
@end

@interface CPDistributedMessagingCenter : NSObject
+ (id)centerNamed:(id)arg1;
- (void)runServerOnCurrentThread;
- (void)registerForMessageName:(id)arg1 target:(id)arg2 selector:(SEL)arg3;
@end

#pragma mark - SpringBoard Hooks

static NSString* const MESSAGING_CENTER           = @"uk.ac.surrey.rb00166.CertManager";
static NSString* const BLOCKED_NOTIFICATION       = @"certificateWasBlocked";

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