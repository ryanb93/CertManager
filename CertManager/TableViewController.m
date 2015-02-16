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
    
    //Cancel event handler.
    UIAlertAction *cancelAlertAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {}];
    
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
    
    
    //String for Alert
    NSString* (^alertMessage)(BOOL trust) = ^NSString *(BOOL trust) {
        
        NSString *trusts = @"trust";
        NSString *action = @"start";
        if(!trust) trusts = @"untrust";
        if(!trust) action = @"stop";
        
        return [NSString stringWithFormat:@"You are about to %@ the \"%@\" root certificate. This will %@ all secure communications with servers identifying with this certificate. Are you sure you want to do this?", trusts, certName, action];
        

    };
    

    UITableViewRowAction *untrustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Untrust" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Untrust Certificate" message:alertMessage(false) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:untrustAlertAction];
        [alert addAction:cancelAlertAction];
        [self presentViewController:alert animated:YES completion:nil];
    }];

    UITableViewRowAction *trustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Trust"  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trust Certificate"
                                                                       message:alertMessage(true)
                                                                preferredStyle:UIAlertControllerStyleAlert];

        
        [alert addAction:cancelAlertAction];
        [alert addAction:trustAlertAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        
        
    }];

    trustAction.backgroundColor = [UIColor colorWithRed:0.35 green:0.71 blue:0.2 alpha:1];
    return @[untrustAction, trustAction];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
