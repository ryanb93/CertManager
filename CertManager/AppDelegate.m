//
//  AppDelegate.m
//  CAManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import "AppDelegate.h"
#import "TableViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    //Create an instance of our table view controller.
    TableViewController *tableViewController = [[TableViewController alloc] initWithStyle:UITableViewStylePlain];
    
    //Add this controller to a navigation controller.
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:tableViewController];

    //Create the window object with the screen bounds.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    //Set the window root view controller to our navigation controller.
    [self.window setRootViewController:navController];
    
    //Make the window visible.
    [self.window makeKeyAndVisible];

    return YES;
}

@end
