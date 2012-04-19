//
//  ol2cSaveMenuController.h
//  OpenLaszlo2Canvas
//
//  Created by Matthias Blanquett on 12.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ol2hSaveMenuController : NSMenu
- (IBAction)doSaveAs:(id)pId;
- (IBAction)doOpen:(id)pId;

@property (strong) IBOutlet NSTextView *textViewText;

- (void)openDlgWithoutIB;
@end
