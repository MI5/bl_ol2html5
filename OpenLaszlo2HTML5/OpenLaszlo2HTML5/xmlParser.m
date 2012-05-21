//
//  xmlParser.m
//  OpenLaszlo2Canvas
//
//
//
//
// Bekannte Einschränkungen: simplelayout muss als erstes bei mehreren Geschwister-
// Elementen gesetzt werden, damit es sich auf alle Geschwister-Elemente beziehen kann
//
//
// Nach verdammt viel hin und her, ist die derzeitige Lösung: Standard ist position:relative;
// Aber sobald x oder y gesetzt wird gilt position:absolute; (somit auch bei Bildern)
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

// Als Property eingeführt, damit ich zwischendurch auch Zugriff
// auf den Parser habe und diesen abbrechen kann.
@property (strong, nonatomic) NSXMLParser *parser;

@property (nonatomic) BOOL isRecursiveCall;

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
@property (strong, nonatomic) NSMutableString *jsOLClassesOutput; // Gefundene <class> werden hier gesammelt
@property (strong, nonatomic) NSMutableString *jQueryOutput0;
@property (strong, nonatomic) NSMutableString *jQueryOutput;
@property (strong, nonatomic) NSMutableString *jsHeadOutput;
@property (strong, nonatomic) NSMutableString *jsHead2Output;   // die mit resource gesammelten globalen vars
                                                                // (+ globale Funktionen + globales gefundenes JS)

@property (strong, nonatomic) NSMutableString *cssOutput; // CSS-Ausgaben, die gesammelt werden, derzeit @Font-Face

@property (strong, nonatomic) NSMutableString *externalJSFilesOutput; // per <script src=''> angegebene externe Skripte

@property (strong, nonatomic) NSMutableString *collectedContentOfClass;

@property (nonatomic) BOOL errorParsing;
@property (nonatomic) NSInteger idZaehler;
@property (nonatomic) NSInteger elementeZaehler;
@property (strong, nonatomic) NSString* element_merker; // Für <class>, um erkennen zu können, ob sich das Tag sich direkt wieder schließt: <tag />
@property (nonatomic) NSInteger verschachtelungstiefe;

// je tiefer die Ebene, desto mehr muss ich einrücken
@property (nonatomic) NSInteger rollUpDownVerschachtelungstiefe;

@property (nonatomic) NSInteger simplelayout_y;
@property (strong, nonatomic) NSMutableArray *simplelayout_y_spacing;
@property (nonatomic) NSInteger firstElementOfSimpleLayout_y;
@property (nonatomic) NSInteger simplelayout_y_tiefe;

@property (nonatomic) NSInteger simplelayout_x;
@property (strong, nonatomic) NSMutableArray *simplelayout_x_spacing;
@property (nonatomic) NSInteger firstElementOfSimpleLayout_x;
@property (nonatomic) NSInteger simplelayout_x_tiefe;

// So können wir stets die von OpenLaszlo gesetzten ids benutzen
@property (strong, nonatomic) NSString* zuletztGesetzteID;

@property (strong, nonatomic) NSString *last_resource_name_for_frametag;
@property (strong, nonatomic) NSMutableArray *collectedFrameResources;

// Für das Element dataset, um die Variablen für das JS-Array durchzählen zu können
@property (nonatomic) int datasetItemsCounter;

// Für jeden Container die Elemente durchzählen, um den Abstand regeln zu können
@property (strong, nonatomic) NSMutableArray *rollupDownElementeCounter;

// Für das Element RollUpDownContainer
@property (strong, nonatomic) NSString *animDuration;

// jQuery UI braucht bei jedem auftauchen eines neuen Tabsheets-elements den Namen des aktuellen Tabsheets,
// um dieses per add einfügen zu können
// Außerdem wird, wenn diese Variable gesetzt wurde, und somit im Quellcode ein TabSheetContainer aufgetaucht ist
// eine entsprechende Anpassung der dafür von jQueri UI benutzten Klassen vorgenommen
@property (strong, nonatomic) NSString *lastUsedTabSheetContainerID;


// Damit ich auch intern auf die Inhalte der Variablen zugreifen kann
@property (strong, nonatomic) NSMutableDictionary *allJSGlobalVars;

// Gefundene <class>-Tags, die definiert wurden
@property (strong, nonatomic) NSMutableDictionary *allFoundClasses;


// Zum internen testen, ob wir alle Attribute erfasst haben
@property (nonatomic) int attributeCount;

// Weil der Aufruf von [parser abortParsing] rekurisv nicht klappt, muss ich es mir so merken
@property (strong, nonatomic) NSString* issueWithRecursiveFileNotFound;

// Bei Switch/When lese ich nur einen Zweig (den ersten) aus, um Dopplungen zu vermeiden
@property (nonatomic) BOOL weAreInTheTagSwitchAndNotInTheFirstWhen;

// Wenn wir in BDSText sind, dann dürfen auf den Text bezogene HTML-Tags nicht ausgewertet werden
@property (nonatomic) BOOL weAreInBDStextAndThereMayBeHTMLTags;

// Für dataset ohne Attribut 'src' muss ich die nachfolgenden tags einzeln aufsammeln
@property (nonatomic) BOOL weAreInDatasetAndNeedToCollectTheFollowingTags;

// Wenn ich in RollUpDown bin, ohne einen umgebenden RollUpDownContainer,
// muss ich den Abstand leider gesondert regeln.
@property (nonatomic) BOOL weAreInRollUpDownWithoutSurroundingRUDContainer;

// Derzeit überspringen wir alles im Element class, später ToDo
// auch in anderen Fällen überspringen wir alle Inhalte, z.B. bei 'splash', das sollten wir so lassen
// im Fall von 'fileUpload' müssen wir eine komplett neue Lösung finden weil es am iPad keine Files gibt
// ToDo: Umbenennen in: weAreCollectingTheCompleteContentInThisElement
@property (nonatomic) BOOL weAreSkippingTheCompleteContenInThisElement;
//auch ein 2. und 3., sonst gibt es Interferenzen wenn ein zu skippendes Element in einem anderen zuu skippenden liegt
@property (nonatomic) BOOL weAreSkippingTheCompleteContenInThisElement2;
@property (nonatomic) BOOL weAreSkippingTheCompleteContenInThisElement3;

@end




@implementation xmlParser
// public
@synthesize lastUsedDataset = _lastUsedDataset;


// private
@synthesize parser = _parser;

@synthesize isRecursiveCall = _isRecursiveCall;

@synthesize log = _log;

@synthesize pathToFile = _pathToFile;

@synthesize items = _items,
bookInProgress = _bookInProgress, keyInProgress = _keyInProgress, textInProgress = _textInProgress;

@synthesize enclosingElement = _enclosingElement, tempVerschachtelungstiefe = _tempVerschachtelungstiefe;

@synthesize output = _output, jsOutput = _jsOutput, jsOLClassesOutput = _jsOLClassesOutput, jQueryOutput0 = _jQueryOutput0, jQueryOutput = _jQueryOutput, jsHeadOutput = _jsHeadOutput, jsHead2Output = _jsHead2Output, cssOutput = _cssOutput, externalJSFilesOutput = _externalJSFilesOutput, collectedContentOfClass = _collectedContentOfClass;

@synthesize errorParsing = _errorParsing, verschachtelungstiefe = _verschachtelungstiefe, rollUpDownVerschachtelungstiefe = _rollUpDownVerschachtelungstiefe;

@synthesize idZaehler = _idZaehler, elementeZaehler = _elementeZaehler, element_merker = _element_merker;

@synthesize simplelayout_y = _simplelayout_y, simplelayout_y_spacing = _simplelayout_y_spacing;
@synthesize firstElementOfSimpleLayout_y = _firstElementOfSimpleLayout_y, simplelayout_y_tiefe = _simplelayout_y_tiefe;

@synthesize simplelayout_x = _simplelayout_x, simplelayout_x_spacing = _simplelayout_x_spacing;
@synthesize firstElementOfSimpleLayout_x = _firstElementOfSimpleLayout_x, simplelayout_x_tiefe = _simplelayout_x_tiefe;

@synthesize zuletztGesetzteID;

@synthesize last_resource_name_for_frametag = _last_resource_name_for_frametag, collectedFrameResources = _collectedFrameResources;

@synthesize datasetItemsCounter = _datasetItemsCounter, rollupDownElementeCounter = _rollupDownElementeCounter;

@synthesize animDuration = _animDuration, lastUsedTabSheetContainerID = _lastUsedTabSheetContainerID;

@synthesize allJSGlobalVars = _allJSGlobalVars;

@synthesize allFoundClasses = _allFoundClasses;

@synthesize attributeCount = _attributeCount;

@synthesize issueWithRecursiveFileNotFound = _issueWithRecursiveFileNotFound;

@synthesize weAreInTheTagSwitchAndNotInTheFirstWhen = _weAreInTheTagSwitchAndNotInTheFirstWhen;
@synthesize weAreInBDStextAndThereMayBeHTMLTags = _weAreInBDStextAndThereMayBeHTMLTags;
@synthesize weAreInDatasetAndNeedToCollectTheFollowingTags = _weAreInDatasetAndNeedToCollectTheFollowingTags;
@synthesize weAreInRollUpDownWithoutSurroundingRUDContainer = _weAreInRollUpDownWithoutSurroundingRUDContainer;
@synthesize weAreSkippingTheCompleteContenInThisElement = _weAreSkippingTheCompleteContenInThisElement;
@synthesize weAreSkippingTheCompleteContenInThisElement2 = _weAreSkippingTheCompleteContenInThisElement2;
@synthesize weAreSkippingTheCompleteContenInThisElement3 = _weAreSkippingTheCompleteContenInThisElement3;




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

    if ([self log])
    {
        [[self log] appendString:s];
        [[self log] appendString:@"\n"];

        // ToDo: Diese Zeile nur beim debuggen drin, damit ich nicht scrollen muss (tut extrem verlangsamen den Converter-Lauf sonst)
        // [self jumpToEndOfTextView];
    }
}


//1. Try: #define NSLog(...) OLLog(self,__VA_ARGS__)
//2. Try: #define NSLog(x,...) OLLog(self,x)
// Final Try:

//////////////////////////////////////////////
#define NSLog(...) OLLog(self,__VA_ARGS__)
//////////////////////////////////////////////
/********** Dirty Trick um NSLog umzuleiten *********/




-(id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"-init is not a valid initializer for the class xmlParser. use initWith:(NSURL*) pathToFile instead" userInfo:nil];
    //return nil;
    return [self initWith:[NSURL URLWithString:@""]];
}

// Eigener Konstruktor:
-(id)initWith:(NSURL*) pathToFile
{
    return [self initWith:pathToFile recursiveCall:NO];
}

// Eigener Konstruktor, den rekursive Instanzen aufrufen:
-(id)initWith:(NSURL*) pathToFile recursiveCall:(BOOL)isRecursive
{
    if (self = [super init])
    {
        self.isRecursiveCall = isRecursive;

        self.log = [[globalAccessToTextView textStorage] mutableString];

        self.pathToFile = pathToFile;

        self.items = [[NSMutableArray alloc] init];
        
        self.enclosingElement = @"";
        self.tempVerschachtelungstiefe = 1;
        
        self.output = [[NSMutableString alloc] initWithString:@""];
        self.jsOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsOLClassesOutput = [[NSMutableString alloc] initWithString:@""];
        self.jQueryOutput0 = [[NSMutableString alloc] initWithString:@""];
        self.jQueryOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsHeadOutput = [[NSMutableString alloc] initWithString:@""];
        // Wir sammeln hierdrin die global gesetzten Konstanten/Variablen, auf die vom Open-
        // Laszlo-Skript per canvas.* zugegriffen wird. Dazu legen wir einfach ein
        // canvas-JS-Objekt an! Aber natürlich nur einmal, nicht bei rekursiven Aufrufen.
        // ToDo: Sowohl das new Object als auch die gesammelten globalen Vars in jsHelper packen?
        if (self.isRecursiveCall)
        {
            self.jsHead2Output = [[NSMutableString alloc] initWithString:@""];
        }
        else
        {
            self.jsHead2Output = [[NSMutableString alloc] initWithString:@"// Globales Objekt für direkt in canvas global deklarierte Konstanten und Variablen\n"
                //"var canvas = new Object();\n\n"
                // statt dessen besser:
                "function canvasKlasse() {\n}\nvar canvas = new canvasKlasse();\n"
                "canvasKlasse.prototype.setAttribute = function(varname,value)\n{\n  eval('this.'+varname+' = '+value+';');\n}\n"
                "canvas.height = $(window).height(); // <-- Var, auf die zugegriffen wird\n\n"
                // ToDo: 1000 muss natürlich aus dem canvas-element ausgelesen werden
                // und fixer wert nur wenn keine Prozentangabe dabei
                "canvas.width = 1000; // $(window).width(); // <-- Var, auf die zugegriffen wird\n\n"
                "// Globale Klasse für in verschiedenen Methoden (lokal?) deklarierte Methoden\n"
                "function parentKlasse() {\n}\n"
                "var parent = new parentKlasse(); // <-- Unbedingt nötg, damit es auch ein Objekt gibt\n\n"];
        }
        self.cssOutput = [[NSMutableString alloc] initWithString:@""];
        self.externalJSFilesOutput = [[NSMutableString alloc] initWithString:@""];
        self.collectedContentOfClass = [[NSMutableString alloc] initWithString:@""];

        self.errorParsing = NO;
        self.verschachtelungstiefe = 0;
        self.rollUpDownVerschachtelungstiefe = 0;
        self.idZaehler = 0;
        self.elementeZaehler = 0;
        self.element_merker = @"";

        self.simplelayout_y = 0;
        self.simplelayout_y_spacing = [[NSMutableArray alloc] init];
        self.firstElementOfSimpleLayout_y = YES;
        self.simplelayout_y_tiefe = 0;

        self.simplelayout_x = 0;
        self.simplelayout_x_spacing = [[NSMutableArray alloc] init];
        self.firstElementOfSimpleLayout_x = YES;
        self.simplelayout_x_tiefe = 0;

        self.zuletztGesetzteID = @"";

        self.last_resource_name_for_frametag = [[NSString alloc] initWithString:@""];
        self.collectedFrameResources = [[NSMutableArray alloc] init];

        self.animDuration = @"slow";
        self.lastUsedTabSheetContainerID = @"";
        self.lastUsedDataset = @"";
        self.datasetItemsCounter = 0;
        self.rollupDownElementeCounter = [[NSMutableArray alloc] init];

        self.issueWithRecursiveFileNotFound = @"";

        self.weAreInTheTagSwitchAndNotInTheFirstWhen = NO;
        self.weAreInBDStextAndThereMayBeHTMLTags = NO;
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
        self.weAreInRollUpDownWithoutSurroundingRUDContainer = NO;
        self.weAreSkippingTheCompleteContenInThisElement = NO;
        self.weAreSkippingTheCompleteContenInThisElement2 = NO;
        self.weAreSkippingTheCompleteContenInThisElement3 = NO;

        self.allJSGlobalVars = [[NSMutableDictionary alloc] initWithCapacity:200];
        self.allFoundClasses = [[NSMutableDictionary alloc] initWithCapacity:200];
    }
    return self;
}


-(NSArray*) startWithString:(NSString*)s
{
    // NSLog(@"GATTV: %@",[[globalAccessToTextView textStorage] string]);
    // NSLog(@"SharedSingleton: %@",[[sharedSingleton.textView textStorage] string]);
    // [[[sharedSingleton.textView textStorage] mutableString] appendString: @"Dahinter"];
    // [self.log appendString:@"Länger und"];
    // OLLog(self, @"sogar noch länger");




    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self.pathToFile path]];
    if (!fileExists)
    {
        // NSLog(@"XML-File not found. Did you initialise with initWith: pathTofile?");

        // Ich frage den String in diesem Array beim verlassen der Rekursion ab,
        // falls er zwischendurch mal eine Datei nicht findet.
        NSArray *r = [NSArray arrayWithObjects:@"XML-File not found", nil];
        return r;
    }
    else
    {
        // Create a parser
        if ([s isEqualToString:@""])
        {
            self.parser = [[NSXMLParser alloc] initWithContentsOfURL:self.pathToFile];
        }
        else
        {
            NSData* d = [s dataUsingEncoding:NSUTF8StringEncoding];
            self.parser = [[NSXMLParser alloc] initWithData:d];


            // Ich muss es jetzt sofort nullen, sonst kann es zu einer Endlos-Schleife kommen, wenn ein Include folgt!
            // Denn vor dem rekursiven Aufruf wird ja getestet ib in self.collectedContentOfClass was drin ist und nur
            // daran wird erkannt ob wir 's' durchparsen oder den Filename!
            self.collectedContentOfClass = [[NSMutableString alloc] initWithString:@""];
            s = @"";
            // Oder? Check auch mal mit auskommentieren // ToDo
        }

        [self.parser setDelegate:self];

        // You may need to turn some of these on depending on the type of XML file you are parsing
        /*
         [parser setShouldProcessNamespaces:NO];
         [parser setShouldReportNamespacePrefixes:NO];
         [parser setShouldResolveExternalEntities:NO];
         */

        // NSLog([NSString stringWithFormat:@"Passing so much times here, but are we recursive? => %d",self.isRecursiveCall]);
        // Do the parse
        [self.parser parse];

        // Zur Sicherheit mache ich von allem ne Copy.
        // Nicht, dass es beim Verlassen der Rekursion zerstört wird
        NSArray *r = [NSArray arrayWithObjects:[self.output copy],[self.jsOutput copy],[self.jsOLClassesOutput copy],[self.jQueryOutput0 copy],[self.jQueryOutput copy],[self.jsHeadOutput copy],[self.jsHead2Output copy],[self.cssOutput copy],[self.externalJSFilesOutput copy],[self.allJSGlobalVars copy],[self.allFoundClasses copy], nil];
        return r;
    }
}


-(NSArray*) start
{
    return [self startWithString:@""];
}



- (void) rueckeMitLeerzeichenEin:(NSInteger)n
{
    for (int i = 0; i<n; i++)
    {
        [self.output appendString:@"  "];
    }
}

- (NSMutableString*) addCSSAttributes:(NSDictionary*) attributeDict forceWidthAndHeight:(BOOL)b
{
    if (!b)
        [self instableXML:@"ERROR: Don't call addCSSAttributes:forcingWidthAndHeight with b = false"];

    NSMutableString *style = [self addCSSAttributes:attributeDict];


    // width erzwingen
    if ([style rangeOfString:@"width:"].location == NSNotFound)
    {
        [style appendString:@"width:inherit;"];
    }

    // height erzwingen
    if ([style rangeOfString:@"height:"].location == NSNotFound)
    {
        [style appendString:@"height:inherit;"];
    }

    return style;
}


