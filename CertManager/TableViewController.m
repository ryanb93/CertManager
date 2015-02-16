//
//  TableViewController.m
//  CertManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//
#import <CertUI/CertUIPrompt.h>
#import <OpenSSL/x509.h>

#import "TableViewController.h"
#import "CertDataStore.h"
#import "X509Wrapper.h"

@interface TableViewController ()

@property (strong, atomic) CertDataStore * certStore;

@end

@implementation TableViewController

#pragma mark - TableViewController

/**
 *  Method called when the view is first created. Here we deal with setting up the certificate store and setting the title.
 */
- (void)viewDidLoad
{
    //Call to super.
    [super viewDidLoad];
    
    //Create our certificate store object.
    _certStore = [[CertDataStore alloc] init];
    
    //Set the title of the navigation bar to use the trust store version.
    [self setTitle:[NSString stringWithFormat:@"Trust Store Version: %i", [_certStore trustStoreVersion]]];
}

#pragma mark - UITableViewDataSource

/**
 *  Returns the number of sections that are in the table view.
 *  In this case we have a section for each unique character a certificate starts with.
 *
 *  @param tableView The table view that called this function.
 *
 *  @return The number of sections in the table.
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_certStore numberOfTitles];
}

/**
 *  Returns the number of items in each individual section of the table view.
 *
 *  @param tableView The table view that called this function.
 *  @param section   The number of the section.
 *
 *  @return The number of items in a particular section of the table.
 */
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_certStore numberOfCertificatesInSection:section];
}

/**
 *  Returns a title for the section in a table view.
 *
 *  @param tableView The table view that called this function.
 *  @param section   The number of the section.
 *
 *  @return A title for the table view.
 */
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_certStore titleForCertificatesInSection:section];
}

/**
 *  Returns all the different titles that are available to the list view.
 *
 *  @param tableView The table view that called this function.
 *
 *  @return An array containing the titles.
 */
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [_certStore titles];
}

/**
 *  Return the index of the section having the given title and section title index.
 *
 *  @param tableView The table view that called this function.
 *  @param title     The title.
 *  @param index     The index.
 *
 *  @return The index of the object in the list of titles.
 */
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [[_certStore titles] indexOfObject:title];
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"caCell"];
    //If there were no reusable cells.
    if (nil == cell) {
        //Create a new cell.
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"caCell"];
    }
    
    //Get the name and issuer of the certificate for this row.
    NSString  *title   = [self tableView:self.tableView titleForHeaderInSection:[indexPath section]];
    NSInteger row      = [indexPath row];
    NSString *certName = [_certStore nameForCertificateWithTitle:title andOffset:row];
    NSString *issuer   = [_certStore issuerForCertificateWithTitle:title andOffset:row];

    //Style the cell.
    cell.imageView.image = [UIImage imageNamed:@"trusted"];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    //Set the cell text.
    [cell.textLabel setText: certName];
    [cell.detailTextLabel setText:[NSString stringWithFormat:@"Issued by: %@", issuer]];
    
    return cell;
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

    //Get the name of the certificate to use in alerts.
    NSString  *title   = [self tableView:self.tableView titleForHeaderInSection:[indexPath section]];
    NSInteger row      = [indexPath row];
    NSString *certName = [_certStore nameForCertificateWithTitle:title andOffset:row];
    
    //Cancel event handler if the user presses the cancel button on an alert.
    UIAlertAction *cancelAlertAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             [self.tableView beginUpdates];
                                                             [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                                                                   withRowAnimation:UITableViewRowAnimationRight];
                                                             [self.tableView endUpdates];
                                                         }];
    
    //Untrust event handler.
    UIAlertAction *untrustAlertAction = [UIAlertAction actionWithTitle:@"Untrust" style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              NSLog(@"Untrusting: %@", certName);
                                                              
                                                          }];
    
    //Trust event handler.
    UIAlertAction *trustAlertAction = [UIAlertAction actionWithTitle:@"Trust" style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action) {
                                                            
                                                            NSLog(@"Trusting: %@", certName);
                                                            
                                                        }];
    
    
    /**
     *  A block function that generates a message depending on the trust or untrust.
     *
     *  @param trust If the alert was for trusting the certificate.
     *
     *  @return A customised message for the user.
     */
    NSString* (^alertMessage)(BOOL) = ^NSString *(BOOL trust) {
        NSString *trusts = @"trust";
        NSString *action = @"start";
        if(!trust) {
            trusts = @"untrust";
            action = @"stop";
        }
        return [NSString stringWithFormat:@"You are about to %@ the \"%@\" root certificate. This will %@ all secure communications with servers identifying with this certificate. Are you sure you want to do this?", trusts, certName, action];
    };
    

    /**
     *  This is a block function which shows the user an alert asking if they want to untrust the certificate.
     *
     *  @param action    The action taken.
     *  @param indexPath The index of the row on the table which was swiped.
     *
     */
    void (^untrustAlert)(UITableViewRowAction*, NSIndexPath*) = ^(UITableViewRowAction *action, NSIndexPath *indexPath) {
        
        //Create an alert controller and use the alert message function to generate a message.
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Untrust Certificate"
                                                                       message:alertMessage(false)
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        //Add the alert actions to the controller. This adds the buttons automatically.
        [alert addAction:untrustAlertAction];
        [alert addAction:cancelAlertAction];
        
        //Show the alert to the user.
        [self presentViewController:alert animated:YES completion:nil];
    };

    
    /**
     *  This is a block function which shows the user an alert asking if they want to trust the certificate.
     *
     *  @param action    The action taken.
     *  @param indexPath The index of the row on the table which was swiped.
     *
     */
    void (^trustAlert)(UITableViewRowAction*, NSIndexPath*) = ^(UITableViewRowAction *action, NSIndexPath *indexPath) {
        
        //Create an alert controller and use the alert message function to generate a message.
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trust Certificate"
                                                                       message:alertMessage(true)
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        //Add the alert actions to the controller. This adds the buttons automatically.
        [alert addAction:trustAlertAction];
        [alert addAction:cancelAlertAction];
        
        //Show the alert to the user.
        [self presentViewController:alert animated:YES completion:nil];
    };

    //Create an untrust action object which calls the untrustAlert function when tapped.
    UITableViewRowAction *untrustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                             title:@"Untrust"
                                                                           handler:untrustAlert];
    
    //Create a trust action object which calls the trustAlert function when tapped.
    UITableViewRowAction *trustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                                                             title:@"Untrust"
                                                                           handler:trustAlert];

    //Set the trust background colour to green.
    trustAction.backgroundColor = [UIColor colorWithRed:0.35 green:0.71 blue:0.2 alpha:1];
    
    //Return both the swipe actions back to the list.
    return @[untrustAction, trustAction];
}

@end
