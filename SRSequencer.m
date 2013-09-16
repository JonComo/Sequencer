//
// Copyright (c) 2013 Jon Como
//

#import "SRSequencer.h"

#import "AVAssetStitcher.h"
#import <MobileCoreServices/UTCoreTypes.h>

#import "SQClipCell.h"
#import "LXReorderableCollectionViewFlowLayout.h"

#import "SQVideoComposer.h"

#import "SQTimeline.h"

#import "Macros.h"

// Maximum and minumum length to record in seconds
#define MAX_RECORDING_LENGTH 600.0
#define MIN_RECORDING_LENGTH 1.0

// Set the recording preset to use
#define CAPTURE_SESSION_PRESET AVCaptureSessionPreset640x480

// Set the input device to use when first starting
#define INITIAL_CAPTURE_DEVICE_POSITION AVCaptureDevicePositionBack

// Set the initial torch mode
#define INITIAL_TORCH_MODE AVCaptureTorchModeOff

@interface SRSequencer (Private) <UICollectionViewDataSource>

- (void)startNotificationObservers;
- (void)endNotificationObservers;

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position;
- (AVCaptureDevice *) audioDevice;

- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

- (void)cleanTemporaryFiles;

@end

@implementation SRSequencer
{
    bool setupComplete;
    
    AVCaptureDeviceInput *videoInput;
    AVCaptureDeviceInput *audioInput;
    
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    AVCaptureMovieFileOutput *movieFileOutput;
    
    AVCaptureVideoOrientation orientation;
    
    id deviceConnectedObserver;
    id deviceDisconnectedObserver;
    id deviceOrientationDidChangeObserver;
    
    AVPlayerLayer *playLayer;
    
    int currentRecordingSegment;
    
    CMTime currentFinalDurration;
    int inFlightWrites;
    
    NSTimer *timerStop;
    
    SRClip *clipRecording;
    
    BOOL hadSetFocusPoint;
    BOOL hadSetExposurePoint;
    
    CGSize videoSize;
    NSString *exportPreset;
}

- (id)initWithDelegate:(id<SRSequencerDelegate>)managerDelegate
{
    if (self = [super init])
    {
        _delegate = managerDelegate;
        
        setupComplete = NO;
        
        _clips = [NSMutableArray array];
        
        currentRecordingSegment = 0;
        _isPaused = NO;
        inFlightWrites = 0;
        
        movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        
        _asyncErrorHandler = ^(NSError *error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:error.domain delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        };
        
        _lockExposure = NO;
        _lockFocus = NO;
        
        _viewForExposurePoint = [self targetViewWithText:@"EXPOSURE" size:CGSizeMake(70, 70)];
        _viewForFocusPoint = [self targetViewWithText:@"FOCUS" size:CGSizeMake(70, 70)];
        
        [self startNotificationObservers];
    }
    
    return self;
}

