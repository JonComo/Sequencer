//
//  SQClipViewController.m
//  Sequencer
//
//  Created by Jon Como on 9/13/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipViewController.h"

#import "SRClip.h"

#import "SAVideoRangeSlider.h"

#import "JCMoviePlayer.h"

@interface SQClipViewController () <SAVideoRangeSliderDelegate>
{
    SAVideoRangeSlider *videoRangeSlider;
    __weak IBOutlet JCMoviePlayer *moviePlayer;
}

@end

@implementation SQClipViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self refreshUI];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)refreshUI
{
    moviePlayer.URL = self.clip.URL;
    
    [self addRange];
}

-(void)addRange
{
    [videoRangeSlider removeFromSuperview];
    videoRangeSlider = nil;
    
    videoRangeSlider = [[SAVideoRangeSlider alloc] initWithFrame:CGRectMake(10, 220, self.view.frame.size.height-20, 70) videoUrl:self.clip.URL];
    
    [videoRangeSlider setPopoverBubbleSize:200 height:100];
    videoRangeSlider.delegate = self;
    
    [self.view addSubview:videoRangeSlider];
}

- (IBAction)trim:(id)sender
{
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    [videoRangeSlider exportVideoToURL:outputURL completion:^(BOOL success) {
        [self.clip replaceWithFileAtURL:outputURL];
        
        [self refreshUI];
    }];
}

- (IBAction)done:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
