//
//  xmlParser.h
//  OpenLaszlo2Canvas
//
//  Created by Matthias Blanquett on 13.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface xmlParser : NSObject <NSXMLParserDelegate>

-(id)initWith:(NSURL*) pathToFile;

-(void) start;

@end
