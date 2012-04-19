//
//  globalVars.h
//  OpenLaszlo2HTML
//
//  Created by Matthias Blanquett on 19.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import <Foundation/Foundation.h>

@class globalVars;
extern globalVars *sharedSingleton;

@interface globalVars : NSObject

@property NSTextView *textView;


@end