- (void)setupSessionWithPreset:(NSString *)preset withCaptureDevice:(AVCaptureDevicePosition)cd withError:(NSError **)error
{
    if(setupComplete){
        //*error = [NSError errorWithDomain:@"Setup session already complete." code:102 userInfo:nil];
        //return;
    }
    
    if (_captureSession)
    {       
        [_captureSession stopRunning];
        [_captureSession removeInput:videoInput];
        [_captureSession removeOutput:movieFileOutput];
    }
    
    setupComplete = YES;
    
	AVCaptureDevice *captureDevice = [self cameraWithPosition:cd];
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = preset;
    
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:nil];
    
    [videoInput.device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:NULL];
    [videoInput.device addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self lock];
    
    if([_captureSession canAddInput:videoInput])
    {
        [_captureSession addInput:videoInput];
    }else{
        *error = [NSError errorWithDomain:@"Error setting video input." code:101 userInfo:nil];
        return;
    }
    
    audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if([_captureSession canAddInput:audioInput])
    {
        [_captureSession addInput:audioInput];
    }else{
        *error = [NSError errorWithDomain:@"Error setting audio input." code:101 userInfo:nil];
        return;
    }
    
    if([_captureSession canAddOutput:movieFileOutput])
    {
        [_captureSession addOutput:movieFileOutput];
    }else{
        *error = [NSError errorWithDomain:@"Error setting file output." code:101 userInfo:nil];
        return;
    }
    
    if ([preset isEqualToString:AVCaptureSessionPreset1920x1080])
    {
        videoSize = CGSizeMake(1920, 1080);
        exportPreset = AVAssetExportPreset1920x1080;
    }else if ([preset isEqualToString:AVCaptureSessionPreset1280x720])
    {
        videoSize = CGSizeMake(1280, 720);
        exportPreset = AVAssetExportPreset1280x720;
    }else if ([preset isEqualToString:AVCaptureSessionPreset640x480])
    {
        videoSize = CGSizeMake(640, 480);
        exportPreset = AVAssetExportPreset640x480;
    }
    
    [self setupPreviewLayer];
}

-(void)setupSessionWithDefaults
{
    NSError *error;
    [self setupSessionWithPreset:CAPTURE_SESSION_PRESET withCaptureDevice:INITIAL_CAPTURE_DEVICE_POSITION withError:&error];
    
    if(error){
        self.asyncErrorHandler(error);
        return;
    }
}

-(UIView *)targetViewWithText:(NSString *)text size:(CGSize)size
{
    UIView *targetView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    
    [targetView setBackgroundColor:[UIColor clearColor]];
    targetView.layer.borderColor = [UIColor whiteColor].CGColor;
    targetView.layer.borderWidth = 2;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(4, size.height - 20, size.width - 8, 20)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setTextColor:[UIColor whiteColor]];
    [label setFont:[UIFont systemFontOfSize:16]];
    [label setMinimumScaleFactor:0.1];
    
    [label setAdjustsFontSizeToFitWidth:YES];
    
    [label setTextAlignment:NSTextAlignmentCenter];
    label.text = text;
    
    [targetView addSubview:label];
    
    [targetView setUserInteractionEnabled:NO];
    
    return targetView;
}

- (void)dealloc
{
    [_captureSession removeOutput:movieFileOutput];
    
    [self endNotificationObservers];
    
    NSLog(@"Sequencer out");
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

-(void)setupPreviewLayer
{
    if (captureVideoPreviewLayer)
    {
        [captureVideoPreviewLayer removeFromSuperlayer];
        captureVideoPreviewLayer.session = nil;
        captureVideoPreviewLayer = nil;
    }
    
    captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    
    self.viewPreview.layer.masksToBounds = NO;
    captureVideoPreviewLayer.frame = self.viewPreview.bounds;
    
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self.viewPreview.layer insertSublayer:captureVideoPreviewLayer below:self.viewPreview.layer.sublayers[0]];
    
    [[captureVideoPreviewLayer connection] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
    
    // Start the session. This is done asychronously because startRunning doesn't return until the session is running.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.captureSession startRunning];
    });
}

-(void)setViewPreview:(UIView *)viewPreview
{
    _viewPreview = viewPreview;
}

-(void)flipCamera
{
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    AVCaptureDevicePosition currentCameraPosition = [[videoInput device] position];
    
    if (currentCameraPosition == AVCaptureDevicePositionBack)
    {
        currentCameraPosition = AVCaptureDevicePositionFront;
    }else{
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *backFacingCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == currentCameraPosition){
			backFacingCamera = device;
		}
	}
    
    newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];
    
    if (newVideoInput != nil)
    {
        [_captureSession beginConfiguration];
        
        [_captureSession removeInput:videoInput];
        
        if ([_captureSession canAddInput:newVideoInput])
        {
            [_captureSession addInput:newVideoInput];
            videoInput = newVideoInput;
            
            if(currentCameraPosition == AVCaptureDevicePositionBack)
            {
                
                //[[captureVideoPreviewLayer connection] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
            }else{
                
                
                //[[captureVideoPreviewLayer connection] setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
            }
        }
        else
        {
            [_captureSession addInput:videoInput];
        }
        
        //captureSession.sessionPreset = oriPreset;
        [_captureSession commitConfiguration];
    }
}

