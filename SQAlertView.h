//
//  SQAlertView.h
//  Sequencer
//
//  Created by Jon Como on 10/1/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SRClip.h"

@interface SQAlertView : UIAlertView

@property (nonatomic, strong) SRClip *clip;

@end
