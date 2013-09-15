//
//  SQTrimViewController.m
//  Sequencer
//
//  Created by Jon Como on 9/13/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQTrimViewController.h"

#import "SRClip.h"

#import "SAVideoRangeSlider.h"

#import "JCMoviePlayer.h"

@interface SQTrimViewController () <SAVideoRangeSliderDelegate>
{
    SAVideoRangeSlider *videoRangeSlider;
    __weak IBOutlet JCMoviePlayer *moviePlayer;
}

@end

@implementation SQTrimViewController

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
    
    videoRangeSlider = [[SAVideoRangeSlider alloc] initWithFrame:CGRectMake(20, 230, self.view.frame.size.height-40, 60) videoUrl:self.clip.URL];
    
    [videoRangeSlider setPopoverBubbleSize:100 height:50];
    videoRangeSlider.delegate = self;
    
    [self.view addSubview:videoRangeSlider];
}

- (IBAction)trim:(id)sender
{
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    [videoRangeSlider exportVideoToURL:outputURL completion:^(BOOL success) {
        [self.clip replaceWithFileAtURL:outputURL];
        
        [self.clip generateThumbnailCompletion:^(BOOL success) {
            [self refreshUI];
        }];
    }];
}

- (IBAction)done:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didGestureStateEndedLeftPosition:(CGFloat)leftPosition rightPosition:(CGFloat)rightPosition
{
    moviePlayer.range = CMTimeRangeMake(CMTimeMake(leftPosition * 1000, 1000), CMTimeMake((rightPosition - leftPosition) * 1000, 1000));
}

-(void)videoRange:(SAVideoRangeSlider *)videoRange didPanToTime:(CMTime)time
{
    [moviePlayer.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

@end