- (void)pauseRecording
{
    if (!self.isRecording) return;
    
    float currentLength = CMTimeGetSeconds(movieFileOutput.recordedDuration);
    
    if (currentLength == 0){
        if (!timerStop)
            timerStop = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(pauseRecording) userInfo:nil repeats:YES];
        
        return;
    }
    
    [timerStop invalidate];
    timerStop = nil;
    
    _isPaused = YES;
    
    self.isRecording = NO;
    [movieFileOutput stopRecording];
    
    if([self.delegate respondsToSelector:@selector(sequencer:isRecording:)])
        [self.delegate sequencer:self isRecording:NO];
    
    currentFinalDurration = CMTimeAdd(currentFinalDurration, movieFileOutput.recordedDuration);
}

- (void)record
{
    if (self.isRecording) return;
    if (![self.captureSession isRunning]) return;
    if (inFlightWrites != 0) return;
    if (movieFileOutput.isRecording) return;
    
    _isPaused = NO;
    self.isRecording = YES;
    
    NSURL *outputFileURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    clipRecording = [[SRClip alloc] initWithURL:outputFileURL];
    
    
    if([videoInput device].position == AVCaptureDevicePositionBack)
    {
        if ([[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] isVideoMirrored])
            [[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoMirrored:NO];
        
        [[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
    }else{
        if (![[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] isVideoMirrored])
            [[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoMirrored:YES];
        
        [[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
    }
    
    [movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
}

-(void)preview
{
    if (playLayer){
        [self stopPreview];
        return;
    }
    
    [self.captureSession stopRunning];
    
    AVAssetStitcher *combined = [self stitcherFromClips:self.clips];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:combined.composition];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopPreview) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    
    
    playLayer = [AVPlayerLayer layer];
    
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    
    playLayer.player = player;
    
    [player play];
    
    playLayer.frame = CGRectMake(0, 0, self.viewPreview.bounds.size.width, self.viewPreview.bounds.size.height);
    [self.viewPreview.layer addSublayer:playLayer];
}

-(void)stopPreview
{
    [playLayer removeFromSuperlayer];
    playLayer = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [self.captureSession startRunning];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate implementation

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    inFlightWrites++;
    
    NSLog(@"AVCaptureMovieOutput started writing to file");
    
    if([self.delegate respondsToSelector:@selector(sequencer:isRecording:)])
        [self.delegate sequencer:self isRecording:YES];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"AVCaptureMovieOutput finished writing");
    
    if (error)
    {
        if(self.asyncErrorHandler){
            self.asyncErrorHandler(error);
        }else{
            NSLog(@"Error capturing output: %@", error);
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [clipRecording generateThumbnailsCompletion:^(NSError *error) {
            if (!error)
            {
                [self addClip:clipRecording];
                
                if ([self.delegate respondsToSelector:@selector(sequencer:clipCountChanged:)])
                    [self.delegate sequencer:self clipCountChanged:self.clips.count];
            }
            
            clipRecording = nil;
            
            inFlightWrites--;
            self.isRecording = NO;
            
            NSLog(@"Can record");
        }];
    });
}

- (void)reset
{
    if (movieFileOutput.isRecording){
        [self pauseRecording];
    }
    
    _isPaused = NO;
    
    for (int i = 0; i<self.clips.count; i++){
        SRClip *clip = self.clips[i];
        [self removeClip:clip];
    }
    
    if ([self.delegate respondsToSelector:@selector(sequencer:clipCountChanged:)])
        [self.delegate sequencer:self clipCountChanged:self.clips.count];
    
    [self.collectionViewClips reloadData];
}

-(AVAssetStitcher *)stitcherFromClips:(NSArray *)clipsCombining
{
    AVAssetStitcher *stitcher = [[AVAssetStitcher alloc] initWithOutputSize:videoSize];
    
    __block NSError *stitcherError;
    
    [clipsCombining enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        SRClip *clip = (SRClip *)obj;
        AVURLAsset *asset = [AVURLAsset assetWithURL:clip.URL];
        
        [stitcher addAsset:asset withTransform:^CGAffineTransform(AVAssetTrack *videoTrack) {
            
            //
            // The following transform is applied to each video track. It changes the size of the
            // video so it fits within the output size and stays at the correct aspect ratio.
            //
            
            //return CGAffineTransformIdentity;
            /*
             CGFloat ratioW = videoSize.width / videoTrack.naturalSize.width;
             CGFloat ratioH = videoSize.height / videoTrack.naturalSize.height;
             if(ratioW < ratioH)
             {
             // When the ratios are larger than one, we must flip the translation.
             float neg = (ratioH > 1.0) ? 1.0 : -1.0;
             CGFloat diffH = videoTrack.naturalSize.height - (videoTrack.naturalSize.height * ratioH);
             return CGAffineTransformConcat( CGAffineTransformMakeTranslation(0, neg*diffH/2.0), CGAffineTransformMakeScale(ratioH, ratioH) );
             }
             else
             {
             // When the ratios are larger than one, we must flip the translation.
             float neg = (ratioW > 1.0) ? 1.0 : -1.0;
             CGFloat diffW = videoTrack.naturalSize.width - (videoTrack.naturalSize.width * ratioW);
             return CGAffineTransformConcat( CGAffineTransformMakeTranslation(neg*diffW/2.0, 0), CGAffineTransformMakeScale(ratioW, ratioW) );
             }
             */
            
            return asset.preferredTransform;
            
        } withErrorHandler:^(NSError *error) {
            
            stitcherError = error;
            
        }];
        
    }];
    
    if(stitcherError){
        return nil;
    }
    
    return stitcher;
}

- (void)finalizeClips:(NSArray *)clipsCombining toFile:(NSURL *)finalVideoLocationURL withCompletionHandler:(ErrorHandlingBlock)completionHandler
{
    //[self reset];
    
    if (clipsCombining.count == 0)
    {
        completionHandler([NSError errorWithDomain:@"No clips to export" code:104 userInfo:nil]);
        return;
    }
    
    NSError *error;
    if([finalVideoLocationURL checkResourceIsReachableAndReturnError:&error]){
        completionHandler([NSError errorWithDomain:@"Output file already exists." code:104 userInfo:nil]);
        return;
    }
    
    if(inFlightWrites != 0){
        completionHandler([NSError errorWithDomain:@"Can't finalize recording unless all sub-recorings are finished." code:106 userInfo:nil]);
        return;
    }
    
    /*
    
    SQVideoComposer *videoComposer = [SQVideoComposer new];
    
    [videoComposer exportClips:clipsCombining toURL:finalVideoLocationURL withPreset:preset withCompletionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(error){
                completionHandler(error);
            }else{
                completionHandler(nil);
            }
        });
    }]; */
    
    
    
    AVAssetStitcher *stitcher = [self stitcherFromClips:clipsCombining];
    
    [stitcher exportTo:finalVideoLocationURL withPreset:exportPreset withCompletionHandler:^(NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(error){
                completionHandler(error);
            }else{
                //[self cleanTemporaryFiles];
                //[temporaryFileURLs removeAllObjects];
                
                completionHandler(nil);
            }
        });
        
    }];
}

#pragma mark - Observer start and stop

- (void)startNotificationObservers
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    //
    // Reconnect to a device that was previously being used
    //
    
    deviceConnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        
        AVCaptureDevice *device = [notification object];
        
        NSString *deviceMediaType = nil;
        
        if ([device hasMediaType:AVMediaTypeAudio])
        {
            deviceMediaType = AVMediaTypeAudio;
        }
        else if ([device hasMediaType:AVMediaTypeVideo])
        {
            deviceMediaType = AVMediaTypeVideo;
        }
        
        if (deviceMediaType != nil)
        {
            [_captureSession.inputs enumerateObjectsUsingBlock:^(AVCaptureDeviceInput *input, NSUInteger idx, BOOL *stop) {
            
                if ([input.device hasMediaType:deviceMediaType])
                {
                    NSError	*error;
                    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
                    if ([_captureSession canAddInput:deviceInput])
                    {
                        [_captureSession addInput:deviceInput];
                    }
                    
                    if(error)
                    {
                        if(self.asyncErrorHandler)
                        {
                            self.asyncErrorHandler(error);
                        }else{
                            NSLog(@"Error reconnecting device input: %@", error);
                        }
                    }
                    
                    *stop = YES;
                }
            
            }];
        }
        
    }];
    
    //
    // Disable inputs from removed devices that are being used
    //
    
    deviceDisconnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
        
        AVCaptureDevice *device = [notification object];
        
        if ([device hasMediaType:AVMediaTypeAudio])
        {
            [_captureSession removeInput:audioInput];
            audioInput = nil;
        }
        else if ([device hasMediaType:AVMediaTypeVideo])
        {
            [_captureSession removeInput:videoInput];
            videoInput = nil;
        }
        
    }];
    
    //
    // Track orientation changes. Note: This are pushed into the Quicktime video data and needs
    // to be used at decoding time to transform the video into the correct orientation.
    //
    
    /*
    
    orientation = AVCaptureVideoOrientationPortrait;
    deviceOrientationDidChangeObserver = [notificationCenter addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        
        switch ([[UIDevice currentDevice] orientation])
        {
            case UIDeviceOrientationLandscapeLeft:
                orientation = AVCaptureVideoOrientationLandscapeRight;
                
                [[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                
                break;
            default:
                orientation = AVCaptureVideoOrientationLandscapeLeft;
                
                [[movieFileOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                break;
        }
        
        [[captureVideoPreviewLayer connection] setVideoOrientation:orientation];
    }];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
     
     */
}

