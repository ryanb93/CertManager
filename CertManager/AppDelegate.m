//
//  AppDelegate.m
//  CAManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import "AppDelegate.h"

#import "TrustStoreTableViewController.h"
#import "ManualTableViewController.h"
#import "LogTableViewController.h"
#import "BrowserViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    //Create instances of the view controllers
    TrustStoreTableViewController *tableViewController = [[TrustStoreTableViewController alloc] init];
    ManualTableViewController *blockedController = [[ManualTableViewController alloc] init];
    LogTableViewController *logController = [[LogTableViewController alloc] init];
    BrowserViewController *browser = [[BrowserViewController alloc] init];
    
    //Create navigation controllers for each view.
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:tableViewController];
    UINavigationController *blockedNavController = [[UINavigationController alloc] initWithRootViewController:blockedController];
    UINavigationController *logNavController = [[UINavigationController alloc] initWithRootViewController:logController];
    UINavigationController *browserNavController = [[UINavigationController alloc] initWithRootViewController:browser];
    
    //Create tab controller and add navigation views.
    UITabBarController *tabViewController = [[UITabBarController alloc] init];
    [tabViewController setViewControllers:[NSArray arrayWithObjects:navController, blockedNavController, logNavController, browserNavController, nil]];
        
    //Create the window object with the screen bounds.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window setRootViewController:tabViewController];
    [self.window makeKeyAndVisible];

    return YES;
}

@end
