//
//  ol2hAppDelegate.m
//  OpenLaszlo2HTML5
//
//  Created by Matthias Blanquett on 19.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import "ol2hAppDelegate.h"

#import "xmlParser.h"

#import "ol2hSaveMenuController.h"

@implementation ol2hAppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    BOOL SOFORTSTART = YES;

    

    if (SOFORTSTART)
    {
        // erstmal so starten, weil ich es über den Klick auf den Button nicht hinbekommen
        // NSString *filename = @"Test.txt";
        // NSString *path = @"/Users/MI5/Downloads/";
        // NSData* d = [[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@%@",path,filename]];
        
        NSURL *u = [NSURL URLWithString:@"file://localhost/Users/MI5/Downloads/Test.txt"];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[u path]];
        if (!fileExists) // Damit es auch auf Arbeit klappt, dort anderes Verzeichnis
            u = [NSURL URLWithString:@"file://localhost/Users/Blanquett/Downloads/Test.txt"];
        
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

@end
