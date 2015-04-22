//
//  ViewController.h
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BrowserViewController : UIViewController<UIWebViewDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, retain) UIWebView       * webView;
@property (nonatomic, retain) UIToolbar       * toolbar;
@property (nonatomic, retain) UIBarButtonItem * back;
@property (nonatomic, retain) UIBarButtonItem * forward;
@property (nonatomic, retain) UIBarButtonItem * refresh;
@property (nonatomic, retain) UIBarButtonItem * stop;

@property (strong, nonatomic) UILabel     *pageTitle;
@property (strong, nonatomic) UITextField *addressField;
@property (strong, nonatomic) UIButton    *lockButton;

- (void)updateAddress:(NSURLRequest*)request;
- (void)informError:(NSError*)error;
@end

