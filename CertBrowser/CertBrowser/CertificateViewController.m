//
//  CertificateViewController.m
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "CertificateViewController.h"

@interface CertificateViewController ()

@end

@implementation CertificateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)closeView:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_certificates count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
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
    SecCertificateRef certificate = (__bridge SecCertificateRef)(_certificates[[indexPath row]]);
    NSString *certName = (__bridge NSString *)(SecCertificateCopySubjectSummary(certificate));
    [cell.textLabel setText: certName];

    return cell;
}

@end
