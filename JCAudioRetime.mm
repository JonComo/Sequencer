//
//  JCAudioRetime.m
//  iPhoneTest
//
//  Created by Jon Como on 9/15/13.
//
//

#import "JCAudioRetime.h"

#import <AVFoundation/AVAudioPlayer.h>

#include "Dirac.h"
#include <stdio.h>
#include <sys/time.h>
#include "Utilities.h"

#import "Macros.h"

#import "JCMath.h"

/*
 This is the callback function that supplies data from the input stream/file whenever needed.
 It should be implemented in your software by a routine that gets data from the input/buffers.
 The read requests are *always* consecutive, ie. the routine will never have to supply data out
 of order.
 */
long myReadData(float **chdata, long numFrames, void *userData)
{
	// The userData parameter can be used to pass information about the caller (for example, "self") to
	// the callback so it can manage its audio streams.
	if (!chdata)	return 0;
	
    JCAudioRetime *Self = (JCAudioRetime *)userData;
    if (!Self)	return 0;
	
	// we want to exclude the time it takes to read in the data from disk or memory, so we stop the clock until
	// we've read in the requested amount of data
	//gExecTimeTotal += DiracClockTimeSeconds(); 		// ............................. stop timer ..........................................
    
	OSStatus err = [Self.reader readFloatsConsecutive:numFrames intoArray:chdata];
	
	DiracStartClock();								// ............................. start timer ..........................................
    
	return err;
	
}

@implementation JCAudioRetime

@synthesize reader;

-(void)retimeAudioAtURL:(NSURL *)originalURL withRatio:(float)ratio rePitch:(BOOL)rePitch completion:(void (^)(NSURL *))block
{
    NSString *outputSound = [[NSString stringWithFormat:@"%@/retimed.aif", DOCUMENTS] retain];
    NSURL *inUrl = originalURL;
    NSURL *outUrl = [[NSURL fileURLWithPath:outputSound] retain];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[outUrl path]]){
        [[NSFileManager defaultManager] removeItemAtURL:outUrl error:nil];
    }
    
    reader = [[EAFRead alloc] init];
    writer = [[EAFWrite alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        long numChannels = 1;		// DIRAC LE allows mono only
        float sampleRate = 44100.;
        
        // open input file
        [reader openFileForRead:inUrl sr:sampleRate channels:numChannels];
        
        // create output file (overwrite if exists)
        [writer openFileForWrite:outUrl sr:sampleRate channels:numChannels wordLength:16 type:kAudioFileAIFFType];
        
        // DIRAC parameters
        // Here we set our time an pitch manipulation values
        
        //float repitchValue = [JCMath mapValue:ratio range:CGPointMake(0.5, 2) range:CGPointMake(-12, 12)];
        
        float time      = ratio;                 // 115% length
        float pitch     = pow(2.0, 0.0/12.0);     // pitch shift (0 semitones)
        float formant   = pow(2.0, 0.0/12.0);    // formant shift (0 semitones). Note formants are reciprocal to pitch in natural transposing
        
        // First we set up DIRAC to process numChannels of audio at 44.1kHz
        // N.b.: The fastest option is kDiracLambdaPreview / kDiracQualityPreview, best is kDiracLambda3, kDiracQualityBest
        // The probably best *default* option for general purpose signals is kDiracLambda3 / kDiracQualityGood
        void *dirac = DiracCreate(kDiracLambdaPreview, kDiracQualityPreview, numChannels, sampleRate, &myReadData, (void*)self);
        //	void *dirac = DiracCreate(kDiracLambda3, kDiracQualityBest, numChannels, sampleRate, &myReadData);
        if (!dirac) {
            printf("!! ERROR !!\n\n\tCould not create DIRAC instance\n\tCheck number of channels and sample rate!\n");
            printf("\n\tNote that the free DIRAC LE library supports only\n\tone channel per instance\n\n\n");
            exit(-1);
        }
        
        // Pass the values to our DIRAC instance
        DiracSetProperty(kDiracPropertyTimeFactor, time, dirac);
        DiracSetProperty(kDiracPropertyPitchFactor, pitch, dirac);
        DiracSetProperty(kDiracPropertyFormantFactor, formant, dirac);
        
        // upshifting pitch will be slower, so in this case we'll enable constant CPU pitch shifting
        if (pitch > 1.0)
            DiracSetProperty(kDiracPropertyUseConstantCpuPitchShift, 1, dirac);
        
        // Print our settings to the console
        DiracPrintSettings(dirac);
        
        NSLog(@"Running DIRAC version %s\nStarting processing", DiracVersion());
        
        // Get the number of frames from the file to display our simplistic progress bar
        SInt64 numf = [reader fileNumFrames];
        SInt64 outframes = 0;
        SInt64 newOutframe = numf*time;
        //long lastPercent = -1;
        //percent = 0;
        
        // This is an arbitrary number of frames per call. Change as you see fit
        long numFrames = 8192;
        
        // Allocate buffer for output
        float **audio = AllocateAudioBuffer(numChannels, numFrames);
        
        double bavg = 0;
        
        // MAIN PROCESSING LOOP STARTS HERE
        while (YES)
        {
            // Display ASCII style "progress bar"
    //		percent = 100.f*(double)outframes / (double)newOutframe;
    //		long ipercent = percent;
    //		if (lastPercent != percent) {
    //			[self performSelectorOnMainThread:@selector(updateBarOnMainThread:) withObject:self waitUntilDone:NO];
    //			printf("\rProgress: %3i%% [%-40s] ", ipercent, &"||||||||||||||||||||||||||||||||||||||||"[40 - ((ipercent>100)?40:(2*ipercent/5))] );
    //			lastPercent = ipercent;
    //			fflush(stdout);
    //		}
            
            DiracStartClock();								// ............................. start timer ..........................................
            
            // Call the DIRAC process function with current time and pitch settings
            // Returns: the number of frames in audio
            long ret = DiracProcess(audio, numFrames, dirac);
            bavg += (numFrames/sampleRate);
            //gExecTimeTotal += DiracClockTimeSeconds();		// ............................. stop timer ..........................................
            
            //printf("x realtime = %3.3f : 1 (DSP only), CPU load (peak, DSP+disk): %3.2f%%\n", bavg/gExecTimeTotal, DiracPeakCpuUsagePercent(dirac));
            
            // Process only as many frames as needed
            long framesToWrite = numFrames;
            unsigned long nextWrite = outframes + numFrames;
            if (nextWrite > newOutframe) framesToWrite = numFrames - nextWrite + newOutframe;
            if (framesToWrite < 0) framesToWrite = 0;
            
            // Write the data to the output file
            [writer writeFloats:framesToWrite fromArray:audio];
            
            // Increase our counter for the progress bar
            outframes += numFrames;
            
            // As soon as we've written enough frames we exit the main loop
            if (ret <= 0) break;
        }
        
        //percent = 100;
        //[self performSelectorOnMainThread:@selector(updateBarOnMainThread:) withObject:self waitUntilDone:NO];
        
        
        // Free buffer for output
        DeallocateAudioBuffer(audio, numChannels);
        
        // destroy DIRAC instance
        DiracDestroy( dirac );
        
        // Done!
        NSLog(@"\nDone!");
        
        [reader release];
        [writer release]; // important - flushes data to file
        
        // start playback on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) block(outUrl);
        });
        
        [pool release];
    });
}

@end
