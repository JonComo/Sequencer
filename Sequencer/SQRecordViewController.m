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

#import "SQClipCell.h"

#import "SQTrimViewController.h"

#import "SQTimeline.h"

#import "JCDropDown.h"

#define TIPRecord @"TAP TO SET FOCUS"
#define TIPRecordStop @"TAP TO SET EXPOSURE"

@interface SQRecordViewController () <SRSequencerDelegate, UICollectionViewDelegateFlowLayout>
{
    SRSequencer *sequence;
    
    __weak IBOutlet JCDropDown *dropDownClip;
    __weak IBOutlet JCDropDown *dropDownCam;
    
    __weak IBOutlet UIView *viewPreview;
    __weak IBOutlet SQTimeline *collectionViewClips;
    
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

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [collectionViewClips reloadData];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!sequence.captureSession)
        [sequence setupSessionWithDefaults];
    
    if (sequence.captureSession.isInterrupted || !sequence.captureSession.isRunning)
        [sequence.captureSession startRunning];
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
    
    //Clip actions
    
    JCDropDownAction *duplicate = [JCDropDownAction dropDownActionWithName:@"DUPLICATE" action:^{
        [self duplicateSelected];
    }];
    
    JCDropDownAction *delete = [JCDropDownAction dropDownActionWithName:@"DELETE" action:^{
        [self deleteSelected];
    }];
    
    JCDropDownAction *trim = [JCDropDownAction dropDownActionWithName:@"TRIM" action:^{
        [self trim];
    }];
    
    JCDropDownAction *join = [JCDropDownAction dropDownActionWithName:@"JOIN" action:^{
        [self join];
    }];
    
    JCDropDownAction *import = [JCDropDownAction dropDownActionWithName:@"IMPORT" action:^{
        [self import];
    }];
    
    JCDropDownAction *retimeSlow = [JCDropDownAction dropDownActionWithName:@"RETIME SLOW" action:^{
        [self retime:2.0];
    }];
    
    JCDropDownAction *retimeFast = [JCDropDownAction dropDownActionWithName:@"RETIME FAST" action:^{
        [self retime:0.5];
    }];
    
    dropDownClip.actions = [@[import, retimeSlow, retimeFast, trim, join, delete, duplicate] mutableCopy];
    
    
    //Cam actions
    
    JCDropDownAction *setFocusAction = [JCDropDownAction dropDownActionWithName:@"SET FOCUS" action:^{
        setFocus = YES;
    }];
    
    JCDropDownAction *setExposureAction = [JCDropDownAction dropDownActionWithName:@"SET EXPOSURE" action:^{
        setFocus = NO;
    }];
    
    dropDownCam.actions = [@[setFocusAction, setExposureAction] mutableCopy];
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

#pragma UIActions

-(void)viewTapped:(UITapGestureRecognizer *)tap
{
    CGPoint viewLocation = [tap locationInView:tap.view];
    
    if (setFocus)
    {
        [sequence setFocusPoint:viewLocation];
    }else{
        [sequence setExposurePoint:viewLocation];
    }
}

- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)record:(id)sender
{
    if (sequence.isRecording)
    {
        [sequence pauseRecording];
    }else{
        [sequence record];
    }
}

- (IBAction)preview:(id)sender {
    [sequence preview];
}

- (IBAction)done:(id)sender
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"RENDERING";
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:sequence.clips toFile:outputURL withVideoSize:CGSizeMake(640, 480) withPreset:AVAssetExportPreset640x480 withCompletionHandler:^(NSError *error) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        
        if (error) return;
        
        UISaveVideoAtPathToSavedPhotosAlbum([outputURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }];
}

//clip actions

- (void)retime:(float)amout
{
    SRClip *lastSelected;
    
    for (SRClip *clip in sequence.clips)
    {
        if (clip.isSelected)
        {
            lastSelected = clip;
        }
    }
    
    if (!lastSelected) return;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = [NSString stringWithFormat:@"RETIMING %.2f X %.1f", CMTimeGetSeconds(lastSelected.asset.duration), amout];
    
    [SQClipTimeStretch stretchClip:lastSelected byAmount:amout completion:^(SRClip *stretchedClip) {
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        [sequence addClip:stretchedClip];
    }];
}

- (void)import
{
    
    [sequence.captureSession stopRunning];
    
    [[JCActionSheetManager sharedManager] setDelegate:self];
    [[JCActionSheetManager sharedManager] imagePickerInView:self.view onlyLibrary:YES completion:^(UIImage *image, NSURL *movieURL) {
        
        [sequence.captureSession startRunning];
        
        [sequence addClipFromURL:movieURL];
    }];
}

- (void)deleteSelected
{
    [sequence deleteSelectedClips];
    [collectionViewClips reloadData];
}

- (void)duplicateSelected
{
    [sequence duplicateSelectedClips];
    [collectionViewClips reloadData];
}

- (void)trim
{
    SQTrimViewController *trimVC = [self.storyboard instantiateViewControllerWithIdentifier:@"trimVC"];
    
    SRClip *selectedClip;
    
    for (SRClip *clip in sequence.clips){
        if (clip.isSelected) selectedClip = clip;
    }
    
    if (!selectedClip) return;
    
    trimVC.clip = selectedClip;
    
    trimVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self presentViewController:trimVC animated:YES completion:nil];
}

- (void)join
{
    SRClip *selectedClip;
    
    for (SRClip *clip in sequence.clips){
        if (clip.isSelected) selectedClip = clip;
    }
    
    if (!selectedClip) return;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"CONSOLIDATING";
    
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
        hud.labelText = @"SAVED TO PHOTO LIBRARY";
        
        [hud hide:YES afterDelay:2];
    });
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [sequence.clips objectAtIndex:indexPath.row];
    
    clip.isSelected = !clip.isSelected;
    
    [collectionViewClips reloadData];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [sequence.clips objectAtIndex:indexPath.row];
    
    return [clip timelineSize];
}

@end
