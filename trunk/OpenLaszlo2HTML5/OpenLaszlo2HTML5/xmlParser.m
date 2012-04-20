//
//  xmlParser.m
//  OpenLaszlo2Canvas
//
//
//
//
// Bekannte Einschränkungen: simplelayout muss als erstes bei mehreren Geschwister-Elementen gesetzt werden, damit es sich auf alle Geschwister-Elemente beziehen kann
//
//
//
//
//
//
//  Created by Matthias Blanquett on 13.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

#import "xmlParser.h"

#import "globalVars.h"

#import "ausgabeText.h"

// Private Variablen
@interface xmlParser()

@property (strong, nonatomic) NSMutableString *log;

@property (strong, nonatomic) NSURL * pathToFile;

@property (strong, nonatomic) NSMutableArray *items;

@property (strong, nonatomic) NSMutableDictionary *bookInProgress;
@property (strong, nonatomic) NSString *keyInProgress;
@property (strong, nonatomic) NSMutableString *textInProgress;

@property (strong, nonatomic) NSString *enclosingElement;
@property (nonatomic) NSInteger tempVerschachtelungstiefe;

@property (strong, nonatomic) NSMutableString *output;
@property (strong, nonatomic) NSMutableString *jsOutput;
@property (strong, nonatomic) NSMutableString *jQueryOutput;
@property (strong, nonatomic) NSMutableString *jsHeadOutput;
@property (strong, nonatomic) NSMutableString *jsHead2Output; // die mit resource gesammelten globalen vars

@property (nonatomic) BOOL errorParsing;
@property (nonatomic) NSInteger viewIdZaehler;
@property (nonatomic) NSInteger verschachtelungstiefe;

@property (nonatomic) NSInteger simplelayout_y;
@property (strong, nonatomic) NSMutableArray *simplelayout_y_spacing;
@property (nonatomic) NSInteger firstElementOfSimpleLayout_y;
@property (nonatomic) NSInteger simplelayout_y_tiefe;

@property (nonatomic) NSInteger simplelayout_x;
@property (strong, nonatomic) NSMutableArray *simplelayout_x_spacing;
@property (nonatomic) NSInteger firstElementOfSimpleLayout_x;
@property (nonatomic) NSInteger simplelayout_x_tiefe;

@property (strong, nonatomic) NSString *last_resource_name_for_frametag;
@property (strong, nonatomic) NSMutableArray *collectedFrameResources;

// Damit ich auch intern auf die Inhalte der Variablen zugreifen kann
@property (strong, nonatomic) NSMutableDictionary *allJSGlobalVars;
@end




@implementation xmlParser
// public


// private
@synthesize log = _log;

@synthesize pathToFile = _pathToFile;

@synthesize items = _items,
bookInProgress = _bookInProgress, keyInProgress = _keyInProgress, textInProgress = _textInProgress;

@synthesize enclosingElement = _enclosingElement, tempVerschachtelungstiefe = _tempVerschachtelungstiefe;

@synthesize output = _output, jsOutput = _jsOutput, jQueryOutput = _jQueryOutput, jsHeadOutput = _jsHeadOutput, jsHead2Output = _jsHead2Output;

@synthesize errorParsing = _errorParsing, verschachtelungstiefe = _verschachtelungstiefe;

@synthesize viewIdZaehler = _viewIdZaehler;

@synthesize simplelayout_y = _simplelayout_y, simplelayout_y_spacing = _simplelayout_y_spacing;
@synthesize firstElementOfSimpleLayout_y = _firstElementOfSimpleLayout_y, simplelayout_y_tiefe = _simplelayout_y_tiefe;

@synthesize simplelayout_x = _simplelayout_x, simplelayout_x_spacing = _simplelayout_x_spacing;
@synthesize firstElementOfSimpleLayout_x = _firstElementOfSimpleLayout_x, simplelayout_x_tiefe = _simplelayout_x_tiefe;

@synthesize last_resource_name_for_frametag = _last_resource_name_for_frametag, collectedFrameResources = _collectedFrameResources;

@synthesize allJSGlobalVars = _allJSGlobalVars;




/********** Dirty Trick um NSLog umzuleiten *********/
// OpenLaszloLog
void OLLog(xmlParser *self, NSString* s,...)
{
    /*
    va_list arguments;
    va_start(arguments, s);

    NSObject *value;

    if ((value = va_arg(arguments, NSObject *)))
    {
        [[self log] appendString:[NSString stringWithFormat:s,@""]];
    }

    va_end(arguments);
     */

    [[self log] appendString:s];
    [[self log] appendString:@"\n"];
}


//1. Try: #define NSLog(...) OLLog(self,__VA_ARGS__)
//2. Try: #define NSLog(x,...) OLLog(self,x)
// Final Try:

//////////////////////////////////////////////
//#define NSLog(...) OLLog(self,__VA_ARGS__)//
//////////////////////////////////////////////
/********** Dirty Trick um NSLog umzuleiten *********/




-(id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"-init is not a valid initializer for the class xmlParser. use initWith:(NSURL*) pathToFile instead" userInfo:nil];
    //return nil;
    return [self initWith:[NSURL URLWithString:@""]];
}

