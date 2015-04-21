//
//  ManualTableViewController.m
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "ManualTableViewController.h"

@interface ManualTableViewController ()

@property (strong, atomic) NSMutableDictionary *blockedCerts;

@end

@implementation ManualTableViewController

#pragma mark - ManualTableViewController

-(id) init {
    
    id this = [super init];
    
    if(this) {
    	[self setTabBarItem:[[UITabBarItem alloc] initWithTitle:@"Manual" image:[UIImage imageNamed:@"file_edit"] tag:1]];
        UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                     target:self
                                                                                     action:@selector(addCertificate)];
        [self.navigationItem setTitle:@"Manual"];
        [self.navigationItem setRightBarButtonItem:rightButton];
    }
    
    
    return this;
}

/**
 *  Method called when the view is first created.
 */
- (void)viewDidLoad
{
    //Call to super.
    [super viewDidLoad];
    
    //Stop selection on the table view.
    [self.tableView setAllowsSelection:NO];
    [self.tableView setRowHeight:UITableViewAutomaticDimension];
    [self.tableView setEstimatedRowHeight:44.0f];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    
}


-(void)addCertificate {
    
    UIAlertController *alert =[UIAlertController alertControllerWithTitle:@"Block Certificate"
                                                                   message:@"Please enter the SHA1 hash of the certificate you wish to block"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"Block"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                  
                                                   

                                               }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Certificate Name";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"SHA1 Hash";
        [textField addTarget:self action:@selector(textChanged:) forControlEvents:UIControlEventEditingChanged];
    }];

    [ok setEnabled:NO];
    [alert addAction:ok];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)textChanged:(id) sender {
    UITextField *tf = (UITextField *)sender;
    UIResponder *resp = tf;
    while(![resp isKindOfClass:[UIAlertController class]]) {
        resp = [resp nextResponder];
    }
    UIAlertController *alert = (UIAlertController *) resp;
	[[alert.actions objectAtIndex:0] setEnabled:[tf.text isSHA1]];
}


- (void)reloadData {
    [self.tableView reloadData];
}


@end
