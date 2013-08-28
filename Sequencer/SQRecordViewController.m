//
//  SQRecordViewController.m
//  Sequencer
//
//  Created by Jon Como on 8/27/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQRecordViewController.h"
#import "SRSequencer.h"

@interface SQRecordViewController () <SRSequencerDelegate>
{
    SRSequencer *sequence;
    __weak IBOutlet UIView *viewPreview;
}

@end

@implementation SQRecordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    sequence = [[SRSequencer alloc] initWithDelegate:self];
    sequence.viewPreview = viewPreview;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [sequence setupSessionWithDefaults];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [sequence record];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [sequence pauseRecording];
}

#pragma SequenceDelegate

-(void)sequencer:(SRSequencer *)sequencer clipCountChanged:(int)count
{
    
}

@end