- (void)endNotificationObservers
{
    //[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:deviceConnectedObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:deviceDisconnectedObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:deviceOrientationDidChangeObserver];
}

#pragma mark - Device finding methods

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position
{
    __block AVCaptureDevice *foundDevice = nil;
    
    [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] enumerateObjectsUsingBlock:^(AVCaptureDevice *device, NSUInteger idx, BOOL *stop) {
        
        if (device.position == position)
        {
            foundDevice = device;
            *stop = YES;
        }

    }];

    return foundDevice;
}

- (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if (devices.count > 0)
    {
        return devices[0];
    }
    return nil;
}

#pragma mark - Connection finding method

- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
    __block AVCaptureConnection *foundConnection = nil;
    
    [connections enumerateObjectsUsingBlock:^(AVCaptureConnection *connection, NSUInteger idx, BOOL *connectionStop) {
        
        [connection.inputPorts enumerateObjectsUsingBlock:^(AVCaptureInputPort *port, NSUInteger idx, BOOL *portStop) {
            
            if( [port.mediaType isEqual:mediaType] )
            {
				foundConnection = connection;
                
                *connectionStop = YES;
                *portStop = YES;
			}
            
        }];
        
    }];
    
	return foundConnection;
}

#pragma  mark - Temporary file handling functions

