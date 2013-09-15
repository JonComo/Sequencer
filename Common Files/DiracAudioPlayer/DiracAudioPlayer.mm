//
//  DiracAudioPlayer.m
//  DiracAudioPlayer
//
//  Created by Stephan M. Bernsee on 12-03-2012.
//  Copyright 2011-2012 The DSP Dimension. All rights reserved.
//
//	DiracAudioPlayer distro version 3.6
//

#import "DiracAudioPlayer.h"
#import "Utilities.h"


#pragma mark Callbacks

// ---------------------------------------------------------------------------------------------------------------------------
/* 
 This function gets called by Dirac whenever it processes a new chunk of data internally. We're
 given the internal frame position which we add to the frame position from the last seek command
 to get the current play time
 */

void DiracCoreTrackInputPositionCallback(unsigned long position, void *userData)
{
	DiracAudioPlayer *Self = (__bridge DiracAudioPlayer*)userData;
	if (!Self)	return;
	Self.mFramePositionInInputFile = Self.mLastResetPositionInFile+position;
#ifdef DEBUG
	printf("Self.mFramePositionInInputFile = %d\n", (int)Self.mFramePositionInInputFile);
#endif
}

// ---------------------------------------------------------------------------------------------------------------------------
/*
 This is the callback function that supplies data from the input stream/file to Dirac when needed.
 The read requests are *always* consecutive, ie. the routine will never have to supply data out
 of order.
 */
long DiracCoreDataProviderCallback(float **chdata, long numFrames, void *userData)
{	
	// The userData parameter can be used to pass information about the caller (for example, "self") to
	// the callback so it can manage its audio streams.
	if (!chdata)	return 0;
	
	DiracAudioPlayer *Self = (__bridge DiracAudioPlayer*)userData;
	if (!Self)	return 0;
	
	// read numFrames frames from our audio file
	OSStatus ret = [Self.mReader readFloatsConsecutive:numFrames intoArray:chdata];

    // we might get zero frames during a seek operation - make sure that we don't interpret this as EOF
    if (!ret && [Self.mReader isSeeking])
        ret = numFrames;
    
	long remaining = 0;
	if (ret < numFrames && ret >= 0) {
		Self.mTotalFramesConsumed += ret;
#ifdef DEBUG
		printf("ret (%d) < numFrames (%ld)\n", ret, numFrames);
#endif
		remaining = numFrames-ret;
		
		if (Self.mLoopCount >= Self.mNumberOfLoops && Self.mNumberOfLoops >= 0) return 0;
		
		[Self loopBack];
		Self.mLoopCount = Self.mLoopCount + 1;
		ret = [Self.mReader readFloatsConsecutive:remaining intoArray:chdata withOffset:ret];
		Self.mTotalFramesConsumed += ret;
		return numFrames;		
	}
	
	// return value < 0 on error, 0 when reaching EOF, numFrames read otherwise
	return ret;
	
}



#pragma mark DiracAudioPlayer Class


@implementation DiracAudioPlayer

// ---------------------------------------------------------------------------------------------------------------------------
/* 
 Seeks back to the beginning of the file and resets our DSP buffers
 */
-(void)loopBack
{
	if (mReader) {
		[mReader seekToStart];
		[self resetProcessing:[mReader tell]];
	}
	mTotalFramesGenerated=mTotalFramesConsumed = 0;
}

// ---------------------------------------------------------------------------------------------------------------------------
/*
 Overridden from DiracAudioPlayerBase
 Do whatever you need to do here if processing is reset, such as after a seek operation
 */
-(void)resetProcessing:(SInt64)position
{

	if (mDirac)
		DiracReset(true, mDirac);	

	mLastResetPositionInFile = position;
}

// ---------------------------------------------------------------------------------------------------------------------------
/* 
 Overridden from DiracAudioPlayerBase

 This is where the actual processing happens. We create a background thread that constantly reads from the file,
 processes audio data and writes it into a cache (mAudioBuffer). If there is enough data in the cache already we don't call
 Dirac on this pass and simply wait until we see that our PlaybackCallback has consumed enough frames.
 
 Note that you might need to change thread priority (via [NSthread setThreadPriority:XX]), cache size (via kAudioBufferNumFrames)
 and hi water mark (by changing the line "if (wd > 2*kAudioBufferNumFrames/3)" below) depending on what else is going on
 in your app. 
 */
