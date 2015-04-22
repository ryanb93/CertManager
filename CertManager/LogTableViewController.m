//
//  LogTableViewController.m
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "LogTableViewController.h"
#import "FSHandler.h"

@interface LogTableViewController ()

@property (strong, atomic) NSMutableArray *logs;

@end

@implementation LogTableViewController

-(id) init {
    
    id this = [super init];
    
    if(this) {
        [self setTabBarItem:[[UITabBarItem alloc] initWithTitle:@"Logs" image:[UIImage imageNamed:@"recents"] tag:2]];
        [self setTitle:@"Logs"];
        UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                                     target:self
                                                                                     action:@selector(clearLogs)];
        [self.navigationItem setRightBarButtonItem:rightButton];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadData)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [self reloadData];
    
        
    }
    
    return this;
}

- (void)reloadData {
    _logs = [FSHandler readLogFile:@"uk.ac.surrey.rb00166.CertManager.log"];
    [self.navigationItem.rightBarButtonItem setEnabled:([_logs count] > 0)];
}

- (void)clearLogs {
    
    UIAlertController *alert =[UIAlertController alertControllerWithTitle:@"Delete Logs"
                                                                  message:@"Are you sure you want to delete all logs? This operation can not be reversed."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"Delete All"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction * action) {
                                                   [FSHandler clearLogFile:@"uk.ac.surrey.rb00166.CertManager.log"];
                                                   [self reloadData];
                                               }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    
    [alert addAction:ok];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [_logs count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //Create a cell, if the system has any reusable cells then use that. This reduces memory usage massively.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"logCell"];
    //If there were no reusable cells.
    if (nil == cell) {
        //Create a new cell.
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"logCell"];
    }
    
    //Set the cell text.
    LogInformation *log = (LogInformation *)[_logs objectAtIndex:[indexPath row]];
    [cell.textLabel setText: [NSString stringWithFormat:@"%@ - %@",[log certificateName], [log peerName]]];
    [cell.detailTextLabel setText:[log application]];
    
    return cell;
}


@end
