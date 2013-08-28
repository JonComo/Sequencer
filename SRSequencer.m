//
// Copyright (c) 2013 Jon Como
//

#import "SRSequencer.h"

#import "AVAssetStitcher.h"
#import <MobileCoreServices/UTCoreTypes.h>

#import "LXReorderableCollectionViewFlowLayout.h"

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
    
    int currentRecordingSegment;
    
    CMTime currentFinalDurration;
    int inFlightWrites;
    
    NSTimer *timerStop;
    
    SRClip *clipRecording;
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
        
        [self startNotificationObservers];
    }
    
    return self;
}

- (void)dealloc
{
    [_captureSession removeOutput:movieFileOutput];
    
    [self endNotificationObservers];
    
    NSLog(@"Sequencer out");
}

- (void)setupSessionWithPreset:(NSString *)preset withCaptureDevice:(AVCaptureDevicePosition)cd withTorchMode:(AVCaptureTorchMode)tm withError:(NSError **)error
{
    if(setupComplete){
        *error = [NSError errorWithDomain:@"Setup session already complete." code:102 userInfo:nil];
        return;
    }
    
    setupComplete = YES;

	AVCaptureDevice *captureDevice = [self cameraWithPosition:cd];
    
	if ([captureDevice hasTorch])
    {
		if ([captureDevice lockForConfiguration:nil])
        {
			if ([captureDevice isTorchModeSupported:tm])
            {
				[captureDevice setTorchMode:AVCaptureTorchModeOff];
			}
            
			[captureDevice unlockForConfiguration];
		}
	}
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = preset;
    
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:nil];
    
    if([_captureSession canAddInput:videoInput])
    {
        [_captureSession addInput:videoInput];
    }
    else
    {
        *error = [NSError errorWithDomain:@"Error setting video input." code:101 userInfo:nil];
        return;
    }

    audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if([_captureSession canAddInput:audioInput])
    {
        [_captureSession addInput:audioInput];
    }
    else
    {
        *error = [NSError errorWithDomain:@"Error setting audio input." code:101 userInfo:nil];
        return;
    }
    
    if([_captureSession canAddOutput:movieFileOutput])
    {
        [_captureSession addOutput:movieFileOutput];
    }
    else
    {
        *error = [NSError errorWithDomain:@"Error setting file output." code:101 userInfo:nil];
        return;
    }
}

-(void)setupSessionWithDefaults
{
    NSError *error;
    [self setupSessionWithPreset:CAPTURE_SESSION_PRESET withCaptureDevice:INITIAL_CAPTURE_DEVICE_POSITION withTorchMode:INITIAL_TORCH_MODE withError:&error];
    
    if(error)
    {
        self.asyncErrorHandler(error);
    }
    else
    {
        captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        
        self.viewPreview.layer.masksToBounds = YES;
        captureVideoPreviewLayer.frame = self.viewPreview.bounds;
        
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        [self.viewPreview.layer insertSublayer:captureVideoPreviewLayer below:self.viewPreview.layer.sublayers[0]];
        
        // Start the session. This is done asychronously because startRunning doesn't return until the session is running.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.captureSession startRunning];
        });
    }
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
    }
    else
    {
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *backFacingCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == currentCameraPosition)
		{
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
    
    [movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
}

-(void)previewOverView:(UIView *)placeholder
{
    if (self.moviePlayerController.playbackState == MPMoviePlaybackStatePlaying)
    {
        [self stopPreview];
        return;
    }
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [self finalizeRecordingToFile:outputURL withVideoSize:CGSizeMake(500, 500) withPreset:AVAssetExportPreset640x480 withCompletionHandler:^(NSError *error) {
        
        if (error) return;
        
        if (!self.moviePlayerController){
            self.moviePlayerController = [[MPMoviePlayerController alloc] initWithContentURL:outputURL];
            self.moviePlayerController.controlStyle = MPMovieControlStyleNone;
        }
        
        [self.moviePlayerController setContentURL:outputURL];
        
        self.moviePlayerController.view.frame = CGRectMake(0, 0, placeholder.bounds.size.width, placeholder.bounds.size.height);
        [placeholder addSubview:self.moviePlayerController.view];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopPreview) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
        
        [self.captureSession stopRunning];
        [self.moviePlayerController play];
    }];
}

