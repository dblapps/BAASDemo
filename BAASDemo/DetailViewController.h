//
//  DetailViewController.h
//  BAASDemo
//
//  Created by David Levi on 1/31/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Notes.h"

@class DetailViewController;
@protocol DetailViewControllerDelegate
- (void) noteTextChanged:(Note*)note;
@end

@interface DetailViewController : UIViewController

@property (weak,nonatomic) id<DetailViewControllerDelegate> delegate;

@property (strong,nonatomic) Note* note;

@end