// Eigener Konstruktor:
-(id)initWith:(NSURL*) pathToFile;
{
    if (self = [super init])
    {
        self.log = [[globalAccessToTextView textStorage] mutableString];

        self.pathToFile = pathToFile;

        self.items = [[NSMutableArray alloc] init];
        
        self.enclosingElement = @"";
        self.tempVerschachtelungstiefe = 1;
        
        self.output = [[NSMutableString alloc] initWithString:@""];
        self.jsOutput = [[NSMutableString alloc] initWithString:@""];
        self.jQueryOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsHeadOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsHead2Output = [[NSMutableString alloc] initWithString:@""];

        self.errorParsing = NO;
        self.verschachtelungstiefe = 0;
        self.viewIdZaehler = 0;

        self.simplelayout_y = 0;
        self.simplelayout_y_spacing = [[NSMutableArray alloc] init];
        self.firstElementOfSimpleLayout_y = YES;
        self.simplelayout_y_tiefe = 0;

        self.simplelayout_x = 0;
        self.simplelayout_x_spacing = [[NSMutableArray alloc] init];
        self.firstElementOfSimpleLayout_x = YES;
        self.simplelayout_x_tiefe = 0;

        self.last_resource_name_for_frametag = [[NSString alloc] initWithString:@""];
        self.collectedFrameResources = [[NSMutableArray alloc] init];

        self.allJSGlobalVars = [[NSMutableDictionary alloc] initWithCapacity:200];
    }
    return self;
}


-(NSArray*) start
{
    // NSLog(@"GATTV: %@",[[globalAccessToTextView textStorage] string]);
    // NSLog(@"SharedSingleton: %@",[[sharedSingleton.textView textStorage] string]);
    // [[[sharedSingleton.textView textStorage] mutableString] appendString: @"Dahinter"];
    // [self.log appendString:@"Länger und"];
    // OLLog(self, @"sogar noch länger");



    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self.pathToFile path]];
    if (!fileExists)
    {
        NSLog(@"XML-File not found. Did you initialise with initWith: pathTofile?");
        exit(0); // Dann aussteigen
    }

    // Create a parser
    // NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xml];
    // Die alte Lösung mit Data war nicht perfekt. Per URL ist besser:
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:self.pathToFile];
    [parser setDelegate:self];

    // You may need to turn some of these on depending on the type of XML file you are parsing
    /*
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser setShouldResolveExternalEntities:NO];
     */

    // Do the parse
    [parser parse];
    // NSLog(@"items = %@", self.items);

    // Zur Sicherheit mache ich von allem ne Copy, nicht, dass es beim Verlassen der Rekursion zerstört wird
    NSArray *r = [NSArray arrayWithObjects:[self.output copy],[self.jsOutput copy],[self.jQueryOutput copy],[self.jsHeadOutput copy],[self.jsHead2Output copy],[self.allJSGlobalVars copy], nil];
    return r;
}



- (void) rueckeMitLeerzeichenEin:(NSInteger)n
{
    for (int i = 0; i<n; i++)
    {
        [self.output appendString:@"  "];
    }
}



