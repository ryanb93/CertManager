//
//  TableViewController.m
//  CertManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//
#import <CertUI/CertUIPrompt.h>
#import <OpenSSL/x509.h>
#import <Security/SecBase.h>

#import "TableViewController.h"
#import "CertDataStore.h"
#import "X509Wrapper.h"
#import "TableCellSwitch.h"

@interface TableViewController ()

@property (strong, atomic) CertDataStore * certStore;
@property (strong, atomic) NSArray * titles;


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
    _titles = [[_certStore titlesForCertificates] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    //Set the title of the navigation bar to use the trust store version.
    [self setTitle:[NSString stringWithFormat:@"Trust Store Version: %i", [_certStore trustStoreVersion]]];
    
    //Stop selection on the table view.
    [self.tableView setAllowsSelection:NO];
    [self.tableView setRowHeight:UITableViewAutomaticDimension];
    [self.tableView setEstimatedRowHeight:44.0f];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];


}

- (void)reloadData {
    [_certStore reloadUntrustedCertificates];
    [self.tableView reloadData];
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
    return [_titles count];
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
    NSString *title = _titles[section];
    return [_certStore numberOfCertificatesForTitle:title];
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
    return _titles[section];
}

/**
 *  Returns all the different titles that are available to the list view.
 *
 *  @param tableView The table view that called this function.
 *
 *  @return An array containing the titles.
 */
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return _titles;
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
    return [_titles indexOfObject:title];
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
    
    TableCellSwitch *switchView = [[TableCellSwitch alloc] initWithFrame:CGRectZero];
    [switchView setIndexPath:indexPath];
    [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    //Set the cell text.
    SecCertificateRef certificate = [_certStore certificateWithTitle:_titles[[indexPath section]]
                                                           andOffSet:[indexPath row]];
    NSString *certName = [_certStore nameForCertificate:certificate];
    NSString *issuer   = [_certStore issuerForCertificate:certificate];
    [cell.textLabel setText: certName];
    [cell.textLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [cell.textLabel setNumberOfLines:0];
    [cell.detailTextLabel setText:[NSString stringWithFormat:@"Issued by: %@", issuer]];
    
    //Style the cell.
    BOOL trusted = [_certStore isTrustedForCertificate:certificate];
    if(trusted) {
        cell.imageView.image = [UIImage imageNamed:@"trusted"];
        [switchView setOn:NO animated:NO];
    }
    else {
        cell.imageView.image = [UIImage imageNamed:@"untrusted"];
        [switchView setOn:YES animated:NO];
    }
    
    [cell setAccessoryView:switchView];
    
    return cell;
}

- (void) switchChanged:(id)sender {
    
    TableCellSwitch *switchControl = sender;
    NSIndexPath *indexPath         = switchControl.indexPath;
    
    //Get the name of the certificate to use in alerts.
    NSString  *title   = [self tableView:self.tableView titleForHeaderInSection:[indexPath section]];
    NSInteger row      = [indexPath row];
    
    SecCertificateRef certificate = [_certStore certificateWithTitle:title andOffSet:row];
    
    if([switchControl isOn]) {
        [_certStore untrustCertificate:certificate];
    }
    else {
        [_certStore trustCertificate:certificate];
    }
    
    [self.tableView reloadData];    
}


@end
