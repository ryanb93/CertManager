//
//  AppDelegate.m
//  CAManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import "AppDelegate.h"

#import "TrustStoreViewController.h"
#import "ManualTableViewController.h"
#import "LogTableViewController.h"
#import "BrowserViewController.h"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    
    //Create an instance of our table view controller.
    TrustStoreViewController *tableViewController = [[TrustStoreViewController alloc] init];
    
    //Create an instance of our blocked intemediatories
    ManualTableViewController *blockedController = [[ManualTableViewController alloc] init];

    LogTableViewController *logController = [[LogTableViewController alloc] init];
    
    BrowserViewController *browser = [[BrowserViewController alloc] init];
    
    //Add this controller to a navigation controller.
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:tableViewController];
    UINavigationController *blockedNavController = [[UINavigationController alloc] initWithRootViewController:blockedController];
    UINavigationController *logNavController = [[UINavigationController alloc] initWithRootViewController:logController];
    UINavigationController *browserNavController = [[UINavigationController alloc] initWithRootViewController:browser];
    
    //Create tab controller and add views.
    UITabBarController *tabViewController = [[UITabBarController alloc] init];
    [tabViewController setViewControllers:[NSArray arrayWithObjects:navController, blockedNavController, logNavController, browserNavController, nil]];
        
    //Create the window object with the screen bounds.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    //Set the window root view controller to our navigation controller.
    [self.window setRootViewController:tabViewController];
    
    //Make the window visible.
    [self.window makeKeyAndVisible];

    return YES;
}

@end
