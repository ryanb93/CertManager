//
//  BrowserViewController.h
//  CertBrowser
//
//  Created by Ryan Burke on 25/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BrowserViewController : UIViewController<UIWebViewDelegate, NSURLConnectionDelegate>

@property (strong, atomic) UIWebView       * webView;
@property (strong, atomic) UIToolbar       * toolbar;
@property (strong, atomic) UIBarButtonItem * back;
@property (strong, atomic) UIBarButtonItem * forward;
@property (strong, atomic) UIBarButtonItem * refresh;
@property (strong, atomic) UIBarButtonItem * stop;

@property (strong, atomic) UITextField *addressField;
@property (strong, atomic) UIButton    *lockButton;

- (void)showUserError:(NSError*)error;

@end

