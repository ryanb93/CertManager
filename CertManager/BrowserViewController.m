//
//  BrowserViewController.m
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//
#import <Security/SecTrust.h>

#import "BrowserViewController.h"
#import "CertificateTableViewController.h"
#import "NSString+FontAwesome.h"

@interface BrowserViewController ()

@property (nonatomic) SecTrustRef trustForRequest;

@end

@implementation BrowserViewController

-(instancetype) init {
    
    id this = [super init];
    
    if(this) {
        [self setTabBarItem:[[UITabBarItem alloc] initWithTitle:@"Browser" image:[UIImage imageNamed:@"world_times"] tag:1]];
        [self.navigationItem setTitle:@"Browser"];
    }
        
    return this;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    [addressField setFont:[UIFont systemFontOfSize:17.0f]];
    [addressField setKeyboardType:UIKeyboardTypeURL];
    
    
    [self.navigationController setToolbarHidden:NO];
    
    UIWebView *web = [[UIWebView alloc] initWithFrame:screenRect];
    [self setWebView:web];
    [self.webView setDelegate:self];
    [self.webView setScalesPageToFit:YES];
    [self.view addSubview:web];
    
    
    NSDictionary *fontAwesome = @{NSFontAttributeName: [UIFont fontWithName:kFontAwesomeFamilyName size:24.0]};
    
    UIBarButtonItem *flexiableItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    
    _back = [[UIBarButtonItem alloc] initWithTitle:[NSString fontAwesomeIconStringForEnum:FAArrowLeft]
                                             style:UIBarButtonItemStylePlain
                                            target:self.webView
                                            action:@selector(goBack)];
    
    _forward = [[UIBarButtonItem alloc] initWithTitle:[NSString fontAwesomeIconStringForEnum:FAArrowRight]
                                                style:UIBarButtonItemStylePlain
                                               target:self.webView
                                               action:@selector(goForward)];
    
    [_back setTitleTextAttributes:fontAwesome forState:UIControlStateNormal];
    [_forward setTitleTextAttributes:fontAwesome forState:UIControlStateNormal];
    
    
    _stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self.webView action:@selector(stopLoading)];
    _refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self.webView action:@selector(reload)];
    

    
    NSArray *items = @[_back, flexiableItem, _stop, flexiableItem, _refresh, flexiableItem, _forward];
    self.toolbarItems = items;
    
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
    CertificateTableViewController *certTable = [[CertificateTableViewController alloc] initWithTrust:self.trustForRequest];
    UINavigationController *certNav = [[UINavigationController alloc] initWithRootViewController:certTable];
    [self.navigationController presentViewController:certNav animated:YES completion:nil];
    
}

- (void)lockIconUseSSL:(BOOL)ssl {
    if(ssl) {
        NSString *lock = [[NSString alloc] initWithString:[NSString fontAwesomeIconStringForEnum:FALock]];
        [_lockButton setTitle:lock forState:UIControlStateNormal];
        [_lockButton setTintColor:[UIColor colorWithRed:0.297 green:0.776 blue:0.302 alpha:1.000]];
        [_lockButton setEnabled:YES];
    }
    else {
        NSString *unlock = [[NSString alloc] initWithString:[NSString fontAwesomeIconStringForEnum:FAUnlockAlt]];
        [_lockButton setTitle:unlock forState:UIControlStateNormal];
        [_lockButton setTintColor:[UIColor colorWithRed:1.000 green:0.100 blue:0.169 alpha:1.000]];
        [_lockButton setEnabled:NO];
    }
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

- (void)showUserError:(NSError *)error {

    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:[error localizedDescription]
                          message:[error localizedRecoverySuggestion]
                          delegate:nil
                          cancelButtonTitle:@"Cancel"
                          otherButtonTitles:nil];
    
    [alert show];
}

#pragma mark UIWebViewDelegate

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    [NSURLConnection connectionWithRequest:request delegate:self];
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
    [self.addressField setText: [[webView.request mainDocumentURL] absoluteString]];
    [self lockIconUseSSL:[webView.request.URL.scheme isEqualToString:@"https"]];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self showUserError:error];
}

#pragma mark NSURLConnectionDelegate


-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    self.trustForRequest = challenge.protectionSpace.serverTrust;
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)pResponse {
    [connection cancel];
}

@end
