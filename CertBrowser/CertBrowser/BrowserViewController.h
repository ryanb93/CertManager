//
//  ViewController.h
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BrowserViewController : UIViewController<UIWebViewDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, retain) IBOutlet UIWebView       * webView;
@property (nonatomic, retain) IBOutlet UIToolbar       * toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * back;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * forward;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * refresh;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * stop;

@property (strong, nonatomic) UILabel     *pageTitle;
@property (strong, nonatomic) UITextField *addressField;
@property (strong, nonatomic) UIButton    *lockButton;

- (void)updateAddress:(NSURLRequest*)request;
- (void)informError:(NSError*)error;
@end

