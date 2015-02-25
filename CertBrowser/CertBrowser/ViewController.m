//
//  ViewController.m
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Security/SecTrust.h>

#import "ViewController.h"
#import "CertificateViewController.h"
#import "NSString+FontAwesome.h"

@interface ViewController ()

@property (nonatomic) BOOL validCertificates;
@property (strong, nonatomic) NSURLRequest* failedRequest;
@property (strong, nonatomic) NSMutableArray* certificatesForRequest;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.webView setDelegate:self];
    [self.webView setScalesPageToFit:YES];
	
    //Get a reference to the navbar.
    UINavigationBar *navBar = self.navigationController.navigationBar;
    
    //Create the address field with the correct size.
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat navHeight = navBar.bounds.size.height;
    CGFloat addressHeight = 30.0f;
    CGFloat padding = (screenWidth * 0.05f);
    CGFloat addressWidth = screenWidth - (2 * padding);
    CGRect addressFrame = CGRectMake(padding, (navHeight - addressHeight) / 2, addressWidth, addressHeight);
    UITextField *addressField = [[UITextField alloc] initWithFrame:addressFrame];
	
    //Set up the address field so it acts nicely.
    [addressField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [addressField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [addressField setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [addressField setBorderStyle:UITextBorderStyleRoundedRect];
    [addressField setClearButtonMode:UITextFieldViewModeAlways];
    [addressField setClearsOnBeginEditing:YES];
    [addressField setFont:[UIFont systemFontOfSize:17.0f]];
    [addressField setKeyboardType:UIKeyboardTypeURL];
	
    //Fire this event when we finish editing.
    [addressField addTarget:self
                     action:@selector(loadRequestFromAddressField:)
           forControlEvents:UIControlEventEditingDidEndOnExit];
    
    //Create a container view.
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 30)];
    
    _lockButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_lockButton setFrame:CGRectMake(5.0f, 0.0f, 20.0f, 30.0f)];
    [[_lockButton titleLabel] setFont:[UIFont fontWithName:kFontAwesomeFamilyName size:26]];
    [_lockButton addTarget:self action:@selector(lockButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    addressField.leftViewMode = UITextFieldViewModeUnlessEditing;
    

    [container addSubview:_lockButton];
    
    [addressField setLeftView:container];
    [navBar addSubview:addressField];
    
    self.addressField = addressField;
    

	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://google.com"]];
	[self.webView loadRequest:urlRequest];
}

- (void)lockButtonPressed:(id)lockButton {
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UINavigationController *myController = [storyboard instantiateViewControllerWithIdentifier:@"CertNavigationController"];
    
    [myController.childViewControllers[0] setCertificates:_certificatesForRequest];
    
    [self.navigationController presentViewController:myController animated:YES completion:nil];
    
}

- (void)lockIconUseSSL:(BOOL)ssl {
    if(ssl) {
        [_lockButton setTitle:[NSString fontAwesomeIconStringForEnum:FALock] forState:UIControlStateNormal];
        [_lockButton setTintColor:[UIColor colorWithRed:0.297 green:0.776 blue:0.302 alpha:1.000]];
    }
    else {
        [_lockButton setTitle:[NSString fontAwesomeIconStringForEnum:FAUnlockAlt] forState:UIControlStateNormal];
        [_lockButton setTintColor:[UIColor colorWithRed:1.000 green:0.100 blue:0.169 alpha:1.000]];
    }
}

- (void)updateTitle:(UIWebView*)aWebView
{
    NSString* pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.pageTitle.text = pageTitle;
}

- (void)loadRequestFromAddressField:(id)addressField
{
    NSString *urlString = [addressField text];
    NSURL *url = [NSURL URLWithString:urlString];
    if(!url.scheme)
    {
        NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
        modifiedURLString = [modifiedURLString stringByReplacingOccurrencesOfString:@" " withString:@""];
        url = [NSURL URLWithString:modifiedURLString];
    }
    
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:urlRequest];
}

- (void)updateButtons
{
    self.forward.enabled = self.webView.canGoForward;
    self.back.enabled = self.webView.canGoBack;
    self.stop.enabled = self.webView.loading;
}

- (void)updateAddress:(NSURLRequest*)request
{
    NSURL* url = [request mainDocumentURL];
    NSString* absoluteString = [url absoluteString];
    self.addressField.text = absoluteString;
}

- (void)informError:(NSError *)error {

    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:[error localizedDescription]
                          message:[error localizedRecoverySuggestion]
                          delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"")
                          otherButtonTitles:nil];
    
    [alert show];
}

#pragma mark UIWebViewDelegate

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    [[NSURLConnection alloc] initWithRequest:request delegate:self];
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self updateTitle:webView];
    [self updateAddress:[webView request]];
    [self lockIconUseSSL:[webView.request.URL.scheme isEqualToString:@"https"]];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self informError:error];
}

#pragma mark NSURLConnectionDataDelegate

-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
  
    NSLog(@"New SSL request");
    
    _certificatesForRequest = [[NSMutableArray alloc] init];
    
    SecTrustRef trustRef = challenge.protectionSpace.serverTrust;
    
    CFIndex count = SecTrustGetCertificateCount(trustRef);
    
    //For each certificate in the certificate chain.
    for (CFIndex i = 0; i < count; i++)
    {
        //Get a reference to the certificate.
        SecCertificateRef certRef = SecTrustGetCertificateAtIndex(trustRef, i);
        [_certificatesForRequest addObject:(__bridge id)certRef];
        
        NSString *summary = (__bridge NSString *) SecCertificateCopySubjectSummary(certRef);
        NSLog(@"Certificate: %@", summary);
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)pResponse {
    NSLog(@"didReceiveResponse");
    _validCertificates = YES;
    [connection cancel];
}

@end
