//
//  CertificateViewController.m
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "CertificateTableViewController.h"
#import "CertDataStore.h"
#import "NSString+FontAwesome.h"

@interface CertificateTableViewController ()

@property (strong, nonatomic) NSMutableArray *certificates;
@property (strong, nonatomic) CertDataStore *certStore;

@end

@implementation CertificateTableViewController

-(id)initWithCertificates:(NSMutableArray *)certs {
    if(self = [super init]) {
        _certificates = certs;
        _certStore = [[CertDataStore alloc] init];

        UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                    target:self
                                                                                    action:@selector(closeView:)];
        [self.navigationItem setTitle:@"Certificate Chain"];
        [self.navigationItem setLeftBarButtonItem:leftButton];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

-(void)closeView:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_certificates count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120.0f;
}
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    CGFloat height = 30.0;
    if(section == 0) height = 0;
    return height;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 30)];
    
    if(section != 0) {
        [view setBackgroundColor:[UIColor clearColor]];
    
    	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(35, 0, 35, 35)];
    	[label setFont:[UIFont fontWithName:kFontAwesomeFamilyName size:36]];
    	[label setText:[NSString fontAwesomeIconStringForEnum:FALink]];
        label.transform = CGAffineTransformMakeRotation(M_PI_4);
        [view addSubview:label];

    }
    
    return view;
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //Create a cell, if the system has any reusable cells then use that. This reduces memory usage massively.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"certificateCell"];
    
    //If there were no reusable cells.
    if (nil == cell) {
        //Create a new cell.
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"certificateCell"];
    }
    
	//Set the cell text.
    SecCertificateRef certificate = (__bridge SecCertificateRef)(_certificates[[indexPath section]]);
    
    UIImageView *certImage = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 100, 100)];
    [certImage setContentMode:UIViewContentModeScaleAspectFit];
    if([indexPath section] == 0) {
    	certImage.image = [UIImage imageNamed:@"RootCert"];
    }
    else {
        certImage.image = [UIImage imageNamed:@"StandardCert"];
    }

    UILabel *certNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 10, 300, 40)];
    [certNameLabel setFont:[UIFont boldSystemFontOfSize:16]];
    certNameLabel.text = (__bridge NSString *)(SecCertificateCopySubjectSummary(certificate));
    
    UILabel *issuerLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 50, 300, 40)];
    issuerLabel.text = [NSString stringWithFormat:@"Issued by: %@", [X509Wrapper CertificateGetIssuerName:certificate] ];
    
    UILabel *expireLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 70, 300, 40)];
    [expireLabel setText:[NSString stringWithFormat:@"Expires: %@", [X509Wrapper CertificateGetExpiryDate:certificate]]];
	
    [cell addSubview:certImage];
    [cell addSubview:certNameLabel];
    [cell addSubview:issuerLabel];
    [cell addSubview:expireLabel];
    
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UIAlertController *alert =[UIAlertController alertControllerWithTitle:@"Block Certificate"
                                                                  message:@"Blocking this certificate will cause all connections accross the system to fail when connecting to a server with this certificate in its chain of trust. Are you sure you want to do this?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *block = [UIAlertAction actionWithTitle:@"Block"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction * action) {
                                                   
                                                   SecCertificateRef certificate = (__bridge SecCertificateRef)([_certificates objectAtIndex:[indexPath section]]);
                                                   [_certStore untrustNormalCertificate:certificate];
                                               }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    
    [alert addAction:block];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
    
}

@end
