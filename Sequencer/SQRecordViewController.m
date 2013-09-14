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

#import "JCActionSheetManager.h"

#import <QuartzCore/QuartzCore.h>

#import "SQClipTimeStretch.h"

#import "SQClipViewController.h"

#define TIPRecord @"TAP TO SET FOCUS"
#define TIPRecordStop @"TAP TO SET EXPOSURE"

@interface SQRecordViewController () <SRSequencerDelegate, UICollectionViewDelegateFlowLayout>
{
    SRSequencer *sequence;
    
    __weak IBOutlet UIView *viewPreview;
    __weak IBOutlet UICollectionView *collectionViewClips;
    __weak IBOutlet UILabel *labelHint;
    
    BOOL setFocus;
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
    
    [viewPreview addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)]];
    
    [self initInterface];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!sequence.captureSession)
        [sequence setupSessionWithDefaults];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [sequence.captureSession stopRunning];
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
    return UIInterfaceOrientationMaskLandscape;
}

-(void)initInterface
{
    viewPreview.layer.borderColor = [UIColor redColor].CGColor;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TIPRecord"])
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TIPRecord"];
        labelHint.text = TIPRecord;
    }else{
        [labelHint removeFromSuperview];
    }
}

#pragma SequenceDelegate

-(void)sequencer:(SRSequencer *)sequencer clipCountChanged:(int)count
{
    [collectionViewClips reloadData];
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

- (IBAction)lock:(UIButton *)sender
{
    [sequence lock];
}

-(void)viewTapped:(UITapGestureRecognizer *)tap
{
    CGPoint viewLocation = [tap locationInView:tap.view];
    
    if (!setFocus)
    {
        setFocus = YES;
        [sequence setFocusPoint:viewLocation];
    }else{
        setFocus = NO;
        [sequence setExposurePoint:viewLocation];
    }
}

- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)edit:(id)sender
{
    SQClipViewController *clipVC = [self.storyboard instantiateViewControllerWithIdentifier:@"clipVC"];
    
    SRClip *selectedClip;
    
    for (SRClip *clip in sequence.clips)
    {
        if (clip.isSelected) selectedClip = clip;
    }
    
    clipVC.clip = selectedClip;
    
    [self presentViewController:clipVC animated:YES completion:nil];
}

- (IBAction)record:(id)sender
{
    if (sequence.isRecording)
    {
        [sequence pauseRecording];
    }else{
        [sequence record];
    }

    [self progressTips];
}

- (IBAction)preview:(id)sender {
    [sequence preview];
}

- (IBAction)done:(id)sender
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Rendering";
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:sequence.clips toFile:outputURL withVideoSize:CGSizeMake(640, 480) withPreset:AVAssetExportPreset640x480 withCompletionHandler:^(NSError *error) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        if (error) return;
        
        UISaveVideoAtPathToSavedPhotosAlbum([outputURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }];
}

- (IBAction)import:(id)sender {
    
    [sequence.captureSession stopRunning];
    
    [[JCActionSheetManager sharedManager] setDelegate:self];
    [[JCActionSheetManager sharedManager] imagePickerInView:self.view onlyLibrary:YES completion:^(UIImage *image, NSURL *movieURL) {
        
        [sequence.captureSession startRunning];
        
        [sequence addClipFromURL:movieURL];
    }];
}

- (IBAction)timeStretch:(id)sender
{
    for (SRClip *clip in sequence.clips)
    {
        if (clip.isSelected)
        {
            [SQClipTimeStretch stretchClip:clip byAmount:.3 completion:^(SRClip *stretchedClip) {
                [sequence addClip:stretchedClip];
            }];
        }
    }
}

- (IBAction)deleteSelected:(id)sender {
    [sequence deleteSelectedClips];
    [collectionViewClips reloadData];
}

- (IBAction)duplicateSelected:(id)sender {
    [sequence duplicateSelectedClips];
    [collectionViewClips reloadData];
}

- (IBAction)consolidateSelected:(id)sender {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Consolidating";
    
    [sequence consolidateSelectedClipsCompletion:^(SRClip *consolidated) {
        
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        [consolidated generateThumbnailCompletion:^(BOOL success) {
            if (success)
            {
                [sequence addClip:consolidated];
                [collectionViewClips reloadData];
            }
        }];
    }];
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
    SRClip *clip = [sequence.clips objectAtIndex:indexPath.row];
    
    clip.isSelected = !clip.isSelected;
    
    [collectionViewClips reloadData];
}

@end
