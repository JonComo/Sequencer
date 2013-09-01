//
//  SQRecordViewController.m
//  Sequencer
//
//  Created by Jon Como on 8/27/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQRecordViewController.h"
#import "SRSequencer.h"

#import "MBProgressHUD.h"
#import "Macros.h"

#import <QuartzCore/QuartzCore.h>

#define TIPRecord @"TAP HERE TO RECORD"
#define TIPRecordStop @"TAP AGAIN TO STOP"

@interface SQRecordViewController () <SRSequencerDelegate, UICollectionViewDelegateFlowLayout>
{
    SRSequencer *sequence;
    __weak IBOutlet UIView *viewPreview;
    __weak IBOutlet UICollectionView *collectionViewClips;
    __weak IBOutlet UILabel *labelHint;
    
    
    NSIndexPath *selectedIndex;
}

@end

@implementation SQRecordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    sequence = [[SRSequencer alloc] initWithDelegate:self];
    sequence.collectionViewClips = collectionViewClips;
    sequence.viewPreview = viewPreview;
    
    [viewPreview addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(recordTapped)]];
    
    [self initInterface];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!sequence.captureSession)
        [sequence setupSessionWithDefaults];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc
{
    NSLog(@"Recorder Removed");
}

-(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

-(void)initInterface
{
    viewPreview.layer.borderColor = [UIColor redColor].CGColor;
    
//    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TIPRecord"])
//    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TIPRecord"];
        labelHint.text = TIPRecord;
//    }else{
//        [labelHint removeFromSuperview];
//    }
}

#pragma SequenceDelegate

-(void)sequencer:(SRSequencer *)sequencer clipCountChanged:(int)count
{
    
}

-(void)sequencer:(SRSequencer *)sequencer isRecording:(BOOL)recording
{
    viewPreview.layer.borderWidth = recording ? 3 : 0;
}

#pragma UIChanges

-(void)progressTips
{
    if ([labelHint.text isEqualToString:TIPRecord])
    {
        [UIView animateWithDuration:0.3 animations:^{
            labelHint.alpha = 0;
        } completion:^(BOOL finished) {
            labelHint.text = TIPRecordStop;
            [UIView animateWithDuration:0.3 animations:^{
                labelHint.alpha = 1;
            }];
        }];
    }else if ([labelHint.text isEqualToString:TIPRecordStop])
    {
        [labelHint removeFromSuperview];
    }
}

#pragma UIActions

-(void)recordTapped
{
    if (sequence.isRecording)
    {
        [sequence pauseRecording];
    }else{
        [sequence record];
    }
    
    [self progressTips];
}

- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)preview:(id)sender {
    if (sequence.moviePlayerController.playbackState != MPMoviePlaybackStatePlaying)
    {
        [sequence previewOverView:viewPreview];
    }else{
        [sequence stopPreview];
    }
}

- (IBAction)done:(id)sender
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Rendering";
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeRecordingToFile:outputURL withVideoSize:CGSizeMake(500, 500) withPreset:AVAssetExportPreset640x480 withCompletionHandler:^(NSError *error) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        if (error) return;
        
        UISaveVideoAtPathToSavedPhotosAlbum([outputURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }];
}

- (IBAction)addClip:(id)sender
{
    
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *) contextInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [hud setMode:MBProgressHUDModeText];
        hud.labelText = @"Saved to Photo Library";
        
        [hud hide:YES afterDelay:2];
    });
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    //[self highlightIndexPath:indexPath];
    [sequence duplicateClipAtIndex:indexPath.row];
}

-(void)highlightIndexPath:(NSIndexPath *)indexPath
{
    selectedIndex = indexPath;
    
    UICollectionViewCell *cell = [collectionViewClips cellForItemAtIndexPath:indexPath];
    
    cell.layer.borderColor = [UIColor orangeColor].CGColor;
    cell.layer.borderWidth = 2;
}

@end
