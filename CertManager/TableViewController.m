//
//  ViewController.m
//  CertManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//
#import <CertUI/CertUIPrompt.h>
#import <Securityd/OTATrustUtilities.h>
#import <Securityd/SecTrustServer.h>
#import <OpenSSL/x509.h>

#import "TableViewController.h"
#import "X509Wrapper.h"

@interface TableViewController ()

@end

@implementation TableViewController

#pragma mark - TableViewController

- (void)loadView
{
    [super loadView];
    int versionNumber = InitOTADirectory();
    [self setTitle:[NSString stringWithFormat:@"Trust Store Version: %i", versionNumber]];
    [self setCertificates];
}


- (void)setCertificates
{
    //Create the array to hold the list of names.
    _names = [[NSMutableArray alloc] init];

    //Gets a reference to the current OTA.
    SecOTAPKIRef ref = SecOTAPKICopyCurrentOTAPKIRef();

    //This returns dictionary of a hash in the Index file and an offset.
    CFDictionaryRef lookup = SecOTAPKICopyAnchorLookupTable(ref);

    //Create an array to hold the values of the offsets.
    NSMutableArray *offsets = [[NSMutableArray alloc] init];

    //Loop through each value in the dictionary.
    for (NSString *value in (__bridge NSDictionary *)lookup) {
        //Inside each dicationary value there is an array containing 1 or more offsets.
        NSArray *val = (NSArray *)CFDictionaryGetValue(lookup, (__bridge const void *)(value));
        if(val != nil) {
            //For each String inside the array.
            for (NSString *nums in val) {
                if(nums != nil) {
                    //Add the offset String to the offsets array.
                    [offsets addObject:nums];
                }
            }
        }
    }

    //Use function from SecTrustServer to get certificates from offsets.
    NSMutableArray *certs = (__bridge NSMutableArray *) CopyCertsFromIndices((__bridge CFArrayRef)offsets);

    //Sort the data alphabetically.
    [certs sortUsingFunction:sortCerts context:nil];

    //Go through each certificate
    for (id cert in certs) {
        SecCertificateRef certRef = (__bridge SecCertificateRef) cert;
        NSString *summary = (__bridge NSString *)(SecCertificateCopySubjectSummary(certRef));
        NSString *first = [NSString stringWithFormat:@"%c", [summary characterAtIndex:0]];
        if(![_names containsObject:first]) {
            [_names addObject:first];
        }
    }

    _certificates = [[NSMutableDictionary alloc] init];

    for (id name in _names) {
        NSMutableArray *tmp = [[NSMutableArray alloc] init];
        for (id certificate in certs) {
            SecCertificateRef certRef = (__bridge SecCertificateRef) certificate;
            NSString *summary = (__bridge NSString *)(SecCertificateCopySubjectSummary(certRef));
            NSString *first = [NSString stringWithFormat:@"%c", [summary characterAtIndex:0]];
            if([first isEqualToString:name]) {
                [tmp addObject:certificate];
            }
        }

        [_certificates setObject:tmp forKey:name];
    }

}

NSInteger sortCerts(id id1, id id2, void *context)
{
    CFStringRef summary = SecCertificateCopySubjectSummary((__bridge SecCertificateRef)id1);
    CFStringRef summary2 = SecCertificateCopySubjectSummary((__bridge SecCertificateRef)id2);
    return CFStringCompare(summary, summary2, 0);
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return [_certificates count];
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return [[_certificates objectForKey:[_names objectAtIndex:section]] count];

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_names objectAtIndex:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return _names;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [_names indexOfObject:title];
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

    NSString *name = [_names objectAtIndex:[indexPath section]];

    SecCertificateRef cert = (__bridge SecCertificateRef)[[_certificates objectForKey:name] objectAtIndex:[indexPath row]];

    NSData *certificateData = (__bridge NSData *) SecCertificateCopyData(cert);

    const unsigned char *certificateDataBytes = (const unsigned char *)[certificateData bytes];

    X509 *certificateX509 = d2i_X509(NULL, &certificateDataBytes, [certificateData length]);

    NSString *issuer = [X509Wrapper CertificateGetIssuerName:certificateX509];

    cell.imageView.image = [UIImage imageNamed:@"trusted.png"];

    CFStringRef summary = SecCertificateCopySubjectSummary(cert);
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [[cell textLabel] setText:(__bridge NSString *)summary];
    [[cell detailTextLabel] setText:[NSString stringWithFormat:@"Issued by: %@", issuer]];
    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *name = [_names objectAtIndex:[indexPath section]];
    id cert_data = [[_certificates objectForKey:name] objectAtIndex:[indexPath row]];

    SecCertificateRef cert = (__bridge SecCertificateRef) cert_data;

    SecTrustRef trust;

    SecPolicyRef type = SecPolicyCreateBasicX509();
    
    SecTrustCreateWithCertificates(cert, type, &trust);

    CertUIPrompt *prompt = [[CertUIPrompt alloc] init];
    CFStringRef summary = SecCertificateCopySubjectSummary(cert);
    [prompt setHost:(__bridge NSString *)(summary)];
    [prompt setTrust:trust];
    [prompt showAndWaitForResponse];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewRowAction *untrustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Untrust"  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){

        NSString *certName = [_names objectAtIndex:[indexPath section]];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Untrust Certificate" message:[NSString stringWithFormat:@"You are about to untrust the %@ certificate. This will stop all secure communications with servers identifying with this certificate. Are you sure you want to do this?", certName] delegate:nil cancelButtonTitle:@"No" otherButtonTitles: @"Yes", nil];
        [alert show];
    }];

    UITableViewRowAction *trustAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Trust"  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Trust Certificate" message:@"You are about to trust this certificate. This will allow all secure communications with servers identifying with this certificate. Are you sure you want to do this?" delegate:nil cancelButtonTitle:@"No" otherButtonTitles: @"Yes", nil];
        [alert show];
    }];

    trustAction.backgroundColor = [UIColor colorWithRed:0.35 green:0.71 blue:0.2 alpha:1];
    return @[untrustAction, trustAction];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
