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

#import "SQVideoComposer.h"

#import "JCMoviePlayer.h"

@interface SQTrimViewController () <SAVideoRangeSliderDelegate, JCMoviePlayerDelegate>
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
    
    moviePlayer.delegate = self;
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

-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

-(BOOL)shouldAutorotate
{
    return YES;
}

-(void)refreshUI
{
    [self addRange];
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.clip.URL];
    [moviePlayer setupWithPlayerItem:item];
}

-(void)addRange
{
    [videoRangeSlider removeFromSuperview];
    videoRangeSlider = nil;
    
    videoRangeSlider = [[SAVideoRangeSlider alloc] initWithFrame:CGRectMake(20, 250, self.view.frame.size.height-40, 60) clip:self.clip];
    
    [videoRangeSlider setPopoverBubbleSize:100 height:50];
    videoRangeSlider.delegate = self;
    
    [self.view addSubview:videoRangeSlider];
}

- (IBAction)preview:(id)sender {
    if (moviePlayer.isPlaying)
    {
        [moviePlayer stop];
    }else{
        moviePlayer.range = videoRangeSlider.range;
        [moviePlayer play];
    }
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

-(void)videoRange:(SAVideoRangeSlider *)videoRange didPanToTime:(CMTime)time
{
    [moviePlayer.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

-(void)moviePlayer:(JCMoviePlayer *)player playbackStateChanged:(JCMoviePlayerState)state
{
    if (state == JCMoviePlayerStateFinished){
        [player stop];
    }
}

@end
