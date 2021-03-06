//
//  MDAudioManager.m
//  Modest
//
//  Created by Josep Llodrà Grimalt on 23/03/14.
//  Copyright (c) 2014 Atlantis of code. All rights reserved.
//

#import "MDAudioManager.h"
#import "MDEqMeterView.h"
#import "fmod.hpp"

@interface MDAudioManager () {
    FMOD::System    *system;
    FMOD::Sound     *sound;
    FMOD::Channel   *channel;
    unsigned int    version;
    void            *extradriverdata;
    
    BOOL            exitNow;
}

@end

@implementation MDAudioManager
@synthesize threadDict;

- (void)setUp
{
    @autoreleasepool {

        //delegate = appDelegate;
        exitNow = NO;
        extradriverdata = NULL;
        system = NULL;
        sound = NULL;
        channel = NULL;

        bool isPlaying;
        int sampleSize = 64;
        float *spec, *specLeft, *specRight;
        spec = new float[sampleSize];
        memset(spec, 0, sizeof(float) * sampleSize);
        specLeft = new float[sampleSize];
        specRight = new float[sampleSize];
        float maxpow;

        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        
        threadDict = [[NSThread currentThread] threadDictionary];
        [threadDict setValue:[NSNumber numberWithBool:exitNow] forKey:@"exitNow"];
        [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
        [threadDict setValue:@"" forKey:@"infoText"];

        [self initFMOD];

        
        MDEqMeterView *eqView;
        eqView = [[NSApp delegate] eqMeterView];
        [eqView setS:spec];

        do {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.055]];
            }
            system->update();
            channel->isPlaying(&isPlaying);
            if(isPlaying) {
                channel->getSpectrum(specLeft, sampleSize, 0, FMOD_DSP_FFT_WINDOW_RECT);
                channel->getSpectrum(specRight, sampleSize, 1, FMOD_DSP_FFT_WINDOW_RECT);
                maxpow = 0;
                for (int i = 0; i < sampleSize; i++) {
                    spec[i] = (specLeft[i] + specRight[i]) / 2;
                    maxpow = (spec[i] > maxpow) ? spec[i] : maxpow;
                }
                for (int i = 0; i < sampleSize; i++) {
                    spec[i] = spec[i] / maxpow;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [eqView setNeedsDisplay:YES];
                });
            }

            exitNow = [[threadDict valueForKey:@"exitNow"] boolValue];
        } while(!exitNow);
        delete [] spec;
        delete [] specLeft;
        delete [] specRight;
        channel->stop();
        sound->release();
        system->release();
        [[self threadDict] setValue:nil];
        NSLog(@"Audio Manager Thread exiting");
    }
}

- (void)initFMOD {
    NSLog(@"Configuring FMOD");
    
    if(FMOD::System_Create(&system) != FMOD_OK) {
        NSLog(@"Error creating system");
    }
    
    if(system->getVersion(&version) != FMOD_OK) {
        NSLog(@"Error getting version");
    }
    
    if (version < FMOD_VERSION) {
        NSLog(@"FMOD lib version %08x doesn't match header version %08x", version, FMOD_VERSION);
    }
    
    if(system->init(1, FMOD_INIT_NORMAL, extradriverdata) != FMOD_OK) {
        NSLog(@"Error initializating FMOD");
    }
    
    if(system->setStreamBufferSize(64*1024, FMOD_TIMEUNIT_RAWBYTES) != FMOD_OK) {
        NSLog(@"Error setting buffer size FMOD");
    }
}

- (void)loadSong:(NSURL*)file
{
    NSLog(@"loadSong");
    
    channel->stop();
    sound->release();
    [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];

    system->createSound([[file path] UTF8String], FMOD_DEFAULT, 0, &sound);
    
    [self readInfo];
}

- (void)loadScenemusicAndPlay
{
    NSLog(@"loadStreamAndPlay");
    
    channel->stop();
    sound->release();
    channel = NULL;
    FMOD_RESULT result = system->createSound("http://de.scenemusic.net/necta192.mp3", FMOD_SOFTWARE | FMOD_2D | FMOD_CREATESTREAM | FMOD_NONBLOCKING,  0, &sound);
    if(result != FMOD_OK) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[NSApp delegate] statusText] setStringValue:@"Error connecting..."];
        });
        return; // error
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[NSApp delegate] statusText] setStringValue:@"Buffering..."];
    });
    while(!channel) {
        result = system->playSound(FMOD_CHANNEL_FREE, sound, false, &channel);
        usleep(100);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[NSApp delegate] statusText] setStringValue:@"Playing Scenemusic..."];
    });
    [threadDict setValue:[NSNumber numberWithBool:YES] forKey:@"isPlaying"];
    
    [self readInfo];
}

- (void)loadSongAndPlay:(NSURL*)file
{
    NSLog(@"loadSongAndPlay");
    
    channel->stop();
    sound->release();
    [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
   
    //system->createSound([[file path] UTF8String], FMOD_DEFAULT | FMOD_SOFTWARE, 0, &sound);
    system->createSound([[file path] UTF8String], FMOD_DEFAULT, 0, &sound);
    system->playSound(FMOD_CHANNEL_FREE, sound, false, &channel);
    [threadDict setValue:[NSNumber numberWithBool:YES] forKey:@"isPlaying"];

    
    char name[100];
    sound->getName(name, 100);
    NSString *songname = [NSString stringWithCString:name encoding:NSASCIIStringEncoding];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[[NSApp delegate] songsTableView] addSong:file songName:songname];
    });
    [self readInfo];
}


- (void)play
{
    NSLog(@"play");
    bool isPaused;
    channel->getPaused(&isPaused);
    if(isPaused) {
        channel->setPaused(false);
    } else {
        system->playSound(FMOD_CHANNEL_FREE, sound, false, &channel);
    }
    [threadDict setValue:[NSNumber numberWithBool:YES] forKey:@"isPlaying"];
}

- (void)stop
{
    NSLog(@"stop");
    channel->stop();
    [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
}

- (void)pause
{
    NSLog(@"pause");
    channel->setPaused(true);
    [threadDict setValue:[NSNumber numberWithBool:NO] forKey:@"isPlaying"];
}

- (void)readInfo {
    int numtags, numtagsupdated, count;
    FMOD_TAG tag;
    NSString *info = @"";
    char *tagLine;
    
    sound->getNumTags(&numtags, &numtagsupdated);
     
    for (count=0; count < numtags; count++) {
        sound->getTag(0, count, &tag);
        if (tag.datatype == FMOD_TAGDATATYPE_STRING) {
            if(asprintf(&tagLine, "%s = %s\n", tag.name, tag.data) >= 0) {
                info = [info stringByAppendingString:[NSString stringWithCString:tagLine encoding:NSASCIIStringEncoding]];
                free(tagLine);
            }
        } else if (tag.datatype == FMOD_TAGDATATYPE_INT) {
            if(asprintf(&tagLine, "%s = %02d\n", tag.name, ((unsigned int *)tag.data)[0]) >= 0) {
                info = [info stringByAppendingString:[NSString stringWithCString:tagLine encoding:NSASCIIStringEncoding]];
                free(tagLine);
            }
        } else {
            if(asprintf(&tagLine, "%s = binary (%d bytes)\n", tag.name, tag.datalen) >= 0) {
                info = [info stringByAppendingString:[NSString stringWithCString:tagLine encoding:NSASCIIStringEncoding]];
                free(tagLine);
            }
        }
    }
    [threadDict setValue:info forKey:@"infoText"];
}

@end