- (NSMutableString*) addCSSAttributes:(NSDictionary*) attributeDict
{
    // Alle Styles in einem eigenen String sammeln, könnte nochmal nützlich werden
    NSMutableString *style = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"bgcolor"])
    {
        NSLog(@"Setting the attribute 'bgcolor' as CSS 'background-color'.");
        [style appendString:@"background-color:"];
        [style appendString:[attributeDict valueForKey:@"bgcolor"]];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"fgcolor"])
    {
        NSLog(@"Setting the attribute 'fgcolor' as CSS 'color'.");
        [style appendString:@"color:"];
        [style appendString:[attributeDict valueForKey:@"fgcolor"]];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"valign"])
    {
        NSLog(@"Setting the attribute 'valign' as CSS 'vertical-align'.");
        [style appendString:@"vertical-align:"];
        [style appendString:[attributeDict valueForKey:@"valign"]];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"height"])
    {
        NSLog(@"Setting the attribute 'height' as CSS 'height'.");
        [style appendString:@"height:"];

        if ([[attributeDict valueForKey:@"height"] rangeOfString:@"${parent.height}"].location != NSNotFound)
        {
            [style appendString:@"inherit"];
        }
        else
        {
            [style appendString:[attributeDict valueForKey:@"height"]];
            if ([[attributeDict valueForKey:@"height"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
        }

        [style appendString:@";"];
    }

    // speichern, falls width schon gesetz wurde für Attribut resource
    BOOL widthGesetzt = NO;
    if ([attributeDict valueForKey:@"width"])
    {
        NSLog(@"Setting the attribute 'width' as CSS 'width'.");
        [style appendString:@"width:"];

        if ([[attributeDict valueForKey:@"width"] rangeOfString:@"${parent.width}"].location != NSNotFound)
        {
            [style appendString:@"inherit"];
        }
        else
        {
            [style appendString:[attributeDict valueForKey:@"width"]];
            if ([[attributeDict valueForKey:@"width"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
        }
        [style appendString:@";"];

        widthGesetzt = YES;
    }

    if ([attributeDict valueForKey:@"x"])
    {
        NSLog(@"Setting the attribute 'x' as CSS 'left'.");
        [style appendString:@"left:"];
        [style appendString:[attributeDict valueForKey:@"x"]];
        if ([[attributeDict valueForKey:@"x"] rangeOfString:@"%"].location == NSNotFound)
            [style appendString:@"px"];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"y"])
    {
        NSLog(@"Setting the attribute 'y' as CSS 'top'.");
        [style appendString:@"top:"];
        [style appendString:[attributeDict valueForKey:@"y"]];
        if ([[attributeDict valueForKey:@"y"] rangeOfString:@"%"].location == NSNotFound)
            [style appendString:@"px"];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"resource"])
    {
        NSLog(@"Setting the attribute 'ressource' as CSS 'background-image:url()");
        NSString *s = @"";

        // Wenn ein Punkt enthalten ist, ist es wohl eine Datei
        if ([[attributeDict valueForKey:@"resource" ] rangeOfString:@"."].location != NSNotFound)
        {
            //Möglichkeit 1: Resource wird direkt als String angegeben!
            s = [attributeDict valueForKey:@"resource"];


        }
        else
        {
            // Möglichkeit 2: Resource wurde vorher extern gesetzt
            
            // Namen des Bildes aus eigener vorher angelegter Res-DB ermitteln
            if ([[self.allJSGlobalVars valueForKey:[attributeDict valueForKey:@"resource"]] isKindOfClass:[NSArray class]])
            {
                s = [[self.allJSGlobalVars valueForKey:[attributeDict valueForKey:@"resource"]] objectAtIndex:0];
            }
            else
            {
                s = [self.allJSGlobalVars valueForKey:[attributeDict valueForKey:@"resource"]];
            }
        }



        NSLog(@"Untersuche das Bild auf Dateiebene");
        // Dann erstmal width und height von dem Image auf Dateiebene ermitteln
        NSURL *path = [self.pathToFile URLByDeletingLastPathComponent];

        NSURL *pathToImg = [NSURL URLWithString:s relativeToURL:path];

        // [NSString stringWithFormat:@"%@%@",path,s];
        NSLog([NSString stringWithFormat:@"Path to Image: %@",pathToImg]);
        NSImage *image = [[NSImage alloc] initByReferencingURL:pathToImg];
        NSSize dimensions = [image size];
        NSInteger w = (int) dimensions.width;
        NSInteger h = (int) dimensions.height;
        NSLog([NSString stringWithFormat:@"Resolving width of image from original file: %d",w]);
        NSLog([NSString stringWithFormat:@"Resolving height of Image from original file: %d",h]);
        if (!widthGesetzt)
            [style appendString:[NSString stringWithFormat:@"width:%dpx;",w]];
        // Height setzen wir erstmal immer, später ändern? (ToDo)
        [style appendString:[NSString stringWithFormat:@"height:%dpx;",h]];

        [style appendString:@"background-image:url("];
        [style appendString:s];
        [style appendString:@");"];
    }

    return style;
}






- (NSMutableString*) addJSCode:(NSDictionary*) attributeDict withId:(NSString*)idName
{
    // Den ganzen Code in einem eigenen String sammeln, und nur JS ausgeben, wenn gefüllt
    NSMutableString *code = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"visible"])
    {
        NSLog(@"Setting the attribute 'visible' as JS.");

        // Remove all occurrences of $,{,}
        NSString *s = [attributeDict valueForKey:@"visible"];
        s = [s stringByReplacingOccurrencesOfString:@"$" withString:@""];
        s = [s stringByReplacingOccurrencesOfString:@"{" withString:@""];
        s = [s stringByReplacingOccurrencesOfString:@"}" withString:@""];

        [code appendString:s];
        [code appendString:@" ? document.getElementById('"];
        [code appendString:idName];
        [code appendString:@"').style.visibility = 'visible' : document.getElementById('"];
        [code appendString:idName];
        [code appendString:@"').style.visibility = 'hidden';"];
    }


    NSMutableString *rueckgabe = [[NSMutableString alloc] initWithString:@""];
    if ([code length] > 0)
    {
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];

        [rueckgabe appendString:@"<script type=\"text/javascript\">"];
        [rueckgabe appendString:code];
        [rueckgabe appendString:@"</script>\n"];
    }
    return rueckgabe;
}