- (void)cleanTemporaryFiles
{
    for(SRClip *clip in self.clips)
    {
        [[NSFileManager defaultManager] removeItemAtURL:clip.URL error:nil];
    }
    
    [self.clips removeAllObjects];
    
    if ([self.delegate respondsToSelector:@selector(sequencer:clipCountChanged:)])
        [self.delegate sequencer:self clipCountChanged:self.clips.count];
}

#pragma UICollectionViewDataSourceDelegate

-(void)setCollectionViewClips:(SQTimeline *)collectionViewClips
{
    collectionViewClips.dataSource = self;
    
    LXReorderableCollectionViewFlowLayout *layout = [[LXReorderableCollectionViewFlowLayout alloc] init];
    [layout setMinimumInteritemSpacing:10];
    [layout setMinimumLineSpacing:10];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    [collectionViewClips setCollectionViewLayout:layout];
    
    [collectionViewClips registerNib:[UINib nibWithNibName:@"clipCell" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:@"clipCell"];
    
    _collectionViewClips = collectionViewClips;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SQClipCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"clipCell" forIndexPath:indexPath];
    
    SRClip *clip = [self.clips objectAtIndex:indexPath.row];
    
    cell.clip = clip;
    
    return cell;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.clips.count;
}

- (void)collectionView:(UICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)fromIndexPath didMoveToIndexPath:(NSIndexPath *)toIndexPath
{
    SRClip *clip = [self.clips objectAtIndex:fromIndexPath.item];
    [self.clips removeObjectAtIndex:fromIndexPath.item];
    [self.clips insertObject:clip atIndex:toIndexPath.item];
}

