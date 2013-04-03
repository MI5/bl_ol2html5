//
//  ol2hAppDelegate.h
//  OpenLaszlo2HTML5
//
//  Created by Matthias Blanquett on 19.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ol2hAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *openButton;
@property (weak) IBOutlet NSButton *IHaveABackupButton;

- (IBAction)openFileClicked:(id)sender;
- (IBAction)iHaveABackupClicked:(id)sender;

@end