// Die ID ermitteln (für simplelayout) - auch canvas muss als view mitgezählt werden
- (NSString*) addIdToElement
{


    NSString *id = [[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler];

    // alle views kriegen eine id verpasst (u. a. wegen Simplelayout)
    [self.output appendString:@" id=\"view"];
    [self.output appendString:id];
    [self.output appendString:@"\""];

    return id;
}



- (void) check4Simplelayout
{
    // ToDo: Umbennen: Ist kein viewIdZaehler mehr, sondern eine IdZaehler
    self.viewIdZaehler++;

    // simplelayout verlassen, alsbald das letzte Geschwisterchen erreicht ist
    BOOL wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y = NO;
    if (self.simplelayout_y-1 == self.verschachtelungstiefe)
    {
        self.simplelayout_y = 0;
        [self.simplelayout_y_spacing removeLastObject];
        self.firstElementOfSimpleLayout_y = YES;
        self.simplelayout_y_tiefe--;
        
        // Wenn wir ein tiefer verschachteltes simlelayout gerade verlassen, merken wir uns das
        // das heißt ein anderes simplelayout (y) ist noch aktiv
        if (self.simplelayout_y_tiefe > 0)
            wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y = YES;
    }
    
    
    // simplelayout verlassen, alsbald das letzte Geschwisterchen erreicht ist
    BOOL wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X = NO;
    if (self.simplelayout_x-1 == self.verschachtelungstiefe)
    {
        self.simplelayout_x = 0;
        [self.simplelayout_x_spacing removeLastObject];
        self.firstElementOfSimpleLayout_x = YES;
        self.simplelayout_x_tiefe--;


        // Wenn wir ein tiefer verschachteltes simlelayout gerade verlassen, merken wir uns das
        // das heißt ein anderes simplelayout (x) ist noch aktiv
        if (self.simplelayout_x_tiefe > 0)
            wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X = YES;
    }






    NSString *id = [[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler];
    // Hol die aktuell geltende SpacingHöhe (für Simplelayout Y + x)
    NSInteger spacing_y = [[self.simplelayout_y_spacing lastObject] integerValue];
    NSInteger spacing_x = [[self.simplelayout_x_spacing lastObject] integerValue];

    // Simplelayout Y
    if (wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y)
    {
        // If-Abfrage bauen
        [self.jsOutput appendString:@"if (document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling && document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild)\n"];
        
        [self.jsOutput appendString:@"  document.getElementById('view"];
        [self.jsOutput appendString:id];
        
        // parseInt removes the "px" at the end
        [self.jsOutput appendString:@"').style.top = (parseInt(document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild.offsetTop)+parseInt(document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild.style.height)+"];
        [self.jsOutput appendString:[NSString stringWithFormat:@"%d", spacing_y]];
        [self.jsOutput appendString:@") + \"px\";\n\n"];
        
        wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y = NO;
    }
    else if (self.simplelayout_y == self.verschachtelungstiefe)  // > 0)
    {
        if (!self.firstElementOfSimpleLayout_y)
        {
            // Den allerersten sippling auslassen
            [self.jsOutput appendString:@"if (document.getElementById('view"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling)\n"];
            
            [self.jsOutput appendString:@"  document.getElementById('view"];
            [self.jsOutput appendString:id];
            
            // parseInt removes the "px" at the end
            [self.jsOutput appendString:@"').style.top = (parseInt(document.getElementById('view"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling.offsetTop)+parseInt(document.getElementById('view"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling.style.height)+"];
            [self.jsOutput appendString:[NSString stringWithFormat:@"%d", spacing_y]];
            [self.jsOutput appendString:@") + \"px\";\n\n"];
        }
        self.firstElementOfSimpleLayout_y = NO;
    }
    
    
    
    // Simplelayout X
    if (wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X)
    {
        // If-Abfrage bauen
        [self.jsOutput appendString:@"if (document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling && document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild)\n"];
        
        [self.jsOutput appendString:@"  document.getElementById('view"];
        [self.jsOutput appendString:id];
        
        // parseInt removes the "px" at the end
        [self.jsOutput appendString:@"').style.left = (parseInt(document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild.offsetLeft)+parseInt(document.getElementById('view"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild.offsetWidth)+"];
        [self.jsOutput appendString:[NSString stringWithFormat:@"%d", spacing_x]];
        [self.jsOutput appendString:@") + \"px\";\n\n"];
        
        wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X = NO;
    }
    else if (self.simplelayout_x == self.verschachtelungstiefe) // > 0)
    {
        if (!self.firstElementOfSimpleLayout_x)
        {
            // Den allerersten sippling auslassen
            [self.jsOutput appendString:@"if (document.getElementById('view"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling)\n"];
            
            [self.jsOutput appendString:@"  document.getElementById('view"];
            [self.jsOutput appendString:id];
            
            // parseInt removes the "px" at the end
            [self.jsOutput appendString:@"').style.left = (parseInt(document.getElementById('view"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling.offsetLeft)+parseInt(document.getElementById('view"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling.offsetWidth)+"];
            [self.jsOutput appendString:[NSString stringWithFormat:@"%d", spacing_x]];
            [self.jsOutput appendString:@") + \"px\";\n\n"];
        }
        self.firstElementOfSimpleLayout_x = NO;
    }
}



#pragma mark Delegate calls

- (void) parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
     attributes:(NSDictionary *)attributeDict
{



    self.verschachtelungstiefe++;

    NSLog([NSString stringWithFormat:@"Opening Element: %@", elementName]);
    NSLog([NSString stringWithFormat:@"with these attributes: %@\n", attributeDict]);

    // This is a string we will append to as the text arrives
    self.textInProgress = [[NSMutableString alloc] init];

    // Kann ich eventuell noch gebrauchen um das aktuelle Tag abzufragen
    self.keyInProgress = [elementName copy];


    if ([elementName isEqualToString:@"window"] ||
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"BDSedit"] ||
        [elementName isEqualToString:@"BDStext"] ||
        [elementName isEqualToString:@"rollUpDown"])
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];




    if ([elementName isEqualToString:@"include"])
    {
        NSLog(@"Include Tag found!");
        NSLog(@"Calling myself recursive");
        if (![attributeDict valueForKey:@"href"])
            NSLog(@"ERROR: No src given in include-tag");

        NSURL *path = [self.pathToFile URLByDeletingLastPathComponent];
        NSURL *pathToInclude = [NSURL URLWithString:[attributeDict valueForKey:@"href"] relativeToURL:path];

        xmlParser *x = [[xmlParser alloc] initWith:pathToInclude];
        NSArray* result = [x start];

        [self.output appendString:[result objectAtIndex:0]];
        [self.jsOutput appendString:[result objectAtIndex:1]];
        [self.jQueryOutput appendString:[result objectAtIndex:2]];
        [self.jsHeadOutput appendString:[result objectAtIndex:3]];
        [self.jsHead2Output appendString:[result objectAtIndex:4]];
        [self.allJSGlobalVars addEntriesFromDictionary:[result objectAtIndex:5]];


        NSLog(@"Leaving recursion");
    }





    if ([elementName isEqualToString:@"canvas"])
    {
        [self check4Simplelayout];


        [self.output appendString:@"<div"];

        [self addIdToElement];

        [self.output appendString:@" class=\"ol_standard_canvas\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];
    }


    if ([elementName isEqualToString:@"resource"])
    {
         // Falls src angegeben ist, kann die var direkt gespeichert werden.
        if ([attributeDict valueForKey:@"src"])
        {
            [self.jsHeadOutput appendString:@"var "];
            [self.jsHeadOutput appendString:[attributeDict valueForKey:@"name"]];
            [self.jsHeadOutput appendString:@" = \""];
            [self.jsHeadOutput appendString:[attributeDict valueForKey:@"src"]];
            [self.jsHeadOutput appendString:@"\";\n"];

            // Auch intern die Var speichern
            [self.allJSGlobalVars setObject:[attributeDict valueForKey:@"src"] forKey:[attributeDict valueForKey:@"name"]];
        }
        else if ([attributeDict valueForKey:@"name"])
        {
            // Ansonsten machen wir im tag 'frame' weiter
            self.last_resource_name_for_frametag = [attributeDict valueForKey:@"name"];
        }
    }




    // ToDo: -Hier ist noch viel zu tun: Nur bei boolean bisher die Quotes entfernt
    // ToDo: -wir legen jedesmal ein neues Objekt an, das darf nur einmal geschehen
    if ([elementName isEqualToString:@"attribute"])
    {
        // ToDo: Attrbute kann bis jetzt nur globale Variable handeln, die direkt in canvas liegen
        if ([attributeDict valueForKey:@"name"])
        {
            BOOL weNeedQuotes = YES;
            if ([[attributeDict valueForKey:@"type"] isEqualTo:@"boolean"])
                weNeedQuotes = NO;
            // [self.jsHead2Output appendString:@"var "]; -> Wir lösen es mal als Objekt und schauen mal: ToCheck
            [self.jsHead2Output appendString:@"canvas=new Object();\ncanvas."]; // ToDo, ToDo, ToDo: Hard coded Trick
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"name"]];
            [self.jsHead2Output appendString:@" = "];
            if (weNeedQuotes)
                [self.jsHead2Output appendString:@"\""];
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"value"]];
            if (weNeedQuotes)
                [self.jsHead2Output appendString:@"\""];
            [self.jsHead2Output appendString:@";\n"];

            // Auch intern die Var speichern? Erstmal nein
            // [self.allJSGlobalVars setObject:[attributeDict valueForKey:@"src"] forKey:[attributeDict valueForKey:@"name"]];
        }
    }






    if ([elementName isEqualToString:@"frame"])
    {
        // Erstmal alle frame-Einträge sammeln, weil wir nicht wissen wie viele noch kommen
        [self.collectedFrameResources addObject:[attributeDict valueForKey:@"src"]];
    }

    if ([elementName isEqualToString:@"window"])
    {
        [self.output appendString:@"<div class=\"ol_standard_window\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];
    }




    if ([elementName isEqualToString:@"simplelayout"])
    {
        // Simplelayout mit Achse Y berücksichtigen
        if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"y"])
        {
            // Anstatt nur TRUE gleichzeitig darin die Verschachtelungstiefe speichern
            // somit wird simplelayout nur in der richtigen Element-Ebene angewandt
            self.simplelayout_y = self.verschachtelungstiefe;

            // spacing müssen wir auch sichern und später berücksichtigen
            if ([attributeDict valueForKey:@"spacing"])
            {
                [self.simplelayout_y_spacing addObject:[attributeDict valueForKey:@"spacing"]];
            }
            else
            {
                [self.simplelayout_y_spacing addObject:@"0"];
            }

            self.simplelayout_y_tiefe++;

            /*******************/
            // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Größe an der beinhaltenden Elemente
            // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
            // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
            [self.jsOutput appendString:@"// Alle nachfolgenden Simplelayouts sollen entsprechend der Breite des vorherigen Divs aufrücken\n"];

            // If-Abfrage drum herum als Schutz gegen unbekannte Elemente oder wenn simplelayout das letzte Element
            // mehrerer Geschwister ist, was nicht unterstützt wird
            [self.jsOutput appendString:@"if (document.getElementById('view"];
            [self.jsOutput appendString:[[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler]];
            [self.jsOutput appendString:@"').lastElementChild)\n"];

            [self.jsOutput appendString:@"  document.getElementById('view"];
            [self.jsOutput appendString:[[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler]];
            [self.jsOutput appendString:@"').style.width = document.getElementById('view"];
            [self.jsOutput appendString:[[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler]];
            // ToDo: Hier muss ich eigentlich dasjenige Kind suchen, welches die größte Breite hat
            [self.jsOutput appendString:@"').lastElementChild.style.width"];
            [self.jsOutput appendString:@";\n\n"];
            /*******************/
        }



        // Simplelayout mit Achse X berücksichtigen
        if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"x"])
        {
            // Anstatt nur TRUE gleichzeitig darin die Verschachtelungstiefe speichern
            // somit wird simplelayout nur in der richtigen Element-Ebene angewandt
            self.simplelayout_x = self.verschachtelungstiefe;

            // spacing müssen wir auch sichern und später berücksichtigen
            if ([attributeDict valueForKey:@"spacing"])
            {
                [self.simplelayout_x_spacing addObject:[attributeDict valueForKey:@"spacing"]];
            }
            else
            {
                [self.simplelayout_x_spacing addObject:@"0"];
            }

            self.simplelayout_x_tiefe++;


            /*******************/
            // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Größe an der beinhaltenden Elemente
            // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
            // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
            [self.jsOutput appendString:@"// Alle nachfolgenden Simplelayouts sollen entsprechend der Höhe des vorherigen Divs aufrücken\n"];

            // If-Abfrage drum herum als Schutz gegen unbekannte Elemente oder wenn simplelayout das letzte Element
            // mehrerer Geschwister ist, was nicht unterstützt wird
            [self.jsOutput appendString:@"if (document.getElementById('view"];
            [self.jsOutput appendString:[[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler]];
            [self.jsOutput appendString:@"').lastElementChild)\n"];

            [self.jsOutput appendString:@"  document.getElementById('view"];
            [self.jsOutput appendString:[[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler]];
            [self.jsOutput appendString:@"').style.height = document.getElementById('view"];
            [self.jsOutput appendString:[[NSString alloc] initWithFormat:@"%d", self.viewIdZaehler]];
            // ToDo: Hier muss ich eigentlich dasjenige Kind suchen, welches die größte height hat
            [self.jsOutput appendString:@"').lastElementChild.style.height"];
            [self.jsOutput appendString:@";\n\n"];
            /*******************/
        }
    }













    if ([elementName isEqualToString:@"view"] || [elementName isEqualToString:@"basebutton"])
    {
        [self check4Simplelayout];

        [self.output appendString:@"<div"];


        // id hinzufügen und gleichzeitg speichern
        NSString *id = [self addIdToElement];


        [self.output appendString:@" class=\"ol_standard_view\" style=\""];


        [self.output appendString:[self addCSSAttributes:attributeDict]];








        [self.output appendString:@"\">\n"];

        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"view%@",id]]];
    }






    // ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand der definierten Klasse erkannt werden
    if ([elementName isEqualToString:@"BDStext"])
    {
        [self check4Simplelayout];

        [self.output appendString:@"<div"];

        [self addIdToElement];

        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];

        if ([attributeDict valueForKey:@"text"])
        {
            [self.output appendString:[attributeDict valueForKey:@"text"]];
        }
    }


    // ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand der definierten Klasse erkannt werden
    if ([elementName isEqualToString:@"BDSedit"])
    {
        [self check4Simplelayout];

        [self.output appendString:@"<input type=\"text\""];

        [self addIdToElement];

        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\" />\n"];
    }






    // Das äußere Div behält die selbst generierte ID, die beiden inneren DIVs erhalten die
    // in OpenLaszlo gesetzte Original-ID
    if ([elementName isEqualToString:@"rollUpDown"])
    {
        [self check4Simplelayout];

        [self.output appendString:@"<div "];

        [self addIdToElement];

        [self.output appendString:@" style=\"width:inherit;height:inherit;"];

        // [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

        /* *************CANVAS***************VERWORFEN************* SPÄTER NUTZEN FÜR DIE RUNDEN ECKEN
        [self.output appendString:@"<canvas style=\"position:absolute; top:37px; left:81px;\" id=\"leiste\" width=\"500\" height=\"200\"></canvas>"];

        [self.output appendString:@"<canvas style=\"position:absolute; top:61px; left:81px;\" id=\"details\" width=\"500\" height=\"200\"></canvas>"];

        // <!-- Div für den Klick-Button auf dem Dreieck -->
        [self.output appendString:@"<div style=\"position:absolute; top:12px; left:82px;\" id=\"container\"></div>"];

        [self.output appendString:@"<div style=\"top:38px;left:82px;height:22px;width:225px;position:absolute;\" onClick=\"touchStart(event)\">"];
        [self.output appendString:@"<script src=\"jsHelper.js\" type=\"text/javascript\"></script>\n"];
         */


        // Die id ermitteln
        NSString *id4flipleiste;
        NSString *id4panel;
        if ([attributeDict valueForKey:@"id"])
        {
            id4flipleiste = [attributeDict valueForKey:@"id"];
            id4panel = [NSString stringWithFormat:@"%@_panel",[attributeDict valueForKey:@"id"]];
        }
        else
        {
            //Sollte eigentlich nicht vorkommen, dass wir hier reinrutschen
            id4flipleiste = [NSString stringWithFormat:@"flipleiste_%d",1];
            id4panel = [NSString stringWithFormat:@"panel_%d",1];
        }

        // Text für Titelleiste ermitteln
        NSString *title = @"";
        if ([attributeDict valueForKey:@"header"])
        {
            title = [attributeDict valueForKey:@"header"];
        }

        int heightOfFlipBar = 30;
        
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<!-- Die Flipleiste -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:[NSString stringWithFormat:@"<div style=\"position:absolute; top:0px; left:0px; width:inherit; height:%dpx; background-color:lightblue; line-height: %dpx; vertical-align:middle;\" id=\"",heightOfFlipBar]];
        [self.output appendString:id4flipleiste];
        [self.output appendString:@"\"><span style=\"margin-left:8px;\">"];
        [self.output appendString:title];
        [self.output appendString:@"</span></div>\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<!-- Das aufklappende Menü -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:[NSString stringWithFormat:@"<div style=\"position:absolute; top:%dpx; left:0px; width:inherit; height:inherit; background-color:white;\" id=\"",heightOfFlipBar]];
        [self.output appendString:id4panel];
        [self.output appendString:@"\"></div>\n"];

        // Die jQuery-Ausgabe
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"$(\"#%@\").click(function(){$(\"#%@\").slideToggle(\"slow\");});\n",id4flipleiste,id4panel]];
    }








    if ([elementName isEqualToString:@"text"])
    {
        // Text mit foundCharacters sammeln und beim schließen anzeigen
    }









    // 'attribute' muss wissen in welchem umschließenen Tag wir uns befinden
    if (self.tempVerschachtelungstiefe == self.verschachtelungstiefe)
    {
        // ToDo // ToDo // ToDO
        self.enclosingElement = elementName;
        self.tempVerschachtelungstiefe = self.verschachtelungstiefe;
    }
}


