//
//  ManualTableViewController.m
//  CertManager
//
//  Created by Ryan Burke on 21/04/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "ManualTableViewController.h"

#import "FSHandler.h"

@interface ManualTableViewController ()

@property (strong, atomic) NSMutableDictionary *blockedCerts;
@property (strong, atomic) NSMutableArray *blockedCertSHA1s;

@end

@implementation ManualTableViewController

#pragma mark - ManualTableViewController

static NSString * const UNTRUSTED_CERTS_PLIST = @"CertManagerUntrustedCerts";
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
    
    [self reloadData];
    
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
                                                   NSString *name = [[alert.textFields objectAtIndex:0] text];
                                                   NSString *sha1 = [[[alert.textFields objectAtIndex:1] text] lowercaseString];
                                                   if(![_blockedCerts objectForKey:sha1]) {
                                                       [_blockedCerts setValue:name forKey:sha1];
                                                   }
                                                   [FSHandler writeToPlist:UNTRUSTED_CERTS_PLIST withData:_blockedCerts];
                                                   [self reloadData];
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
    
    _blockedCerts = [FSHandler readDictionaryFromPlist:UNTRUSTED_CERTS_PLIST];
    
    _blockedCertSHA1s = [[_blockedCerts keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [(NSString*)obj2 compare:(NSString*)obj1];
    }] mutableCopy];
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_blockedCertSHA1s count];
}

#pragma mark - UITableViewDelegate

/**
 *  This function creates the buttons used when the user swipes left on a table cell.
 *
 *  @param tableView The table view that called this function.
 *  @param indexPath The index of the cell that was swiped.
 *
 *  @return An array of actions that the cell can perform.
 */
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    

    void (^deleteAlert)(UITableViewRowAction*, NSIndexPath*) = ^(UITableViewRowAction *action, NSIndexPath *indexPath) {
        
        //Create an alert controller and use the alert message function to generate a message.
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Certificate"
                                                                       message:@"You are about to delete this certificate. This will allow all secure communications "
                                    "to and from servers containing this certificate in their chain of trust. Are you sure you want to do this?"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        //Add the alert actions to the controller. This adds the buttons automatically.
        [alert addAction: [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive
                                                  handler:^(UIAlertAction * action) {
                                                      NSString *sha1 = [_blockedCertSHA1s objectAtIndex:[indexPath row]];
                                                      [_blockedCerts removeObjectForKey:sha1];
                                                      [FSHandler writeToPlist:UNTRUSTED_CERTS_PLIST withData:_blockedCerts];
                                                      [self reloadData];
                                                  }]];
        
        [alert addAction: [UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil]];
        //Show the alert to the user.
        [self presentViewController:alert animated:YES completion:nil];
    };

    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                           title:@"Delete"
                                                                         handler:deleteAlert];

    return @[deleteAction];

}

/**
 *  This function enables the swipe on list elements.
 *
 *  @param tableView    The table view that called this function.
 *  @param editingStyle The editing style (unused)
 *  @param indexPath    The index of the cell (unused)
 */
-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Empty, shows the swipable buttons for all cells.
}


/**
 *  This is a function which creates the cell object and returns it back to the table view.
 *
 *  @param tableView The table view that called this function.
 *  @param indexPath The index of the cell to be created.
 *
 *  @return A completed cell object which will be placed into the table.
 */
-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //Create a cell, if the system has any reusable cells then use that. This reduces memory usage massively.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"blockedCell"];
    //If there were no reusable cells.
    if (nil == cell) {
        //Create a new cell.
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"blockedCell"];
    }
    

    NSString *sha1 = [_blockedCertSHA1s objectAtIndex:[indexPath row]];
    NSString *name = [_blockedCerts valueForKey:sha1];
    
    //Set the cell text.
    [cell.textLabel setText: name];
    [cell.textLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [cell.textLabel setNumberOfLines:0];
    [cell.detailTextLabel setText:sha1];
    [cell.imageView setImage:[UIImage imageNamed:@"untrusted"]];
    
    

    return cell;
}



@end
