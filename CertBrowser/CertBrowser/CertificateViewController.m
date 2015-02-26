//
//  CertificateViewController.m
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "CertificateViewController.h"
#import "X509Wrapper.h"
#import "NSString+FontAwesome.h"

@interface CertificateViewController ()

@end

@implementation CertificateViewController

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
    
    UIImageView *certImage = (UIImageView *)[cell viewWithTag:10];
    if([indexPath section] == 0) {
    	certImage.image = [UIImage imageNamed:@"RootCert"];
    }

    UILabel *certNameLabel = (UILabel *)[cell viewWithTag:11];
    certNameLabel.text = (__bridge NSString *)(SecCertificateCopySubjectSummary(certificate));
    
    UILabel *issuerLabel = (UILabel *)[cell viewWithTag:12];
    issuerLabel.text = [NSString stringWithFormat:@"Issued by: %@", [X509Wrapper CertificateGetIssuerName:certificate] ];
    
    return cell;
}

@end
