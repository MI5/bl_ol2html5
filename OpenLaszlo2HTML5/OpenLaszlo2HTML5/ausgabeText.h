//
//  ausgabeText.h
//  OpenLaszlo2HTML
//
//  Created by Matthias Blanquett on 18.04.12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ausgabeText : NSView
@property (strong) IBOutlet NSTextView *textView;

- (NSInteger)tag;


extern NSTextView* globalAccessToTextView;


@end
