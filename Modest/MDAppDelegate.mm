//
//  MDAppDelegate.m
//  Modest
//
//  Created by Josep Llodrà Grimalt on 22/03/14.
//  Copyright (c) 2014 Atlantis of code. All rights reserved.
//

#import "MDAppDelegate.h"
#import "MDAudioManager.h"

@interface MDAppDelegate () {
    MDAudioManager *audioManager;
    NSThread *audioManagerThread;
    NSOpenPanel *openPanel;
}
@end

@implementation MDAppDelegate
@synthesize eqMeterView;
@synthesize songsTableView;
@synthesize statusText;

- (id)init {
    self = [super init];
    if (self == nil) return nil;
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    ((NSView *)self.window.contentView).wantsLayer = YES;
    // audio thread
    audioManager = [[MDAudioManager alloc] init];
    audioManagerThread = [[NSThread alloc] initWithTarget:audioManager
                                                 selector:@selector(setUp:)
                                                   object:self];
    [audioManagerThread start];
    // init file picker
    openPanel = [NSOpenPanel openPanel];

}

- (IBAction)addButton:(NSButton *)sender {
    [openPanel setAllowedFileTypes:@[@"it", @"xm", @"s3m", @"mod"]];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    //[openDlg setDirectoryURL:@""];
    
    if([openPanel runModal] == NSOKButton) {
        NSArray* files = [openPanel URLs];
        for(int i = 0; i < [files count]; i++) {
            NSURL *fileNSUrl = [files objectAtIndex:i];
            [statusText setStringValue:[fileNSUrl path]];
            [audioManager performSelector:@selector(loadSongAndPlay:) onThread:audioManagerThread withObject:fileNSUrl waitUntilDone:NO];
        }
    }
}

- (IBAction)playButton:(NSButton *)sender {
    [audioManager performSelector:@selector(play) onThread:audioManagerThread withObject:nil waitUntilDone:NO];
}

- (IBAction)pauseButton:(NSButton *)sender {
    [audioManager performSelector:@selector(pause) onThread:audioManagerThread withObject:nil waitUntilDone:NO];
}

- (IBAction)stopButton:(NSButton *)sender {
    [audioManager performSelector:@selector(stop) onThread:audioManagerThread withObject:nil waitUntilDone:NO];
}

- (void)playSong:(NSURL*)fileNSUrl {
    [audioManager performSelector:@selector(loadSong:) onThread:audioManagerThread withObject:fileNSUrl waitUntilDone:YES];
    [audioManager performSelector:@selector(play) onThread:audioManagerThread withObject:nil waitUntilDone:NO];
    [statusText setStringValue:[fileNSUrl path]];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[audioManagerThread threadDictionary] setValue:[NSNumber numberWithBool:YES] forKey:@"exitNow"];
    
}

@end