// ToDo: Später als Kategorie in NSObject packen oder in MyToolBox
static inline BOOL isEmpty(id thing)
{
    return thing == nil
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0);
}


- (void) parser:(NSXMLParser *)parser
  didEndElement:(NSString *)elementName
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"window"] || [elementName isEqualToString:@"view"])
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

    self.verschachtelungstiefe--;

    NSLog([NSString stringWithFormat:@"Closing Element: %@\n", elementName]);

    // Schließen von canvas oder windows
    if ([elementName isEqualToString:@"canvas"] || [elementName isEqualToString:@"window"])
    {
        [self.output appendString:@"</div>\n"];
    }


    if ([elementName isEqualToString:@"text"])
    {
        [self.output appendString:self.textInProgress];
        [self.output appendString:@"\n"];
    }




    if ([elementName isEqualToString:@"simplelayout"])
    {

    }



    if ([elementName isEqualToString:@"resource"])
    {
        // Dann gab es keine frame-tags
        if ([self.collectedFrameResources count] == 0)
            return;

        // Erst nachdem die Resource beendet wurde wissen wir ob wir ein Array anlegen müssen oder nicht
        if ([self.collectedFrameResources count] == 1)
        {
            [self.jsHeadOutput appendString:@"var "];
            [self.jsHeadOutput appendString:self.last_resource_name_for_frametag];
            [self.jsHeadOutput appendString:@" = \""];
            [self.jsHeadOutput appendString:[self.collectedFrameResources objectAtIndex:0]];
            [self.jsHeadOutput appendString:@"\";\n"];
        }
        else // Okay, mehrere Einträge vorhanden, also müssen wir ein Array anlegen
        {
            [self.jsHeadOutput appendString:@"var "];
            [self.jsHeadOutput appendString:self.last_resource_name_for_frametag];
            [self.jsHeadOutput appendString:@" = new Array();\n"];
            for (int i=0; i<[self.collectedFrameResources count]; i++)
            {
                [self.jsHeadOutput appendString:self.last_resource_name_for_frametag];
                [self.jsHeadOutput appendString:@"["];
                [self.jsHeadOutput appendString:[NSString stringWithFormat:@"%d" ,i]];
                [self.jsHeadOutput appendString:@"] = \""];
                [self.jsHeadOutput appendString:[self.collectedFrameResources objectAtIndex:i]];
                [self.jsHeadOutput appendString:@"\"\n"];
            }
            [self.jsHeadOutput appendString:@"\n"];
        }


        // Auch intern die Var speichern - ich muss es kopieren, sonst wird es ja gleich gelöscht
        [self.allJSGlobalVars setObject:[self.collectedFrameResources copy] forKey:self.last_resource_name_for_frametag];


        // Und das Array wieder leeren
        [self.collectedFrameResources removeAllObjects];
        // und den brauchen wir auch nicht mehr
        self.last_resource_name_for_frametag = [[NSString alloc] initWithString:@""];
    }



    if ([elementName isEqualToString:@"frame"])
    {

    }





    if ([elementName isEqualToString:@"attribute"])
    {

    }




    // Schließen von view
    if ([elementName isEqualToString:@"view"] || [elementName isEqualToString:@"basebutton"])
    {
        [self.output appendString:@"</div>\n"];
    }


    // Schließen von BDStext
    if ([elementName isEqualToString:@"BDStext"])
    {
        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        [self.output appendString:self.textInProgress];

        [self.output appendString:@"</div>\n"];
    }

    // Schließen von BDSedit
    if ([elementName isEqualToString:@"BDSedit"])
    {
        // Nichts, da kein schließendes Tag gesetzt werden muss
    }



    if ([elementName isEqualToString:@"rollUpDown"])
    {
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"</div>\n"];
    }




    /*
    if ([elementName isEqual:@"Item"])
    {
        [self.items addObject:self.bookInProgress];

        // Clear the current item
        self.bookInProgress = nil;
        return;
    }
     */

    // Clear the text and key
    self.textInProgress = nil;
    self.keyInProgress = nil;
}

