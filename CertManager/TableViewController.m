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

- (void)viewDidLoad
{
    [super viewDidLoad];

    _certStore = [[CertDataStore alloc] init];
    
    [self setTitle:[NSString stringWithFormat:@"Trust Store Version: %i", [_certStore trustStoreVersion]]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_certStore numberOfCertificates];
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_certStore numberOfCertificatesInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_certStore titleForCertificatesInSection:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [_certStore titles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [[_certStore titles] indexOfObject:title];
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Empty, shows the swipable buttons.
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"caCell"];

    if (nil == cell) {
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

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString  *title   = [self tableView:self.tableView titleForHeaderInSection:[indexPath section]];
    NSInteger row      = [indexPath row];
    NSString *certName = [_certStore nameForCertificateWithTitle:title andOffset:row];
    
    UITableViewRowAction *untrustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Untrust"  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Untrust Certificate" message:[NSString stringWithFormat:@"You are about to untrust the \"%@\" root certificate. This will stop all secure communications with servers identifying with this certificate. Are you sure you want to do this?", certName] delegate:nil cancelButtonTitle:@"No" otherButtonTitles: @"Yes", nil];
        [alert show];
    }];

    UITableViewRowAction *trustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Trust"  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Trust Certificate" message:[NSString stringWithFormat:@"You are about to trust the \"%@\" root certificate. This will allow secure communications with servers identifying with this certificate. Are you sure you want to do this?", certName] delegate:nil cancelButtonTitle:@"No" otherButtonTitles: @"Yes", nil];
        [alert show];
    }];

    trustAction.backgroundColor = [UIColor colorWithRed:0.35 green:0.71 blue:0.2 alpha:1];
    return @[untrustAction, trustAction];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
