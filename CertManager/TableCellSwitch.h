//
//  TableCellSwitch.h
//  CertManager
//
//  Created by Ryan Burke on 23/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TableCellSwitch : UISwitch

@property (strong, atomic) NSIndexPath* indexPath;

@end

@implementation TableCellSwitch

@synthesize indexPath = _indexPath;

@end