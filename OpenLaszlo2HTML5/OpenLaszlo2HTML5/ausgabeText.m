//
//  ausgabeText.m
//  OpenLaszlo2HTML
//
//  Created by Matthias Blanquett on 18.04.12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ausgabeText.h"

#import "globalVars.h"

NSTextView* globalAccessToTextView = nil;


@implementation ausgabeText
@synthesize textView = _textView;


+ (void)initialize
{
    if(!globalAccessToTextView)
        globalAccessToTextView = [[NSTextView alloc] init];
}

// Beim aufwachen legt IB die Objekte an, in dem Moment sichern wir uns die Referenz.
// Anders ging es nicht gelöst... hat mich echt monstermäßig viel Zeit gekostet
-(void) awakeFromNib
{
    // Möglichkeit 1, direkt als globale Var hier:
    globalAccessToTextView = self.textView;
    // Möglichkeit 2, eine eigene Klasse für globale Variablen
    // Ich muss die Klasse einmal anlegen, damit es klappt! Dann gibt es nur noch eine Instanz
    globalVars *gv = [[globalVars alloc] init];
    gv.textView = nil; // Nur damit die Warnung weggeht ist diese Zeile nötig.
    sharedSingleton.textView = self.textView;
}


- (id) init
{
    if (self = [super init])
    {

    }
    return self;
}

- (NSInteger)tag
{
    return 99; // Damit ich diese View wiederfinden und Text reinpacken kann, klappt nur nicht
}

- (IBAction)button2Clicked:(id)sender
{
    // Rumexperimentiert hier mit textStorage, echt nervig

    // [[textView textStorage] string:@""];

    // NSLog(@"Textboxinhalt 1: %@",[[self.textView textStorage] string]);
    // NSLog(@"Textboxinhalt 2: %@",[[globalAccessToTextView textStorage] string]);
    // NSRange nsr = {5,0};

    //[globalAccessToTextView replaceCharactersInRange:nsr withString:@""];
    // [globalAccessToTextView.textStorage replaceCharactersInRange:nsr withString:@""];

    // Lösung: [[[globalAccessToTextView textStorage] mutableString] appendString: @"Dahinter"];

    //[globalAccessToTextView.textStorage initWithString:@"ERSETZT!"];
    //[globalAccessToTextView setString:@"ERSETZT!"];
    // Klappt leider nicht... KA warum
    // NSLog(@"View with Tag 99: %@",[[[[NSApplication sharedApplication] keyWindow] contentView] viewWithTag:99]);
}


@end