#pragma Clip Operations

-(SRClip *)lastSelectedClip
{
    SRClip *selectedClip;
    
    for (SRClip *clip in self.clips)
    {
        if (clip.isSelected)
            selectedClip = clip;
    }
    
    return selectedClip;
}

-(NSArray *)selectedClips
{
    NSMutableArray *clips = [NSMutableArray array];
    
    for (SRClip *clip in self.clips)
    {
        if (clip.isSelected)
            [clips addObject:clip];
    }
    
    return clips;
}

-(void)addClip:(SRClip *)clip
{
    NSUInteger index = [self indexToInsert];
    NSLog(@"Index: %i", index);
    [self.clips insertObject:clip atIndex:index];
    
    [self.collectionViewClips reloadData];
    [self.collectionViewClips scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:MAX(0,self.clips.count-1) inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
}

-(NSUInteger)indexToInsert
{
//    NSInteger index = [self.clips count];
//    
//    for (SRClip *clip in self.clips)
//    {
//        if (clip.insertAfter)
//        {
//            NSUInteger indexOfCell = [self.clips indexOfObject:clip];
//            index = indexOfCell + 1;
//            break;
//        }else if (clip.insertBefore)
//        {
//            NSUInteger indexOfCell = [self.clips indexOfObject:clip];
//            index = indexOfCell - 1;
//            break;
//        }
//    }
//    
//    if (index < 0) index = 0;
//    if (index > self.clips.count) index = self.clips.count;
//    
//    return index;
    
    __block NSInteger index = [self.clips count];
    
    [self.clips enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SRClip *clip = obj;
        
        if (clip.isSelected) {
            index = idx + 1;
            *stop = YES;
        }
    }];
    
    if (index < 0) index = 0;
    if (index > self.clips.count) index = self.clips.count;
    
    return index;
}

-(void)deleteSelectedClips
{
    NSArray *selected = [self selectedClips];
    
    for (SRClip *clip in selected)
        [self removeClip:clip];
    
    [self.collectionViewClips reloadData];
}

-(void)duplicateSelectedClips
{
    NSArray *selected = [self selectedClips];
    
    for (SRClip *clip in selected){
        SRClip *newClip = [clip duplicate];
        [self addClip:newClip];
    }
}

