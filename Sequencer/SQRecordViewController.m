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
    __weak IBOutlet JCDropDown *dropDownTime;
    __weak IBOutlet JCDropDown *dropDownFile;
    __weak IBOutlet JCDropDown *dropDownScale;
    
    
    __weak IBOutlet UIView *viewPreview;
    __weak IBOutlet SQTimeline *timeline;
    
    BOOL setFocus;
    BOOL rePitch;
}

@end

@implementation SQRecordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    sequence = [[SRSequencer alloc] initWithDelegate:self];
    sequence.timeline = timeline;
    sequence.viewPreview = viewPreview;
    
    [viewPreview addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)]];
    
    [self initInterface];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [timeline reloadData];
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

-(void)dealloc
{
    NSLog(@"Recorder Removed");
}

-(void)initInterface
{
    viewPreview.layer.borderColor = [UIColor redColor].CGColor;
    
    //File actions
    
    JCDropDownAction *close = [JCDropDownAction dropDownActionWithName:@"CLOSE" action:^{
        [self close];
    }];
    
    JCDropDownAction *save = [JCDropDownAction dropDownActionWithName:@"SAVE" action:^{
        [self save];
    }];
    
    dropDownFile.actions = [@[close, save] mutableCopy];
    
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
    
    dropDownClip.actions = [@[import, trim, join, delete, duplicate] mutableCopy];
    
    //Scale actions
    
    JCDropDownAction *flipH = [JCDropDownAction dropDownActionWithName:@"FLIP H" action:^{
        SRClip *selected = [sequence.timeline lastSelectedClip];
        if (!selected) return;
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(-1, 1);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, 0));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDownAction *flipV = [JCDropDownAction dropDownActionWithName:@"FLIP V" action:^{
        SRClip *selected = [sequence.timeline lastSelectedClip];
        if (!selected) return;
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0, videoTrack.naturalSize.height));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDownAction *scaleDown = [JCDropDownAction dropDownActionWithName:@"SCALE / 2" action:^{
        SRClip *selected = [sequence.timeline lastSelectedClip];
        if (!selected) return;
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(0.5, 0.5);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(videoTrack.naturalSize.width/4, videoTrack.naturalSize.height/4));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDownAction *scaleUp = [JCDropDownAction dropDownActionWithName:@"SCALE X 2" action:^{
        SRClip *selected = [sequence.timeline lastSelectedClip];
        if (!selected) return;
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(2, 2);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(-videoTrack.naturalSize.width/2, -videoTrack.naturalSize.height/2));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    dropDownScale.actions = [@[flipH, flipV, scaleDown, scaleUp] mutableCopy];
    
    //Time actions
    
    JCDropDownAction *retimeSlow = [JCDropDownAction dropDownActionWithName:@"RETIME SLOW" action:^{
        [self retime:2.0];
    }];
    
    JCDropDownAction *retimeFast = [JCDropDownAction dropDownActionWithName:@"RETIME FAST" action:^{
        [self retime:0.5];
    }];
    
    JCDropDownAction *retimePitch = [JCDropDownAction dropDownActionWithName:@"REPITCH NO" action:nil];
    
    __weak JCDropDownAction *weakPitch = retimePitch;
    [retimePitch setAction:^{
        rePitch = !rePitch;
        weakPitch.name = rePitch ? @"REPITCH YES" : @"REPITCH NO";
    }];
    
    dropDownTime.actions = [@[retimePitch, retimeFast, retimeSlow] mutableCopy];
    
    
    //Cam actions
    
    JCDropDownAction *setFocusAction = [JCDropDownAction dropDownActionWithName:@"SET FOCUS" action:^{
        setFocus = YES;
    }];
    
    JCDropDownAction *setExposureAction = [JCDropDownAction dropDownActionWithName:@"SET EXPOSURE" action:^{
        setFocus = NO;
    }];
    
    JCDropDownAction *session1080 = [JCDropDownAction dropDownActionWithName:@"1920 X 1080" action:^{
        [sequence setupSessionWithPreset:AVCaptureSessionPreset1920x1080 withCaptureDevice:AVCaptureDevicePositionBack withError:nil];
    }];
    
    JCDropDownAction *session720 = [JCDropDownAction dropDownActionWithName:@"1280 X 720" action:^{
        [sequence setupSessionWithPreset:AVCaptureSessionPreset1280x720 withCaptureDevice:AVCaptureDevicePositionBack withError:nil];
    }];
    
    JCDropDownAction *session480 = [JCDropDownAction dropDownActionWithName:@"640 X 480" action:^{
        [sequence setupSessionWithPreset:AVCaptureSessionPreset640x480 withCaptureDevice:AVCaptureDevicePositionBack withError:nil];
    }];
    
    JCDropDownAction *flipCamera = [JCDropDownAction dropDownActionWithName:@"FLIP" action:^{
        [sequence flipCamera];
    }];
    
    dropDownCam.actions = [@[setFocusAction, setExposureAction, flipCamera] mutableCopy];
    
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset640x480])
        [dropDownCam.actions insertObject:session480 atIndex:0];
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset1280x720])
        [dropDownCam.actions insertObject:session720 atIndex:0];
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset1920x1080])
        [dropDownCam.actions insertObject:session1080 atIndex:0];
}