// This method can get called multiple times for the
// text in a single element
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [self.textInProgress appendString:string];
}


- (void) parserDidStartDocument:(NSXMLParser *)parser
{
    NSLog(@"File found and parsing started");
}





- (void) parserDidEndDocument:(NSXMLParser *)parser
{
    // Move NSTextView to the end
    NSRange range;
    range = NSMakeRange ([[globalAccessToTextView string] length], 0);
    [globalAccessToTextView scrollRangeToVisible: range];


    NSMutableString *pre = [[NSMutableString alloc] initWithString:@""];

    [pre appendString:@"<!DOCTYPE HTML>\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n<meta http-equiv=\"pragma\" content=\"no-cache\">\n<meta http-equiv=\"cache-control\" content=\"no-cache\">\n<meta http-equiv=\"expires\" content=\"0\">\n<title>Canvastest</title>\n<link rel=\"stylesheet\" type=\"text/css\" href=\"formate.css\">\n<!--[if IE]><script src=\"excanvas.js\"></script><![endif]-->\n<script type=\"text/javascript\" src=\"jquery172.js\"></script>\n<style type='text/css'>body { text-align: center; }</style>\n\n<script type=\"text/javascript\">\n"];

    // [pre appendString:self.jsHeadOutput]; 

    // erstmal nur die mit resource gesammelten globalen vars ausgeben
    [pre appendString:self.jsHead2Output];
    [pre appendString:@"</script>\n\n</head>\n\n<body style=\"margin:0px;\">\n"];


    // Kurzer Tausch damit ich den Header davorschalten kann
    NSMutableString *temp = [[NSMutableString alloc] initWithString:self.output];
    self.output = [[NSMutableString alloc] initWithString:pre];
    [self.output appendString:temp];


    // Füge noch die nötigen JS ein:
    [self.output appendString:@"\n<script type=\"text/javascript\">\n"];
    [self.output appendString:self.jsOutput];
    [self.output appendString:@"\n\n$(function()\n{\n  "];
    [self.output appendString:self.jQueryOutput];
    [self.output appendString:@"\n});\n</script>\n\n"];

    // Und nur noch die schließenden Tags
    [self.output appendString:@"</body>\n</html>"];

    // Path zum speichern ermitteln
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    NSString *dlDirectory = [paths objectAtIndex:0];
    NSString * path = [[NSString alloc] initWithString:dlDirectory];
    path = [path stringByAppendingString: @"/output_ol2x.html"];

    // NSLog(@"%@",path);

    if (self.errorParsing == NO)
    {
        NSLog(@"XML processing done! Writing file...");

        // Schreiben einer Datei per NSData:
        // NSData* data = [self.output dataUsingEncoding:NSUTF8StringEncoding];
        // [data writeToFile:@"output_ol2x.html" atomically:NO];
        

        // Aber wir machen es direkt über den String:
        bool success = [self.output writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];

        if (success)
            NSLog(@"...done.");
        else
            NSLog(@"...failed.");
    }
    else
    {
        NSLog(@"Error occurred during XML processing");
    }
}




- (void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSString *errorString = [NSString stringWithFormat:@"Error code %i", [parseError code]];
    NSLog([NSString stringWithFormat:@"Error parsing XML: %@", errorString]);

    if ([errorString hasSuffix:@"5"])
    {
        NSLog(@"XML-Dokument unvollständig geladen bzw Datei nicht vorhanden bzw kein vollständiges XML-Tag enthalten.");
    }
    
    self.errorParsing=YES;
}


/********** Dirty Trick um NSLog umzuleiten *********/
// Wieder zurückdefinieren:
#undef NSLog
/********** Dirty Trick um NSLog umzuleiten *********/

@end
