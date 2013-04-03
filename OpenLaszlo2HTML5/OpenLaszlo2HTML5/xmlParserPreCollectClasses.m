//
//  xmlParserPreCollectClasses.m
//  OpenLaszlo2HTML5
//
//  Created by Matthias Blanquett on 02.04.13.
//  Copyright (c) 2013 Buhl. All rights reserved.
//

#import "xmlParserPreCollectClasses.h"

// Private Variablen
@interface xmlParserPreCollectClasses()
@property (strong, nonatomic) NSXMLParser *parser;
@property (strong, nonatomic) NSURL * pathToFile;
@property (strong, nonatomic) NSMutableDictionary *allFoundClasses;
@property (strong, nonatomic) NSMutableArray *allIncludedIncludes;

@end


@implementation xmlParserPreCollectClasses

@synthesize pathToFile = _pathToFile, parser = _parser, allFoundClasses = _allFoundClasses, allIncludedIncludes = _allIncludedIncludes;


// Konstruktor:
-(id)initWith:(NSURL*) pathToFile
{
    if (self = [super init])
    {
        self.pathToFile = pathToFile;
        self.allFoundClasses = [[NSMutableDictionary alloc] initWithCapacity:200];
        self.allIncludedIncludes = [[NSMutableArray alloc] init];
    }

    return self;
}


-(NSArray*) startWithString:(NSString*)s
{
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self.pathToFile path]];

    if (!fileExists)
    {
        // Ich frage den String in diesem Array beim verlassen der Rekursion ab,
        // falls er zwischendurch mal eine Datei nicht findet.
        NSArray *r = [NSArray arrayWithObjects:@"XML-File not found", nil];
        return r;
    }
    else
    {
        if ([s isEqualToString:@""])
        {
            // Create a parser from the prevous set file
            self.parser = [[NSXMLParser alloc] initWithContentsOfURL:self.pathToFile];
        }
        else
        {
            // Create a parser from string
            NSData* d = [s dataUsingEncoding:NSUTF8StringEncoding];
            self.parser = [[NSXMLParser alloc] initWithData:d];
        }

        // Dadurch werden hierdrin die entsprechenden Delegate-Methoden aufgerufen
        [self.parser setDelegate:self];

        // Do the parse
        [self.parser parse];

        // Zurückliefern des Arrays mit 2 Objekten
        NSArray *r = [NSArray arrayWithObjects:[self.allFoundClasses copy],[self.allIncludedIncludes copy], nil];
        return r;
    }
}


-(void) callMyselfRecursive:(NSString*)relativePath
{
    NSURL *path = [self.pathToFile URLByDeletingLastPathComponent];

    // Schutz gegen Leerzeichen im Pfad
    relativePath = [relativePath stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

    NSURL *pathToFile = [NSURL URLWithString:relativePath relativeToURL:path];

    // Test ob wir die Datei schonmal vorher eingebunden haben.
    // Wenn ja, dann raus um eine unendliche Rekursion zu vermeiden bei Über-Kreuz-Include
    if ([self.allIncludedIncludes containsObject:pathToFile])
    {
        return;
    }
    // Alle bereits eingebunden Dateien abspeichern, damit ich nicht <includes> doppelt inkludiere
    [self.allIncludedIncludes addObject:pathToFile];


    xmlParserPreCollectClasses *x = [[xmlParserPreCollectClasses alloc] initWith:pathToFile];


    // Die soweit erkannten Klassennamen werden übergeben...
    [x.allFoundClasses addEntriesFromDictionary:self.allFoundClasses];

    // Die soweit inkludierten <includes> müssen auch rekursiv aufgerufenen Dateien bekannt sein!
    x.allIncludedIncludes = [[NSMutableArray alloc] initWithArray:self.allIncludedIncludes];

    NSArray* result = [x startWithString:@""];


    if (![[result objectAtIndex:0] isEqual:@"XML-File not found"])
    {
        // ... und hier mit den neu gefunden wieder gesetzt.
        [self.allFoundClasses setDictionary:[result objectAtIndex:0]];

        // Hier auch überschreiben, da ich ja die Werte mit übergeben hatte
        self.allIncludedIncludes = [[NSMutableArray alloc] initWithArray:[result objectAtIndex:1]];
    }
}




#pragma mark Delegate calls

- (void) parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
     attributes:(NSDictionary *)attributeDict
{

    // Ich bin nur an den Klassennamen interessiert...
    if ([elementName isEqualToString:@"class"])
    {
        NSString *name = [attributeDict valueForKey:@"name"];

        // Wir sammeln alle gefundenen 'name'-Attribute von class in einem eigenen Dictionary.
        // Weil die names können später eigene <tags> werden! Ich muss dann später darauf testen
        // ob das ELement vorher definiert wurde.
        // Als dazugehöriges Objekt setzen wir ein NSDictionary, in dem ALLE Attribute der Klasse
        // gesammelt werden.
        // Die direkt im Tag definierten werden direkt hier gesetzt.
        // Per <attribute> gesetzte werden später beim auslesen der Klasse ergänzt.

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:attributeDict copyItems:YES];
        // 'name' und 'extends' verwerte ich ja jeweils intern,
        // und brauche diese Attribute nicht mehr zu setzen.
        [dict removeObjectForKey:@"name"];
        [dict removeObjectForKey:@"extends"];

        [self.allFoundClasses setObject:dict forKey:name];
    }



    // ...und dadurch auch zwangsläufig an den includes.
    if ([elementName isEqualToString:@"include"] || [elementName isEqualToString:@"import"])
    {
        NSString *href = [attributeDict valueForKey:@"href"];

        if (![href hasSuffix:@".lzx"])
        {
            // Wegen Chapter 15, 3.1
            href = [NSString stringWithFormat:@"%@/library.lzx",href];
        }

        // Diese implizit inkludierten Files, können auch explizit gesetzt werden. Dann ignorieren.
        // Damit kein Fehler geworfen wird, hier abfangen und nicht rekursiv aufrufen.
        if (![href isEqualToString:@"lz/button.lzx"] &&
            ![href isEqualToString:@"lz/radio.lzx"] &&
            ![href isEqualToString:@"lz/list.lzx"] &&

            ![href isEqualToString:@"rpc/ajax.lzx"] &&

            ![href isEqualToString:@"base/basecomponent.lzx"] &&
            ![href isEqualToString:@"base/basevaluecomponent.lzx"] &&
            ![href isEqualToString:@"base/baseformitem.lzx"] &&
            ![href isEqualToString:@"base/baselistitem.lzx"] &&
            ![href isEqualToString:@"base/baselist.lzx"] &&
            ![href isEqualToString:@"base/basebutton.lzx"] &&

            ![href isEqualToString:@"incubator/base64.lzx"])
            [self callMyselfRecursive:href];
    }
}






@end
