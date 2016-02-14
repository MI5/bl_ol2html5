//
//  ol2hAppDelegate.m
//  OpenLaszlo2HTML5
//
//  Created by Matthias Blanquett on 19.04.12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ol2hAppDelegate.h"

#import "xmlParser.h"

#import "ol2hSaveMenuController.h"

@implementation ol2hAppDelegate

@synthesize window = _window, openButton = _openButton, IHaveABackupButton = _IHaveABackupButton;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    BOOL SOFORTSTART = YES;



    if (SOFORTSTART)
    {
        NSURL *u = [NSURL URLWithString:@"file://localhost/Users/MI5/Downloads/Taxango2013/Taxango.lzx"];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[u path]];
        if (!fileExists) // Damit es auch auf Arbeit klappt, dort anderes Verzeichnis
            u = [NSURL URLWithString:@"file://localhost/Users/Blanquett/Downloads/Taxango2013/Taxango.lzx"];
        fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[u path]];
        if (!fileExists)
            return;


        xmlParser *x = [[xmlParser alloc] initWith:u];
        [x start];

        // Anwendung beenden dann direkt wieder
        exit(0);
    }
}



- (IBAction)openFileClicked:(id)sender
{
    ol2hSaveMenuController *o = [[ol2hSaveMenuController alloc] init];
    [o openDlgWithoutIB];
}

- (IBAction)iHaveABackupClicked:(id)sender
{
    if ([self.IHaveABackupButton state] == NSOnState)
    {
        [self.openButton setEnabled: YES];
    }
    else
    {
        [self.openButton setEnabled: NO];
    }
}

@end
