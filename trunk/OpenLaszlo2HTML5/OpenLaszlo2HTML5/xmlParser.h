//
//  xmlParser.h
//  OpenLaszlo2Canvas
//
//  Created by Matthias Blanquett on 13.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface xmlParser : NSObject <NSXMLParserDelegate>

// Für das Element item innerhalb von dataset
// Ich muss es bei rekursiven Aufrufen von außen setzen können, deswegen public
@property (strong, nonatomic) NSString *lastUsedDataset;

-(id)initWith:(NSURL*) pathToFile;

// Weil wir uns auch rekursiv aufrufen, muss ich zwischendruch ein Array mit den Zwischenergebnissen zurückgeben
// Array enthält derzeit 6 Objekte (5 Strings und unsere intern gesammelten JS-Variablen
-(NSArray*) start;


// Damit die C-Funktion die NSLog() umleitet, darauf zugreifen kann
- (void) jumpToEndOfTextView;

@end