-(void)processAudioThread:(id)param
{
    
#if __has_feature(objc_arc)
	@autoreleasepool {
#else
		// Each thread needs its own AutoreleasePool
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
    
 		// If our Dirac instance is still valid we have run into a previous instance that has not been
		// deleted yet because the process has not fully stopped.
		// In this case we simply wait a short period of time and then try again.
		if (mDirac) {
			NSLog(@"Running into existing Dirac instance - retrying");
			[NSThread sleepForTimeInterval:.2];
			[self performSelectorOnMainThread:@selector(triggerPlay:) withObject:self waitUntilDone:NO];
			goto end;
		}
		{
			
#ifdef DEBUG
			NSLog(@"entering thread");
#endif
			// we create a reader instance to read from our file
			mReader = [[EAFRead alloc] init];
			mLastResetPositionInFile=mFramePositionInInputFile = 0;
			OSStatus err = [mReader openFileForRead:mInUrl sr:kOversample*mSampleRate channels:mNumChannels];
			if (err != noErr) {
				printf("!! ERROR !!\n\tCould not read from that file - may be DRM protected?\n");
                arc_release(mReader);
				mReader = nil;
				goto end;
			}
			
			
			mTotalFramesInFile = [mReader fileNumFrames] / kOversample;
#ifdef DEBUG
			NSLog(@"mTotalFramesInFile = %d", (int)mTotalFramesInFile);
#endif	
			mAudioBufferReadPos = mAudioBufferWritePos = 0;
			
			// Before starting processing we set up our Dirac instance
			mDirac = DiracCreate(kDiracLambdaPreview, kDiracQualityPreview, mNumChannels, mSampleRate, DiracCoreDataProviderCallback, (__bridge void*)self);
			if (!mDirac) {
				printf("!! ERROR !!\n\n\tCould not create Dirac instance\n\tCheck sample rate!\n");
				exit(-1);
			}
			
			// This is the number of frames each call to Dirac will add to the cache.
			long numFrames = 512;
			
			DiracSetProperty(kDiracPropertyTimeFactor, mTimeFactor, mDirac);
			DiracSetProperty(kDiracPropertyPitchFactor, mPitchFactor, mDirac);
			
			// register our custom callback for -currentTime
			DiracSetProcessingBeganCallback(DiracCoreTrackInputPositionCallback, (__bridge void*)self, mDirac);

			// create a buffer
			float **audio = AllocateAudioBuffer(mNumChannels, numFrames);
			
			long ret = 0;
			mLoopCount = 0;
			
		again:
			
			// MAIN PROCESSING LOOP STARTS HERE
			for(;;) {
				
				if([[NSThread currentThread] isCancelled]) {
					mIsProcessing = NO;
#ifdef DEBUG
					NSLog(@"Thread has been cancelled");
#endif
					break;
				}
				
				// first we determine if we actually need to add new data to the cache. If the distance
				// between read and write position in the cache is larger than 2/3 the cache size 
				// we assume there is still enough data so we simply skip processing this time
				long wd = wrappedDiff(mAudioBufferReadPos, mAudioBufferWritePos, kAudioBufferNumFrames);
				if (wd > 2*kAudioBufferNumFrames/3) {
					// if you're getting drop-outs decrease this value. We only use it to avoid hogging
					// the CPU with the above comparison when there is nothing to do
					[NSThread sleepForTimeInterval:.01];
					continue;
				}
				
				// call DiracProcess to produce new frames
				ret = DiracProcess(audio, numFrames, mDirac);
//				ret = DiracCoreDataProviderCallback(audio, numFrames, self); // for debugging

				// we exit if we hit EOF or an error
				if (ret <= 0) {
#ifdef DEBUG
					NSLog(@"ret: %d\n", (int)ret);
#endif
					break;
				}
				
				// make a note of how many frames we have processed during this pass
				mTotalFramesGenerated += ret;
				
				// add them to the cache
				for (long v = 0; v < ret; v++) {
					for (long c = 0; c < mNumChannels; c++) {
						
						float value = audio[c][v] * mVolume;
						
						// some settings might cause a slight increase in amplitude, make sure we don't cause nasty digital wrapping!
						if (value > 0.999f) value = 0.999f;
						else if (value < -1.f) value = -1.f;
						
						mAudioBuffer[c][mAudioBufferWritePos] = (SInt16)(value * 32768.f);
					}
					mAudioBufferWritePos++;
					if (mAudioBufferWritePos > kAudioBufferNumFrames-1)
						mAudioBufferWritePos = 0;
				}

			} // END MAIN PROCESSING LOOP
			
			// handle our demo timeout by stopping playback and displaying a note
			if (ret == kDiracErrorDemoTimeoutReached) {
				[self performSelectorOnMainThread:@selector(HandleDemoTimeout:) withObject:self waitUntilDone:NO];		
			}
			
			// we're done processing on this thread
			mIsProcessing = NO;
			
			// free buffer for output
			DeallocateAudioBuffer(audio, mNumChannels);
			
			// get rid of Dirac
			if (mDirac) {
				DiracDestroy(mDirac);
				mDirac = NULL;
			}
			// release our reader object
			arc_release(mReader);
			mReader = nil;
			
			
#ifdef DEBUG
			NSLog(@"exiting thread");
#endif
		}
	end:
		;	// need empty statement after label to make compiler happy
		
		// release the pool
#if __has_feature(objc_arc)
	}
#else
	[pool release];
#endif
	
	
}


// ---------------------------------------------------------------------------------------------------------------------------

-(void)changeDuration:(float)duration
{
	if (mDirac) {
		if (DiracSetProperty(kDiracPropertyTimeFactor, duration, mDirac) != kDiracErrorNoErr) {
			NSLog(@"Can't set property 'kDiracPropertyTimeFactor' in %@ - may be a demo or DiracLE limitation", NSStringFromSelector(_cmd));
		}
	}
	[super changeDuration:duration];
}
// ---------------------------------------------------------------------------------------------------------------------------

-(void)changePitch:(float)pitch
{
	if (mDirac) {
		if (DiracSetProperty(kDiracPropertyPitchFactor, pitch, mDirac) != kDiracErrorNoErr) {
			NSLog(@"Can't set property 'kDiracPropertyPitchFactor' in %@ - may be a demo or DiracLE limitation", NSStringFromSelector(_cmd));
		}
	}
	[super changePitch:pitch];
}


// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------------------------------------------

@end