-(void)consolidateSelectedClipsCompletion:(void (^)(SRClip *))consolidateHandler
{
    NSMutableArray *clipsToCombine = [NSMutableArray array];
    
    for (SRClip *clip in self.clips)
    {
        if (clip.isSelected)
            [clipsToCombine addObject:clip];
    }
    
    NSURL *exportURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [self finalizeClips:clipsToCombine toFile:exportURL withCompletionHandler:^(NSError *error) {
        if (!error)
        {
            SRClip *newClip = [[SRClip alloc] initWithURL:exportURL];
            if (consolidateHandler) consolidateHandler(newClip);
        }else{
            if (consolidateHandler) consolidateHandler(nil);
        }
    }];
}

-(void)removeClip:(SRClip *)clip
{
    [clip remove];
    [self.clips removeObject:clip];
}

-(void)addClipFromURL:(NSURL *)url
{
    SRClip *newClip = [[SRClip alloc] initWithURL:url];
    
    [newClip generateThumbnailsCompletion:^(NSError *error) {
        if (!error)
            [self addClip:newClip];
    }];
}

#pragma Camera operations

-(void)setExposureMode:(AVCaptureExposureMode)mode
{
    if (![videoInput.device isExposureModeSupported:mode]) return;
    
    [self configureDevice:^{
        [videoInput.device setExposureMode:mode];
        hadSetExposurePoint = YES;
    }];
}

-(void)setFocusMode:(AVCaptureFocusMode)mode
{
    if (![videoInput.device isFocusModeSupported:mode]) return;
    
    [self configureDevice:^{
        [videoInput.device setFocusMode:mode];
        hadSetFocusPoint = YES;
    }];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"adjustingExposure"])
    {
        if (!videoInput.device.isAdjustingExposure && hadSetExposurePoint)
        {
            hadSetExposurePoint = NO;
            [self performSelector:@selector(lockCurrentExposure) withObject:nil afterDelay:2];
        }
    }else if ([keyPath isEqualToString:@"adjustingFocus"])
    {
        if (!videoInput.device.isAdjustingFocus && hadSetFocusPoint)
        {
            hadSetFocusPoint = NO;
            [self performSelector:@selector(lockCurrentFocus) withObject:nil afterDelay:2];
        }
    }
}

-(void)configureDevice:(void(^)(void))configureCode
{
    NSError *lockError;
    [videoInput.device lockForConfiguration:&lockError];
    if (lockError) return;
    
    if (configureCode) configureCode();
    
    [videoInput.device unlockForConfiguration];
}

-(void)setFocusPoint:(CGPoint)point
{
    CGPoint pointOfInterest = [captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    
    [self configureDevice:^{
        [videoInput.device setFocusPointOfInterest:pointOfInterest];
        
        [self displayView:self.viewForFocusPoint atPoint:point];
    }];
    
    [self setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
}

-(void)setExposurePoint:(CGPoint)point
{
    CGPoint pointOfInterest = [captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    
    [self configureDevice:^{
        [videoInput.device setExposurePointOfInterest:pointOfInterest];
        
        [self displayView:self.viewForExposurePoint atPoint:point];
    }];
    
    [self setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
}

-(void)displayView:(UIView *)view atPoint:(CGPoint)point
{
    view.frame = CGRectMake(point.x - view.frame.size.width/2, point.y - view.frame.size.height/2, view.frame.size.width, view.frame.size.height);
    
    [self.viewPreview addSubview:view];
    
    view.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        view.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            view.alpha = 0;
        } completion:^(BOOL finished) {
            [view removeFromSuperview];
        }];
    }];
}

-(void)lock
{
    [self setFocusMode:AVCaptureFocusModeLocked];
    [self setExposureMode:AVCaptureExposureModeLocked];
}

-(void)lockCurrentExposure
{
    [self setExposureMode:AVCaptureExposureModeLocked];
}

-(void)lockCurrentFocus
{
    [self setFocusMode:AVCaptureFocusModeLocked];
}

-(void)setExposureState
{
    [self setExposureMode:self.lockExposure ? AVCaptureExposureModeLocked : AVCaptureExposureModeContinuousAutoExposure];
}

@end
