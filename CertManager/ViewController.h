//
//  ViewController.h
//  CAManager
//
//  Created by Ryan Burke on 16/11/2014.
//  Copyright (c) 2014 Ryan Burke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UITableViewController<UITableViewDataSource, UITableViewDelegate>

@property (strong, atomic) NSMutableDictionary* certificates;

@property (strong, atomic) NSMutableArray* names;


@end

