//
//  globalVars.m
//  OpenLaszlo2HTML
//
//  Created by Matthias Blanquett on 19.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import "globalVars.h"

@implementation globalVars

@synthesize textView = _textView;

- (id) init
{
    if (self = [super init])
    {
        self.textView = nil;
    }
    return self;
}

globalVars *sharedSingleton;

// Wird nur einmal beim anlegen der Klasse aufgerufen
+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[globalVars alloc] init];
    }
}



@end
