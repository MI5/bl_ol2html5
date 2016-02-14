//
//  xmlParserPreCollectClasses.h
//  OpenLaszlo2HTML5
//
//  Created by Matthias Blanquett on 02.04.13.
//  Copyright (c) 2013. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface xmlParserPreCollectClasses : NSObject <NSXMLParserDelegate>

-(id)initWith:(NSURL*) pathToFile;

-(NSArray*) startWithString:(NSString*)s;

@end