-(void)stopPreview
{
    [self.moviePlayerController stop];
    [self.moviePlayerController.view removeFromSuperview];
    self.moviePlayerController = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    
    [self.captureSession startRunning];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate implementation

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    inFlightWrites++;
    
    NSLog(@"AVCaptureMovieOutput started writing to file");
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
        [clipRecording generateThumbnailCompletion:^(BOOL success) {
            
            if (success){
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
        [self removeClipAtIndex:i];
    }
    
    if ([self.delegate respondsToSelector:@selector(sequencer:clipCountChanged:)])
        [self.delegate sequencer:self clipCountChanged:self.clips.count];
    
    [self.collectionViewClips reloadData];
}

- (void)finalizeRecordingToFile:(NSURL *)finalVideoLocationURL withVideoSize:(CGSize)videoSize withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))completionHandler
{
    //[self reset];
    
    if (self.clips.count == 0)
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
    
    AVAssetStitcher *stitcher = [[AVAssetStitcher alloc] initWithOutputSize:videoSize];

    __block NSError *stitcherError;
    
    [self.clips enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        SRClip *clip = (SRClip *)obj;
        
        [stitcher addAsset:[AVURLAsset assetWithURL:clip.URL] withTransform:^CGAffineTransform(AVAssetTrack *videoTrack) {
            
            //
            // The following transform is applied to each video track. It changes the size of the
            // video so it fits within the output size and stays at the correct aspect ratio.
            //
            
            return CGAffineTransformIdentity;
            
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
            
        } withErrorHandler:^(NSError *error) {
            
            stitcherError = error;
            
        }];
        
    }];
    
    if(stitcherError){
        completionHandler(stitcherError);
        return;
    }
    
    [stitcher exportTo:finalVideoLocationURL withPreset:preset withCompletionHandler:^(NSError *error) {
        
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
                        }
                        else
                        {
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
    
    orientation = AVCaptureVideoOrientationPortrait;
    deviceOrientationDidChangeObserver = [notificationCenter addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        
        switch ([[UIDevice currentDevice] orientation])
        {
            case UIDeviceOrientationPortrait:
                orientation = AVCaptureVideoOrientationPortrait;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                orientation = AVCaptureVideoOrientationPortraitUpsideDown;
                break;
            case UIDeviceOrientationLandscapeLeft:
                orientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIDeviceOrientationLandscapeRight:
                orientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            default:
                orientation = AVCaptureVideoOrientationPortrait;
                break;
        }
        
    }];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
}

- (void)endNotificationObservers
{
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
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

-(void)setCollectionViewClips:(UICollectionView *)collectionViewClips
{
    collectionViewClips.dataSource = self;
    
    LXReorderableCollectionViewFlowLayout *layout = [[LXReorderableCollectionViewFlowLayout alloc] init];
    [layout setMinimumInteritemSpacing:0];
    [layout setMinimumLineSpacing:0];
    [layout setItemSize:CGSizeMake(60, 60)];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    [collectionViewClips setCollectionViewLayout:layout];
    
    _collectionViewClips = collectionViewClips;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cellClip" forIndexPath:indexPath];
    
    SRClip *clip = [self.clips objectAtIndex:indexPath.row];
    
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:100];
    
    imageView.image = clip.thumbnail;
    
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

-(void)addClip:(SRClip *)clip
{
    [self.clips addObject:clip];
    
    [self.collectionViewClips reloadData];
    [self.collectionViewClips scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:MAX(0,self.clips.count-1) inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:YES];
}

-(void)removeClipAtIndex:(NSInteger)index
{
    SRClip *clip = [self.clips objectAtIndex:index];
    
    [[NSFileManager defaultManager] removeItemAtURL:clip.URL error:nil];
    
    [self.clips removeObjectAtIndex:index];
}

-(void)duplicateClipAtIndex:(NSInteger)index
{
    SRClip *clipAtIndex = self.clips[index];
    
    SRClip *newClip = [clipAtIndex duplicate];
    
    [newClip generateThumbnailCompletion:^(BOOL success) {
        [self addClip:newClip];
    }];
}

-(void)addClipFromURL:(NSURL *)url
{
    SRClip *newClip = [[SRClip alloc] initWithURL:url];
    
    [newClip generateThumbnailCompletion:^(BOOL success) {
        [self addClip:newClip];
    }];
}

@end