#pragma SequenceDelegate

-(void)sequencer:(SRSequencer *)sequencer isRecording:(BOOL)recording
{
    viewPreview.layer.borderWidth = recording ? 3 : 0;
}

-(void)sequencer:(SRSequencer *)sequencer isZoomedIn:(BOOL)isZoomed
{
    
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

- (void)close
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

- (IBAction)preview:(id)sender
{
    [sequence preview];
}

- (void)save
{
    [self showHUDWithTitle:@"RENDERING" hideAfterDelay:NO];
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:sequence.clips toFile:outputURL withPreset:sequence.exportPreset progress:^(float progress) {
        [self showProgress:progress];
    } withCompletionHandler:^(NSError *error)
    {
        [self hideHUD];
        
        if (error) return;
        
        UISaveVideoAtPathToSavedPhotosAlbum([outputURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }];
}

//clip actions

- (void)retime:(float)amout
{
    SRClip *lastSelected = [sequence.timeline lastSelectedClip];
    
    if (!lastSelected) return;
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:lastSelected.URL options:nil];
    [self showHUDWithTitle:[NSString stringWithFormat:@"RETIMING %.2f X %.1f", CMTimeGetSeconds(asset.duration), amout] hideAfterDelay:NO];
    
    [SQClipTimeStretch stretchClip:lastSelected byAmount:amout rePitch:rePitch completion:^(SRClip *stretchedClip) {
        [self hideHUD];
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
}

- (void)duplicateSelected
{
    [sequence duplicateSelectedClips];
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
    if ([sequence.timeline selectedClips].count < 2)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [hud setMode:MBProgressHUDModeText];
        hud.labelText = @"SELECT 2 OR MORE CLIPS";
        
        [hud hide:YES afterDelay:1];
        return;
    }
    
    [self showHUDWithTitle:@"JOINING" hideAfterDelay:NO];
    
    [sequence consolidateSelectedClipsProgress:^(float progress) {
        [self showProgress:progress];
    } completion:^(SRClip *consolidated) {
        [self hideHUD];
        
        [consolidated generateThumbnailsCompletion:^(NSError *error) {
            if (error){
                [self showHUDWithTitle:@"ERROR" hideAfterDelay:YES];
                return;
            }
            
            [sequence addClip:consolidated];
        }];
    }];
}

-(void)applyTransform:(CGAffineTransform)transform toClip:(SRClip *)clip
{
    [clip setModifyLayerInstruction:^(AVMutableVideoCompositionLayerInstruction *layerInstruction, CMTimeRange range) {
        [layerInstruction setTransform:transform atTime:range.start];
    }];
    
    [self exportClip:clip completion:^{
        [clip setModifyLayerInstruction:nil];
    }];
}

-(void)exportClip:(SRClip *)clip completion:(void(^)(void))block
{
    [self showHUDWithTitle:@"EXPORTING" hideAfterDelay:NO];
    
    NSURL *exportURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:@[clip] toFile:exportURL withPreset:sequence.exportPreset progress:^(float progress) {
        [self showProgress:progress];
    } withCompletionHandler:^(NSError *error)
    {
        [self hideHUD];
        
        if (block) block();
        
        if (error)
        {
            [self showHUDWithTitle:@"ERROR" hideAfterDelay:YES];
            return;
        }
        
        SRClip *exported = [[SRClip alloc] initWithURL:exportURL];
        
        [exported generateThumbnailsCompletion:^(NSError *error) {
            [sequence addClip:exported];
        }];
    }];
}

-(void)showHUDWithTitle:(NSString *)title hideAfterDelay:(BOOL)hide
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = title;
    
    if (hide)
        [hud hide:YES afterDelay:1];
}

-(void)hideHUD
{
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}

-(void)showProgress:(float)progress
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    
    if (hud.mode != MBProgressHUDModeDeterminate)
        hud.mode = MBProgressHUDModeDeterminate;
    
    hud.progress = progress;
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *) contextInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [hud setMode:MBProgressHUDModeText];
        hud.labelText = !error ? @"SAVED TO PHOTO LIBRARY" : @"ERROR SAVING";
        
        [hud hide:YES afterDelay:2];
    });
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [sequence.clips objectAtIndex:indexPath.row];
    
    clip.isSelected = !clip.isSelected;
    
    [timeline reloadData];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [sequence.clips objectAtIndex:indexPath.row];
    
    return clip.timelineSize;
}

@end
