//
//  ol2cSaveMenuController.m
//  OpenLaszlo2Canvas
//
//  Created by Matthias Blanquett on 12.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import "ol2hSaveMenuController.h"

#import "xmlParser.h"

@implementation ol2hSaveMenuController
@synthesize textViewText = _textViewText;

- (IBAction)doSaveAs:(id)pId
{	
    NSLog(@"doSaveAs");	
    NSSavePanel *saveDlg = [NSSavePanel savePanel];
    NSInteger tvarInt	= [saveDlg runModal];
    if(tvarInt == NSOKButton)
    {
     	NSLog(@"doSaveAs we have an OK button");	
    }
    else if(tvarInt == NSCancelButton)
    {
     	NSLog(@"doSaveAs we have a Cancel button");
     	return;
    }
    else
    {
     	NSLog(@"doSaveAs tvarInt not equal 1 or zero = %3ld",tvarInt);
     	return;
    }

    NSString * tvarDirectory = [[saveDlg directoryURL] absoluteString];
    NSLog(@"doSaveAs directory = %@",tvarDirectory);

    NSString * tvarFilename = [[saveDlg URL] absoluteString];
    NSLog(@"doSaveAs filename = %@",tvarFilename);
}

- (IBAction)doOpen:(id)pId
{
    NSLog(@"doOpen");

    // Manchmal stürzt es bei dieser Zeile ab, why???
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];

    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];

    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];

    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];

    NSInteger tvarNSInteger	= [openDlg runModal];
    if(tvarNSInteger == NSOKButton)
    {
     	NSLog(@"doOpen: We have an OK button");	
    }
    else if(tvarNSInteger == NSCancelButton)
    {
     	NSLog(@"doOpen: We have a Cancel button");
     	return;
    }
    else
    {
     	NSLog(@"doOpen tvarInt not equal 1 or zero = %3ld",tvarNSInteger);
     	return;
    }


    // Falls man mehrere Files hätte:
    /****************************
    // Get an array containing the full filenames of all
    // files and directories selected.
    NSArray* files = [openDlg URLs];

    // Loop through all the files and process them.
    for(int i = 0; i < [files count]; i++ )
    {
        NSString* fileName = [files objectAtIndex:i];
        
        // Do something with the filename.
    }
    ****************************/


    NSString * tvarDirectory = [[openDlg directoryURL] absoluteString];
    NSLog(@"doOpen directory = %@",tvarDirectory);

    NSString * tvarFilename = [[openDlg URL] absoluteString];
    NSLog(@"doOpen filename 1 = %@",tvarFilename);

    // Alternative dazu:
    /*
    // Lokal:
    NSError *error;
    NSString* contents = [NSString stringWithContentsOfFile:tvarFilename 
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
    NSData* xmlData = [contents dataUsingEncoding:NSUTF8StringEncoding];

    // Remote:
    NSError *error;
    NSString* contents = [NSString stringWithContentsOfUrl:[NSURL URLWithString:URLOFXMLFILE] 
    encoding:NSUTF8StringEncoding
    error:&error];
    NSData* xmlData = [contents dataUsingEncoding:NSUTF8StringEncoding];
    */






    // Übergeben des Dateinamens an xmlParser. Dort geht es weiter
    xmlParser * x = [[xmlParser alloc] initWith:[openDlg URL]];
    [x start];
}

- (void)openDlgWithoutIB
{
    [self doOpen:nil];
}

@end