// Immer wenn die CSS-Height-Auswertung auf eine Wert trifft,
// der berechnet werden muss, dann wird diese Methode aufgerufen.
- (void) setTheHeightWithJQuery:(NSString*)s
{
    [self.jQueryOutput appendString:[NSString stringWithFormat:@"\n  // Setting the height of '#%@' by jQuery, because it is a computed value (%@)\n",self.zuletztGesetzteID,s]];

    // this.y von OpenLaszlo muss durch die entsprechende CSS-Angabe ersetzt werden
    s = [s stringByReplacingOccurrencesOfString:@"this.y" withString:[NSString stringWithFormat:@"parseInt($('#%@').css('top'))",self.zuletztGesetzteID]];

    [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').height(%@);\n",self.zuletztGesetzteID,s]];
}




- (NSMutableString*) addCSSAttributes:(NSDictionary*) attributeDict
{
    // Egal welcher String da drin steht, hauptsache nicht Canvas
    // Für canvas muss ich bei bestimmten Attributen anders vorgehen
    // insbesondere font-size wird dann global deklariert usw.
    return [self addCSSAttributes:attributeDict toElement:@"xyz"];
}




- (NSMutableString*) addCSSAttributes:(NSDictionary*) attributeDict toElement:(NSString*) elemName
{
    // Alle Styles in einem eigenen String sammeln, könnte nochmal nützlich werden
    NSMutableString *style = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"bgcolor"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'bgcolor' as CSS 'background-color'.");
        [style appendString:@"background-color:"];
        [style appendString:[attributeDict valueForKey:@"bgcolor"]];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"fgcolor"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'fgcolor' as CSS 'color'.");
        [style appendString:@"color:"];
        [style appendString:[attributeDict valueForKey:@"fgcolor"]];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"topmargin"])
    {
        NSString *s = [attributeDict valueForKey:@"topmargin"];

        self.attributeCount++;
        NSLog(@"Setting the attribute 'topmargin' as CSS 'margin-top'.");
        [style appendString:@"margin-top:"];
        [style appendString:s];
        if ([s rangeOfString:@"%"].location == NSNotFound)
            [style appendString:@"px"];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"valign"])
    {
        if ([[attributeDict valueForKey:@"valign"] isEqual:@"middle"])
        {
            self.attributeCount++;

            // http://phrogz.net/css/vertical-align/index.html
            NSLog(@"Setting the attribute 'valign:middle' by computing difference of height of surrounding element and inner element. And setting the half of it as CSS top.");
            // Dies beides klappt nicht wirklich...
            // 1) [style appendString:@"position:absolute; top:50%; margin-top:-12px;"];
            // 2) [style appendString:@"line-height:4em;"];
            // Ich setze also über jQuery direkt ausgehend von der Höhe des Eltern-Elements
            [self.jQueryOutput appendString:@"\n  // valign wurde als Attribut gefunden: Richte das Element entsprechend mittig (vertikal) aus\n"];

            // [self.jQueryOutput appendFormat:@"  $('#%@').css('top',toInt((parseInt($('#%@').parent().css('height'))-parseInt($('#%@').css('height')))/3));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
            // So wohl korrekter:
            [self.jQueryOutput appendFormat:@"  $('#%@').css('top',toInt((parseInt($('#%@').parent().css('height'))-parseInt($('#%@').outerHeight()))/2));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        }


        // Bottom heißt es soll am untern Ende des umgebenden divs aufsetzen
        if ([[attributeDict valueForKey:@"valign"] isEqual:@"bottom"])
        {
            self.attributeCount++;

            NSLog(@"Setting the attribute 'valign:bottom' by computing as CSS top.");
            // Dies beides klappt nicht wirklich...
            // 1) [style appendString:@"position:absolute; top:50%; margin-top:-12px;"];
            // 2) [style appendString:@"line-height:4em;"];
            // Ich setze also über jQuery direkt ausgehend von der Höhe des Eltern-Elements
            [self.jQueryOutput appendString:@"\n  // valign wurde als Attribut gefunden: Richte das Element entsprechend mittig (vertikal) aus\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').css('top',toInt((parseInt($('#%@').parent().css('height'))-parseInt($('#%@').outerHeight()))));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        }

        // Nichts zu tun, der Ausgangswert
        if ([[attributeDict valueForKey:@"valign"] isEqual:@"top"])
        {
            self.attributeCount++;

            NSLog(@"Setting the attribute 'valign:top' as CSS 'vertical-align:top'.");
            [style appendString:@"vertical-align:"];
            [style appendString:[attributeDict valueForKey:@"valign"]];
            [style appendString:@";"];
        }
    }

    if ([attributeDict valueForKey:@"height"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'height' as CSS 'height'.");

        NSString *s = [attributeDict valueForKey:@"height"];

        if ([s rangeOfString:@"${parent.height}"].location != NSNotFound ||
            [s rangeOfString:@"${immediateparent.height}"].location != NSNotFound)
        {
            [style appendString:@"height:"];
            [style appendString:@"inherit"];
            [style appendString:@";"];
        }
        else if ([s rangeOfString:@"${parent.height"].location != NSNotFound)
        {
            // = Die Höhe des vorherigen Elements abzüglich eines gegebenen Wertes

            // $, {} strippen
            s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

            // Höhe des Elternelements ermitteln
            NSString *hoeheElternElement = [NSString stringWithFormat:@"$('#%@').parent().height()",self.zuletztGesetzteID];

            // Replace 'parent.height' mit der per jQuery ermittelten Höhe des Eltern-Elements
            s = [s stringByReplacingOccurrencesOfString:@"parent.height" withString:hoeheElternElement];

            [self setTheHeightWithJQuery:s];
        }
        else if ([s rangeOfString:@"${canvas.height"].location != NSNotFound)
        {
            // canvas.height ist die Höhe des windows
            // Die entsprechende globale Variable dafür wurde vorher gesetzt

            // $, {} strippen
            s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

            [self setTheHeightWithJQuery:s];
        }
        else
        {
            [style appendString:@"height:"];
            [style appendString:s];
            if ([s rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }
    }

    if ([attributeDict valueForKey:@"boxheight"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'boxheight' as CSS 'height'.");
        
        if ([[attributeDict valueForKey:@"boxheight"] rangeOfString:@"${parent.height}"].location != NSNotFound)
        {
            [style appendString:@"height:"];
            [style appendString:@"inherit"];
            [style appendString:@";"];
        }
        else if ([[attributeDict valueForKey:@"boxheight"] rangeOfString:@"${immediateparent.height"].location != NSNotFound)
        {
            // = Die Höhe des vorherigen Elements abzüglich eines gegebenen Wertes

            NSString *s = [attributeDict valueForKey:@"boxheight"];

            // $, {} strippen
            s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

            // Höhe des Elternelements ermitteln
            NSString *hoeheElternElement = [NSString stringWithFormat:@"$('#%@').parent().height()",self.zuletztGesetzteID];

            // Replace 'immediateparent.height' mit der per jQuery ermittelten Höhe des Eltern-
            // Elements
            s = [s stringByReplacingOccurrencesOfString:@"immediateparent.height" withString:hoeheElternElement];

            [self setTheHeightWithJQuery:s];
        }
        else
        {
            [style appendString:@"height:"];
            [style appendString:[attributeDict valueForKey:@"boxheight"]];
            if ([[attributeDict valueForKey:@"boxheight"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }
    }

    // speichern, falls width schon gesetz wurde für Attribut resource
    BOOL widthGesetzt = NO;
    if ([attributeDict valueForKey:@"width"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'width' as CSS 'width'.");

        if ([[attributeDict valueForKey:@"width"] rangeOfString:@"${parent.width}"].location != NSNotFound || [[attributeDict valueForKey:@"width"] rangeOfString:@"${immediateparent.width}"].location != NSNotFound)
        {
            [style appendString:@"width:"];
            [style appendString:@"inherit"];
            [style appendString:@";"];
        }
        else if ([[attributeDict valueForKey:@"width"] rangeOfString:@"${parent.width"].location != NSNotFound || [[attributeDict valueForKey:@"width"] rangeOfString:@"${immediateparent.width"].location != NSNotFound)
        {
            // = Die Höhe des vorherigen Elements abzüglich eines gegebenen Wertes

            NSString *s = [attributeDict valueForKey:@"width"];
            // $, {} strippen
            s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

            // Höhe des Elternelements ermitteln
            NSString *breiteElternElement = [NSString stringWithFormat:@"$('#%@').parent().width()",self.zuletztGesetzteID];

            // Replace 'parent.width' mit der per jQuery ermittelten Höhe des Eltern-Elements
            s = [s stringByReplacingOccurrencesOfString:@"immediateparent.width" withString:breiteElternElement];
            s = [s stringByReplacingOccurrencesOfString:@"parent.width" withString:breiteElternElement];

            // per jQuery die Höhe setzen.
            [self.jQueryOutput appendString:[NSString stringWithFormat:@"\n  // Setting the width of '#%@' by jQuery, because it is a computed value (%@)\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"width"]]];
            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').width(%@);\n",self.zuletztGesetzteID,s]];
        }
        else
        {
            [style appendString:@"width:"];
            [style appendString:[attributeDict valueForKey:@"width"]];
            if ([[attributeDict valueForKey:@"width"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        widthGesetzt = YES;
    }

    if ([attributeDict valueForKey:@"controlwidth"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'controlwidth' as CSS 'width'.");
        [style appendString:@"width:"];

        if ([[attributeDict valueForKey:@"controlwidth"] rangeOfString:@"${parent.width}"].location != NSNotFound)
        {
            [style appendString:@"inherit"];
        }
        else
        {
            [style appendString:[attributeDict valueForKey:@"controlwidth"]];
            if ([[attributeDict valueForKey:@"controlwidth"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
        }
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"x"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'x' as CSS 'left'.");

        NSString *s = [attributeDict valueForKey:@"x"];

        if ([s rangeOfString:@"${canvas.width"].location != NSNotFound)
        {
            // canvas.width ist die Höhe des windows
            // Die entsprechende globale Variable dafür wurde vorher gesetzt

            // $, {} strippen
            s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

            [self.jQueryOutput appendString:[NSString stringWithFormat:@"\n  // Setting the left-value of '#%@' by jQuery, because it is a computed value (%@)\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"x"]]];

            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('left',%@+'px');\n",self.zuletztGesetzteID,s]];
        }
        else
        {
            [style appendString:@"left:"];
            [style appendString:[attributeDict valueForKey:@"x"]];
            if ([[attributeDict valueForKey:@"x"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        [style appendString:@"float:none;position:absolute;"];
    }

    if ([attributeDict valueForKey:@"y"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'y' as CSS 'top'.");

        NSString *s = [attributeDict valueForKey:@"y"];

        if ([s rangeOfString:@"${canvas.height"].location != NSNotFound)
        {
            // canvas.height ist die Höhe des windows
            // Die entsprechende globale Variable dafür wurde vorher gesetzt

            // $, {} strippen
            s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

            [self.jQueryOutput appendString:[NSString stringWithFormat:@"\n  // Setting the top-value of '#%@' by jQuery, because it is a computed value (%@)\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"y"]]];

            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('top',%@+'px');\n",self.zuletztGesetzteID,s]];
        }
        else
        {
            [style appendString:@"top:"];
            [style appendString:[attributeDict valueForKey:@"y"]];
            if ([[attributeDict valueForKey:@"y"] rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        [style appendString:@"float:none;position:absolute;"];
    }



    if ([attributeDict valueForKey:@"fontsize"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'fontsize' as CSS 'font-size'.");

        [style appendString:@"font-size:"];
        [style appendString:[attributeDict valueForKey:@"fontsize"]];
        [style appendString:@"px;"];


        // ToDo: Die in 'canvas' gesetzten Attribute hier her verlagern
        if (![elemName isEqualToString:@"canvas"])
        {
            // Die Eigenschaft fontsize überträgt sich auf alle Kinder und Enkel
            [self.jQueryOutput appendString:@"\n\n  // Alle Kinder und Enkel kriegen ebenfalls diese Eigenschaft mit\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').find('.ol_text').css('font-size','%@px');\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"fontsize"]];
        }
    }



    if ([attributeDict valueForKey:@"fontstyle"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'fontstyle' as CSS 'font-weight'.");
        
        [style appendString:@"font-weight:"];
        [style appendString:[attributeDict valueForKey:@"fontstyle"]];
    }



    if ([attributeDict valueForKey:@"font"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'font' as CSS 'font-family'.");

        [style appendString:@"font-family:"];
        [style appendString:[attributeDict valueForKey:@"font"]];
        [style appendString:@";"];
    }


    if ([attributeDict valueForKey:@"align"])
    {
        if ([[attributeDict valueForKey:@"align"] isEqual:@"center"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'align=center' as CSS 'margin:auto;'.");
            // Funktioniert leider nicht:
            //[style appendString:@"margin-left:auto; margin-right:auto;"];

            [self.jQueryOutput appendString:@"\n  // align wurde als Attribut gefunden: Richte das Element entsprechend mittig (horizontal) aus\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').css('left',toInt((parseInt($('#%@').parent().css('width'))-parseInt($('#%@').css('width')))/2));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        }

        // Hier mache ich erstmal nichts, align=left sollte eigentlich Ausgangswert sein, aber To Check (ToDo)
        if ([[attributeDict valueForKey:@"align"] isEqual:@"left"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'align=left' for now.");
        }

        // ToDo, hierzu muss ich mir noch eine Lösung einfallen lassen
        if ([[attributeDict valueForKey:@"align"] isEqual:@"right"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'align=right' for now.");
        }

        // ToDo, hierzu muss ich mir noch eine Lösung einfallen lassen
        if ([[attributeDict valueForKey:@"align"] isEqual:@"${classroot.textalign}"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'align=${classroot.textalign}' for now.");
        }
    }






    // Skipping this attributes
    if ([attributeDict valueForKey:@"scriptlimits"])
    {
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'scriptlimits'.");
    }
    if ([attributeDict valueForKey:@"stretches"])
    {
        // Wird automatisch von CSS bei Hintergrundbildern berücksichtigt
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'stretches'.");
    }
    if ([attributeDict valueForKey:@"initstage"])
    {
        // Dieses Attribut spielt hoffentlich keine Rolle
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'initstage'.");
    }
    if ([attributeDict valueForKey:@"listwidth"])
    {
        // Kann mit diesem Attribut derzeit nichts anfangen
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'listwidth'.");
    }
    if ([attributeDict valueForKey:@"negativecolor"]) // ToDo
    {
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'negativecolor'.");
    }
    if ([attributeDict valueForKey:@"positivecolor"]) // ToDo
    {
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'positivecolor'.");
    }






    // Neuerding kann auch in 'source' der Pfad zu einer Datei enthalten sein, nicht nur in resource
    if ([attributeDict valueForKey:@"resource"] || [attributeDict valueForKey:@"source"])
    {
        NSString *src = @"";
        if ([attributeDict valueForKey:@"resource"])
        {
            NSLog(@"Setting the attribute 'resource' as CSS 'background-image:url()'");
            src = [attributeDict valueForKey:@"resource"];
        }
        else
        {
            NSLog(@"Setting the attribute 'source' as CSS 'background-image:url()'");
            src = [attributeDict valueForKey:@"source"];
        }

        self.attributeCount++;
        NSString *s = @"";

        // Wenn ein Punkt enthalten ist, ist es wohl eine Datei
        if ([src rangeOfString:@"."].location != NSNotFound ||
            [src isEqualToString:@"lzgridsortarrow_rsrc"] /* ... Keine Ahnung wo diese Res herkommen soll. Super nervig sowas. */ )
        {
            // Möglichkeit 1: Resource wird direkt als String angegeben!
            s = src;
        }
        else
        {
            // Möglichkeit 2: Resource wurde vorher extern gesetzt

            // Namen des Bildes aus eigener vorher angelegter Res-DB ermitteln
            if ([[self.allJSGlobalVars valueForKey:src] isKindOfClass:[NSArray class]])
            {
                s = [[self.allJSGlobalVars valueForKey:src] objectAtIndex:0];
            }
            else
            {
                s = [self.allJSGlobalVars valueForKey:src];
            }
        }
        if (s == nil || [s isEqualToString:@""])
            [self instableXML:[NSString stringWithFormat:@"ERROR: The image-path '%@' isn't valid.",src]];



        NSLog(@"Checking the image-size directly on file-system:");
        // Dann erstmal width und height von dem Image auf Dateiebene ermitteln
        NSURL *path = [self.pathToFile URLByDeletingLastPathComponent];

        NSURL *pathToImg = [NSURL URLWithString:s relativeToURL:path];

        // [NSString stringWithFormat:@"%@%@",path,s];
        NSLog([NSString stringWithFormat:@"Path to Image: %@",pathToImg]);
        NSImage *image = [[NSImage alloc] initByReferencingURL:pathToImg];
        NSSize dimensions = [image size];
        NSInteger w = (int) dimensions.width;
        NSInteger h = (int) dimensions.height;
        NSLog([NSString stringWithFormat:@"Resolving width of image from original file: %d (setting as CSS-width)",w]);
        NSLog([NSString stringWithFormat:@"Resolving height of Image from original file: %d (setting as CSS-height)",h]);
        if (!widthGesetzt)
            [style appendString:[NSString stringWithFormat:@"width:%dpx;",w]];
        // Height setzen wir erstmal immer, später ändern? (ToDo)
        [style appendString:[NSString stringWithFormat:@"height:%dpx;",h]];

        [style appendString:@"background-image:url("];
        [style appendString:s];
        [style appendString:@");"];
        // Aus irgendeinem Grund müssen nach meiner großen Änderung von absolute auf relative
        // die Bilder trotzdem weiterhin absolute sein... aber nur die... hmmm.
        // Das ist Unsinn...
        // Bilder dürfen nicht absolute sein, weil ich in bestimmten Situationen auf
        // position:absolute teste (Simplelayout) und nur bei absolute-Elementen aufrücke
        // Wenn Bilder IMMER absolute wären, würde diese Abfrage brechen
        // [style appendString:@"position:absolute;"];
    }





    // Immer wenn ein Element von uns hier auf "absolute" gesetzt wurde
    // Dann muss ich die größe des Parents erweitern
    if ([style rangeOfString:@"position:absolute"].location != NSNotFound)
    {
        [self.jQueryOutput appendString:@"\n  // Ein position:absolute! Wir müssen eventuell deswegen die Höhe des Eltern-Elements anpassen, da absolute-Elemente\n  // nicht im Fluss auftauchen, aber das umgebende Element trotzdem mindestens so hoch sein muss, dass es dieses mit umfasst.\n"];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  var h = parseInt($('#%@').css('top'))+($('#%@').outerHeight('true'));\n",self.zuletztGesetzteID,self.zuletztGesetzteID]];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  if (h > $('#%@').parent().height())\n",self.zuletztGesetzteID]];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"    $('#%@').parent().height(h);\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID]];
    }



    return style;
}




// titlewidth hier extra setzen, außerhalb addCSS, titlewidth bezieht sich  immer auf den Text VOR
// einem input-Feld und nicht auf das input-Feld selber.
- (NSMutableString*) addTitlewidth:(NSDictionary*) attributeDict
{
    NSMutableString *titlewidth = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"titlewidth"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'titlewidth' as width for the leading text of the input-field.");

        [titlewidth appendString:@" style=\"width:"];
        [titlewidth appendString:[attributeDict valueForKey:@"titlewidth"]];
        //[titlewidth appendString:@"px;top:3px;\""]; // vom Rand wegrückenm damit es zentriert ist
    }
    else
    {
        // vom Rand wegrückenm damit es zentriert ist
        //[titlewidth appendString:@" style=\"top:3px;\""];
    }

    return titlewidth;
}



// Remove all occurrences of $,{,}
- (NSString *) removeOccurrencesofDollarAndCurlyBracketsIn:(NSString*)s
{
    s = [s stringByReplacingOccurrencesOfString:@"$" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"{" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"}" withString:@""];

    return s;
}


// Remove all occurrences of (,)
- (NSString *) removeOccurrencesofBracketsIn:(NSString*)s
{
    s = [s stringByReplacingOccurrencesOfString:@"(" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@")" withString:@""];

    return s;
}


- (NSMutableString*) addJSCode:(NSDictionary*) attributeDict withId:(NSString*)idName
{
    // Den ganzen Code in einem eigenen String sammeln, und nur JS ausgeben, wenn gefüllt
    NSMutableString *code = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"visible"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'visible' as JS.");


        NSString *s = [attributeDict valueForKey:@"visible"];
        s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];



        // Verkettete Bedingungen bei Visibility werden leider noch nicht unterstützt
        // dringend ToDo !!! ToDo ToDo
        // Auch Bedingungen mit > werden noch nicht unterstützt
        if ([s rangeOfString:@"&&"].location != NSNotFound ||
            [s rangeOfString:@"||"].location != NSNotFound ||
            [s rangeOfString:@">"].location != NSNotFound)
        {
            // [self instableXML:@"Verkettete Bedingung oder >-Zeichen in Bedingung! Mist..."];
        }
        else
        {







        // Falls der string geklammert war, muss ich diese entfernen
        // ToDo: Gibt es Fälle wo die Klammern lebensentscheidend sind?
        s = [self removeOccurrencesofBracketsIn:s];

        if ([s isEqualToString:@"false"] || [s isEqualToString:@"true"])
        {
            [self.jQueryOutput appendString:@"\n  // Die Visibility wurde nur per false oder true gesetzt und ist von nichts abhängig\n"];
            [self.jQueryOutput appendString:@"  $('#"];
            [self.jQueryOutput appendString:idName];
            [self.jQueryOutput appendString:@"').toggle("];
            [self.jQueryOutput appendString:s];
            [self.jQueryOutput appendString:@");\n"];
        }
        else
        {
            // Ich brauche den String bis zum Punkt, denn das ist unsere Variable für die ein
            // onChange-Event eingerichtet werden muss.
            // Die Position des Punktes:
            NSRange positionDesPunktes = [s rangeOfString:@"."];
            NSString *idVonDerEsAbhaengigIst = [s substringToIndex:positionDesPunktes.location];
            NSString *bedingung = [s substringFromIndex:positionDesPunktes.location+1];
            // NSLog([NSString stringWithFormat:@"Heimlicher Test: %@",bedingung]);



            // Wenn wir hier in den ersten Zweig reinkommen, dann ist 'bedingung' was anderes,
            // und zwar der Variablenname ohne vorstehendes 'canvas.'
            if ([idVonDerEsAbhaengigIst isEqualToString:@"canvas"] ||
                [idVonDerEsAbhaengigIst isEqualToString:@"!canvas"])
            {
                /* alte Lösung per plain JS (hat nicht auf spätere Änderungen der Var reagiert)
                 [code appendString:s];
                 [code appendString:@" ? document.getElementById('"];
                 [code appendString:idName];
                 [code appendString:@"').style.visibility = 'visible' : document.getElementById('"];
                 [code appendString:idName];
                 [code appendString:@"').style.visibility = 'hidden';"];
                 */

                BOOL wirMuessenNegieren = NO;
                if ([idVonDerEsAbhaengigIst isEqualToString:@"!canvas"])
                    wirMuessenNegieren = YES;

                // neue Lösung nun mit watch/unwatch-Methode
                [self.jQueryOutput appendString:@"\n  // Die Visibility ändert sich abhängig von dem Wert einer woanders gesetzten Variable (bei jeder Änderung, deswegen watchen der Variable)\n"];
                [self.jQueryOutput appendString:@"  canvas.watch(\""];
                [self.jQueryOutput appendString:bedingung];
                [self.jQueryOutput appendString:@"\", "];
                [self.jQueryOutput appendString:@"function (id, oldval, newval)\n  {\n"];
                [self.jQueryOutput appendString:@"    console.log('canvas.' + id + ' changed from ' + oldval + ' to ' + newval);\n"];
                [self.jQueryOutput appendString:@"    // Wenn wir ein input oder ein select sind...\n"];
                [self.jQueryOutput appendString:@"    if (($('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').is('input') && $('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').prev().is('span') && $('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').parent().is('div')) ||\n"];
                [self.jQueryOutput appendString:@"        ($('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').is('select') && $('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').prev().is('span') && $('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').parent().is('div')))\n"];
                [self.jQueryOutput appendString:@"      $('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').parent().toggle("];
                if (wirMuessenNegieren)
                    [self.jQueryOutput appendString:@"!"];
                [self.jQueryOutput appendString:@"newval"]; // nicht 's', war's vorher, dann spinnt es.
                [self.jQueryOutput appendString:@");\n"];
                [self.jQueryOutput appendString:@"  else\n"];
                [self.jQueryOutput appendString:@"      $('#"];
                [self.jQueryOutput appendString:idName];
                [self.jQueryOutput appendString:@"').toggle("];
                if (wirMuessenNegieren)
                    [self.jQueryOutput appendString:@"!"];
                [self.jQueryOutput appendString:@"newval"]; // nicht 's', war's vorher, dann spinnt es.
                [self.jQueryOutput appendString:@");\n"];

                [self.jQueryOutput appendString:@"    return newval;\n  });\n"];


                // Wenn !='' oder ==0 auftaucht, dieses rausschmeißen, weil wir nur die Variable brauchen zum setzen.
                s = [s stringByReplacingOccurrencesOfString:@"!=''" withString:@""];
                s = [s stringByReplacingOccurrencesOfString:@"==0" withString:@""];


                // Negationszeichen aus 's' entfernen, falls wir hier drin sind weil ein '!canvas' vorliegt
                s = [s stringByReplacingOccurrencesOfString:@"!" withString:@""];

                [self.jQueryOutput appendString:@"  // Und einmal sofort die Visibility anpassen durch setzen der Variable mit sich selber\n  "];
                [self.jQueryOutput appendString:s];
                [self.jQueryOutput appendString:@" = "];
                [self.jQueryOutput appendString:s];
                [self.jQueryOutput appendString:@";\n\n"];
            }
            else
            {
                if ([idVonDerEsAbhaengigIst isEqualToString:@"parent"] ||
                    [idVonDerEsAbhaengigIst isEqualToString:@"!parent"])
                {
                    // Wenn wir hier drin sind, wurde gar keine andere Variable gesetzt, sondern 'nur' parent.
                    // Auf parent greifen wir über die Ausgangsvariable selber zu, dazu teilen wir der Funktion
                    // togglieVisibility anstatt der anderen Variable das Stichwort '__PARENT__' mit.


                    BOOL wirMuessenNegieren = NO;
                    if ([idVonDerEsAbhaengigIst isEqualToString:@"!parent"])
                        wirMuessenNegieren = YES;


                    [self.jQueryOutput appendString:@"\n  // Die Visibility ändert sich abhängig von dem Wert des parents! (bei jeder Änderung)\n"];
                    [self.jQueryOutput appendString:@"  $('#"];
                    [self.jQueryOutput appendString:idName];
                    [self.jQueryOutput appendString:@"').parent().change(function()\n  {\n"];
                    [self.jQueryOutput appendString:@"    toggleVisibility('#"];
                    [self.jQueryOutput appendString:idName];
                    [self.jQueryOutput appendString:@"', '"];
                    [self.jQueryOutput appendString:@"__PARENT__', \""];
                    if (wirMuessenNegieren)
                        [self.jQueryOutput appendString:@"!"];
                    [self.jQueryOutput appendString:bedingung];
                    [self.jQueryOutput appendString:@"\");\n"];
                    [self.jQueryOutput appendString:@"  });\n"];

                    [self.jQueryOutput appendString:@"  // Und einmal sofort die Visibility anpassen\n"];
                    [self.jQueryOutput appendString:@"  toggleVisibility('#"];
                    [self.jQueryOutput appendString:idName];
                    [self.jQueryOutput appendString:@"', '"];
                    [self.jQueryOutput appendString:@"__PARENT__', \""];
                    if (wirMuessenNegieren)
                        [self.jQueryOutput appendString:@"!"];
                    [self.jQueryOutput appendString:bedingung];
                    [self.jQueryOutput appendString:@"\");\n"];
                }
                else
                {
                    BOOL wirMuessenNegieren = NO;
                    if ([idVonDerEsAbhaengigIst rangeOfString:@"!"].location != NSNotFound)
                    {
                            idVonDerEsAbhaengigIst = [idVonDerEsAbhaengigIst stringByReplacingOccurrencesOfString:@"!" withString:@""];
                            wirMuessenNegieren = YES;
                    }

                    [self.jQueryOutput appendString:@"\n  // Die Visibility ändert sich abhängig von dem Wert einer woanders gesetzten Variable (bei jeder Änderung)\n"];
                    [self.jQueryOutput appendString:@"  $('#"];
                    [self.jQueryOutput appendString:idVonDerEsAbhaengigIst];
                    [self.jQueryOutput appendString:@"').change(function()\n  {\n"];
                    [self.jQueryOutput appendString:@"    toggleVisibility('#"];
                    [self.jQueryOutput appendString:idName];
                    [self.jQueryOutput appendString:@"', '#"];
                    [self.jQueryOutput appendString:idVonDerEsAbhaengigIst];
                    // Da in den Bedingungen selber oft das ' verwendet wird, hier das "
                    [self.jQueryOutput appendString:@"', \""];
                    if (wirMuessenNegieren)
                        [self.jQueryOutput appendString:@"!"];
                    [self.jQueryOutput appendString:bedingung];
                    [self.jQueryOutput appendString:@"\");\n"];

                    /* Alte Lösung ohne externe Funktion (Nachteil war, dass ich die initiale
                     // Visibility nicht setzen konnte):
                     [self.jQueryOutput appendString:@"    var value = $(this).val();\n"];
                     [self.jQueryOutput appendString:@"    $('#"];
                     [self.jQueryOutput appendString:idName];
                     [self.jQueryOutput appendString:@"').toggle("];
                     [self.jQueryOutput appendString:bedingung];
                     [self.jQueryOutput appendString:@");\n"];
                     [self.jQueryOutput appendString:@"    // Dazu gehörigen Text auch mit entfernen\n"];
                     [self.jQueryOutput appendString:@"    if ($('#"];
                     [self.jQueryOutput appendString:idName];
                     [self.jQueryOutput appendString:@"').prev().is('span'))\n"];
                     [self.jQueryOutput appendString:@"      $('#"];
                     [self.jQueryOutput appendString:idName];
                     [self.jQueryOutput appendString:@"').prev().toggle("];
                     [self.jQueryOutput appendString:bedingung];
                     [self.jQueryOutput appendString:@");\n"];
                     */
                    [self.jQueryOutput appendString:@"  });\n"];

                    [self.jQueryOutput appendString:@"  // Und einmal sofort die Visibility anpassen\n"];
                    [self.jQueryOutput appendString:@"  toggleVisibility('#"];
                    [self.jQueryOutput appendString:idName];
                    [self.jQueryOutput appendString:@"', '#"];
                    [self.jQueryOutput appendString:idVonDerEsAbhaengigIst];
                    // Da in den Bedingungen selber oft das ' verwendet wird, hier das "
                    [self.jQueryOutput appendString:@"', \""];
                    if (wirMuessenNegieren)
                        [self.jQueryOutput appendString:@"!"];
                    [self.jQueryOutput appendString:bedingung];
                    [self.jQueryOutput appendString:@"\");\n"];
                }
            }
        }
        }
    }




    if ([attributeDict valueForKey:@"onclick"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onclick' as jQuery.");

        NSString *s = [attributeDict valueForKey:@"onclick"];
        // Remove all occurrences of $,{,}
        // Wohl doch nicht nötig (und bricht sonst auch selbst definierte Funktionen, welche { und } benutzen
        // s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];

        // Wir löschen erstmal 'canvas.', weil wir direkt die Funktin in JS deklarieren
        // Als Klassenmethode macht (noch) keinen Sinn, dann müssten wir ja erstmal mit new() ein objekt anlegen
        // Außerdem wäre canvas ja der Klassenname und nicht der Objektname. Objekt bringt uns also hier nicht weiter
        s = [s stringByReplacingOccurrencesOfString:@"canvas." withString:@""];


        NSMutableString *gesammelterCode = [[NSMutableString alloc] initWithString:@""];
        [gesammelterCode appendString:@"\n  // JS-onClick-event\n  $('#"];
        [gesammelterCode appendString:idName];
        [gesammelterCode appendString:@"').click(function(){"];
        [gesammelterCode appendString:s];
        [gesammelterCode appendString:@"});"];



        // Bei onClick soll sich immer der Mauszeiger ändern.
        [self.jQueryOutput appendString:@"\n  // onClick-Funktionalität, deswegen anderer Mouscursor!\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').hover(function() {  $(this).css('cursor','pointer');}, function() {$(this).css('cursor','auto');});\n",idName];


        // Hiermit kann ich es jederzeit auch direkt im Div anzeigen, damit ich es schneller finde bei Debug-Suche
        BOOL jQueryAusgabe = TRUE;


        if (jQueryAusgabe)
        {
            [self.jQueryOutput appendString:@"  "];
            [self.jQueryOutput appendString:gesammelterCode];
            [self.jQueryOutput appendString:@"\n"];
        }
        else
        {
            [code appendString:gesammelterCode];
        }
    }



    // Skipping the attribute 'onblur'
    // ToDo -> Implementierung wohl genau so wie eins weiter oben, nur als onblur
    if ([attributeDict valueForKey:@"onblur"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onblur'.");
    }




    // Skipping the attribute 'onvalue'
    // ToDo -> Implementierung wohl genau so wie weiter oben, nur als onvalue
    if ([attributeDict valueForKey:@"onvalue"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onvalue'.");
    }




    // Skipping the attribute 'onfocus'
    // ToDo -> Implementierung wohl genau so wie eins oben, nur als onfocus
    if ([attributeDict valueForKey:@"onfocus"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onfocus'.");
    }


    // Skipping the attribute 'onmousedown'
    // ToDo -> Implementierung wohl genau so wie weiter oben, nur als onmousedown
    if ([attributeDict valueForKey:@"onmousedown"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onmousedown'.");
    }


    // Skipping the attribute 'onmouseout'
    // ToDo -> Implementierung wohl genau so wie weiter oben, nur als onmouseout
    if ([attributeDict valueForKey:@"onmouseout"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onmouseout'.");
    }


    // Skipping the attribute 'onmouseover'
    // ToDo -> Implementierung wohl genau so wie weiter oben, nur als onmouseover
    if ([attributeDict valueForKey:@"onmouseover"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onmouseover'.");
    }


    // Skipping the attribute 'onmouseup'
    // ToDo -> Implementierung wohl genau so wie weiter oben, nur als onmouseup
    if ([attributeDict valueForKey:@"onmouseup"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'onmouseup'.");
    }








    // Skipping this attribute // ToDo...
    if ([attributeDict valueForKey:@"datapath"])
    {
        self.attributeCount++;
        NSLog(@"ToDo: Implement later the attribute 'datapath'.");
    }



    // ToDo
    if ([attributeDict valueForKey:@"clickable"])
    {
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'clickable'.");
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




// Die ID ermitteln
// self.zuletztGesetzteID wird hier gesetzt, wird vom Simplelayout gebraucht
- (NSString*) addIdToElement:(NSDictionary*) attributeDict
{
    // Erstmal auch dann setzen, wenn wir eine gegebene ID von OpenLaszlo haben, evtl. zu ändern
    self.idZaehler++;
    NSLog(@"Setting the (attribute 'id' as) HTML-attribute 'id'.");

    if ([attributeDict valueForKey:@"id"])
    {
        self.attributeCount++;
        self.zuletztGesetzteID = [attributeDict valueForKey:@"id"];
    }
    else
    {
        self.zuletztGesetzteID = [NSString stringWithFormat:@"element%d",self.idZaehler];
    }



    [self.output appendString:@" id=\""];
    [self.output appendString:self.zuletztGesetzteID];
    [self.output appendString:@"\""];




    // Und Simplelayout-Check von hier aus aufrufen, da alle Elemente mit gesetzter ID überprüft werden sollen
    [self check4Simplelayout];

    return self.zuletztGesetzteID;
}


// Muss immer nach addIDToElement aufgerufen werden, da wir auf die zuletzt gesetzten id zurückgreifen
- (void) check4Simplelayout
{

    // simplelayout verlassen, alsbald das letzte Geschwisterchen erreicht ist
    BOOL wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y = NO;
    if (self.simplelayout_y-1 == self.verschachtelungstiefe)
    {
        self.simplelayout_y = 0;
        [self.simplelayout_y_spacing removeLastObject];
        self.firstElementOfSimpleLayout_y = YES;
        self.simplelayout_y_tiefe--;

        // Wenn wir ein tiefer verschachteltes simlelayout gerade verlassen, merken wir uns das.
        // Das heißt ein anderes simplelayout (y) ist noch aktiv
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


        // Wenn wir ein tiefer verschachteltes simlelayout gerade verlassen, merken wir uns das.
        // Das heißt ein anderes simplelayout (x) ist noch aktiv
        if (self.simplelayout_x_tiefe > 0)
            wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X = YES;
    }






    NSString *id = self.zuletztGesetzteID;
    // Hol die aktuell geltende SpacingHöhe (für Simplelayout Y + x)
    NSInteger spacing_y = [[self.simplelayout_y_spacing lastObject] integerValue];
    NSInteger spacing_x = [[self.simplelayout_x_spacing lastObject] integerValue];



    // Simplelayout Y
    if (wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y)
    {
        // If-Abfrage bauen
        [self.jsOutput appendString:@"if (document.getElementById('"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling && document.getElementById('"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild)\n"];

        [self.jsOutput appendString:@"  document.getElementById('"];
        [self.jsOutput appendString:id];

        // parseInt removes the "px" at the end
        [self.jsOutput appendString:@"').style.top = (parseInt(document.getElementById('"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild.offsetTop)+parseInt(document.getElementById('"];
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
            // Seit wir von absolute auf relative umgestiegen sind und zusätzlich auch noch auf
            // float:left umgestellt haben, müssen wir die width nur korrigieren, wenn das Element
            // position:absolute ist. Dann müssen wir es doch immer noch verrücken.

            // Den allerersten sippling auslassen
            [self.jsOutput appendString:@"if (document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling && document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').style.position == 'absolute')\n"];

            [self.jsOutput appendString:@"  document.getElementById('"];
            [self.jsOutput appendString:id];

            // parseInt removes the "px" at the end
            [self.jsOutput appendString:@"').style.top = (parseInt(document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling.offsetTop)+"];

            // Seit wir von absolute auf relative umgestiegen sind,brauchen wir nur noch offsetTop?
               [self.jsOutput appendString:@"parseInt(document.getElementById('"];
               [self.jsOutput appendString:id];
               [self.jsOutput appendString:@"').previousElementSibling.style.height)"];
            // Bei position:absolute wirkt sich die Spacing-Angabe wohl auch hier nicht aus
            // [self.jsOutput appendFormat:@"+%d", spacing_y];
            [self.jsOutput appendString:@") + \"px\";\n"];
            
            // Ansonsten müssen wir halt nur/noch entsprechend des spacing-Wertes nach unten
            // rücken. Mit top klappt es nicht (zumindestens nicht bei mehr als 2 Elementen)
            // mit padding klappt es auch nicht, aber mit margin... zum Glück
            [self.jsOutput appendString:@"else\n"];
            [self.jsOutput appendString:@"  // ansonsten wegen 'spacing' nach unten rücken\n"];
            [self.jsOutput appendString:@"  document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').style.marginTop = '"];
            [self.jsOutput appendString:[NSString stringWithFormat:@"%d", spacing_y]];
            [self.jsOutput appendString:@"px';\n\n"];
        }
        self.firstElementOfSimpleLayout_y = NO;
    }



    // Simplelayout X
    if (wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X)
    {
        // If-Abfrage bauen
        [self.jsOutput appendString:@"if (document.getElementById('"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling && document.getElementById('"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild)\n"];

        [self.jsOutput appendString:@"  document.getElementById('"];
        [self.jsOutput appendString:id];

        // parseInt removes the "px" at the end
        [self.jsOutput appendString:@"').style.left = (parseInt(document.getElementById('"];
        [self.jsOutput appendString:id];
        [self.jsOutput appendString:@"').previousElementSibling.lastElementChild.offsetLeft)+parseInt(document.getElementById('"];
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
            // Seit wir von absolute auf relative umgestiegen sind und zusätzlich auch noch auf
            // float:left umgestellt haben, müssen wir die width GAR NICHT mehr korrigieren
            // Stopp: Es gibt eine Ausnahme: Wenn unser Element position:absolute ist dann
            // müssen wir es doch immer noch verrücken.

            // Den allerersten sippling auslassen
            [self.jsOutput appendString:@"// Für den Fall, dass wir position:absolute sind nehmen wir keinen Platz ein\n// und rücken somit nicht automatisch auf. Dies müssen wir hier nachkorrigieren. Spacing wird bei 'absolute' NICHT korrigiert.\n"];
            [self.jsOutput appendString:@"if (document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling && document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').style.position == 'absolute')\n"];

            [self.jsOutput appendString:@"  document.getElementById('"];
            [self.jsOutput appendString:id];

            // parseInt removes the "px" at the end
            [self.jsOutput appendString:@"').style.left = ("];
            //  Seit wir von absolute auf relative umgestiegen sind, brauchen wir nur noch Width
                //[self.jsOutput appendString:@"parseInt(document.getElementById('"];
                //[self.jsOutput appendString:id];
                //[self.jsOutput appendString:@"').previousElementSibling.offsetLeft)+"];
            [self.jsOutput appendString:@"parseInt(document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').previousElementSibling.offsetWidth)"];

            // Bei position:absolute wirkt sich die Spacing-Angabe NICHT aus, bei allen
            // betroffenen Elementen so festgestellt...
            // [self.jsOutput appendFormat:@"+%d", spacing_x];

            [self.jsOutput appendString:@") + \"px\";\n"];

            // ...Deswegen kommt hier auch ein Else hin
            [self.jsOutput appendString:@"else\n"];

            // Ansonsten müssen wir halt nur/noch entsprechend des spacing-Wertes nach rechts
            // rücken. Mit left klappt es nicht (zumindestens nicht bei mehr als 2 Elementen)
            // mit padding klappt es auch nicht, aber mit margin... zum Glück
            [self.jsOutput appendString:@"  // ansonsten wegen 'spacing' nach rechts rücken\n"];
            [self.jsOutput appendString:@"  document.getElementById('"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').style.marginLeft = '"];
            [self.jsOutput appendString:[NSString stringWithFormat:@"%d", spacing_x]];
            [self.jsOutput appendString:@"px';\n\n"];
        }
        self.firstElementOfSimpleLayout_x = NO;
    }
}

// ToDo: Im Release kommt hier das "exit(0);" dann raus.
- (void) instableXML:(NSString*)s
{
    NSLog([NSString stringWithFormat:@"%@",s]);
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Exception geworfen" userInfo:nil];
    // exit(0);
}




-(void) callMyselfRecursive:(NSString*)relativePath
{
    NSURL *path = [self.pathToFile URLByDeletingLastPathComponent];
    NSURL *pathToFile = [NSURL URLWithString:relativePath relativeToURL:path];

    xmlParser *x = [[xmlParser alloc] initWith:pathToFile recursiveCall:YES];
    // Wenn es eine Datei ist, die Items für ein Dataset enthält, dann muss das rekursiv
    // auferufene Objekt das letzte DataSet wissen, damit es die Items richtig zuordnen kann
    x.lastUsedDataset = self.lastUsedDataset;
    // Zur Zeit ignorieren wir Datasets mit eigenen bennannten Tags, deswegen müssen wir
    // falls diese in einer eigenen Datei definiert sind, dies mitteilen
    x.weAreInDatasetAndNeedToCollectTheFollowingTags = self.weAreInDatasetAndNeedToCollectTheFollowingTags;

    NSArray* result = [x start];

    if ([[result objectAtIndex:0] isEqual:@"XML-File not found"])
    {
        NSLog(@"Recursive given file wasn't found. Parsing of this file aborted.");
        NSLog([NSString stringWithFormat:@"Filename is: \"%@\"",[pathToFile absoluteString]]);
        NSLog(@"I can't help it. This file doesn't exist.");
        // 5 Stunden Zeit verloren wegen diesem Aufruf... Man kann nicht rekursiv abbrechen.
        // [self.parser abortParsing];
        self.issueWithRecursiveFileNotFound = [pathToFile absoluteString];
    }
    else
    {
        [self.output appendString:[result objectAtIndex:0]];
        [self.jsOutput appendString:[result objectAtIndex:1]];
        [self.jsOLClassesOutput appendString:[result objectAtIndex:2]];
        [self.jQueryOutput0 appendString:[result objectAtIndex:3]];
        [self.jQueryOutput appendString:[result objectAtIndex:4]];
        [self.jsHeadOutput appendString:[result objectAtIndex:5]];
        [self.jsHead2Output appendString:[result objectAtIndex:6]];
        [self.cssOutput appendString:[result objectAtIndex:7]];
        [self.externalJSFilesOutput appendString:[result objectAtIndex:8]];
        [self.allJSGlobalVars addEntriesFromDictionary:[result objectAtIndex:9]];
        [self.allFoundClasses addEntriesFromDictionary:[result objectAtIndex:10]];
    }

    NSLog(@"Leaving recursion");
}




#pragma mark Delegate calls

- (void) parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
     attributes:(NSDictionary *)attributeDict
{
    // Zum internen testen, ob wir alle Elemente erfasst haben
    BOOL element_bearbeitet = NO;

    // Zum internen testen, ob wir alle Attribute erfasst haben
    self.attributeCount = 0;

    // Zählt alle Elemente durch
    // Berücksichtigt noch keine rekursiv erfassten Element
    // Hat derzeit nur rein statistische Zwecke bzw. keinen Zweck (ToDo - Delete?)
    self.elementeZaehler++;


    if ([elementName isEqualToString:@"items"])
    {
        element_bearbeitet = YES;


        // markierung für den Beginn der item-Liste
        self.datasetItemsCounter = 0;


        // Hier muss ich auch die Var auf NO setzen, denn dann sind es nur normale 'items', die
        // ich einsammeln kann und keine tags die im Tag-Namem den Variablennamen haben
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
    }

    // skipping All Elements in dataset without attribut 'src', die nicht 'items' sind
    // Muss ich dringend tun und wenn ich hier drin bin alle Tags einsammeln (ToDo)
    if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
    {
        [self.collectedContentOfClass appendString:@""];

        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@ for now.", elementName]);
        return;
    }

    // skipping All Elements in Class-elements (ToDo)
    // skipping all Elements in splash (ToDo)
    // skipping all Elements in fileUpload (ToDo)
    if (self.weAreSkippingTheCompleteContenInThisElement)
    {
        // Wenn wir in <class> sind, sammeln wir alles (wird erst später rekursiv ausgewertet)
        // Erst den Elementnamen hinzufügen
        [self.collectedContentOfClass appendFormat:@"<%@",elementName];


        // Dann die Attribute
        NSArray *keys = [attributeDict allKeys];
        if ([keys count] > 0)
        {
            for (NSString *key in keys)
            {
                [self.collectedContentOfClass appendString:@" "];
                [self.collectedContentOfClass appendString:key];
                [self.collectedContentOfClass appendString:@"=\""];


                // Es ist mir folgendes passiert: XML-Parser beschwert sich über '<'-Zeichen im
                // Attribut. Dies ist tatsächlich ein XML-Verstoß. Tatsächlich steht im OL-Code
                // auch '&lt;' und nicht '<'. Warum wandelt der Parser dies um????
                // Jedenfalls muss ich durch alle Attribute durch und dort '<' durch '&lt;'
                // wieder zurück ersetzen. Das gleiche gilt für & und &amp;
                NSString *s = [attributeDict valueForKey:key];
                // Das &-ersetzen muss natürlich als erstes kommen, weil ich danach ja wieder
                // welche einfüge (durch die Entitys).
                s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
                s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];

                
                [self.collectedContentOfClass appendString:s];
                [self.collectedContentOfClass appendString:@"\""];
            }
        }

        [self.collectedContentOfClass appendString:@">"];

        // Falls der unverändert bleibt, muss ich das eben gesetzte '>' wieder entfernen und durch '/>' ersetzen
        self.element_merker = elementName;


        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@", elementName]);
        return;
    }
    // skipping All Elements in BDSreplicator (ToDo)
    // skipping all Elements in BDSinputgrid (ToDo)
    if (self.weAreSkippingTheCompleteContenInThisElement2)
    {
        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@", elementName]);
        return;
    }
    // skipping All Elements in nicebox (ToDo)
    if (self.weAreSkippingTheCompleteContenInThisElement3)
    {
        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@", elementName]);
        return;
    }

    // Skipping the elements in all when-truncs, except the first one
    if (self.weAreInTheTagSwitchAndNotInTheFirstWhen)
    {
        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@", elementName]);
        return;
    }

    // Alle einzeln durchgehen, damit wir besser fehlende überprüfen können, deswegen ist dies kein redundanter Code
    if (self.weAreInBDStextAndThereMayBeHTMLTags)
    {
        if ([elementName isEqualToString:@"br"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendString:@"<br />"];
            return;
        }

        if ([elementName isEqualToString:@"b"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendString:@"<b>"];
            return;
        }

        if ([elementName isEqualToString:@"u"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendString:@"<u>"];
            return;
        }

        if ([elementName isEqualToString:@"font"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendString:@"<font"];
            for (id e in attributeDict)
            {
                // Alle Elemente in font (color usw...) einfach ausgeben
                [self.textInProgress appendString:[NSString stringWithFormat:@" %@",e]];
                [self.textInProgress appendString:[NSString stringWithFormat:@"=\"%@\"",[attributeDict valueForKey:e]]];
            }
            [self.textInProgress appendString:@">"];
            return;
        }
    }





    self.verschachtelungstiefe++;




    NSLog([NSString stringWithFormat:@"\nOpening Element: %@", elementName]);
    NSLog([NSString stringWithFormat:@"with these attributes: %@\n", attributeDict]);

    // This is a string we will append to as the text arrives
    self.textInProgress = [[NSMutableString alloc] init];

    // Kann ich eventuell noch gebrauchen um das aktuelle Tag abzufragen
    self.keyInProgress = [elementName copy];


    if ([elementName isEqualToString:@"window"] ||
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"rotateNumber"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"buttonnext"] ||
        [elementName isEqualToString:@"BDSedit"] ||
        [elementName isEqualToString:@"BDStext"] ||
        [elementName isEqualToString:@"text"] ||
        [elementName isEqualToString:@"button"] ||
        [elementName isEqualToString:@"rollUpDownContainer"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"rollUpDown"])
            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];




    // Sollte als erstes stehen, damit der zuletzt gesetzte Zähler, auf den hier zurückgegriffen wird, noch stimmt.
    if ([elementName isEqualToString:@"simplelayout"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"spacing"])
            self.attributeCount++;



        // ToDo - Eine Abstandsangabe für das erste Element.
        if ([attributeDict valueForKey:@"inset"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'inset' for now.");
        }
        // ToDo - Name... puh... dabei hat SimpleLayout gar kein eigenes div, oder?
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'name' for now.");
        }


        // Simplelayout mit Achse Y berücksichtigen
        if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"y"])
        {
            self.attributeCount++;


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

            // SimpleLayout-Tiefenzähler (y) um 1 erhöhen
            self.simplelayout_y_tiefe++;

            /*******************/
            // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Breite
            // der beinhaltenden Elemente an.
            // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
            // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
            [self.jsOutput appendString:@"// Eventuell nachfolgende Simplelayouts müssen entsprechend der Breite des vorherigen umgebenden Divs aufrücken.\n"];

            // [self.jsOutput appendString:@"// position:absolute richtet sich perfekt selber aus, nur bei position:relative ist es nötig.\n"];

            // If-Abfrage drum herum als Schutz gegen unbekannte Elemente oder wenn simplelayout
            // das letzte Element mehrerer Geschwister ist, was nicht unterstützt wird (es muss
            // stets das erste sein)
            [self.jsOutput appendString:@"if (document.getElementById('"];
            [self.jsOutput appendString:self.zuletztGesetzteID];
            [self.jsOutput appendString:@"').lastElementChild"];

            // Ich nehme Test auf position: relative hier mal raus
            // Leider klappt es nur dann z.B. bei dem 'Taxango Foren'-Button
            // [self.jsOutput appendFormat:@"&& $('#%@').css('position') == 'relative'",self.zuletztGesetzteID];

            [self.jsOutput appendString:@")\n{\n"];
            [self.jsOutput appendFormat:@"  var widths = $('#%@').children().map(function () { return $(this).outerWidth(); }).get();\n",self.zuletztGesetzteID];

            // [self.jsOutput appendString:@"  alert(widths);\n"];
            // [self.jsOutput appendString:@"  alert(getMaxOfArray(widths));\n"];

            [self.jsOutput appendFormat:@"  $('#%@').css('width',getMaxOfArray(widths));\n}\n\n",self.zuletztGesetzteID];






            // Alte Lösung ohne jQuery - nicht mehr nötig.
            //[self.jsOutput appendString:@"  document.getElementById('"];
            //[self.jsOutput appendString:self.zuletztGesetzteID];
            //[self.jsOutput appendString:@"').style.width = document.getElementById('"];
            //[self.jsOutput appendString:self.zuletztGesetzteID];
            // ToDo -> Done!: Hier muss ich eigentlich dasjenige Kind suchen, welches die größte Breite hat
            // offsetWidth killt zu vieles, z.B. Width element9, deswegen style.width lassen
            //[self.jsOutput appendString:@"').lastElementChild.style.width"];
            //[self.jsOutput appendString:@";\n\n"];
            /*******************/


            // Auch noch die Höhe setzen! (Damit die Angaben im umgebenden Div stimmen)
            // Da sich valign=middle auf die Höhenangabe bezieht, muss diese mit jQueryOutput0
            // noch vor allen anderen Angaben gesetzt werden.
            // Jedoch darf die Höhe nicht bei RollUpDownContainern gesetzt werden, da diese immer
            // auf 'auto' gestellt sein müssen, damit es gescheit mit scrollt.

            [self.jQueryOutput0 appendString:@"\n\n  // Y-Simplelayout: Deswegen die Höhe aller beinhaltenden Elemente auf erster Ebene ermitteln\n  // und dem umgebenden div die Summe als Höhe mitgeben (nur bei rudElement MUSS es auto bleiben)\n"];
            [self.jQueryOutput0 appendString:@"  var sumH = 0;\n"];
            // [self.jQueryOutput0 appendString:@"  var zaehler = 0;\n"];
            [self.jQueryOutput0 appendString:@"  $('#"];
            [self.jQueryOutput0 appendString:self.zuletztGesetzteID];
            [self.jQueryOutput0 appendString:@"').children().each(function() {\n    sumH += $(this).outerHeight(true);\n"];
            // [self.jQueryOutput0 appendString:@"    zaehler++;\n"];
            [self.jQueryOutput0 appendString:@"  });\n"];

            // Seitdem ich den y-abstand stets per margin setze, darf ich den y-abstand nicht mehr
            // setzen, da er in outerWidth(true) ja bereits enthalten ist!
            // [self.jQueryOutput0 appendString:@"  sumH += (zaehler-1) * "];
            // [self.jQueryOutput0 appendString:[self.simplelayout_y_spacing lastObject]];
            // [self.jQueryOutput0 appendString:@";\n"];

            [self.jQueryOutput0 appendString:@"  if (!($('#"];
            [self.jQueryOutput0 appendString:self.zuletztGesetzteID];
            [self.jQueryOutput0 appendString:@"').hasClass('rudElement')))"];
            [self.jQueryOutput0 appendString:@"\n    $('#"];
            [self.jQueryOutput0 appendString:self.zuletztGesetzteID];
            [self.jQueryOutput0 appendString:@"').height(sumH);\n"];
            // [self.jQueryOutput appendString:@"\n  console.log('Die Simplelayout-Höhe ist: ' + sumH);"];
        }



        // Simplelayout mit Achse X berücksichtigen
        if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"x"])
        {
            self.attributeCount++;


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

            // SimpleLayout-Tiefenzähler (x) um 1 erhöhen
            self.simplelayout_x_tiefe++;


            /*******************/
            // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Höhe
            // der beinhaltenden Elemente an.
            // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
            // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
            [self.jsOutput appendString:@"// Eventuell nachfolgende Simplelayouts müssen entsprechend der Höhe des vorherigen umgebenden Divs aufrücken.\n"];
            [self.jsOutput appendString:@"// position:absolute richtet sich perfekt selber aus, nur bei position:relative ist es nötig.\n"];

            // If-Abfrage drum herum als Schutz gegen unbekannte Elemente oder wenn simplelayout
            // das letzte Element mehrerer Geschwister ist, was nicht unterstützt wird (es muss
            // stets das erste sein)
            [self.jsOutput appendString:@"if (document.getElementById('"];
            [self.jsOutput appendString:self.zuletztGesetzteID];
            [self.jsOutput appendString:@"').lastElementChild"];
            [self.jsOutput appendFormat:@"&& $('#%@').css('position') == 'relative'",self.zuletztGesetzteID];
            [self.jsOutput appendString:@")\n{\n"];
            [self.jsOutput appendFormat:@"  var heights = $('#%@').children().map(function () { return $(this).outerHeight(); }).get();\n",self.zuletztGesetzteID];

            // [self.jsOutput appendString:@"  alert(heights);\n"];
            // [self.jsOutput appendString:@"  alert(getMaxOfArray(heights));\n"];

            [self.jsOutput appendFormat:@"  $('#%@').css('height',getMaxOfArray(heights));\n}\n\n",self.zuletztGesetzteID];

            // Alte Lösung ohne jQuery - nicht mehr nötig.
            //[self.jsOutput appendString:@"  document.getElementById('"];
            //[self.jsOutput appendString:self.zuletztGesetzteID];
            //[self.jsOutput appendString:@"').style.height = document.getElementById('"];
            //[self.jsOutput appendString:self.zuletztGesetzteID];
            // ToDo -> Done!: Hier muss ich eigentlich dasjenige Kind suchen, welches die größte height hat
            //[self.jsOutput appendString:@"').lastElementChild.style.height"];
            //[self.jsOutput appendString:@";\n}\n\n"];
            /*******************/


            // Auch noch die Breite setzen! (Damit die Angaben im umgebenden Div stimmen)
            // Da sich valign=middle auf die Höhenangabe bezieht, muss diese mit jQueryOutput0
            // noch vor allen anderen Angaben gesetzt werden.
            // Update: Bricht Element9 (z.B.), es wird dann zu breit, deswegen bei
            // position:absolute es sich per CSS-Angabe -> width:Auto und float:left sich selbst
            // optimal ausrichten lassen.
            // Nur bei position:relative muss ich nachhelfen, weil es dort sonst 0 wäre
            // Auf sowas erstmal zu kommen.... oh man.

            [self.jQueryOutput0 appendString:@"\n  // X-Simplelayout: Deswegen die Breite aller beinhaltenden Elemente auf erster Ebene ermitteln und dem umgebenden div die Summe als\n  // Breite mitgeben (das darf nur bei position:relative gemacht werden, position:absolute nimmt von selbst die perfekte Breite an)\n"];
            [self.jQueryOutput0 appendString:@"  var sumW = 0;\n"];
            //[self.jQueryOutput0 appendString:@"  var zaehler = 0;\n"];
            [self.jQueryOutput0 appendString:@"  $('#"];
            [self.jQueryOutput0 appendString:self.zuletztGesetzteID];
            [self.jQueryOutput0 appendString:@"').children().each(function() {\n    sumW += $(this).outerWidth(true);\n"];
            // [self.jQueryOutput0 appendString:@"    zaehler++;\n"];
            [self.jQueryOutput0 appendString:@"  });\n"];

            // Seitdem ich den x-abstand stets per margin setze, darf ich den x-abstand nicht mehr
            // setzen, da er in outerWidth(true) ja bereits enthalten ist!
            // [self.jQueryOutput0 appendString:@"  sumW += (zaehler-1) * "];
            // [self.jQueryOutput0 appendString:[self.simplelayout_x_spacing lastObject]];
            // [self.jQueryOutput0 appendString:@";\n"];

            [self.jQueryOutput0 appendString:@"  if ($('#"];
            [self.jQueryOutput0 appendString:self.zuletztGesetzteID];
            [self.jQueryOutput0 appendString:@"').css('position') == 'relative'"];
            [self.jQueryOutput0 appendString:@")\n"];

            [self.jQueryOutput0 appendString:@"    $('#"];
            [self.jQueryOutput0 appendString:self.zuletztGesetzteID];
            [self.jQueryOutput0 appendString:@"').width(sumW);\n"];
        }
    }






    if ([elementName isEqualToString:@"include"])
    {
        element_bearbeitet = YES;

        NSLog(@"Include Tag found! So I am calling myself recursive");

        if (![attributeDict valueForKey:@"href"])
        {
            [self instableXML:@"ERROR: No attribute 'src' given in include-tag"];
        }
        else
        {
            self.attributeCount++;
            NSLog(@"Using the element 'href' as path to the recursive called file.");
        }

        [self callMyselfRecursive:[attributeDict valueForKey:@"href"]];
    }




    // font als CSS anlegen
    if ([elementName isEqualToString:@"font"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"name"])
            [self instableXML:@"ERROR: No attribute 'name' given in font-tag"];
        else
            self.attributeCount++;
        if (![attributeDict valueForKey:@"src"])
            [self instableXML:@"ERROR: No attribute 'src' given in font-tag"];
        else
            self.attributeCount++;

        if ([attributeDict valueForKey:@"style"])
        {
            self.attributeCount++;
            NSLog(@"Setting the element 'font' as CSS '@font-face' (with 'name' and 'src' and 'style').");
        }
        else
        {
            NSLog(@"Setting the element 'font' as CSS '@font-face' (with 'name' and 'src').");
        }

        NSString *name = [attributeDict valueForKey:@"name"];
        NSString *src = [attributeDict valueForKey:@"src"];
        NSString *weight;
        if ([attributeDict valueForKey:@"style"])
            weight = [attributeDict valueForKey:@"style"];
        else
            weight = @"normal";


        [self.cssOutput appendString:@"@font-face {\n  font-family: "];
        [self.cssOutput appendString:name];
        [self.cssOutput appendString:@";\n  src: url('"];
        [self.cssOutput appendString:src];
        [self.cssOutput appendString:@"');\n"];
        [self.cssOutput appendString:@"  font-style: normal;\n"];
        [self.cssOutput appendString:@"  font-weight: "];
        [self.cssOutput appendString:weight];
        [self.cssOutput appendString:@";\n}\n\n"];
    }


    if ([elementName isEqualToString:@"canvas"])
    {
        element_bearbeitet = YES;



        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];

        [self.output appendString:@" class=\"ol_standard_canvas\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict toElement:elementName]];

        [self.output appendString:@"\">\n"];

        // Wir deklarieren Angaben zur Schriftart und Schriftgröße lieber nochmal als CSS für das
        // body-Element. Aber nur wenn font-art oder wenigstens fontsize auch angegeben wurde
        if ([attributeDict valueForKey:@"fontsize"] || [attributeDict valueForKey:@"font"])
        {
            NSString *fontsize;
            if ([attributeDict valueForKey:@"fontsize"])
                fontsize = [attributeDict valueForKey:@"fontsize"];
            else
                fontsize = @"12";

            NSString *font;
            if ([attributeDict valueForKey:@"font"])
                font = [attributeDict valueForKey:@"font"];
            else
                font = @"";

            [self.cssOutput appendString:@"body\n{\n  text-align: center;\n  font-size: "];
            [self.cssOutput appendString:fontsize];
            [self.cssOutput appendString:@"px;\n"];
            [self.cssOutput appendString:@"  font-family: "];
            [self.cssOutput appendString:font];
            [self.cssOutput appendString:@", Verdana, Helvetica, sans-serif, Arial;\n"];

            // Auch noch die Hintergrundfarbe auf Body anwenden, falls vorhanden
            if ([attributeDict valueForKey:@"bgcolor"])
            {
                [self.cssOutput appendString:@"  background-color: "];
                [self.cssOutput appendString:[attributeDict valueForKey:@"bgcolor"]];
                [self.cssOutput appendString:@";\n"];
            }

            [self.cssOutput appendString:@"}\n\n"];


            // auch für div.ol_text muss ich font-size und font-family übernehmen
            [self.cssOutput appendString:@"div.ol_text\n{\n  font-size: "];
            [self.cssOutput appendString:fontsize];
            [self.cssOutput appendString:@"px;\n"];
            [self.cssOutput appendString:@"  font-family: "];
            [self.cssOutput appendString:font];
            [self.cssOutput appendString:@", Verdana, Helvetica, sans-serif, Arial;\n"];
            [self.cssOutput appendString:@"}\n\n"];
        }
    }






    if ([elementName isEqualToString:@"dataset"])
    {
        element_bearbeitet = YES;


        // Erstmal ignorieren
        if ([attributeDict valueForKey:@"proxied"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'proxied'.");
        }

        // Erstmal ignorieren
        if ([attributeDict valueForKey:@"timeout"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'timeout'.");
        }



        if (![attributeDict valueForKey:@"name"])
            [self instableXML:@"ERROR: No attribute 'name' given in dataset-tag"];
        else
            self.attributeCount++;

        NSString *name = [attributeDict valueForKey:@"name"];
        self.lastUsedDataset = name; // item braucht es später
        NSLog(@"Using the attribute 'name' as name for a new JS-Array().");






        // Dringend ToDo -> ungefähre Anleitung: Alle nachfolgenden Tags in eine eigene Data-Struktur überführen
        // Und diese Tags nicht auswerten lassen vom XML-Parser
        // Aber wieder rückgängig machen in 'items', falls wir darauf stoßen
        // Muss (logischerweise) vor der Rekursion stehen, deswegen steht es hier oben
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = YES;





        // Ein Array mit dem Namen des gefundenen datasets und den dataset-items als Elementen
        [self.jsHead2Output appendString:@"// Ein Array mit dem Namen des gefundenen datasets und den dataset-items als Elementen\n"];

        [self.jsHead2Output appendString:@"var "];
        [self.jsHead2Output appendString:name];
        [self.jsHead2Output appendString:@" = new Array();\n"];


        // Fals es per src in eigener externer Datei angegeben ist, müssen wir diese auslesen
        if ([attributeDict valueForKey:@"src"])
        {
            self.attributeCount++;

            // type ignorieren wir, ist wohl immer auf 'http'
            if ([attributeDict valueForKey:@"type"])
            {
                self.attributeCount++;
                NSLog(@"Skipping the attribute 'type'.");
            }
            // request ignorieren wir, ist wohl immer auf 'true' bzw. spielt für JS keine Rolle
            if ([attributeDict valueForKey:@"request"])
            {
                self.attributeCount++;
                NSLog(@"Skipping the attribute 'request'.");
            }

            // querytype ist wohl ein request in die Wolke (auf eine .php-Datei), erstmal ignorieren
            // Es gibt als Querytipe sowohl "POST", als auch "GET"
            // ToDo onwerk
            if ([attributeDict valueForKey:@"querytype"])
            {
                self.attributeCount++;
                NSLog(@"Skipping the attribute 'querytype'.");
                if ([[attributeDict valueForKey:@"querytype"] isEqualToString:@"POST"])
                    NSLog(@"I will ignore this src-file for now (it's a POST-Request).");
                else
                    NSLog(@"I will ignore this src-file for now (it's a GET-Request).");
            }
            else
            {
                NSLog([NSString stringWithFormat:@"'src'-Attribute in dataset found! So I am calling myself recursive with the file %@",[attributeDict valueForKey:@"src"]]);
                [self callMyselfRecursive:[attributeDict valueForKey:@"src"]];
            }
        }
        else
        {
            // Die in <items> enthaltenen <item>-Elemente werden ausgelesen.
        }
    }


    if ([elementName isEqualToString:@"datapointer"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"xpath"])
            self.attributeCount++;
    }





    // ToDo falls kommerziell: Die gefunden Attribute automatisch hinzufügen zur Klasse und
    // nicht wie hier, weil wir wissen welche Attribute es alles gibt bei 'item'
    if ([elementName isEqualToString:@"item"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"value"])
        {
            [self instableXML:@"ERROR: No attribute 'value' given in item-tag"];
        }
        else
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'value' as index for JS-Array.");
        }

        // Könnten wir nochmal brauchen, kann hier aber auch deaktiviert werden (Schalter)
        BOOL useAssociativeJSArray = NO;

        [self.jsHead2Output appendString:self.lastUsedDataset];
        [self.jsHead2Output appendString:@"["];
        if (useAssociativeJSArray)
        {
            [self.jsHead2Output appendString:@"'"];
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"value"]];
            [self.jsHead2Output appendString:@"'"];
        }
        else
        {
            // Könnten wir nochmal brauchen, kann hier aber auch deaktiviert werden (Schalter)
            BOOL arrayLengthToInsertNewArrayElements = NO;
            if (arrayLengthToInsertNewArrayElements)
            {
                [self.jsHead2Output appendString:self.lastUsedDataset];
                [self.jsHead2Output appendString:@".length"];
            }
            else
            {
                [self.jsHead2Output appendString:[NSString stringWithFormat:@"%d",self.datasetItemsCounter]];
                self.datasetItemsCounter++;
            }
        }
        [self.jsHead2Output appendString:@"] = new datasetItem("];
        if (!isNumeric([attributeDict valueForKey:@"value"]))
            [self.jsHead2Output appendString:@"'"];
        [self.jsHead2Output appendString:[attributeDict valueForKey:@"value"]];
        if (!isNumeric([attributeDict valueForKey:@"value"]))
            [self.jsHead2Output appendString:@"'"];

        if ([attributeDict valueForKey:@"info"])
        {
            self.attributeCount++;

            [self.jsHead2Output appendString:@",'"];
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"info"]];
            [self.jsHead2Output appendString:@"'"];
        }
        else
        {
            [self.jsHead2Output appendString:@",''"];
        }

        if ([attributeDict valueForKey:@"afa"])
        {
            self.attributeCount++;
            
            [self.jsHead2Output appendString:@",'"];
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"afa"]];
            [self.jsHead2Output appendString:@"'"];
        }
        else
        {
            [self.jsHead2Output appendString:@",''"];
        }

        if ([attributeDict valueForKey:@"check"])
        {
            self.attributeCount++;
            
            [self.jsHead2Output appendString:@",'"];
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"check"]];
            [self.jsHead2Output appendString:@"'"];
        }
        else
        {
            [self.jsHead2Output appendString:@",''"];
        }

        [self.jsHead2Output appendString:@",'"];
    }




    if ([elementName isEqualToString:@"resource"])
    {
        element_bearbeitet = YES;

         // Falls src angegeben ist, kann die var direkt gespeichert werden.
        if ([attributeDict valueForKey:@"src"])
        {
            self.attributeCount++;


            if (![attributeDict valueForKey:@"name"])
                [self instableXML:@"ERROR: No attribute 'name' given in resource-tag"];
            else
                self.attributeCount++;

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
            self.attributeCount++;

            // Ansonsten machen wir im tag 'frame' weiter
            self.last_resource_name_for_frametag = [attributeDict valueForKey:@"name"];
        }
    }




    if ([elementName isEqualToString:@"attribute"])
    {
        element_bearbeitet = YES;


        if (![attributeDict valueForKey:@"name"])
            [self instableXML:@"ERROR: No attribute 'name' given in attribute-tag"];
        else
            self.attributeCount++;


        // Es gibt auch attributes ohne type, dann mit 'number' initialisieren...
        // ... das klappt leider nicht. Weil es auch Nichtzahlen gibt ohne 'type'
        // Deswegen doch lieber als 'string' initialsieren.
        NSString *type_;
        if ([attributeDict valueForKey:@"type"])
        {
            NSLog(@"Using the attribute 'type' to determine if we need quotes.");
            self.attributeCount++;
            type_ = [attributeDict valueForKey:@"type"];
        }
        else
            type_ = @"string";


        // Es gibt auch attributes ohne Startvalue, dann mit einem leeren String initialisieren
        NSString *value;
        if ([attributeDict valueForKey:@"value"])
        {
            NSLog(@"Setting the attribute 'value' as value of the class-member (see next line).");
            self.attributeCount++;
            value = [attributeDict valueForKey:@"value"];
        }
        else
            value = @""; // Quotes werden dann automatisch unten reingesetzt


        // Das Attribut 'setter' hmmm, ToDo
        if ([attributeDict valueForKey:@"setter"])
        {
            NSLog(@"Skipping the attribute 'setter' (ToDo).");
            self.attributeCount++;
        }


        // ToDo: 'attrbute' kann bis jetzt nur globale Variable verarbeiten, die direkt in canvas liegen
        if ([attributeDict valueForKey:@"name"])
        {
            NSLog([NSString stringWithFormat:@"Setting '%@' as class-member in JavaScript-class 'canvas'.",[attributeDict valueForKey:@"name"]]);

            BOOL weNeedQuotes = YES;
            if ([type_ isEqualTo:@"boolean"] ||
                [type_ isEqualTo:@"number"])
                weNeedQuotes = NO;

            // Kann auch ein berechneter Werte sein ($ davor). Wenn ja dann $ usw. entfernen
            // und wir arbeiten dann natürlich ohne Quotes.
            if ([value hasPrefix:@"$"])
            {
                value = [self removeOccurrencesofDollarAndCurlyBracketsIn:value];
                weNeedQuotes = NO;
            }

            [self.jsHead2Output appendString:@"canvas."];
            [self.jsHead2Output appendString:[attributeDict valueForKey:@"name"]];
            [self.jsHead2Output appendString:@" = "];
            if (weNeedQuotes)
                [self.jsHead2Output appendString:@"\""];
            [self.jsHead2Output appendString:value];
            if (weNeedQuotes)
                [self.jsHead2Output appendString:@"\""];
            [self.jsHead2Output appendString:@";\n"];

            // Auch intern die Var speichern? Erstmal nein. Wir wollen bewusst per JS/jQuery immer
            // drauf zugreifen! Weil die Variablen nach dem Export noch benutzbar sein sollen.
            // [self.allJSGlobalVars setObject:[attributeDict valueForKey:@"src"] forKey:[attributeDict valueForKey:@"name"]];
        }

        // Das Attribut 'when' taucht in Doku nicht auf, wird ignoriert
        if ([attributeDict valueForKey:@"when"])
        {
            NSLog(@"Skipping the attribute 'when'.");
            self.attributeCount++;
        }
    }






    if ([elementName isEqualToString:@"frame"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"src"])
            [self instableXML:@"ERROR: No attribute 'src' given in frame-tag"];
        else
            self.attributeCount++;

        // Erstmal alle frame-Einträge sammeln, weil wir nicht wissen wie viele noch kommen
        [self.collectedFrameResources addObject:[attributeDict valueForKey:@"src"]];
    }



    if ([elementName isEqualToString:@"window"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div class=\"ol_standard_window\""];

        // id hinzufügen und gleichzeitg speichern
        NSString *id = [self addIdToElement:attributeDict];
        [self.output appendString:@" style=\""];



        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

        // ToDo: Wird derzeit nicht ausgewertet - macht es überhaupt Sinn Window anzuzeigen? Irgendwas mit debug
        if ([attributeDict valueForKey:@"closeable"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'closeable' for now.");
        }
        if ([attributeDict valueForKey:@"resizable"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'resizable' for now.");
        }
        if ([attributeDict valueForKey:@"visible"])
        {
            // self.attributeCount++;
            // NSLog(@"Skipping the attribute 'visible' for now.");
        }
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'name' for now.");
        }


        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];
    }












    if ([elementName isEqualToString:@"view"] || [elementName isEqualToString:@"rotateNumber"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];


        // id hinzufügen und gleichzeitg speichern
        NSString *id = [self addIdToElement:attributeDict];



        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur in view wegen 'cobrand-view',
        // hätte sonst eventuell zu viele Seiteneffekte.
        // Außerdem ist name hier nicht erlaubt gemäß HTML-Validator als Attribut bei DIVs
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the views attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }




        // Wird derzeit noch übersprungen (ToDo)
        if ([attributeDict valueForKey:@"layout"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'layout' on view (ToDo).");
        }
        // Wird derzeit noch übersprungen (ToDo)
        if ([attributeDict valueForKey:@"frame"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'frame' on view (ToDo).");
        }
        // Wird derzeit noch übersprungen (ToDo)
        if ([attributeDict valueForKey:@"clip"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'clip' on view (ToDo).");
        }
        // Wird derzeit noch übersprungen (ToDo)
        if ([attributeDict valueForKey:@"ignoreplacement"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'ignoreplacement' on view (ToDo).");
        }


        // ToDo: Seit auswerten von <class> gibt es placement doch merhmals....
        if ([attributeDict valueForKey:@"placement"])
        {
            self.attributeCount++; // ToDo, dann einzeln reinschieben in die isEqualToString:@"x"

            // Es gibt nur einmal im gesamten Code das Attribut placement mit _info
            // Die zugehörige Klasse '_info' ist in BDSlib.lzx definiert
            // Aber nur dafür extra 'class' auslesen lohnt nicht, stattdessen setzen wir die
            // Attribute einfach manuell (Trick).
            if ([[attributeDict valueForKey:@"placement"] isEqualToString:@"_info"])
            {


                [self.jQueryOutput appendString:@"\n  // Anstatt 'placement' auszuwerten...\n"];
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('background-color','#D3964D');\n",id]];
                // [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('border-right','#D29860 1px solid');\n",id]];
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('left','2px');\n",id]];
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('top','39px');\n",id]]; // 39 anstatt 40, damit der Strich am iPad verschwindet
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('width','inherit');\n",id]];
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').css('height','50px');\n",id]];
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').children().filter(':last').css('top','8px');\n",id]];
            }
        }


        [self.output appendString:@" class=\"ol_standard_view\" style=\""];


        [self.output appendString:[self addCSSAttributes:attributeDict]];


        [self.output appendString:@"\">\n"];

        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];
    }





    if ([elementName isEqualToString:@"button"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<!-- Normaler button: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        [self.output appendString:@"<input type=\"button\""];

        // id hinzufügen und gleichzeitg speichern
        NSString *id = [self addIdToElement:attributeDict];






        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur hier
        // hätte sonst eventuell zu viele Seiteneffekte.
        // Außerdem ist name hier nicht erlaubt gemäß HTML-Validator als Attribut bei DIVs
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the views attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }





        [self.output appendString:@" class=\"ol_standard_view\" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        [self.output appendString:@"\" "];

        // Den Text als Beschriftung für den Button setzen
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            [self.output appendString:@"value=\""];
            [self.output appendString:[attributeDict valueForKey:@"text"]];
            [self.output appendString:@"\""];
        }



        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"isdefault"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'isdefault' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"placement"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'placement' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"focusable"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'focusable' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"doesenter"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'doesenter' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"clip"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'clip' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"text_padding_x"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text_padding_x' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"text_x"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text_x' for now.");
        }




        [self.output appendString:@" />\n"];

        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];
    }




    // ToDo: BaseButton sichtbar und schön machen per CSS und eigene class dafür (evtl. button von
    // jQuery UI?
    if ([elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"buttonnext"])
    {
        element_bearbeitet = YES;


        if ([elementName isEqualToString:@"basebutton"])
            [self.output appendString:@"<!-- Basebutton: -->\n"];
        else if ([elementName isEqualToString:@"imgbutton"])
            [self.output appendString:@"<!-- Imagebutton: -->\n"];
        else
            [self.output appendString:@"<!-- Buttonnext: -->\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];


        [self.output appendString:@"<div"];

        // id hinzufügen und gleichzeitg speichern
        NSString *id = [self addIdToElement:attributeDict];




        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur in buttonnext
        // hätte sonst eventuell zu viele Seiteneffekte.
        // Außerdem ist name nicht erlaubt gemäß HTML-Validator als Attribut bei DIVs
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the buttons attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }



        [self.output appendString:@" class=\"ol_standard_view\" style=\""];


        [self.output appendString:[self addCSSAttributes:attributeDict]];


        [self.output appendString:@"\">\n"];


        // ToDo: Wird derzeit nicht ausgewertet - gemäß Doku ist hier 'false' der Standardwert, aber puh
        if ([attributeDict valueForKey:@"focusable"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'focusable' for now.");
        }

        // ToDo: Wird derzeit nicht ausgewertet - ist zum ersten mal bei einem imgbutton aufgetaicht (nur da?)
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text' for now.");
        }

        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];
    }




    // ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand der definierten Klasse erkannt werden
    if ([elementName isEqualToString:@"BDStext"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];





        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur hier,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es in div auch nicht erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }





        [self.output appendString:@" class=\"ol_text\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];


        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"multiline"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'multiline' for now.");
        }


        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;

            if ([[attributeDict valueForKey:@"text"] hasPrefix:@"$"])
            {
                NSLog(@"Setting the attribute 'text' later with jQuery, because it is Code.");
                [self.output appendString:@"CODE! - Wird dynamisch mit jQuery ersetzt."];


                NSString *code = [attributeDict valueForKey:@"text"];
                // Remove all occurrences of $,{,}
                code = [self removeOccurrencesofDollarAndCurlyBracketsIn:code];


                // ToDo, mit ShowEUR gibt es noch Probs
                if ([code rangeOfString:@"ShowEUR"].location == NSNotFound)
                {
                    [self.jQueryOutput appendString:@"\n  // Der Text von BDSText wird hier dynamisch gesetzt\n"];
                    [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').html(%@);\n",self.zuletztGesetzteID,code]];
                }
            }
            else
            {
                NSLog(@"Setting the attribute 'text' as text between opening and closing tag.");
                [self.output appendString:[attributeDict valueForKey:@"text"]];
            }
        }

        self.weAreInBDStextAndThereMayBeHTMLTags = YES;
        NSLog(@"We won't include possible following HTML-Tags, because it is content of the text.");

        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]]];
    }


    // ToDo ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand der definierten Klasse erkannt werden
    if ([elementName isEqualToString:@"BDSedit"])
    {
        element_bearbeitet = YES;


        if ([attributeDict valueForKey:@"password"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'password' for HTML '<input type=\"password\">'.");

            if ([[attributeDict valueForKey:@"password"] isEqual:@"true"])
                [self.output appendString:@"<input type=\"password\""];
            else
                [self.output appendString:@"<input type=\"text\""];
        }
        else
        {
            if ([attributeDict valueForKey:@"pattern"])
            {
                self.attributeCount++;

                if ([[attributeDict valueForKey:@"pattern"] isEqual:@"[0-9a-z@_.\\-]*"])
                    [self.output appendString:@"<input type=\"email\""];
                else
                    [self.output appendString:@"<input type=\"text\""];
            }
            else
            {
                [self.output appendString:@"<input type=\"text\""];
            }
        }


        [self addIdToElement:attributeDict];

        [self.output appendString:@" style=\""];

        // Die Width ist bei input-Feldern regelmäßig zu lang, vermutlich wegen interner
        // border-/padding-/margin-/Angaben bei OpenLaszlo. Deswegen hier vorher Wert abändern.
        if ([attributeDict valueForKey:@"width"])
        {
            int neueW = [[attributeDict valueForKey:@"width"] intValue]-14;
            [attributeDict setValue:[NSString stringWithFormat:@"%d",neueW] forKey:@"width"];
        }

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\" />\n"];


        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"maxlength"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'maxlength' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'name' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text' for now.");
        }




        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]]];
    }





    if ([elementName isEqualToString:@"BDScombobox"])
    {
        element_bearbeitet = YES;


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];


        // Umgebendes <Div> für die komplette Combobox inklusive Text
        // WOW, dieses vorangehende <br /> als Lösung zu setzen, hat mich 3 Stunden Zeit gekostet...
        // ToDo: Eigentlich muss ich per jQuery immer entsprechend der Höhe und der X-Koordinate
        // des vorherigen Elements hier aufrücken <--- Alles Quatsch jetzt, nach der neuen Lösung.
        [self.output appendString:@"<div class=\"combobox\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];




        [self.output appendString:@"<span"];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@">"];

        


        // Wenn im Attribut title Code auftaucht, dann müssen wir es dynamisch setzen
        // müssen aber erst abwarten bis wir die ID haben, weil wir die für den Zugriff brauchen.
        // <span> drum herum, damit ich per jQuery darauf zugreifen kann
        BOOL titelDynamischSetzen = NO;
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' in <span>-tags as text in front of combobox.");
            if ([[attributeDict valueForKey:@"title"] hasPrefix:@"$"])
            {
                titelDynamischSetzen = YES;
                [self.output appendString:@"CODE! - Wird dynamisch mit jQuery ersetzt."];
            }
            else
            {
                [self.output appendString:[attributeDict valueForKey:@"title"]];
            }
        }
        [self.output appendString:@"</span>\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];

        [self.output appendString:@"<select size=\"1\""];

        NSString *id =[self addIdToElement:attributeDict];




        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur in input type=checkbox,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }




        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];
            // Remove all occurrences of $,{,}
            code = [self removeOccurrencesofDollarAndCurlyBracketsIn:code];

            [self.jQueryOutput appendString:@"\n  // combobox-Text wird hier dynamisch gesetzt\n"];
            // [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').before(%@);",id,code]];
            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').prev().text(%@);\n",id,code]];
        }




        [self.output appendString:@" style=\""];


        // Im Prinzip nur wegen controlwidth
        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];


        if (![attributeDict valueForKey:@"dataset"])
        {
            [self instableXML:@"ERROR: No attribute 'dataset' given in BDScombobox-tag"];
        }
        else
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'dataset' as arrayname for jQuery, to access the corresponding array, which contains all Entrys (previously set by <dataset>.");
        }



        NSString *dataset = [attributeDict valueForKey:@"dataset"];
        // Falls es ein Ausdruck ist, muss ich §,{,} entfernen
        // Ich lasse den Ausdruck dann von JS auswerten
        // Aber klappt das auch mit dem Attribut '.value' im Ausdruck? (ToDo)
        dataset = [self removeOccurrencesofDollarAndCurlyBracketsIn:dataset];

        [self.jQueryOutput appendString:@"\n  // Dynamisch gesetzter Inhalt bezüglich combobox "];
        [self.jQueryOutput appendString:id];
        [self.jQueryOutput appendString:@"__CodeMarker\n"];
        [self.jQueryOutput appendString:@"  $.each("];
        [self.jQueryOutput appendString:dataset];
        [self.jQueryOutput appendString:@", function(index, option)\n  {\n    $('#"];
        [self.jQueryOutput appendString:id];
        [self.jQueryOutput appendString:@"').append( new Option(option.content, option.value"];
        // [self.jQueryOutput appendString:@" , false, "]; // <- defaultSelected
        // [self.jQueryOutput appendString:@"false"]; // <- nowSelected
        [self.jQueryOutput appendString:@") );\n  });\n"];


        // Vorauswahl setzen, falls eine gegeben ist
        if ([attributeDict valueForKey:@"initvalue"])
        {
            self.attributeCount++;

            if ([[attributeDict valueForKey:@"initvalue"] isEqual:@"false"])
            {
                // 'false' heißt wohl es gibt keinen Init-Wert
            }
            else
            {
                NSLog(@"Using the attribute 'initvalue' to set a starting value for the combobox.");
                [self.jQueryOutput appendString:@"  // Vorauswahl für diese Combobox setzen\n"];
                [self.jQueryOutput appendString:@"  $(\"#cbBundesland option[value="];
                [self.jQueryOutput appendString:[attributeDict valueForKey:@"initvalue"]];
                [self.jQueryOutput appendString:@"]\").attr('selected',true);\n"];
            }
        }



        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+3];
        [self.output appendString:@"<!-- Inhalt wird per jQuery von folgender Anweisung gesetzt: "];
        [self.output appendString:id];
        [self.output appendString:@"__CodeMarker -->\n"];

        // Select auch wieder schließen
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"</select>\n"];

        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw. (und onblur)
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];



        if ([attributeDict valueForKey:@"simple"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'simple'.");
        }




        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n\n"];
    }







    if ([elementName isEqualToString:@"BDScheckbox"] ||
        [elementName isEqualToString:@"checkbox"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];

        [self.output appendString:@"<div class=\"checkbox\" >\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];




        [self.output appendString:@"<input type=\"checkbox\""];

        NSString *id =[self addIdToElement:attributeDict];


        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur in input type=checkbox,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }

        [self.output appendString:@" style=\""];
        
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        
        [self.output appendString:@"vertical-align: middle;\">\n"];




        [self.output appendString:@"<span"];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@">"];




        // Wenn im Attribut title Code auftaucht, dann müssen wir es dynamisch setzen
        // müssen aber erst abwarten bis wir die ID haben, weil wir die für den Zugriff brauchen.
        // <span> drum herum, damit ich per jQuery darauf zugreifen kann
        BOOL titelDynamischSetzen = NO;
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' in <span>-tags as text in front of checkbox.");
            if ([[attributeDict valueForKey:@"title"] hasPrefix:@"$"])
            {
                titelDynamischSetzen = YES;
                [self.output appendString:@"CODE! - Wird dynamisch mit jQuery ersetzt."];
            }
            else
            {
                [self.output appendString:[attributeDict valueForKey:@"title"]];
            }
        }
        [self.output appendString:@"</span>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];





        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];
            // Remove all occurrences of $,{,}
            code = [self removeOccurrencesofDollarAndCurlyBracketsIn:code];

            [self.jQueryOutput appendString:@"\n  // checkbox-Text wird hier dynamisch gesetzt\n"];
            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').next().text(%@);\n",id,code]];
        }





        if ([attributeDict valueForKey:@"controlpos"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'controlpos'.");
        }

        if ([attributeDict valueForKey:@"textalign"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'textalign'.");
        }
        if ([attributeDict valueForKey:@"value"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'value'.");
        }




        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n\n"];
    }






    // ToDo: Bei BDSeditnumber nur Ziffern zulassen als Eingabe inkl. wohl '.' + ',' aber nochmal checken.
    if ([elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];

        [self.output appendString:@"<div class=\"textfield\" >\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];





        [self.output appendString:@"<span"];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@">"];



        // Wenn im Attribut title Code auftaucht, dann müssen wir es dynamisch setzen
        // müssen aber erst abwarten bis wir die ID haben, weil wir die für den Zugriff brauchen.
        // <span> drum herum, damit ich per jQuery darauf zugreifen kann
        BOOL titelDynamischSetzen = NO;
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' in <span>-tags as text in front of textfield.");
            if ([[attributeDict valueForKey:@"title"] hasPrefix:@"$"])
            {
                titelDynamischSetzen = YES;
                [self.output appendString:@"CODE! - Wird dynamisch mit jQuery ersetzt."];
            }
            else
            {
                [self.output appendString:[attributeDict valueForKey:@"title"]];
            }
        }
        [self.output appendString:@"</span>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];

        [self.output appendString:@"<input type=\"text\""];


        NSString *id =[self addIdToElement:attributeDict];



        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur in input type=checkbox,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }




        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];
            // Remove all occurrences of $,{,}
            code = [self removeOccurrencesofDollarAndCurlyBracketsIn:code];

            [self.jQueryOutput appendString:@"\n  // textfield-Text wird hier dynamisch gesetzt\n"];
            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').prev().text(%@);\n",id,code]];
        }


        [self.output appendString:@" style=\""];


        // Die Width ist bei input-Feldern regelmäßig zu lang, vermutlich wegen interner
        // border-/padding-/margin-/Angaben bei OpenLaszlo. Deswegen hier vorher Wert abändern.
        if ([attributeDict valueForKey:@"width"])
        {
            int neueW = [[attributeDict valueForKey:@"width"] intValue]-10;
            [attributeDict setValue:[NSString stringWithFormat:@"%d",neueW] forKey:@"width"];
        }


        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];



        if ([attributeDict valueForKey:@"required"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'required'.");
        }
        if ([attributeDict valueForKey:@"requiredErrorstring"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'requiredErrorstring'.");
        }
        if ([attributeDict valueForKey:@"infotext"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'infotext'.");
        }
        if ([attributeDict valueForKey:@"maxlength"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'maxlength'.");
        }
        if ([attributeDict valueForKey:@"pattern"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'pattern'.");
        }



        // Diese Attribute sind eigentlich nur für BDSeditnumber
        if ([attributeDict valueForKey:@"minvalue"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'minvalue'.");
        }
        if ([attributeDict valueForKey:@"text"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text'.");
        }
        if ([attributeDict valueForKey:@"enabled"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'enabled'.");
        }
        if ([attributeDict valueForKey:@"domain"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'domain'.");
        }
        if ([attributeDict valueForKey:@"minlength"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'minlength'.");
        }
        if ([attributeDict valueForKey:@"simple"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'simple'.");
        }



        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n\n"];
    }







    if ([elementName isEqualToString:@"BDSeditdate"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<div class=\"datepicker\" >\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];




        [self.output appendString:@"<span"];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@">"];



        // Wenn im Attribut title Code auftaucht, dann müssen wir es dynamisch setzen
        // müssen aber erst abwarten bis wir die ID haben, weil wir die für den Zugriff brauchen.
        // <span> drum herum, damit ich per jQuery darauf zugreifen kann
        BOOL titelDynamischSetzen = NO;
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' in <span>-tags as text in front of datepicker.");
            if ([[attributeDict valueForKey:@"title"] hasPrefix:@"$"])
            {
                titelDynamischSetzen = YES;
                [self.output appendString:@"CODE! - Wird dynamisch mit jQuery ersetzt."];
            }
            else
            {
                [self.output appendString:[attributeDict valueForKey:@"title"]];
            }
        }
        [self.output appendString:@"</span>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];

        [self.output appendString:@"<input type=\"text\""];

        NSString *id =[self addIdToElement:attributeDict];





        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur in input type=checkbox,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }






        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];
            // Remove all occurrences of $,{,}
            code = [self removeOccurrencesofDollarAndCurlyBracketsIn:code];

            [self.jQueryOutput appendString:@"\n  // Datepicker-Text wird hier dynamisch gesetzt\n"];
            // [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').before(%@);",id,code]];
            [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').prev().text(%@);\n",id,code]];
        }


        [self.output appendString:@" style=\""];


        // Im Prinzip nur wegen controlwidth
        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"margin-left:4px;\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n\n"];


        // Jetzt noch den jQuery-Code für den Datepicker
        [self.jQueryOutput appendString:@"\n  // Für das mit dieser id verbundene input-Field setzen wir einen jQUery UI Datepicker\n"];
        [self.jQueryOutput appendString:@"  // Aber bei iOS-Devices nutzen wir den eingebauten Datepicker\n"];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  if (isiOS())\n    document.getElementById('%@').setAttribute('type', 'date');\n  else\n    $('#%@').datepicker();\n",id,id]];





        if ([attributeDict valueForKey:@"dateErrorMaxDate"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'dateErrorMaxDate'.");
        }
        if ([attributeDict valueForKey:@"maxdate"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'maxdate'.");
        }
        if ([attributeDict valueForKey:@"mindate"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'mindate'.");
        }
        if ([attributeDict valueForKey:@"restrictyear"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'restrictyear'.");
        }
        if ([attributeDict valueForKey:@"simple"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'simple'.");
        }


        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]]];
    }








    if ([elementName isEqualToString:@"rollUpDownContainer"])
    {
        element_bearbeitet = YES;


        self.weAreInRollUpDownWithoutSurroundingRUDContainer = NO;


        // Beim Betreten eins hochzählen, beim Verlassen runterzählen
        self.rollUpDownVerschachtelungstiefe++;

        // Nicht länger als int gelöst, sondern als Array,
        // weil es ja verschachtelte rollUpDownContainer geben kann
        // Beim Betreten Element dazunehmen, beim Verlassen entfernen
        [self.rollupDownElementeCounter addObject:[NSNumber numberWithInt:0]];

        [self.output appendString:@"<!-- Container für RollUpDown: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];



        [self.output appendString:@"<div class=\"rudContainer\""];

        [self addIdToElement:attributeDict];



        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur hier,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }




        // Im Prinzip nur wegen Boxheight müssen wir in addCSSAttributes rein
        [self.output appendString:@" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict forceWidthAndHeight:YES]];
        [self.output appendString:@"\">\n"];


        // Setz die MiliSekunden für die Animationszeit, damit die 'rollUpDown'-Elemente darauf zugreifen können
        if ([attributeDict valueForKey:@"animduration"])
        {
            self.attributeCount++;
            self.animDuration = [attributeDict valueForKey:@"animduration"];
        }
        else
        {
            self.animDuration = @"slow";
        }



        if ([attributeDict valueForKey:@"mask"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'mask'.");
        }
    }






    if ([elementName isEqualToString:@"rollUpDown"])
    {
        element_bearbeitet = YES;


        // Weil es auch verschachtelte rollUpDowns gibt ohne umschließenden Container,
        // muss ich den Zähler auch hier berücksichtigen.
        // Beim Betreten eins hochzählen, beim Verlassen runterzählen.
        self.rollUpDownVerschachtelungstiefe++;

        // Anzahl der rollUpDown-Elemente auf der aktuellen Ebene
        [self.rollupDownElementeCounter addObject:[NSNumber numberWithInt:0]];



        int breiteVonRollUpDown = 760;
        int abstandNachAussenBeiVerschachtelung = 20;

        // -2 einmal für den Container und einmal für das rollUpDown-Element selber,
        // so kommen wir bei 0 raus für die allererste Ebene.
        // Alte Lösung: (Dann rückt er aber bei dreifach verschachtelten RollUpDowns zu viel ein)
        // int abstand = (self.rollUpDownVerschachtelungstiefe-2)*abstandNachAussenBeiVerschachtelung;
        // Neue Lösung:
        int abstand = 0;


        if (self.weAreInRollUpDownWithoutSurroundingRUDContainer)
        {
            if (self.rollUpDownVerschachtelungstiefe-2 > 0)
                abstand = abstandNachAussenBeiVerschachtelung;
        }
        else
        {
            if (self.rollUpDownVerschachtelungstiefe-2 > 0)
                abstand = abstandNachAussenBeiVerschachtelung-14;
        }


        // Alte Lösung:
        // breiteVonRollUpDown = (breiteVonRollUpDown - abstand*2);
        // Folgeänderung Neue Lösung:
        breiteVonRollUpDown = (breiteVonRollUpDown - (abstand*2*(self.rollUpDownVerschachtelungstiefe-2)));

        // Auch noch die Breite des Rahmens (links und rechts) abziehen.
        // Erst dann ist es geometrisch.
        breiteVonRollUpDown -= 2*2*(self.rollUpDownVerschachtelungstiefe-2);


        if (!self.weAreInRollUpDownWithoutSurroundingRUDContainer)
        {
            breiteVonRollUpDown -= 6*(self.rollUpDownVerschachtelungstiefe-2);
        }

        [self.output appendString:@"<!-- RollUpDown-Element: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];


        [self.output appendString:@"<div class=\"rudElement\""];


        // Das umgebende Div bekommt die Haupt-ID, Panel und Leiste 2 Unter-IDs
        NSString *id4rollUpDown =[self addIdToElement:attributeDict];

        NSString *id4flipleiste = [NSString stringWithFormat:@"%@_flipleiste",id4rollUpDown];
        NSString *id4panel = [NSString stringWithFormat:@"%@_panel",id4rollUpDown];



        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur hier,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }



        // Den Counter aus dem Array rausziehen und als int auslesen
        int counter = [[self.rollupDownElementeCounter objectAtIndex:self.rollUpDownVerschachtelungstiefe-2] intValue];

        [self.output appendString:@" style=\""];
        [self.output appendString:@"top:"];

        // [self.output appendString:[NSString stringWithFormat:@"%d",counter*111]];
        // wtf...
        [self.output appendString:@"6"];

        // Und Zähler um eins erhöhen an der richtigen Stelle im Array
        [self.rollupDownElementeCounter replaceObjectAtIndex:self.rollUpDownVerschachtelungstiefe-2 withObject:[NSNumber numberWithInt:(counter+1)]];

        [self.output appendString:@"px;"];
        [self.output appendString:@"width:"];
        [self.output appendString:[NSString stringWithFormat:@"%d",breiteVonRollUpDown]];
        [self.output appendString:@"px;"];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        // left MUSS als letztes, um evtl. x-Angaben zu überschreiben.
        // Dies betrifft nur das Tab "Vermögenswirksame Leistungen".
        // Durch die dortige X-Angabe wird es auch position:absolute;
        // Hoffe das hat keine Seiteneffekte, lasse es aber erstmal so.
        [self.output appendString:@"left:"];
        [self.output appendFormat:@"%d",abstand];
        [self.output appendString:@"px;"];

        [self.output appendString:@"\">\n"];

        /* *************CANVAS***************VERWORFEN************* SPÄTER NUTZEN FÜR DIE RUNDEN ECKEN --- NE, DOCH NICHT, JETZT GELÖST ÜBER jQuery UI StyleSheets.
        [self.output appendString:@"<canvas style=\"position:absolute; top:37px; left:81px;\" id=\"leiste\" width=\"500\" height=\"200\"></canvas>"];

        [self.output appendString:@"<canvas style=\"position:absolute; top:61px; left:81px;\" id=\"details\" width=\"500\" height=\"200\"></canvas>"];

        // <!-- Div für den Klick-Button auf dem Dreieck -->
        [self.output appendString:@"<div style=\"position:absolute; top:12px; left:82px;\" id=\"container\"></div>"];

        [self.output appendString:@"<div style=\"top:38px;left:82px;height:22px;width:225px;position:absolute;\" onClick=\"touchStart(event)\">"];
        [self.output appendString:@"<script src=\"jsHelper.js\" type=\"text/javascript\"></script>\n"];
         */



        // Text für Titelleiste ermitteln
        NSString *title = @"";
        if ([attributeDict valueForKey:@"header"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'header' as text in <span> in front of element.");

            title = [attributeDict valueForKey:@"header"];



            // Falls der Header variabel ($) ist und berechnet werden muss.
            if ([[attributeDict valueForKey:@"header"] hasPrefix:@"$"])
            {
                NSLog(@"Setting the attribute 'header' later with jQuery, because it is Code.");
                title = @"CODE! - Wird dynamisch mit jQuery ersetzt.";

                NSString *code = [attributeDict valueForKey:@"header"];
                // Remove all occurrences of $,{,}
                code = [self removeOccurrencesofDollarAndCurlyBracketsIn:code];

                [self.jQueryOutput appendString:@"\n  // Der Titel (header) von rollUpDown wird hier dynamisch gesetzt\n"];
                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').html('<span style=\"margin-left:8px;\">'+%@+'</span>');\n",id4flipleiste,code]];
            }
        }

        int heightOfFlipBar = 30;
        if ([attributeDict valueForKey:@"hmargin"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'hmargin' as height for the Flipbar.");

            heightOfFlipBar = [[attributeDict valueForKey:@"hmargin"] intValue];
            heightOfFlipBar +=3; // Abstand nach oben
            heightOfFlipBar +=3; // Abstand nach unten
        }


        // Als callback mit einfügen dann, falls 'onrolleddown' gesetzt wurde.
        NSString *callback = nil;
        if ([attributeDict valueForKey:@"onrolleddown"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'onrolleddown' as as setglobalhelp-String.");

            NSString *s = [attributeDict valueForKey:@"onrolleddown"];

            // Hier wird oft setglobalhelp aufgerufen. Derzeit einfach als eigene Funktion
            // definiert.
            // Ich ersetze erstmal alles genau bis zum und inklusive dem Punkt.
            // Später hier mit NSRegularExpression arbeiten (ToDo)
            if ([s rangeOfString:@"."].location == NSNotFound)
            {
                // Ist natürlich gar nicht instable XML hier, aber ich will abbrechen, falls es
                // ein entsprechendes 'onrolleddown' gibt, welches ohne '.' aufgebaut ist.
                [self instableXML:(@"string does not contain '.' ('onrolleddown'-Attribute in element 'rollupdown')")];
            } else
            {
                s = [s substringFromIndex:[s rangeOfString:@"."].location+1];
                // NSLog(s);
            }

            callback = s;
        }



        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<!-- Die Flipleiste -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<div style=\"position:relative; top:0px; left:0px; width:"];
        [self.output appendString:[NSString stringWithFormat:@"%dpx; height:%dpx; background-color:lightblue; line-height: %dpx; vertical-align:middle;\" class=\"ui-corner-top\" id=\"",breiteVonRollUpDown,heightOfFlipBar]];
        [self.output appendString:id4flipleiste];
        [self.output appendString:@"\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"<span style=\"margin-left:8px;\">"];
        [self.output appendString:title];
        [self.output appendString:@"</span>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<!-- Das aufklappende Menü -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendFormat:@"<div style=\"position:relative; top:0px; left:0px; width:%dpx; ",breiteVonRollUpDown-4];
        // Bei ganz äußeren RUDs soll die Höhe fix sein, ansonsten nicht
        if (self.rollUpDownVerschachtelungstiefe-2 == 0)
            [self.output appendString:@"height:350px; "];
        else
            [self.output appendString:@"height:auto; "];
        [self.output appendString:@"border-width:2px; border-color:lightgrey; border-style:solid; margin-bottom:6px; background-color:white;\" class=\"ui-corner-bottom\" id=\""];
        [self.output appendString:id4panel];
        [self.output appendString:@"\">\n"];


        // Die jQuery-Ausgabe
        if (callback)
            [self.jQueryOutput appendString:@"\n  // Animation bei Klick auf die Leiste (mit callback)\n"];
        else
            [self.jQueryOutput appendString:@"\n  // Animation bei Klick auf die Leiste (ohne callback)\n"];

        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').click(function(){$('#%@').slideToggle(",id4flipleiste,id4panel]];
        [self.jQueryOutput appendString:self.animDuration];
        if (callback)
        {
            [self.jQueryOutput appendString:@","];
            [self.jQueryOutput appendString:@"function() {"];
            [self.jQueryOutput appendString:callback];
            [self.jQueryOutput appendString:@"}"];
        }
        [self.jQueryOutput appendString:@");});\n"];


        // Menüs sind standardmäßig immer zu (falls z. B. gar kein Attribut angegeben wurde)
        // Deswegen das Menü hier zumachen (ohne Animation!)
        // Dieser COde funktioniert nicht....
        //[self.jQueryOutput appendFormat:@"  $('#%@').slideToggle(0); // RUD-Element zuschieben\n",id4panel];
        // Aber dieser:
        [self.jQueryOutput appendFormat:@"  $('#%@').css('display','none'); // RUD-Element zuschieben\n",id4panel];

        if ([attributeDict valueForKey:@"down"])
        {
            self.attributeCount++;

            // Menü wieder öffnen dann (ohne Animation).
            if ([[attributeDict valueForKey:@"down"] isEqual:@"true"])
            {
                NSLog(@"Using the attribute 'down' to open the menu.");

                [self.jQueryOutput appendFormat:@"  $('#%@').css('display','block'); // RUD-Element zuschieben\n",id4panel];
            }
            else
            {
                NSLog(@"Skipping the attribute 'down', because the menu is already closed.");
            }
        }




        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id4rollUpDown]]];


        // Ich setze es hier auf YES, wenn ein schließendes kommt, dann ist er sofort wieder auf NO
        // Genauso bei öffnenem RUD-Container auf NO.
        // Falls erst ein öffnendes kommt, weiß ich so Bescheid und kann die left-Angabe gesondert
        // berücksichtigen
        self.weAreInRollUpDownWithoutSurroundingRUDContainer = YES;
    }






    if ([elementName isEqualToString:@"BDStabsheetcontainer"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<!-- TabSheet-Container: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];



        [self.output appendString:@"<div"];

        self.lastUsedTabSheetContainerID = [self addIdToElement:attributeDict];


        [self.output appendString:@" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict forceWidthAndHeight:YES]];
        [self.output appendString:@"\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<ul>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</ul>\n"];



        // tabwidth auslesen
        int tabwidth = 127;
        int tabwidthForLink;
        if ([attributeDict valueForKey:@"tabwidth"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'tabwidth' as CSS-declaration in the jQuery UI option 'tabTemplate' of 'tabs'.");
            tabwidth = [[attributeDict valueForKey:@"tabwidth"] intValue];
            // Derzeit hat es wohl noch eine Border/Margin, nur so haben wir exakt den gleichen Abstand wie bei Taxango
            tabwidth = tabwidth - 6;
            // Beim IE9 gibt es wohl noch nen extra Randpixel... deswegen nochmal -1
            tabwidth = tabwidth-1;
            // Damit man im Tab auf der kompletten Tableiste klicken kann
            tabwidthForLink = tabwidth - 4*6;
        }




        // Hier legen wir den TabSheetContainer per jQuery an
        [self.jQueryOutput appendString:@"\n  // Ein TabSheetContainer. Jetzt wird's kompliziert. Wird legen ihn hier an.\n  // Die einzelnen Tabs werden, sobald sie im Code auftauchen, per add hinzugefügt\n  // Mit der Option 'tabTemplate' legen wir die width fest\n  // Mit der Option 'fx' legen wir eine Animation für das Wechseln fest\n"];

        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').tabs({ tabTemplate: '<li style=\"width:%dpx;\"><a href=\"#{href}\" style=\"width:%dpx;\"><span>#{label}</span></a></li>' });\n",self.lastUsedTabSheetContainerID,tabwidth,tabwidthForLink]];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').tabs({ fx: { opacity: 'toggle' } });\n",self.lastUsedTabSheetContainerID]];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').tabs();\n",self.lastUsedTabSheetContainerID]];


        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"datapath"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'datapath' for now.");
        }

        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"showinfo"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'showinfo' for now.");
        }
    }

    // Wir müssen hier 2 Sachen machen:
    // 1) Ein div aufmachen mit einer ID
    // 2) per jQuery das neu entdeckte tab mit der tabsheetcCntainerID und der gerade vergebenen tabsheet-ID hinzufügen
    if ([elementName isEqualToString:@"BDStabsheetTaxango"])
    {
        element_bearbeitet = YES;

        // normaler Output
        [self.output appendString:@"<!-- Beginn eines neuen TabSheets: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        [self.output appendString:@"<div "];

        NSString* geradeVergebeneID = [self addIdToElement:attributeDict];

        // Sonst verrutscht es alles wegen der zwischengeschobenen Leiste
        // Etwas geschummelt, aber nun gut.
        // Auch das width muss ich hier explizit übernehmen.
        [self.output appendString:@" style=\"top:50px;width:inherit;\""];

        [self.output appendString:@">\n"];


        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"info"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'info' for now.");
        }


        if (![attributeDict valueForKey:@"title"])
        {
            [self instableXML:@"ERROR: No attribute 'title' given in BDStabsheetTaxango-tag"];
        }
        else
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'title' as heading for the tabsheet.");
        }



        // jQuery-Output
        [self.jQueryOutput appendString:@"\n  // Hinzufügen eines tabsheets in den tabsheetContainer\n"];
        [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').tabs('add', '#%@', '%@');\n",self.lastUsedTabSheetContainerID,geradeVergebeneID,[attributeDict valueForKey:@"title"]]];
    }







    // Nichts zu tun
    if ([elementName isEqualToString:@"library"] ||
        [elementName isEqualToString:@"passthrough"])
    {
        element_bearbeitet = YES;
    }


    // Wohl nichts zu tun (ist eine eigens definierte class - ToDo, falls wir class-Tags auslesen wollen)
    if ([elementName isEqualToString:@"SharedObject"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"soid"])
            self.attributeCount++;
    }


    // ToDo Audio (ist wohl sehr ähnlich aufgebaut wie ressource. Trotzdem erstmal checken
    if ([elementName isEqualToString:@"audio"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"src"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
    }


    // ToDo
    if ([elementName isEqualToString:@"calcDisplay"] || // Ist das eine selbst defineirte Klasse? ToDo
        [elementName isEqualToString:@"calcButton"]) // Ist das eine selbst defineirte Klasse? ToDo
    {
        element_bearbeitet = YES;
        
        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"buttLabel"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"resource"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"labelX"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"align"])
            self.attributeCount++;
    }


    // MEGA MEGA ToDo ToDo ToDo class
    if ([elementName isEqualToString:@"class"])
    {
        element_bearbeitet = YES;


        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;

            NSString * name = [attributeDict valueForKey:@"name"];

            // Wir sammeln alle gefundenen 'name'-Attribute von class in einem eigenen Dictionary. Weil die names
            // können später eigene <tags> werden! Ich muss dann später darauf testen, ob das ELement vorher
            // definiert wurde.
            [self.allFoundClasses setObject:@"Blabla Blub ToDo" forKey:name];

            // Auserdem speichere ich die gefunden Klasse als JS-Objekt und schreibe es nach collectedClasses.js
            // Weil die Attribute ja neu gesetzt werden können, muss ich sie einzeln speichern und später,
            // wenn die Klasse instanziert wird auf eventuell überschriebene Attribute checken


            NSArray *keys = [attributeDict allKeys];


            [self.jsOLClassesOutput appendString:@"\n\n"];
            [self.jsOLClassesOutput appendString:@"///////////////////////////////////////////////////////////////\n"];
            [self.jsOLClassesOutput appendFormat:@"// class = %@ //\n",name];
            [self.jsOLClassesOutput appendString:@"///////////////////////////////////////////////////////////////\n"];
            [self.jsOLClassesOutput appendFormat:@"var %@ = function() {\n",name];


            if ([keys count] > 0)
            {
                // Alle Attributnamen als Array hinzufügen
                [self.jsOLClassesOutput appendString:@"  this.attributeNames = ["];

                int i = 0;
                for (NSString *key in keys)
                {
                    i++;

                    [self.jsOLClassesOutput appendString:@"'"];
                    [self.jsOLClassesOutput appendString:key];
                    [self.jsOLClassesOutput appendString:@"'"];

                    if (i < [keys count])
                        [self.jsOLClassesOutput appendString:@", "];
                }

                [self.jsOLClassesOutput appendString:@"];\n"];


                // Und alle Attributwerte als Array hinzufügen
                [self.jsOLClassesOutput appendString:@"  this.attributeValues = ["];

                i = 0;
                for (NSString *key in keys)
                {
                    i++;
                    
                    [self.jsOLClassesOutput appendString:@"'"];
                    [self.jsOLClassesOutput appendString:[attributeDict valueForKey:key]];
                    [self.jsOLClassesOutput appendString:@"'"];
                    
                    if (i < [keys count])
                        [self.jsOLClassesOutput appendString:@", "];
                }

                [self.jsOLClassesOutput appendString:@"];\n\n"];
            }

            // Den Content von der Klasse ermitteln wir so:
            // Wir lassen es einmal rekrusiv durchlaufen und können so die OL-Elemente in HTML-Elemente umwandeln
            // Später fügt jQuery diese HTML-Elemente, beim auslesen des JS-Objekts, als HTML-Code ein.
            // Hier den String leeren, und dann alles innerhalb <class> definierte da drin sammeln.
            // Wenn <class> geschlossen wird, dann hinzufügen.
            self.collectedContentOfClass = [[NSMutableString alloc] initWithString:@""];
        }
        else
        {
            [self instableXML:@"Eine class ohne 'name'-Attribut macht wohl keinen Sinn. Wie soll man sie sonst später ansprechen?"];
        }






        // Theoretisch könnte auch eine id gesetzt worden sein, auch wenn OL-Doku davon abrät!
        // http://www.openlaszlo.org/lps4.9/docs/developers/tutorials/classes-tutorial.html (1.1)
        // Dann hier aussteigen
        if ([attributeDict valueForKey:@"id"])
        {
            [self instableXML:@"ID attribute on class found!!! It's important to note that you should not assign an id attribute in a class definition. Each id should be unique; ids are global and if you were to include an id assignment in the class definition, then creating several instances of a class would several views with the same id, which would cause unpredictable behavior. http://www.openlaszlo.org/lps4.9/docs/developers/tutorials/classes-tutorial.html (1.1)"];
        }


        // ToDo: ALL This attributes
        if ([attributeDict valueForKey:@"clickable"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"extends"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"onclick"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"oninit"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"resource"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"y"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"fontsize"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"pixellock"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"styleable"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"clip"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"fontstyle"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"bgcolor"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"bgcolor0"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"bgcolor1"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"showhlines"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"showvlines"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"style"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"layout"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"initstage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"antiAliasType"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"gridFit"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"sharpness"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"thickness"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"focusable"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"text_x"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"stateres"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"onmouseout"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"onmouseover"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"focustrap"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"closeable"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"resourcepic"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"animduration"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"doesenter"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"align"])
            self.attributeCount++;



        // Alles was in class definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    if ([elementName isEqualToString:@"splash"]) // ToDo (ist das vielleicht selbst definierte Klasse?)
    {
        element_bearbeitet = YES;
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    if ([elementName isEqualToString:@"fileUpload"]) // ToDo (ist selbst defnierte Klasse)
    {
        element_bearbeitet = YES;
        self.weAreSkippingTheCompleteContenInThisElement = YES;

        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"filter"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"filterdesc"])
            self.attributeCount++;
    }
    // ToDo
    if ([elementName isEqualToString:@"nicemodaldialog"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"initstage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"setfocus"])
            self.attributeCount++;

        // ToDO
        // Alles was in nicemodaldialog definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"dlginfo"] || [elementName isEqualToString:@"dlgwarning"] || [elementName isEqualToString:@"dlgyesno"] || [elementName isEqualToString:@"nicepopup"] || [elementName isEqualToString:@"nicedialog"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"info"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"initstage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"question"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"y"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"modal"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"showhandcursor"])
            self.attributeCount++;


        // ToDo
        // Alles was in nicemodaldialog definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"rollUpDownContainerReplicator"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"max"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"maxinfo"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"newdp"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"xpath"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"y"])
            self.attributeCount++;



        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"calculator_anim"])
    {
        element_bearbeitet = YES;


        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"initstage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;

        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"certdatepicker"])
    {
        element_bearbeitet = YES;


        if ([attributeDict valueForKey:@"closeonselect"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"initstage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"selecteddate"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;



        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"BDSinputgrid"])
    {
        element_bearbeitet = YES;


        if ([attributeDict valueForKey:@"contentdatapath"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"deletecols"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"deletevals"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"infotext"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"metadatapath"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"headerheight"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"trashcol"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"addbutton"])
            self.attributeCount++;

        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement2 = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"BDSreplicator"])
    {
        element_bearbeitet = YES;



        if ([attributeDict valueForKey:@"dataset"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"xpath"])
            self.attributeCount++;


        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement2 = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"nicebox"])
    {
        element_bearbeitet = YES;


        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"layout"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"ignoreplacement"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"y"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;


        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreSkippingTheCompleteContenInThisElement3 = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"infobox_notsupported"] ||
        [elementName isEqualToString:@"infobox_euerhinweis"] ||
        [elementName isEqualToString:@"infobox_stnr"] ||
        [elementName isEqualToString:@"infobox_plausi"])
    {
        element_bearbeitet = YES;

        // Dringend ToDo - Name-Problem endlich lösen
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;

        // ToDo - Wohl einfach addJS hier aufrufen dann
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;

        // ToDo - info... ein eigenes Thema.
        if ([attributeDict valueForKey:@"info"])
            self.attributeCount++;
    }
    // ToDo - Tooltip kann wie <text>TEXT</text> Text in der Mitte beinhalten!!!
    // Evtl. dort mit inkludieren
    if ([elementName isEqualToString:@"tooltip"])
    {
        element_bearbeitet = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"state"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"applied"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"placement"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onremove"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"pooling"])
            self.attributeCount++;
    }
    // ToDo
    if ([elementName isEqualToString:@"animatorgroup"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"duration"])
            self.attributeCount++;

        // ToDo
        if ([attributeDict valueForKey:@"process"])
            self.attributeCount++;
    }
    // ToDo
    if ([elementName isEqualToString:@"animator"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"attribute"])
            self.attributeCount++;

        // ToDo
        if ([attributeDict valueForKey:@"to"])
            self.attributeCount++;
    }
    // ToDo
    if ([elementName isEqualToString:@"datapath"])
    {
        element_bearbeitet = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"int_vscrollbar"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;

        // ToDo
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"stableborderlayout"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"axis"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"combobox"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"defaulttext"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"doesenter"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"editable"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onblur"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onfocus"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"searchable"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"shownitems"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"y"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"textlistitem"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"datapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"text"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"value"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"datacombobox"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"defaulttext"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"itemdatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"listwidth"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onblur"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onfocus"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"shownitems"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"textdatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"valuedatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"statictext"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"align"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"resize"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"text"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"multistatebutton"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"focusable"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"maxstate"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onblur"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"onfocus"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"reference"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"resource"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"statelength"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"statenum"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"text"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
    }





    // Das ist nur ein Schalter. Erst im Nachfolgenden schließenden Element 'when' müssen wir
    // aktiv werden. Jedoch im schließenden 'switch' schalten wir wieder zurück.
    if ([elementName isEqualToString:@"switch"])
    {
        element_bearbeitet = YES;
    }
    if ([elementName isEqualToString:@"when"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"runtime"])
        {
            [self instableXML:@"ERROR: No attribute 'runtime' given in when-tag. Okay, not a real error, because we don't care about this attribute."];
        }
        else
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'runtime'.");
        }
    }



    if ([elementName isEqualToString:@"script"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"when"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'when'.");
        }
        if ([attributeDict valueForKey:@"src"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'src' as external JS-File in the <head> of our HTML-File.");

            if ([[attributeDict valueForKey:@"src"] isEqualToString:@"app-includes/steuerberechnung.js"] ||
                [[attributeDict valueForKey:@"src"] isEqualToString:@"app-includes/taxango.js"])
            {
                // Skippen, weil es da drin einen JS-Bug gibt
                NSLog(@"Skipping this script (ToDo).");
            }
            else
            {
                [self.externalJSFilesOutput appendString:@"<script type=\"text/javascript\" src=\""];
                [self.externalJSFilesOutput appendString:[attributeDict valueForKey:@"src"]];
                [self.externalJSFilesOutput appendString:@"\"></script>\n"];
            }
        }
        else
        {
            // JS-Code mit foundCharacters sammeln und beim schließen übernehmen
        }
    }



    // Wohl Eine Art umgebende View für Check-Felder die eingeblendet werden, damit man für sie die
    // Visibility z.B. nur einmal als ganzes ansprechen muss
    if ([elementName isEqualToString:@"checkview"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<!-- Checkview: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];




        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur hier,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es auch (fast) nur hier in 'input' erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }





        [self.output appendString:@" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        [self.output appendString:@"\">\n"];



        if ([attributeDict valueForKey:@"layout"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'layout'.");
        }
        if ([attributeDict valueForKey:@"mask"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'mask'.");
        }



        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]]];
    }


    // Eine View ohne ID, Attribute, ohne alles, Zweck ist mir noch nicht ganz klar
    // Eine Art Verzögerungs-view?
    if ([elementName isEqualToString:@"deferview"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<!-- Deferview: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<div>\n"];


        if ([attributeDict valueForKey:@"name"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'name'.");
        }
    }


    // Eine BDSFinanzaemter-View... ToDo (evtl. eher eine Art input-Feld und dort zuzuordnen?)
    if ([elementName isEqualToString:@"BDSFinanzaemter"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<!-- Finanzaemter-View: -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<div></div>\n"];


        if ([attributeDict valueForKey:@"controlwidth"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'controlwidth'.");
        }
        if ([attributeDict valueForKey:@"datapath"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'datapath'.");
        }
        if ([attributeDict valueForKey:@"dptext"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'dptext'.");
        }
        if ([attributeDict valueForKey:@"id"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'id'.");
        }
        if ([attributeDict valueForKey:@"title"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'title'.");
        }
    }


    if ([elementName isEqualToString:@"text"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];





        // Ich will 'name'-Attribut erstmal nicht immer dazusetzen, erstmal nur hier,
        // hätte sonst eventuell zu viele Seiteneffekte. (Deswegen ist es nicht in 'addCSS')
        // Und gemäß HTML-Spezifikation ist es hier auch nicht erlaubt
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as HTML 'name'.");
            [self.output appendString:@" name=\""];
            [self.output appendString:[attributeDict valueForKey:@"name"]];
            [self.output appendString:@"\""];
        }





        [self.output appendString:@" class=\"ol_text\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];

        // Dann Text mit foundCharacters sammeln und beim schließen anzeigen





        if ([attributeDict valueForKey:@"resize"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'resize'.");
        }

        // Puh, Text kann auch direkt gesetzt werden... erstmal ToDo, aber wohl nur Copy von BDSText oder so.
        // ToDo ToDo
        if ([attributeDict valueForKey:@"text"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text'.");
        }



        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]]];
    }



    // Ich füge erstmal alle gefundenen Methoden in ein Objekt ein, dass ich 'parent' nenne, da OpenLaszlo
    // oft mit 'parent.*' arbeitet. Evtl. ist dieser Trick etwas zu dirty und muss überdacht werden
    // Die Klasse 'parent' habe ich vorher angelegt.
    if ([elementName isEqualToString:@"method"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"name"])
        {
            [self instableXML:@"ERROR: No attribute 'name' given in method-tag"];
        }
        else
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'name' as method-name for a JS-Function, that is prototyped to the class 'parentKlasse'");
        }

        // Es gibt nicht immer args
        NSString *args = @"";
        // Falls es default Values gibt, muss ich diese in JS extra setzen
        NSMutableString *defaultValues = [[NSMutableString alloc] initWithString:@""];
        if ([attributeDict valueForKey:@"args"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'args' as arguments for this prototyped JS-Function");

            args = [attributeDict valueForKey:@"args"];

            // Überprüfen ob es default values gibt im Handler direkt (mit RegExp)...
            NSError *error = NULL;
            NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"([\\w]+)=([\\w]+)" options:NSRegularExpressionCaseInsensitive error:&error];

            NSUInteger numberOfMatches = [regexp numberOfMatchesInString:args options:0 range:NSMakeRange(0, [args length])];

            if (numberOfMatches > 0)
            {
                NSLog([NSString stringWithFormat:@"There is/are %d argument(s) with a default argument. I will regexp them.",numberOfMatches]);

                NSArray *matches = [regexp matchesInString:args options:0 range:NSMakeRange(0, [args length])];

                NSMutableString *neueArgs = [[NSMutableString alloc] initWithString:@""];

                for (NSTextCheckingResult *match in matches)
                {
                    // NSRange matchRange = [match range];
                    NSRange varNameRange = [match rangeAtIndex:1];
                    NSRange defaultValueRange = [match rangeAtIndex:2];

                    NSString *varName = [args substringWithRange:varNameRange];
                    NSLog([NSString stringWithFormat:@"%Resulting variable name: %@",varName]);
                    NSString *defaultValue = [args substringWithRange:defaultValueRange];
                    NSLog([NSString stringWithFormat:@"%Resulting default value: %@",defaultValue]);

                    // ... dann die Variablennamen der args neu sammeln...
                    if (![neueArgs isEqualToString:@""])
                      [neueArgs appendString:@", "];
                    [neueArgs appendString:varName];



                    ///////////////////// Default- Variablen für JS setzen - Anfang /////////////////////
                    [defaultValues appendString:@"  if(typeof("];
                    [defaultValues appendString:varName];
                    [defaultValues appendString:@")==='undefined') "];
                    [defaultValues appendString:varName];
                    [defaultValues appendString:@" = "];
                    [defaultValues appendString:defaultValue];
                    [defaultValues appendString:@";\n"];
                    ///////////////////// Default- Variablen für JS setzen - Ende /////////////////////
                }
                // ... und hier setzen
                args = neueArgs;
            }
        }

        [self.jsHead2Output appendString:@"\nparentKlasse.prototype."];
        [self.jsHead2Output appendString:[attributeDict valueForKey:@"name"]];
        [self.jsHead2Output appendString:@" = function("];
        [self.jsHead2Output appendString:args];
        [self.jsHead2Output appendString:@")\n{\n"];

        // Falls es default values für die Argumente gibt, muss ich diese hier setzen
        if (![defaultValues isEqualToString:@""])
        {
            [self.jsHead2Output appendString:defaultValues];
            [self.jsHead2Output appendString:@"\n"];
        }

        // Um es auszurichten mit dem Rest
        [self.jsHead2Output appendString:@" "];

        // Okay, jetzt Text der Methode sammeln und beim schließen einfügen
    }


    // Handler wird immer in anderen Tags aufgerufen, wir nehmen von diesem umgebenden Tag
    // einfach die ID um den Handler zurodnen zu können
    if ([elementName isEqualToString:@"handler"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
        {
            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onclick"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-click-event.");

                [self.jQueryOutput appendString:@"\n  // onclick-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $(\"#%@\").click(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onchanged"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onvalue"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onnewvalue"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ontext"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ondata"]) // ToDo: Ist wirklich ondata = change-event?
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-change-event.");

                [self.jQueryOutput appendString:@"\n  // change-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').change(function()\n  {\n    ",self.zuletztGesetzteID]];


                // Extra Code, um den alten Value speichern zu können (s. als Erklärung auch
                // unten bei gegebenenem Attribut args)
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onnewvalue"] ||
                    [[attributeDict valueForKey:@"name"] isEqualToString:@"onvalue"])
                {
                    [self.jQueryOutput appendString:@"var oldvalue = $(this).data('oldvalue') || '';\n"];
                    [self.jQueryOutput appendString:@"    $(this).data('oldvalue', $(this).val());\n\n    "];
                }



                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onerror"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ontimeout"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-error-event.");

                [self.jQueryOutput appendString:@"\n  // error-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').error(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"oninit"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-load-event.");

                [self.jQueryOutput appendString:@"\n  // load-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').load(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onfocus"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-focus-event.");

                [self.jQueryOutput appendString:@"\n  // focus-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').focus(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onselect"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-select-event.");
    
                [self.jQueryOutput appendString:@"\n  // select-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').select(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onblur"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-blur-event.");

                [self.jQueryOutput appendString:@"\n  // blur-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').blur(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onmouseover"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-mouseover-event.");

                [self.jQueryOutput appendString:@"\n  // mouseover-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').mouseover(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onmouseout"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-mouseout-event.");

                [self.jQueryOutput appendString:@"\n  // mouseout-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').mouseout(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onkeyup"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-keyup-event.");

                [self.jQueryOutput appendString:@"\n  // keyup-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').keyup(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }

            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onkeydown"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a jQuery-keydown-event.");

                [self.jQueryOutput appendString:@"\n  // keydown-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').keydown(function()\n  {\n    ",self.zuletztGesetzteID]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }


            // ToDo - ich binde es an den unbekannten Handler
            // Klappt laut jQuery-Doku, irgend jemand anderes muss das event dann z. B. per trigger() aufrufen
            if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onsavestate"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onpaypalclose"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"oninternalstate"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onrolldown"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onfirstdown"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ondatedays"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onchecked"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onhasdefault"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onrolleddown"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onvisible"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onstop"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onmask"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onheight"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ontitlewidth"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"oncontrolpos"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onblurintextfield"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onxxx"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onpattern"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onmaxlength"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onminvalue"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ondomain"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onyes"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onno"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onlistwidth"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onmousewheeldelta"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onisopen"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ontextclick"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ondataset"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onboxheight"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onactual"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"onanimation"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ondown"] ||
                [[attributeDict valueForKey:@"name"] isEqualToString:@"ontabselected"])
            {
                self.attributeCount++;
                NSLog(@"Binding the method in this handler to a custom jQuery-event (has to be triggered).");

                [self.jQueryOutput appendString:@"\n  // 'custom'-Handler für "];
                [self.jQueryOutput appendString:self.zuletztGesetzteID];
                [self.jQueryOutput appendString:@"\n"];

                [self.jQueryOutput appendString:[NSString stringWithFormat:@"  $('#%@').bind('%@',function()\n  {\n    ",self.zuletztGesetzteID,[attributeDict valueForKey:@"name"]]];

                // Okay, jetzt Text sammeln und beim schließen einfügen
            }
        }



        // ToDo
        if ([attributeDict valueForKey:@"reference"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'reference'.");
        }




        // Wenn args gesetzt ist, wird derzeit nur der Wert 'oldvalue' unterstützt
        // und auch nur wenn als event 'onnewvalue' gesetzt wurde
        // Dazu wird der 'onnewvalue' oder 'onvalue'-Handler um Code ergänz der stets
        // den alten Wert in der Variable 'oldvalue' speichert
        if ([attributeDict valueForKey:@"args"])
        {
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"oldvalue"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onnewvalue"] ||
                    [[attributeDict valueForKey:@"name"] isEqualToString:@"onvalue"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'oldvalue'.");
                    NSLog(@"Setting extra-code in the handler to retrieve the oldvalue");
                }
            }

            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"k"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onkeyup"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'k'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"newp"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onblur"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'newp'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"d"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onmousewheeldelta"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'd'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"invoker"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"oninit"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'invoker'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"rowdp"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onblurintextfield"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'rowdp'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"key"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onkeydown"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'key'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onkeyup"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'key'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"val"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"oninit"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'val'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"ontext"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'val'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onisopen"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'val'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onyes"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'val'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onno"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'val'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
            // ToDo:
            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"leave"])
            {
                if ([[attributeDict valueForKey:@"name"] isEqualToString:@"onblur"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attrubute 'args' with value 'k'.");
                    NSLog(@"Skipping for now (ToDo)");
                }
            }
        }
    }

    // ToDo - events sind wohl sehr ähnlich <handler>
    // s. http://www.openlaszlo.org/lps4.9/docs/developers/methods-events-attributes.html
    // Überhaupt alles da drin ToDo
    if ([elementName isEqualToString:@"event"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'name' now (ToDo)");
        }
    }





    // Okay, letzte Chance: Wenn es vorher nicht gematcht hat. Dann war es eventuell eine selbst definierte Klasse?
    // Haben wir die Klasse auch vorher aufgesammelt? Nur dann geht es hier weiter.
    if (!element_bearbeitet && ([self.allFoundClasses objectForKey:elementName] != nil))
    {
        element_bearbeitet = YES;

        NSLog(@"Öffnendes Tag einer selbst definierten Klasse gefunden!");
        // NSLog([NSString stringWithFormat:@"%@",elementName]);
        // NSLog([NSString stringWithFormat:@"%@",[self.allFoundClasses objectForKey:elementName]]);

        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;


        // ToDo: Okay, hier muss ich jetzt per jQuery die Objekte auslesen aus der JS-Datei collectedClasses.js
    }




    /////////////////////////////////////////////////
    // Abfragen ob wir alles erfasst haben (Debug) //
    /////////////////////////////////////////////////
    if (!element_bearbeitet)
        [self instableXML:[NSString stringWithFormat:@"\nERROR: Nicht erfasstes öffnendes Element: '%@'", elementName]];

    NSLog([NSString stringWithFormat:@"Es wurden %d von %d Attributen berücksichtigt.",self.attributeCount,[attributeDict count]]);

    if (self.attributeCount != [attributeDict count])
    {
        [self instableXML:[NSString stringWithFormat:@"\nERROR: Nicht alle Attribute verwertet."]];
    }
    /////////////////////////////////////////////////
    // Abfragen ob wir alles erfasst haben (Debug) //
    /////////////////////////////////////////////////





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

// ToDo: Später in MyToolBox packen
BOOL isNumeric(NSString *s)
{
    NSScanner *sc = [NSScanner scannerWithString: s];
    if ( [sc scanFloat:NULL] )
    {
        return [sc isAtEnd];
    }
    return NO;
}


- (void) parser:(NSXMLParser *)parser
  didEndElement:(NSString *)elementName
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
{
    // Zum internen testen, ob wir alle Elemente erfasst haben
    BOOL element_geschlossen = NO;





    // Schließen von dataset
    if ([elementName isEqualToString:@"dataset"])
    {
        element_geschlossen = YES;

        if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
            self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
        else
            [self.jsHead2Output appendString:@"\n"];
    }

    // skipping All Elements in dataset without attribut 'src'
    if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
    {
        element_geschlossen = YES;

        NSLog([NSString stringWithFormat:@"\nSkipping the closing Element %@ for now.", elementName]);
        return;
    }







    // Okay, beim schließen den gesammelten String rekursiv auswerten und dann das Ergebnis der JS-Klasse hinzufügen
    if ([elementName isEqualToString:@"class"])
    {
        NSLog(@"Starting recursion (with String, not file, because of <class>) Content of string:");


        // Es muss ein gesamtumfassendes Tag geben, sonst ist es kein valides XML.
        // <library>, weil dies einerseits bereits in OL vorkommt und andererseits neutral ist.
        self.collectedContentOfClass = [[NSMutableString alloc] initWithFormat:@"<library>%@",self.collectedContentOfClass];
        [self.collectedContentOfClass appendString:@"</library>"];


        NSLog(self.collectedContentOfClass);
        xmlParser *x = [[xmlParser alloc] initWith:self.pathToFile recursiveCall:YES];

        // In <class> definierte Elemente greifen auch auf extern definierte Ressourcen zurück.
        // Muss ich deswegen hier übertragen.
        x.allJSGlobalVars = self.allJSGlobalVars;

        NSArray* result = [x startWithString:self.collectedContentOfClass];
        NSLog(@"Leaving recursion (with String, not file, because of <class>)");


        // NATÜRLICH DARF ICH HIER NICH APPENDEN, bzw. nicht immer. :-)
        // Ich nehme die einzelnen Resultate und muss schauen was davon relevant ist.
        NSString *rekurisveRueckgabeOutput = [result objectAtIndex:0];
        if (![rekurisveRueckgabeOutput isEqualToString:@""])
            NSLog(@"String 0 aus der Rekursion wird unser content für das JS-Objekt.");


        NSString *rekursiveRueckgabeJsOutput = [result objectAtIndex:1];
        if (![rekursiveRueckgabeJsOutput isEqualToString:@""])
            NSLog(@"String 1 aus der Rekursion wird unser content für ??? ToDo");

        NSString *rekursiveRueckgabeJsOLClassesOutput = [result objectAtIndex:2];
        if (![rekursiveRueckgabeJsOLClassesOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 2 zurück. Da muss ich mir was überlegen!"];

        NSString *rekursiveRueckgabeJQueryOutput0 = [result objectAtIndex:3];
        if (![rekursiveRueckgabeJQueryOutput0 isEqualToString:@""])
            NSLog(@"String 3 aus der Rekursion wird unser content für ??? ToDo");

        NSString *rekursiveRueckgabeJQueryOutput = [result objectAtIndex:4];
        if (![rekursiveRueckgabeJQueryOutput isEqualToString:@""])
            NSLog(@"String 4 aus der Rekursion wird unser content für das JS-Objekt.?? ToDo");
        NSString *rekursiveRueckgabeJsHeadOutput = [result objectAtIndex:5];
        if (![rekursiveRueckgabeJsHeadOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 5 zurück. Da muss ich mir was überlegen!"];

        // ToDo: Diesen String muss ich noch auswerten und irgendwie verbauen
        NSString *rekursiveRueckgabeJsHead2Output = [result objectAtIndex:6];
        if (![rekursiveRueckgabeJsHead2Output isEqualToString:@""])
            NSLog(@"String 6 aus der Rekursion wird unser content für ??? ToDo");

        NSString *rekursiveRueckgabeCssOutput = [result objectAtIndex:7];
        if (![rekursiveRueckgabeCssOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 7 zurück. Da muss ich mir was überlegen!"];
        NSString *rekursiveRueckgabeExternalJSFilesOutput = [result objectAtIndex:8];
        if (![rekursiveRueckgabeExternalJSFilesOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 8 zurück. Da muss ich mir was überlegen!"];

        // ToDo: Dieses Dictionary muss ich noch auswerten und irgendwie verbauen
        // Wohl einfach an das alte appenden, suche dazu nach "[result objectAtIndex:9]"
        NSDictionary *rekursiveRueckgabeAllJSGlobalVars = [result objectAtIndex:9];
        if ([rekursiveRueckgabeAllJSGlobalVars count] > 0)
            NSLog(@"Dictionary 9 aus der Rekursion wird unser content für ??? ToDo");

        NSDictionary *rekursiveRueckgabeAllFoundClasses = [result objectAtIndex:10];
        if ([rekursiveRueckgabeAllFoundClasses count] > 0)
            [self instableXML:@"<class> liefert was in 10 zurück. Da muss ich mir was überlegen!"];





        [self.jsOLClassesOutput appendString:@"  this.content = '"];

        // Überträgt den gesammelten OL-Code in die Datei
        // [self.jsOLClassesOutput appendString:self.collectedContentOfClass];
        // Aber wir wollen ja den schon ausgewerteten Code übertragen:
        [self.jsOLClassesOutput appendString:rekurisveRueckgabeOutput];
        // grrr - hier weitermachen - welche zurückgegebenen Werte muss ich noch auslesen?
        [self.jsOLClassesOutput appendString:@"\n\nAND\n\n"];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJQueryOutput];

        [self.jsOLClassesOutput appendString:@"';\n};\n"];
    }

    if ([elementName isEqualToString:@"class"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"fileUpload"] ||
        [elementName isEqualToString:@"dlginfo"] ||
        [elementName isEqualToString:@"dlgwarning"] ||
        [elementName isEqualToString:@"dlgyesno"] ||
        [elementName isEqualToString:@"nicepopup"] ||
        [elementName isEqualToString:@"nicemodaldialog"] ||
        [elementName isEqualToString:@"nicedialog"] ||
        [elementName isEqualToString:@"rollUpDownContainerReplicator"] ||
        [elementName isEqualToString:@"calculator_anim"] ||
        [elementName isEqualToString:@"certdatepicker"])
    {
        element_geschlossen = YES;

        self.weAreSkippingTheCompleteContenInThisElement = NO;
    }
    // If we are still skipping All Elements, let's return here
    if (self.weAreSkippingTheCompleteContenInThisElement)
    {
        // Wenn wir in <class> sind, sammeln wir alles (wird erst später rekursiv ausgewertet)

        NSString *s = @"";
        if (self.textInProgress != nil)
            s = self.textInProgress;

        // Nachdem ausgelesen, auf nil setzen, sonst haben wir ein rekursives Chaos...
        self.textInProgress = nil;

        // Remove leading and ending Whitespaces and NewlineCharacters
        s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // alle '<' müssen ersetzt werden, sonst meckert der XML-Parser
        s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];

        // Wenn wir nichts eingeschlossen haben und uns sofort wieder schließen. <tag />
        /*
        if ([s isEqualToString:@""] && ([self.element_merker isEqualToString:elementName]))
        {
            // Dann sind wir ein Element, was kein schließendes Tag hat
            // Deswegen das '>' am Ende entfernen
            // Und dafür ein '/>' einfügen

            // Das letzte Char des Strings entfernen:
            
            self.collectedContentOfClass = [[NSMutableString alloc] initWithString:[self.collectedContentOfClass substringToIndex:[self.collectedContentOfClass length] - 1]];

            [self.collectedContentOfClass appendString:@" />"];
        }
        else
        { */
            [self.collectedContentOfClass appendString:s];
            [self.collectedContentOfClass appendFormat:@"</%@>",elementName];
        /* } */

        return;
    }

    if ([elementName isEqualToString:@"BDSinputgrid"] ||
        [elementName isEqualToString:@"BDSreplicator"])
    {
        element_geschlossen = YES;

        self.weAreSkippingTheCompleteContenInThisElement2 = NO;
    }
    // If we are still skipping All Elements, let's return here
    if (self.weAreSkippingTheCompleteContenInThisElement2)
        return;

    if ([elementName isEqualToString:@"nicebox"])
    {
        element_geschlossen = YES;

        self.weAreSkippingTheCompleteContenInThisElement3 = NO;
    }
    // If we are still skipping All Elements, let's return here
    if (self.weAreSkippingTheCompleteContenInThisElement3)
        return;


    // Alle einzeln durchgehen, damit wir besser fehlende überprüfen können, deswegen ist hierin kein redundanter Code
    if (self.weAreInBDStextAndThereMayBeHTMLTags)
    {
        if ([elementName isEqualToString:@"br"])
        {
            element_geschlossen = YES;
        }

        if ([elementName isEqualToString:@"b"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</b>"];
        }

        if ([elementName isEqualToString:@"u"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</u>"];
        }
        if ([elementName isEqualToString:@"font"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</font>"];
        }
    }


    // Damit wir nur einen when-Zweig berücksichtigen, überspringen wir ab jetzt alle weiteren Elemente
    if ([elementName isEqualToString:@"when"])
    {
        element_geschlossen = YES;
        self.weAreInTheTagSwitchAndNotInTheFirstWhen = YES;
    }
    if ([elementName isEqualToString:@"switch"])
    {
        element_geschlossen = YES;
        self.weAreInTheTagSwitchAndNotInTheFirstWhen = NO;
    }
    // wenn wir aber trotzdem immer noch drin sind, dann raus hier, sonst würde er Elemente
    // schließend bearbeiten, die im 'when'-Zweig drin liegen
    if (self.weAreInTheTagSwitchAndNotInTheFirstWhen)
        return;



    if ([elementName isEqualToString:@"window"] ||
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"deferview"] ||
        [elementName isEqualToString:@"checkview"] ||
        [elementName isEqualToString:@"rotateNumber"] ||
        [elementName isEqualToString:@"rollUpDownContainer"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"buttonnext"])
            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

    self.verschachtelungstiefe--;

    NSLog([NSString stringWithFormat:@"Closing Element: %@\n", elementName]);

    // Schließen von canvas oder windows
    if ([elementName isEqualToString:@"canvas"] || [elementName isEqualToString:@"window"])
    {
        element_geschlossen = YES;
        [self.output appendString:@"</div>\n"];
    }


    if ([elementName isEqualToString:@"text"])
    {
        element_geschlossen = YES;

        // Immer auf nil testen, sonst kann es abstürzen hier
        NSString *s = @"";
        if (self.textInProgress != nil)
            s = self.textInProgress;

        // Remove leading and ending Whitespaces and NewlineCharacters
        s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        [self.output appendString:s];
        [self.output appendString:@"</div><br />\n"];
    }




    if ([elementName isEqualToString:@"simplelayout"])
    {
        element_geschlossen = YES;
    }



    if ([elementName isEqualToString:@"resource"])
    {
        element_geschlossen = YES;


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


    // Bei diesen Elementen muss beim schließen nichts unternommen werden
    if ([elementName isEqualToString:@"BDSedit"] ||
        [elementName isEqualToString:@"BDSeditdate"] ||
        [elementName isEqualToString:@"BDScombobox"] ||
        [elementName isEqualToString:@"BDScheckbox"] ||
        [elementName isEqualToString:@"checkbox"] ||
        [elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"] ||
        [elementName isEqualToString:@"BDSFinanzaemter"] ||
        [elementName isEqualToString:@"button"] ||
        [elementName isEqualToString:@"frame"] ||
        [elementName isEqualToString:@"font"] ||
        [elementName isEqualToString:@"items"] ||
        [elementName isEqualToString:@"library"] ||
        [elementName isEqualToString:@"audio"] ||
        [elementName isEqualToString:@"include"] ||
        [elementName isEqualToString:@"datapointer"] ||
        [elementName isEqualToString:@"attribute"] ||
        [elementName isEqualToString:@"SharedObject"] ||
        [elementName isEqualToString:@"infobox_notsupported"] ||
        [elementName isEqualToString:@"infobox_euerhinweis"] ||
        [elementName isEqualToString:@"infobox_stnr"] ||
        [elementName isEqualToString:@"infobox_plausi"] ||
        [elementName isEqualToString:@"tooltip"] ||
        [elementName isEqualToString:@"state"] ||
        [elementName isEqualToString:@"animatorgroup"] ||
        [elementName isEqualToString:@"animator"] ||
        [elementName isEqualToString:@"datapath"] ||
        [elementName isEqualToString:@"int_vscrollbar"] ||
        [elementName isEqualToString:@"combobox"] ||
        [elementName isEqualToString:@"datacombobox"] ||
        [elementName isEqualToString:@"multistatebutton"] ||
        [elementName isEqualToString:@"statictext"] ||
        [elementName isEqualToString:@"stableborderlayout"] ||
        [elementName isEqualToString:@"textlistitem"] ||
        [elementName isEqualToString:@"calcDisplay"] ||
        [elementName isEqualToString:@"calcButton"] ||
        [elementName isEqualToString:@"passthrough"])
    {
        element_geschlossen = YES;
    }



    // Schließen des Div's
    if ([elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"deferview"] ||
        [elementName isEqualToString:@"checkview"] ||
        [elementName isEqualToString:@"rotateNumber"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"buttonnext"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"])
    {
        element_geschlossen = YES;

        [self.output appendString:@"</div>\n"];
    }



    // Schließen von BDStext
    if ([elementName isEqualToString:@"BDStext"])
    {
        element_geschlossen = YES;

        // Immer auf nil testen, sonst kann es abstürzen hier
        NSString *s = @"";
        if (self.textInProgress != nil)
            s = self.textInProgress;

        // Remove leading and ending Whitespaces and NewlineCharacters
        s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        [self.output appendString:s];

        // Ab jetzt dürfen wieder Tags gesetzt werden.
        self.weAreInBDStextAndThereMayBeHTMLTags = NO;
        NSLog(@"BDStext was closed. I will not any longer skip tags.");

        [self.output appendString:@"</div>\n"];
    }



    // Schließen von item
    if ([elementName isEqualToString:@"item"])
    {
        element_geschlossen = YES;

        // Hinzufügen von gesammelten Text
        [self.jsHead2Output appendString:self.textInProgress];
        [self.jsHead2Output appendString:@"');\n"];
    }




    // Schließen von rollUpDownContainer
    if ([elementName isEqualToString:@"rollUpDownContainer"])
    {
        // Beim Betreten eins hochzählen, beim Verlassen runterzählen
        self.rollUpDownVerschachtelungstiefe--;
        // Beim Betreten Element dazunehmen, beim Verlassen entfernen
        [self.rollupDownElementeCounter removeLastObject];
        
        element_geschlossen = YES;
        
        [self.output appendString:@"</div>\n"];
    }




    // Schließen von rollUpDown
    if ([elementName isEqualToString:@"rollUpDown"])
    {
        self.weAreInRollUpDownWithoutSurroundingRUDContainer = NO;

        // Weil es auch verschachtelte rollUpDowns gibt ohne umschließenden Container,
        // muss ich den Zähler auch hier berücksichtigen.
        // Beim Betreten eins hochzählen, beim Verlassen runterzählen.
        self.rollUpDownVerschachtelungstiefe--;
        // Beim Betreten Element dazunehmen, beim Verlassen entfernen
        [self.rollupDownElementeCounter removeLastObject];


        element_geschlossen = YES;

        // Wir schließen hier gleich 2 Elemente, da rollUpDown intern aus mehreren Elementen besteht
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"</div>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];
    }





    if ([elementName isEqualToString:@"script"])
    {
        element_geschlossen = YES;

        NSString *s = self.textInProgress;
        if (s == nil)
            s = @"";


        
        // ToDo, DIESES DUMME REGEXP --- Statt dessen einfach return bei function..asdf.sd.fas.afgwe.
        if ([s rangeOfString:@"function"].location != NSNotFound)
            return;

        // Jetzt wird's richtig schmutzig, ich muss defaultarguments raus-regexpen, weil es die in JS nicht gibt
        // Überprüfen ob es default values gibt im Handler direkt (mit RegExp)...
        NSError *error = NULL;
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"function\\(.*?(\\w+)=(\\w+.*?\\))" options:NSRegularExpressionCaseInsensitive error:&error];
        
        NSUInteger numberOfMatches = [regexp numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])];
        if (numberOfMatches > 0)
            NSLog([NSString stringWithFormat:@"Heimlicher RegExpTest: %d",numberOfMatches]);
        
        NSArray *matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];
        
        for (NSTextCheckingResult *match in matches)
        {
            NSRange varNameRange = [match rangeAtIndex:1];
            NSRange defaultValueRange = [match rangeAtIndex:2];
            
            NSString *varName = [s substringWithRange:varNameRange];
            NSLog([NSString stringWithFormat:@"Found variable name: %@",varName]);
            NSString *defaultValue = [s substringWithRange:defaultValueRange];
            NSLog([NSString stringWithFormat:@"Found default value: %@",defaultValue]);
        }
        
        
        
        
        //s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:@"NIX"];
        
        /*
         if (numberOfMatches > 0)
         {
         NSLog([NSString stringWithFormat:@"There is/are %d pieces of malformed code (default-arguments in function), that is not allowed in JavaScript! I tried to regexp the default arguments out. I hope it worked out.",numberOfMatches]);
         
         NSArray *matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];
         
         NSMutableString *neueArgs = [[NSMutableString alloc] initWithString:@""];
         
         for (NSTextCheckingResult *match in matches)
         {
         NSRange varNameRange = [match rangeAtIndex:1];
         NSRange defaultValueRange = [match rangeAtIndex:2];
         
         NSString *varName = [s substringWithRange:varNameRange];
         NSLog([NSString stringWithFormat:@"Found variable name: %@",varName]);
         NSString *defaultValue = [s substringWithRange:defaultValueRange];
         NSLog([NSString stringWithFormat:@"Found default value: %@",defaultValue]);
         
         // ... dann die Variablennamen der args neu sammeln...
         if (![neueArgs isEqualToString:@""])
         [neueArgs appendString:@", "];
         [neueArgs appendString:varName];
         
         
         
         ///////////////////// Default- Variablen für JS setzen - Anfang /////////////////////
         [defaultValues appendString:@"  if(typeof("];
         [defaultValues appendString:varName];
         [defaultValues appendString:@")==='undefined') "];
         [defaultValues appendString:varName];
         [defaultValues appendString:@" = "];
         [defaultValues appendString:defaultValue];
         [defaultValues appendString:@";\n"];
         ///////////////////// Default- Variablen für JS setzen - Ende /////////////////////
         }
         // ... und hier setzen
         args = neueArgs;
         }
         */
        



        [self.jsHead2Output appendString:s];
    }






    if ([elementName isEqualToString:@"handler"])
    {
        element_geschlossen = YES;

        // Immer auf nil testen, sonst kann es abstürzen hier
        NSString *s = @"";
        if (self.textInProgress != nil)
            s = self.textInProgress;

        // Remove leading and ending Whitespaces and NewlineCharacters
        s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // This ersetzen
        s = [s stringByReplacingOccurrencesOfString:@"this" withString:@"$(this)"];

        // setAttribute ersetzen
        s = [s stringByReplacingOccurrencesOfString:@"setAttribute" withString:@"attr"];

        // ich muss zumindestens für Buttons das Attribut 'text' von OpenLaszlo durch das
        // HTML-Attribut 'value' ersetzen (muss ich eventuell ändern, falls es Sideeffects gibt)
        // Habe es länger gemacht, um nicht z. B. die Phrase 'text' in einem String zu ersetzen
        s = [s stringByReplacingOccurrencesOfString:@".attr('text'" withString:@".attr('value'"];





        [self.jQueryOutput appendString:s];
        [self.jQueryOutput appendString:@"\n  });\n"];
    }
    // ToDo - Analog <handler>? siehe auch bei öffnendem Element von <event>
    if ([elementName isEqualToString:@"event"])
    {
        element_geschlossen = YES;
    }





    if ([elementName isEqualToString:@"method"])
    {
        element_geschlossen = YES;

        // Immer auf nil testen, sonst kann es abstürzen hier
        NSString *s = @"";
        if (self.textInProgress != nil)
            s = self.textInProgress;

        // Remove leading and ending Whitespaces and NewlineCharacters
        s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // tabs eliminieren
        while ([s rangeOfString:@"\t"].location != NSNotFound)
        {
            s = [s stringByReplacingOccurrencesOfString:@"\t" withString:@"  "];
        }
        // Leerzeichen zusammenfassen
        while ([s rangeOfString:@"  "].location != NSNotFound)
        {
            s = [s stringByReplacingOccurrencesOfString:@"  " withString:@" "];
        }



        // super ist nicht erlaubt in JS und gibt es auch nicht. Ich ersetze es erstmal durch this. ToDo
        // Evtl. klappt das schon, weil ja eh alle Funktionen in parentKlasse stecken (To Check)
        s = [s stringByReplacingOccurrencesOfString:@"super" withString:@"this"];


        // This ersetzen
        // s = [s stringByReplacingOccurrencesOfString:@"this" withString:@"$(this)"];




        //s = @"alert('test')";
        [self.jsHead2Output appendString:s];
        [self.jsHead2Output appendString:@"\n}\n"];
    }





    // Okay, letzte Chance: Wenn es vorher nicht gematcht hat. Dann war es eventuell eine selbst definierte Klasse?
    // Haben wir die Klasse auch vorher aufgesammelt? Nur dann geht es hier weiter.
    if (!element_geschlossen && ([self.allFoundClasses objectForKey:elementName] != nil))
    {
        element_geschlossen = YES;
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


    // bei den HTML-Tags innerhalb von BDStext darf ich self.textInProgress nicht auf nil setzen,
    // da ich den Text ja weiter ergänze.
    if (!self.weAreInBDStextAndThereMayBeHTMLTags)
    {
        // Clear the text and key
        self.textInProgress = nil;
        self.keyInProgress = nil;
    }


    if (!element_geschlossen)
        [self instableXML:[NSString stringWithFormat:@"ERROR: Nicht erfasstes schließendes Element: '%@'", elementName]];
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
    // Alles das was wir in dieser Methode machen, machen wir nur einmal,
    // deswegen nicht bei rekursiven Aufrufen!
    if (self.isRecursiveCall)
        return;




    NSMutableString *pre = [[NSMutableString alloc] initWithString:@""];

    [pre appendString:@"<!DOCTYPE HTML>\n<html>\n<head>\n"];
    
    // Nicht HTML5-Konform, aber zum testen um sicherzustellen, dass wir nichts aus dem Cache laden
    [pre appendString:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n<meta http-equiv=\"pragma\" content=\"no-cache\" />\n<meta http-equiv=\"cache-control\" content=\"no-cache\" />\n<meta http-equiv=\"expires\" content=\"0\" />\n"];

    // Viewport für mobile Devices anpassen...
    // ...width=device-width funktioniert nicht im Portrait-Modus.
    // initial-scale baut links und rechts einen kleinen Abstand ein. Wollen wir das? ToDo
    // [pre appendString:@"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n"];
    [pre appendString:@"<meta name=\"viewport\" content=\"\" />\n"];


    // Als <title> nutzen wir den Dateinamen der Datei
    [pre appendFormat:@"<title>%@</title>\n",[[self.pathToFile lastPathComponent] stringByDeletingPathExtension]];

    // CSS-Stylesheet-Datei für das Layout der TabSheets (wohl leider nicht CSS-konform, aber
    // die CSS-Konformität herzustellen ist wohl leider zu viel Aufwand, von daher greifen wir
    // auf diese fertige Lösung zurück)
    [pre appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.19/themes/humanity/jquery-ui.css\">\n"];

    // CSS-Stylesheet-Datei // Diese MUSS nach der Humanity-css kommen, da ich bestimmte Sachen
    // überschreibe
    [pre appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"formate.css\">\n"];

    // IE-Fallback für canvas (falls ich es benutze) - ToDo
    // [pre appendString:@"<!--[if IE]><script src=\"excanvas.js\"></script><![endif]-->\n"];


    // jQuery laden
    [pre appendString:@"<script type=\"text/javascript\" src=\"https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js\"></script>\n"];

    // Falls latest jQuery-Version gewünscht:
    // '<script type="text/javascript" src="http://code.jquery.com/jquery-latest.min.js"></script>'
    // einbauen, aber dann kein Caching!

    // jQuery UI laden (wegen TabSheet)
    [pre appendString:@"<script type=\"text/javascript\" src=\"https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.19/jquery-ui.min.js\"></script>\n"];

    if (![self.jsOLClassesOutput isEqualToString:@""])
    {
        // Die von OpenLaszlo gefundenen Klassen werden zuerst integriert
        [pre appendString:@"<script type=\"text/javascript\" src=\"collectedClasses.js\"></script>\n"];
    }

    // Unser eigenes Skript lieber zuerst
    [pre appendString:@"<script type=\"text/javascript\" src=\"jsHelper.js\"></script>\n"];
    // Dann erst externe gefundene Skripte
    [pre appendString:self.externalJSFilesOutput];

    if (![self.cssOutput isEqualToString:@""])
    {
        [pre appendString:@"\n<style type='text/css'>\n"];
        [pre appendString:self.cssOutput];
        [pre appendString:@"</style>\n\n<script type=\"text/javascript\">\n"];
    }

    // Wird derzeit nicht ins JS ausgegeben, da die Bilder usw. direkt im Code stehen.
    // (Soll das so bleiben?)
    // ... [pre appendString:self.jsHeadOutput]; ...

    // erstmal nur die mit resource gesammelten globalen vars ausgeben
    // (+ globale Funktionen + globales JS)
    [pre appendString:self.jsHead2Output];
    [pre appendString:@"</script>\n\n</head>\n\n<body>\n"];


    // Kurzer Tausch damit ich den Header davorschalten kann
    NSMutableString *temp = [[NSMutableString alloc] initWithString:self.output];
    self.output = [[NSMutableString alloc] initWithString:pre];
    [self.output appendString:temp];


    // Füge noch die nötigen JS ein:
    [self.output appendString:@"\n<script type=\"text/javascript\">\n"];
    [self.output appendString:self.jsOutput];
    [self.output appendString:@"\n\n$(function()\n{\n"];

    [self.output appendString:@"  // globalhelp heimlich als Div einführen\n"];
    [self.output appendString:@"  $('div:first').prepend('<div id=\"___globalhelp\" class=\"ui-corner-all\" style=\"position:absolute;left:810px;top:150px;width:175px;height:300px;z-index:1000;background-color:white;padding:4px;\">Infocenter</div>');\n\n"];

    // dlgFamilienstandSingle -> ToDo, muss später selbständig erkannt werden
    [self.output appendString:@"  // dlgFamilienstandSingle heimlich als Objekt einführen (diesmal direkt im Objekt, ohne prototype)\n"];
    [self.output appendString:@"  function dlg()\n  {\n    // Extern definiert\n    this.open = open;\n    // Intern definiert (beides möglich)\n"];
    [self.output appendString:@"    this.completeInstantiation = function completeInstantiation() { };\n  }\n"];
    [self.output appendString:@"  function open()\n  {\n    alert('Willst du wirklich deine Ehefrau löschen? Usw...');\n  }\n"];
    [self.output appendString:@"  var dlgFamilienstandSingle = new dlg();\n\n"];


    // Vorgezogene jQuery-Ausgaben:
    if (![self.jQueryOutput0 isEqualToString:@""])
    {
        [self.output appendString:self.jQueryOutput0];
        [self.output appendString:@"\n\n  /****************************************************************/\n"];
        [self.output appendString:@"  /*****************************Grenze*****************************/\n"];
        [self.output appendString:@"  /***********Vorgezogene JQuery-Ausgaben sind hier vor ***********/\n"];
        [self.output appendString:@"  /***Diese müssen zwingend vor folgenden jQuery-Ausgaben kommen***/\n"];
        [self.output appendString:@"  /****************************************************************/\n\n\n"];
    }

    // Normale jQuery-Ausgaben
    [self.output appendString:self.jQueryOutput];

    // Falls es mindestens einen TabSheetContainer gab, das Design hier noch anpassen (nur oben Ecken)
    if (![self.lastUsedTabSheetContainerID isEqualToString:@""])
    {
        // Die unteren Ecken entfernen von der TabBar
        [self.output appendString:@"\n  // Die unteren Ecken entfernen von der TabBar\n"];
        [self.output appendString:@"  $('ul').removeClass('ui-corner-all');\n"];
        [self.output appendString:@"  $('ul').addClass('ui-corner-top');\n"];
    }

    [self.output appendString:@"});\n</script>\n\n"];



    // Und nur noch die schließenden Tags
    [self.output appendString:@"</body>\n</html>"];

    // Path zum speichern ermitteln
    // Download-Verzeichnis war es mal, aber Problem ist, dass dann die Ressourcen fehlen...
    // NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    // NSString *dlDirectory = [paths objectAtIndex:0];
    // NSString * path = [[NSString alloc] initWithString:dlDirectory];
    //... deswegen ab jetzt immer im gleichen Verzeichnis wie das OpenLaszlo-input-File
    // Die Dateien dürfen dann nur nicht zufälligerweise genau so heißen wie welche im Verzeischnis
    // (ToDo bei Public Release)
    NSString *path = [[self.pathToFile URLByDeletingLastPathComponent] relativePath];


    NSString *pathToCSSFile = [NSString stringWithFormat:@"%@/formate.css",path];
    NSString *pathToJSFile = [NSString stringWithFormat:@"%@/jsHelper.js",path];
    NSString *pathToCollectedClassesFile = [NSString stringWithFormat:@"%@/collectedClasses.js",path];


    path = [path stringByAppendingString: @"/output_ol2x.html"];

    // NSLog(@"%@",path);

    if (self.errorParsing == NO)
    {
        NSLog(@"XML processing done!\n");

        // Schreiben einer Datei per NSData:
        // NSData* data = [self.output dataUsingEncoding:NSUTF8StringEncoding];
        // [data writeToFile:@"output_ol2x.html" atomically:NO];


        // Aber wir machen es direkt über den String:
        bool success = [self.output writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];

        if (success)
            NSLog(@"Writing HTML-file... succeeded.");
        else
            NSLog(@"Writing HTML-file...failed.");

        // Unterstützende CSS-Datei schreiben
        [self createCSSFile:pathToCSSFile];

        // Unterstützende JS-Datei schreiben
        [self createJSFile:pathToJSFile];

        if (![self.jsOLClassesOutput isEqualToString:@""])
        {
            // Unterstützende collectedOlClasses-Datei schreiben
            [self createCollectedClassesFile:pathToCollectedClassesFile];
        }

        NSLog(@"Job done.");
    }
    else
    {
        NSLog(@"Error occurred during XML processing");
    }



    if (![self.issueWithRecursiveFileNotFound isEqual:@""])
    {
        NSLog(@"\nATTENTION:\nThere was an issue with a recursive file that I couldn't found:");
        NSLog([NSString stringWithFormat:@"'%@'",self.issueWithRecursiveFileNotFound]);
        NSLog(@"I'm sorry I coudn't fix this problem. Your OpenLaszlo-code may be malformed.\n");
        NSLog(@"I continued the parsing anyway, but there may be problems with the Output.");
    }



    [self jumpToEndOfTextView];
}




- (void) createCSSFile:(NSString*)path
{
    NSString *css = @"/* FILE: formate.css */\n"
    "\n"
    "/* Enthaelt standard-Definitionen, die das Aussehen von OpenLaszlo simulieren */\n"
    "/*\n"
    "Known issues:\n"
    "inherit => Not supported by IE6 & IE 7; hilft ersetzen durch auto?\n"
    "previousElementSibling => not supported by IE < 9\n"
    "\n"
    "- simplelayout muss das erste element sein bei aufeinanderfolgenden Schwester-Elementen\n"
    "- keine Unterstützung für Sound-Resourcen\n"
    "- Kommentare gehen verloren\n"
    "- offsetWidth vs clientWidth nochmal testen, aber macht wohl keinen Unterschied:\n"
    "(http://www.quirksmode.org/dom/w3c_cssom.html)\n"
    "\n"
    "\n"
    "ToDo\n"
    "- in FF klappt der direkte Zugriff auf Elemente per id nicht (bei strictem doctype)\n"
    "- Von BDSeditdate und BDScombobox den Anfangscode zusammenfassen (ist gleich)\n"
    "- on vertical Resize die Höhe anpassen\n"
    "- Bei views Layout-Attribut beachten: Dazu wohl Simplelayout-Test als eigene Methode;\n"
    "- Bei Links muss sich der Mauszeiger verändern\n"
    "- Warum bricht er e-Mail beim Bindestrich um?\n"
    "- style.height in check4somplelayout kann/muss ich wohl ersetzen mit offsetHeight\n"
    "- 1000px großes bild soll nur bis zum Bildschirmrand gehen\n"
    "- und zusätzlich sich selbst aktualisieren, wenn Bildschirmhöhe verändert wird\n"
    "- PS: CSS einteilen in Form, Farbe, Schrift\n"
    " */\n"
    "\n"
    "body, html\n"
    "{\n"
    "    /* http://www.quirksmode.org/css/100percheight.html */\n"
    "    height: 100%;\n"
    "    /* prevent browser decorations */\n"
    "    margin: 0;\n"
    "    /* padding: 0; Nicht notwendig: http://www.thestyleworks.de/basics/inheritance.shtml*/\n"
    "    border: 0 none;\n"
    "\n"
    "    /* Prevents scrolling */\n"
    "    overflow: hidden;\n"
    "\n"
    "    text-align: center;\n"
    "}\n"
    "\n"
    "/* Damit der Hintergrund weiß wird, entgegen der Angabe in Humanity.css */\n"
    ".ui-widget-content { border: 1px solid #e0cfc2; background: #ffffff; color: #1e1b1d; }\n"
    "\n"
    "img { border: 0 none; }\n"
    //"* { float:left; } //ALLE Elemente sollen nur so viel Platz einnehmen, wie sie auch brauchen\n" <-- Bricht zu viel, lieber einzeln durchgehen, wo nötig
    "\n"
    "/* Alle Divs müssen position:absolute sein, damit die Positionierung stimmt */\n"
    "/* Korrektur: Seit Benutzung jQuery UI müssen alle Divs position:relative sein */\n"
    "/* sonst bricht jQuery UI */\n"
    "div, span\n"
    "{\n"
	"    position:relative;\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
    "\n"
    "    /* Damit auf jedenfall ein Startwert gesetzt ist,\n"
    "    sonst gibt es massive Probleme beim auslesen der Variable durch JS */\n"
	"    height:auto;\n"
	"    width:auto;\n"
    "}\n"
    "\n"
    "input\n"
    "{\n"
	"    position:relative;\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
    "\n"
    "    /* Damit auf jedenfall ein Startwert gesetzt ist,\n"
    "    sonst gibt es massive Probleme beim auslesen der Variable durch JS */\n"
	"    height:auto;\n"
	"    width:auto;\n"
    "}\n"
    "\n"
    "/* Ziemlich dirty Trick um '<inputs>' und 'Text' innerhalb der TabSheets besser */\n"
    "/* ausrichten zu können. So, dass sie nicht umbrechen, weil Sie position: absolute sind. */\n"
    "/* Andererseits braucht simplelayout eben position:absolute  -  evtl. ToDo */\n"
    "div > div > div > div > div > div > div > div > input,\n"
    "div > div > div > div > div > div > div > div[class=\"ol_text\"]\n"
    "{\n"
    "    position:relative;\n"
    "}\n"
    "\n"
    "/* Das Standard-Canvas, welches den Rahmen darstellt */\n"
    "div.ol_standard_canvas\n"
    "{\n"
    "    background-color:white;\n"
	"    height:100%;\n"
	"    width:100%;\n"
	"    position:absolute;\n"
	"    top:0px;\n"
	"    left:0px;\n"
    "    text-align:left;\n"
	"    padding:0px;\n"
    "}\n"
    "\n"
    "select\n"
    "{\n"
    "    margin-left:5px;\n"
    "}\n"
    "\n"
    "/* Das Standard-Window, wie es ungefaehr in OpenLaszlo aussieht */\n"
    "div.ol_standard_window\n"
    "{\n"
    "    background-color:lightgrey;\n"
	"    height:40px;\n"
	"    width:50px;\n"
	"    position:relative;\n"
	"    top:20px;\n"
	"    left:20px;\n"
    "    text-align:left;\n"
	"    padding:4px;\n"
    "}\n"
    "\n"
    "/* Das Standard-View, wie es ungefaehr in OpenLaszlo aussieht */\n"
    "div.ol_standard_view\n"
    "{\n"
    "    /* background-color:red; /* Standard ist hier keine (=transparent), zum testen red */\n"
    "\n"
	"    height:auto;\n"
	"    width:auto;\n"
	"    position:relative;\n"
	"    top:0px;\n"
	"    left:0px;\n"
    "    /*\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    */\n"
    "}\n"
    "\n"
    "/* Standard-combobox (das umgebende Div) */\n"
    "div.combobox\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    float:none; /* Eine combobox soll immer die ganze Zeile einnehmen. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    margin-top: 8px;\n"
    "}\n"
    "\n"
    "/* CSS-Angaben für den RollUpDownContainer */\n"
    "div.rudContainer\n"
    "{\n"
    "    margin-left:14px;\n"
    "}\n"
    "\n"
    "/* CSS-Angaben für ein RollUpDownElement */\n"
    "div.rudElement\n"
    "{\n"
    "    height:auto;\n" // War mal 'inherit', aber 'auto' erscheint mir logischer, ob was bricht?
    "    margin-bottom:6px;\n"
    "}\n"
    "\n"
    "/* Standard-datepicker (das umgebende Div) */\n"
    "div.datepicker\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    float:none; /* Ein datepicker soll immer die ganze Zeile einnehmen. */\n"
    "    height:30px; /* Sonst ist er nicht richtig anklickbar. */\n"
    "    line-height:26px; /* Damit der Text vor dem Datepicker vertikal zentriert ist. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    margin-top: 8px;\n"
    "}\n"
    "\n"
    "\n"
    "/* Standard-checkbox (das umgebende Div) */\n"
    "div.checkbox\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    width:100%; /* Eine checkbox soll immer die ganze Zeile einnehmen. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    margin-top: 8px;\n"
    "    \n"
    "}\n"
    "\n"
    "/* Standard-textfield (das umgebende Div) */\n"
    "div.textfield\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    text-align:left;\n"
    "    padding:2px;\n"
    "}\n"
    "\n"
    "/* Standard-Text (Text/BDStext) */\n"
    "div.ol_text\n"
    "{\n"
    "    position:relative;\n"
    "    text-align:left;\n"
    "    padding:2px;\n"
    "\n"
    "    font-family: Verdana,sans-serif;\n"
    "    font-style: normal;\n"
    "    font-weight: normal;\n"
    "    font-size: 11px;\n"
    "    line-height: 1.2em;\n"
    "    text-indent: 0;\n"
    "    letter-spacing: 0.01em;\n"
    "    text-decoration: none;\n"
    "    /* wohl nur bei <text>, diese Angaben brechen <BDStext>\n"
    "    white-space: nowrap;\n"
    "    word-wrap: break-word; */\n"
    "}";



    bool success = [css writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    if (success)
        NSLog(@"Writing CSS-file... succeeded.");
    else
        NSLog(@"Writing CSS-file... failed.");   
}



- (void) createJSFile:(NSString*)path
{
    NSString *js = @"/* FILE: jsHelper.js */\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Falls sich die Höhe ändert am iPad (orientationchange)\n"
    "/////////////////////////////////////////////////////////\n"
    "$(window).bind('orientationchange', function(event)\n"
    "{\n"
    "    alert('new orientation:' + window.orientation);\n"
    "});\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// ! A fix for the iOS orientationchange zoom bug.       \n"
    "/////////////////////////////////////////////////////////\n"
    "// <meta name=\"viewport\" content=\"\" /> muss dazu angegeben worden sein.\n"
    "// (in content kann natürlich irgendwas rein)\n"
    "/*\n"
    " Script by @scottjehl, rebound by @wilto.\n"
    " MIT License.\n"
    " */ /*\n"
    "(function(w)\n"
    "{\n"
    "    // This fix addresses an iOS bug, so return early if the UA claims it's something else.\n"
    "    if( !( /iPhone|iPad|iPod/.test( navigator.platform ) && navigator.userAgent.indexOf( \"AppleWebKit\" ) > -1 ) ){\n"
    "        return;\n"
    "    }\n"
    "\n"
    "    var doc = w.document;\n"
    "\n"
    "    if( !doc.querySelector ){ return; }\n"
    "\n"
    "    var meta = doc.querySelector( \"meta[name=viewport]\" ),\n"
    "       initialContent = meta && meta.getAttribute( \"content\" ),\n"
    "       disabledZoom = initialContent + \",maximum-scale=1.024\", // weil wir width= 1024 haben, klappt trotzdem nur manchmal...\n"
    "       enabledZoom = initialContent + \",maximum-scale=10\",\n"
    "       enabled = true,\n"
    "    x, y, z, aig;\n"
    "\n"
    "   if( !meta ){ return; }\n"
    "\n"
    "   function restoreZoom(){\n"
    "       meta.setAttribute('content', enabledZoom );\n"
    "       enabled = true;\n"
    "    }\n"
    "\n"
    "    function disableZoom(){\n"
    "        meta.setAttribute('content', disabledZoom );\n"
    "        enabled = false;\n"
    "     }\n"
    "\n"
    "    function checkTilt( e ){\n"
    "        aig = e.accelerationIncludingGravity;\n"
    "        x = Math.abs( aig.x );\n"
    "        y = Math.abs( aig.y );\n"
    "        z = Math.abs( aig.z );\n"
    "\n"
    "        // If portrait orientation and in one of the danger zones\n"
    "        if( !w.orientation && ( x > 7 || ( ( z > 6 && y < 8 || z < 8 && y > 6 ) && x > 5 ) ) ){\n"
    "            if( enabled ){\n"
    "                disableZoom();\n"
    "            }\n"
    "            }\n"
    "        else if( !enabled ){\n"
    "            restoreZoom();\n"
    "            }\n"
    "        }\n"
    "\n"
    "    w.addEventListener('orientationchange', restoreZoom, false );\n"
    "    w.addEventListener('devicemotion', checkTilt, false );\n"
    "\n"
    "})( this ); */\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Wandelt eine float in einen korrekt gerundeten Integer\n"
    "/////////////////////////////////////////////////////////\n"
    "function toInt(n){ return Math.round(Number(n)); };\n"
    "\n"
    "\n"
    "function getMaxOfArray(numArray)\n"
    "{\n"
    "    return Math.max.apply(null, numArray);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hindere IE 9 am seitlichen scrollen mit dem Scrollrad!\n"
    "/////////////////////////////////////////////////////////\n"
    "function wheel(event)\n"
    "{\n"
    "    if (!event)\n"
    "        event = window.event;\n"
    "\n"
    "    if (event.preventDefault)\n"
    "    {\n"
    "        event.preventDefault();\n"
    "        event.returnValue = false;\n"
    "    }\n"
    "}\n"
    "if (window.addEventListener)\n"
    "    window.addEventListener('DOMMouseScroll', wheel, false);\n"
    "window.onmousewheel = document.onmousewheel = wheel;\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////\n"
    "// Hindere IE 9 am abstürzen, wenn wir console.log aufrufen\n"
    "///////////////////////////////////////////////////////////\n"
    "try {\n"
    "    console\n"
    "} catch(e){\n"
    "    console={};\n"
    "    console.log = function(){};\n"
    "}\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////\n"
    "// Identifiziere ob wir uns auf einer iOS-Platform befinden\n"
    "///////////////////////////////////////////////////////////\n"
    "function isiOS()\n"
    "{\n"
    "    return ((navigator.platform.indexOf('iPhone') != -1) ||\n"
    "            (navigator.platform.indexOf('iPod') != -1) ||\n"
    "            (navigator.platform.indexOf('iPad') != -1) ||\n"
    "            (navigator.userAgent.match(/(iPhone|iPod|iPad)/i) != null));\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// datasetItem-Klasse für in OL deklarierte datasets (bzw. ein Objekt-Konstruktor dafür)\n"
    "/////////////////////////////////////////////////////////\n"
    "function datasetItem(value, info, afa, check, content)\n"
    "{\n"
    "    // Die Propertys des Objekts\n"
    "    this.value = value;\n"
    "    this.content = content;\n"
    "    // Manche items haben auch noch ein info-Attribut\n"
    "    this.info = info;\n"
    "    // Manche items haben auch noch ein afa-Attribut\n"
    "    this.afa = afa;\n"
    "    // Manche items haben auch noch ein check-Attribut\n"
    "    this.check = check;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// toggleVisibility (wird benötigt um Visibility sowohl jetzt, als auch später,\n"
    "// abhängig von einer Bedingung zu setzen)\n"
    "/////////////////////////////////////////////////////////\n"
    "function toggleVisibility(id, idAbhaengig, bedingungAlsString)\n"
    "{\n"
    "  // To To To - Solange ich noch nicht alles auswerte, muss ich hier\n"
    "  // bestimmte objekte selber setzen, damit eval() sich nicht beschwert\n"
    "  var replicator = typeof replicator !== 'undefined' ? replicator : new Object();\n"
    "  var checked = typeof checked !== 'undefined' ? checked : new Object();\n"
    "  var cbType = typeof cbType !== 'undefined' ? cbType : new Object();\n"
    "  var Gewerbesteuerpflicht = typeof Gewerbesteuerpflicht !== 'undefined' ? Gewerbesteuerpflicht : new Object();\n"
    "  var regelmaessig = typeof regelmaessig !== 'undefined' ? regelmaessig : new Object();\n"
    "  var begruendet = typeof begruendet !== 'undefined' ? begruendet : new Object();\n"
    "  var complete = typeof complete !== 'undefined' ? complete : new Object();\n"
    "  var keinestnr = typeof keinestnr !== 'undefined' ? keinestnr : new Object();\n"
    "  var isvalid = typeof isvalid !== 'undefined' ? isvalid : new Object();\n"
    "\n"
    "\n"
    "\n"
    "  // 'value' wird intern von OpenLaszlo benutzt! Indem ich auch in JS 'value' in der Zeile\n"
    "  // vorher setze und danach den string auswerte, der 'value' in der Bedingung enthält,\n"
    "  // muss ich das von OpenLaszlo benutzte 'value' nicht intern parsen (nice Trick, I Think)\n"
    "  if (idAbhaengig == \"__PARENT__\")\n"
    "  {\n"
    "      var value = $(idAbhaengig).parent().val();\n"
    "      // Die nachfolgenden beiden Zeilen helfen mir jetzt bei parent().parent(), oder können sie weg? ToDo\n"
    "      var parent = $(idAbhaengig).parent().parent();\n"
    "      parent.value = $(idAbhaengig).parent().parent().val();\n"
    "  }\n"
    "  else\n"
    "  {\n"
    "      var value = $(idAbhaengig).val();\n"
    "      // Die nachfolgenden beiden Zeilen helfen mir jetzt bei parent().parent(), oder können sie weg? ToDo\n"
    "      var parent = $(idAbhaengig).parent();\n"
    "      parent.value = $(idAbhaengig).parent().val();\n"
    "  }\n"
    "\n"
    " parent.cbType = cbType; // Schummelvariable (ToDo)\n"
    "\n"
    "  console.log(bedingungAlsString)\n"
    "  var bedingung = eval(bedingungAlsString);\n"
    "\n"
    "  // Wenn wir ein input sind, vor uns ist ein span und um uns herum ist ein div\n"
    "  // dann müssen wir das umgebende div togglen, weil dies das komplette input-Feld umfasst\n"
    "  if (($(id).is('input') && $(id).prev().is('span') && $(id).parent().is('div')) ||\n"
    "      ($(id).is('select') && $(id).prev().is('span') && $(id).parent().is('div')))\n"
    "    $(id).parent().toggle(bedingung);\n"
    "  else\n"
    "    $(id).toggle(bedingung);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// globale canvas-Methoden\n"
    "/////////////////////////////////////////////////////////\n"
    "function loadurlchecksave(url)\n"
    "{\n"
    "    window.location.href = url;\n"
    "}\n"
    "\n"
    "function setglobalhelp(s)\n"
    "{\n"
    "    $('#___globalhelp').text(s);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// globales lz-Objekt, um Aufrufe darauf abzufangen\n"
    "/////////////////////////////////////////////////////////\n"
    "var lz = new Object();\n"
    "lz.Cursor = new Object();\n"
    "lz.Cursor.restoreCursor = function() {};\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// jQuery\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Zentriere Anzeige beim öffnen der Seite\n"
    "/////////////////////////////////////////////////////////\n"
    "$(function()\n"
    "{\n"
    "    adjustOffsetOnBrowserResize();\n"
    "});\n"
    "\n"
    "function adjustOffsetOnBrowserResize()\n"
    "{\n"
    "    // var widthDesErstenKindes = parseInt($('div:first').children(':first').css('width'));\n"
    "    var unsereWidth = parseInt($('div:first').css('width'));\n"
    "    var left;\n"
    "    if ((($(window).width())-unsereWidth)/2 > 0)\n"
    "        left = (($(window).width())-unsereWidth)/2;\n"
    "    else\n"
    "        left = 0;\n"
    "    $('div:first').css('left', left +'px');\n"
    "}\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Zentriere Anzeige beim resizen der Seite\n"
    "/////////////////////////////////////////////////////////\n"
    "$(window).resize(function()\n"
    "{\n"
    "    adjustOffsetOnBrowserResize();\n"
    "});\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// watch/unwatch-Skript um auf Änderungen von Variablen reagieren zu können\n"
    "/////////////////////////////////////////////////////////\n"
    "/*\n"
    "* object.watch polyfill\n"
    "*\n"
    "* 2012-04-03\n"
    "*\n"
    "* By Eli Grey, http://eligrey.com\n"
    "* Public Domain.\n"
    "* NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.\n"
    "*/\n"
    "\n"
    "// object.watch\n"
    "if (!Object.prototype.watch) {\n"
    "    Object.defineProperty(Object.prototype, 'watch', {\n"
    "    enumerable: false\n"
    "        , configurable: true\n"
    "        , writable: false\n"
    "        , value: function (prop, handler) {\n"
    "            var oldval = this[prop], newval = oldval,\n"
    "            getter = function () {\n"
    "                return newval;\n"
    "            },\n"
    "            setter = function (val) {\n"
    "                oldval = newval;\n"
    "                return newval = handler.call(this, prop, oldval, val);\n"
    "            };\n"
    "            if (delete this[prop]) { // can't watch constants\n"
    "                Object.defineProperty(this, prop, {\n"
    "                get: getter,\n"
    "                set: setter,\n"
    "                enumerable: true,\n"
    "                configurable: true\n"
    "                });\n"
    "            }\n"
    "        }\n"
    "    });\n"
    "}\n"
    "\n"
    "// object.unwatch\n"
    "if (!Object.prototype.unwatch) {\n"
    "    Object.defineProperty(Object.prototype, 'unwatch', {\n"
    "    enumerable: false\n"
    "        , configurable: true\n"
    "        , writable: false\n"
    "        , value: function (prop) {\n"
    "            var val = this[prop];\n"
    "            delete this[prop]; // remove accessors\n"
    "            this[prop] = val;\n"
    "        }\n"
    "    });\n"
    "}";



    bool success = [js writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    if (success)
        NSLog(@"Writing JS-file... succeeded.");
    else
        NSLog(@"Writing JS-file... failed.");  
}




- (void) createCollectedClassesFile:(NSString*)path
{
    NSString *js = @"/* FILE: collectedClasses.js */\n"
    "\n"
    "////////////////////////////////////////////////////////////////////////////////////////////////////\n"
    "// Beinhaltet alle von OpenLaszlo mittels <class> definierte Klassen. Es werden korrespondierende //\n"
    "// 'Constructor Functions' angelegt, welche später von jQuery verarbeitet werden. Sobald          //\n"
    "// der Converter auf die Klasse dann stößt, legt er ein hier definiertes Objekt per new an.       //\n"
    "////////////////////////////////////////////////////////////////////////////////////////////////////\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////////////////////////////////////////\n"
    "//  class = x //\n"
    "/////////////////////////////////////////////////////////////////////////////////////////////\n"
    "var Person = function(name) {\n"
    "  this.name = name;\n"
    "  this.say = function () {\n"
    "    return 'I am ' + this.name;\n"
    "  };\n"
    "};\n"
    "Person.prototype.say2 = function() {};\n"
    "Person.prototype.say3 = 2;\n"
    "\n";



    js = [NSString stringWithFormat:@"%@%@", js, self.jsOLClassesOutput];




    bool success = [js writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    if (success)
        NSLog(@"Writing JS-file (collectedClasses.js)... succeeded.");
    else
        NSLog(@"Writing JS-file (collectedClasses.js)... failed.");  
}




- (void) jumpToEndOfTextView
{
    // Move NSTextView to the end
    NSRange range;
    range = NSMakeRange ([[globalAccessToTextView string] length], 0);
    [globalAccessToTextView scrollRangeToVisible: range];
}


- (void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSString *errorString = [NSString stringWithFormat:@"Error code %i", [parseError code]];
    NSLog([NSString stringWithFormat:@"Error parsing XML: %@", errorString]);



    if ([errorString hasSuffix:@"512"])
    {
        NSLog(@"Parsing aborted programmatically.");
    }

    if ([errorString hasSuffix:@"76"])
    {
        NSLog(@"z. B. schließendes Tag gefunden ohne korrespondierendes öffnendes Tag.");
    }

    if ([errorString hasSuffix:@"5"])
    {
        NSLog(@"XML-Dokument unvollständig geladen bzw Datei nicht vorhanden bzw kein vollständiges XML-Tag enthalten bzw. malformed XML (z. B. kein umschließendes Tag um alles).");
    }

    if ([errorString hasSuffix:@"38"])
    {
        NSLog(@"Kleiner-Zeichen (<) in Attribut (NSXMLParserLessThanSymbolInAttributeError) ");
    }

    if ([errorString hasSuffix:@"68"])
    {
        NSLog(@"Z. B. '/ />' am Elementende oder Ampersand (&) im Attribut (NSXMLParserNAMERequiredError) ");
    }

    NSLog(@"\nI had no success parsing the document. I'm sorry.");

    self.errorParsing=YES;
    [self jumpToEndOfTextView];

    [self instableXML:@"ERROR: XML-Parser hat einen Error geworfen."];
}


/********** Dirty Trick um NSLog umzuleiten *********/
// Wieder zurückdefinieren:
#undef NSLog
/********** Dirty Trick um NSLog umzuleiten *********/

@end
