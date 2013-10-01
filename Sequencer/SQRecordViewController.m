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

#import "SQAlertView.h"

#define TIPRecord @"TAP TO SET FOCUS"
#define TIPRecordStop @"TAP TO SET EXPOSURE"

@interface SQRecordViewController () <SRSequencerDelegate, UIAlertViewDelegate>
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
    [timeline frameUpdated];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!sequence.captureSession)
        [sequence setupSessionWithDefaults];
    
    if (sequence.captureSession.isInterrupted || !sequence.captureSession.isRunning)
        [sequence.captureSession startRunning];
    
    
    [timeline reloadData];
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
    //File actions
    
    JCDropDownAction *import = [JCDropDownAction dropDownActionWithName:@"IMPORT" action:^{
        [self import];
    }];
    
    JCDropDownAction *close = [JCDropDownAction dropDownActionWithName:@"CLOSE" action:^{
        [self close];
    }];
    
    JCDropDownAction *save = [JCDropDownAction dropDownActionWithName:@"SAVE" action:^{
        [self save];
    }];
    
    dropDownFile.actions = [@[close, save, import] mutableCopy];
    
    //Clip actions
    
    JCDropDownAction *duplicate = [JCDropDownAction dropDownActionWithName:@"DUPLICATE" action:^{
        if ([timeline selectedClips].count == 0){
            [self showHUDWithTitle:@"SELECT CLIPS TO DUPLICATE" hideAfterDelay:YES];
            return;
        }
        
        [self showHUDWithTitle:@"DUPLICATING" hideAfterDelay:NO];
        [sequence duplicateSelectedClipsCompletion:^{
            [self hideHUD];
        }];
    }];
    
    JCDropDownAction *delete = [JCDropDownAction dropDownActionWithName:@"DELETE" action:^{
        if ([timeline selectedClips].count == 0){
            [self showHUDWithTitle:@"SELECT CLIPS TO DELETE" hideAfterDelay:YES];
            return;
        }
        
        [sequence deleteSelectedClips];
    }];
    
    JCDropDownAction *trim = [JCDropDownAction dropDownActionWithName:@"TRIM" action:^{
        
        [self trim];
    }];
    
    JCDropDownAction *join = [JCDropDownAction dropDownActionWithName:@"JOIN" action:^{
        
        [self join];
    }];
    
    dropDownClip.actions = [@[trim, join, delete, duplicate] mutableCopy];
    
    //Scale actions
    
    JCDropDownAction *flipH = [JCDropDownAction dropDownActionWithName:@"FLIP H" action:^{
        SRClip *selected = [timeline lastSelectedClip];
        if (!selected){
            [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
            return;
        }
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(-1, 1);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, 0));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDownAction *flipV = [JCDropDownAction dropDownActionWithName:@"FLIP V" action:^{
        SRClip *selected = [timeline lastSelectedClip];
        if (!selected){
            [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
            return;
        }
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0, videoTrack.naturalSize.height));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDownAction *scaleDown = [JCDropDownAction dropDownActionWithName:@"SCALE / 2" action:^{
        SRClip *selected = [timeline lastSelectedClip];
        if (!selected){
            [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
            return;
        }
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(0.5, 0.5);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(videoTrack.naturalSize.width/4, videoTrack.naturalSize.height/4));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDownAction *scaleUp = [JCDropDownAction dropDownActionWithName:@"SCALE X 2" action:^{
        SRClip *selected = [timeline lastSelectedClip];
        if (!selected){
            [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
            return;
        }
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(2, 2);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(-videoTrack.naturalSize.width/2, -videoTrack.naturalSize.height/2));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    dropDownScale.actions = [@[flipH, flipV, scaleDown, scaleUp] mutableCopy];
    
    //Time actions
    
    JCDropDownAction *retimeSlow = [JCDropDownAction dropDownActionWithName:@"RETIME SLOW" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO RETIME" hideAfterDelay:YES];
            return;
        }
        
        [self retimeClip:lastSelected multiple:2.0];
    }];
    
    JCDropDownAction *retimeFast = [JCDropDownAction dropDownActionWithName:@"RETIME FAST" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO RETIME" hideAfterDelay:YES];
            return;
        }
        
        [self retimeClip:lastSelected multiple:0.5];
    }];
    
    JCDropDownAction *retimeCustom = [JCDropDownAction dropDownActionWithName:@"SET DURATION" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO RETIME" hideAfterDelay:YES];
            return;
        }
        
        SQAlertView * alert = [[SQAlertView alloc] initWithTitle:@"NEW DURATION" message:nil delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"RETIME", nil];
        
        alert.clip = lastSelected;
        
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *textfield = [alert textFieldAtIndex:0];
        textfield.placeholder = @"SECONDS";
        textfield.keyboardAppearance = UIKeyboardAppearanceDark;
        textfield.keyboardType = UIKeyboardTypeDecimalPad;
        alert.tag = 0;
        [alert show];
    }];
    
    JCDropDownAction *retimePitch = [JCDropDownAction dropDownActionWithName:@"REPITCH NO" action:nil];
    
    __weak JCDropDownAction *weakPitch = retimePitch;
    [retimePitch setAction:^{
        rePitch = !rePitch;
        weakPitch.name = rePitch ? @"REPITCH YES" : @"REPITCH NO";
    }];
    
    dropDownTime.actions = [@[retimePitch, retimeFast, retimeSlow,retimeCustom] mutableCopy];
    
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
    
    dropDownCam.actions = [@[setFocusAction, setExposureAction] mutableCopy];
    
     if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront])
         [dropDownCam.actions addObject:flipCamera];
    
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset640x480])
        [dropDownCam.actions insertObject:session480 atIndex:0];
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset1280x720])
        [dropDownCam.actions insertObject:session720 atIndex:0];
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset1920x1080])
        [dropDownCam.actions insertObject:session1080 atIndex:0];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 0)
    {
        //retime alert
        UITextField *textfield = [alertView textFieldAtIndex:0];
        [self showHUDWithTitle:textfield.text hideAfterDelay:YES];
        
        float newDuration = [textfield.text floatValue];
        
        SQAlertView *alert = (SQAlertView *)alertView;
        SRClip *clip = alert.clip;
        
        float clipDuration = CMTimeGetSeconds(clip.positionInComposition.duration);
        
        float ratio = newDuration / clipDuration;
        
        [self retimeClip:clip multiple:ratio];
    }
    
    if (alertView.tag == 1)
    {
        //close alert
        if (buttonIndex == 1){
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

#pragma SequenceDelegate

-(void)sequencer:(SRSequencer *)sequencer isRecording:(BOOL)recording
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
    UIAlertView *closeAlert = [[UIAlertView alloc] initWithTitle:@"CLOSE PROJECT?" message:nil delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"CLOSE", nil];
    closeAlert.tag = 1;
    [closeAlert show];
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
    if (sequence.player.superview){
        [sequence hidePreview];
        [sequence stop];
    }else{
        [sequence refreshPreview];
        [sequence showPreview];
        [sequence play];
    }
}

- (void)save
{
    [self showHUDWithTitle:@"RENDERING" hideAfterDelay:NO];
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:sequence.clips toFile:outputURL withPreset:sequence.exportPreset progress:^(float progress) {
        [self showProgress:progress];
    } withCompletionHandler:^(NSError *error) {
        [self hideHUD];
        
        if (error) return;
        
        UISaveVideoAtPathToSavedPhotosAlbum([outputURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }];
}

//clip actions

- (void)retimeClip:(SRClip *)clip multiple:(float)amount
{
    SRClip *lastSelected = [timeline lastSelectedClip];
    if (!lastSelected) return;
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:lastSelected.URL options:nil];
    [self showHUDWithTitle:[NSString stringWithFormat:@"RETIMING %.2f X %.1f", CMTimeGetSeconds(asset.duration), amount] hideAfterDelay:NO];
    
    [SQClipTimeStretch stretchClip:lastSelected byAmount:amount rePitch:rePitch completion:^(SRClip *stretchedClip) {
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

- (void)trim
{
    if ([timeline selectedClips].count == 0){
        [self showHUDWithTitle:@"SELECT CLIPS TO TRIM" hideAfterDelay:YES];
        return;
    }
    
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
    if ([timeline selectedClips].count < 2){
        [self showHUDWithTitle:@"SELECT 2 OR MORE CLIPS TO JOIN" hideAfterDelay:YES];
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
    hud.mode = hide ? MBProgressHUDModeText : MBProgressHUDModeIndeterminate;
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

@end
