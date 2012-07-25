//
//  xmlParser.m
//  OpenLaszlo2Canvas
//
//
//
// iwie gibt es noch ein Problem mit den pointer-events (globalhelp verdeckt Foren-Button)
//
//
// 'name' Attribute werden global gemacht, aber zumindestens bei input-Feldern
// überschreiben Sie sich dann gegenseitig. z. B. 'Gewerbesteuerpflicht', 'cbType' oder
// 'regelmaessig', 'begruendet', 'complete'
// -> Ja, ist ja auch Unsinn. Aber erst toggleVisibility auf constraints umstellen, dann kann ich
// die Zeile die 'name'-Attribute global macht, wohl rausnehmen!
// -> Aber Vorsicht!! Wenn die View auf erster Ebene ist, muss sie weiterhin global bleiben!
// http://www.openlaszlo.org/lps4.2/docs/developers/program-development.html Dort 2.2.3
//
//
//
// Eher unwichtig:
// - width/height muss nicht mehr initial auf 'auto' gesetzt werden, seitdem der ganze JS-Code
// in '$(window).load(function()' steckt,
//
//
//
// Als Optionen mit anbieten
// - skip build-in-splash-Tag
// - keep comments
// - auswahl ob $swf8 usw. true oder false
// - Schalter für 'Writing Log-File to File-System' (search the 'x' string)
// - Anzahl ausgewertete Elemente anzeigen (self.elementeZaehler)
//
//
//
//  Created by Matthias Blanquett on 13.04.12.
//  Copyright (c) 2012 Buhl. All rights reserved.
//

BOOL debugmode = YES;
BOOL positionAbsolute = NO; // Yes ist 100% gemäß OL-Code-Inspektion richtig, aber leider ist der
                             // Code noch an zu vielen Stellen auf position: relative ausgerichtet.


BOOL kompiliereSpeziellFuerTaxango = YES;



BOOL werteItemUndItemsAlsArrayAus = YES; // Muss ich noch in eine XML-Struktur überführen



#import "xmlParser.h"

#import "globalVars.h"

#import "ausgabeText.h"

// Private Variablen
@interface xmlParser()

// Als Property eingeführt, damit ich zwischendurch auch Zugriff
// auf den Parser habe und diesen abbrechen kann.
@property (strong, nonatomic) NSXMLParser *parser;

@property (nonatomic) BOOL isRecursiveCall;

// Falls Resourcen relativ gesetzt sind, in tiefer verschachtelten library-files.
// dann muss ich an den originären Pfad kommen, um den Pfad der Bilder
// js-intern richtig setzen zu können.
@property (strong, nonatomic) NSString *pathToFile_basedir;

@property (strong, nonatomic) NSMutableString *log;

@property (strong, nonatomic) NSURL * pathToFile;

@property (strong, nonatomic) NSMutableArray *items;

@property (strong, nonatomic) NSMutableDictionary *bookInProgress;
@property (strong, nonatomic) NSString *keyInProgress;
@property (strong, nonatomic) NSMutableString *textInProgress;

@property (strong, nonatomic) NSMutableArray *enclosingElements;
@property (strong, nonatomic) NSMutableArray *enclosingElementsIds;

@property (strong, nonatomic) NSMutableString *output;
@property (strong, nonatomic) NSMutableString *jsOutput;
@property (strong, nonatomic) NSMutableString *jsOLClassesOutput; // Gefundene <class> werden hier gesammelt
@property (strong, nonatomic) NSMutableString *jQueryOutput0;
@property (strong, nonatomic) NSMutableString *jQueryOutput;
@property (strong, nonatomic) NSMutableString *jsHeadOutput;
@property (strong, nonatomic) NSMutableString *jsHead2Output;   // die mit resource gesammelten globalen vars
                                                                // (+ globale Funktionen + globales gefundenes JS)
@property (strong, nonatomic) NSMutableString *jsComputedValuesOutput; // kommt DIREKT nach dem DOM
@property (strong, nonatomic) NSMutableString *jsConstraintValuesOutput; // kommt ebenfalls direkt nach dem DOM


@property (strong, nonatomic) NSMutableString *cssOutput; // CSS-Ausgaben, die gesammelt werden, derzeit @Font-Face

@property (strong, nonatomic) NSMutableString *externalJSFilesOutput; // per <script src=''> angegebene externe Skripte

@property (strong, nonatomic) NSMutableString *collectedContentOfClass;

@property (nonatomic) BOOL errorParsing;

@property (nonatomic) NSInteger baselistitemCounter;
@property (nonatomic) NSInteger idZaehler;
@property (nonatomic) NSInteger elementeZaehler;
@property (strong, nonatomic) NSString* element_merker; // Für <class>, um erkennen zu können, ob sich das Tag sich direkt wieder schließt: <tag />
// NSUInteger, damit ich es mit [NSArray count]; verrechnen kann, was ebenfalls NSUInteger zurückgibt
@property (nonatomic) NSUInteger verschachtelungstiefe;

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

// jQuery UI braucht bei jedem auftauchen eines neuen Tabsheets-elements den Namen des
// aktuellen Tabsheets, um dieses per add einfügen zu können.
// Außerdem wird, wenn diese Variable gesetzt wurde, und somit im Quellcode ein TabSheetContainer
// auftaucht, eine entsprechende Anpassung der dafür von jQueri UI benutzten Klassen vorgenommen
@property (strong, nonatomic) NSString *lastUsedTabSheetContainerID;

@property (strong, nonatomic) NSMutableArray *rememberedID4closingSelfDefinedClass;
@property (strong, nonatomic) NSString *defaultplacement;


// "method" muss das name-attribut nach didEndElement rüberretten,
// damit ich es auch für canvas setzen kann.
@property (strong, nonatomic) NSString *lastUsedNameAttributeOfMethod;

// "class" muss das name-attribut in den rekursiven Aufruf <evaluateclass> rüberretten,
// damit ich dort die gefundenen Attribute richtig zuweisen kann.
@property (strong, nonatomic) NSString *lastUsedNameAttributeOfClass;

// Damit auch 'face' es nutzen kann
@property (strong, nonatomic) NSString *lastUsedNameAttributeOfFont;


// Falls eine Methode da dran gebunden wird, brauche ich den Namen (da selten id)
// oder oft auch gar kein Name (Beispiel 11.4) -> Dann tempName
@property (strong, nonatomic) NSString *lastUsedNameAttributeOfDataPointer;

// Damit ich auch intern auf die Inhalte der Variablen zugreifen kann
@property (strong, nonatomic) NSMutableDictionary *allJSGlobalVars;

// Damit ich alle Images preloaden kann
@property (strong, nonatomic) NSMutableArray *allImgPaths;

// Gefundene <class>-Tags, die definiert wurden
@property (strong, nonatomic) NSMutableDictionary *allFoundClasses;


// Zum internen testen, ob wir alle Attribute erfasst haben
@property (nonatomic) int attributeCount;

// Weil der Aufruf von [parser abortParsing] rekurisv nicht klappt, muss ich es mir so merken
@property (strong, nonatomic) NSString* issueWithRecursiveFileNotFound;

// Bei Switch/When lese ich nur einen Zweig (den ersten) aus, um Dopplungen zu vermeiden
@property (nonatomic) BOOL weAreInTheTagSwitchAndNotInTheFirstWhen;

// Wenn wir gerade Text einsammeln, dann dürfen auf den Text bezogene HTML-Tags nicht ausgewertet werden
@property (nonatomic) BOOL weAreCollectingTextAndThereMayBeHTMLTags;

// Für dataset ohne Attribut 'src' muss ich die nachfolgenden tags einzeln aufsammeln
@property (nonatomic) BOOL weAreInDatasetAndNeedToCollectTheFollowingTags;

// Wenn ich in RollUpDown bin, ohne einen umgebenden RollUpDownContainer,
// muss ich den Abstand leider gesondert regeln.
@property (nonatomic) BOOL weAreInRollUpDownWithoutSurroundingRUDContainer;


@property (nonatomic) BOOL weAreCollectingTheCompleteContentInClass;
//auch ein 2. und 3., sonst gibt es Interferenzen wenn ein zu skippendes Element in einem anderen zu skippenden liegt

@property (nonatomic) BOOL weAreSkippingTheCompleteContentInThisElement;


// Wenn wir <class> auswerten dann haben wir generelle Klassen und dürfen keine
// festen IDs vergeben!
@property (nonatomic) BOOL ignoreAddingIDsBecauseWeAreInClass;

// oninit-Code in einem Handler wird direkt ausgeführt (load-Handler ist unpassend)
@property (nonatomic) BOOL onInitInHandler;
// 'reference'-Variable in einem Handler muss an das korrekte Element gebunden werden
@property (nonatomic) BOOL referenceAttributeInHandler;
// 'method'-Variable in einem Handler
@property (strong, nonatomic) NSString *methodAttributeInHandler;

@end




@implementation xmlParser
// public
@synthesize lastUsedDataset = _lastUsedDataset;


// private
@synthesize parser = _parser;

@synthesize isRecursiveCall = _isRecursiveCall, pathToFile_basedir = _pathToFile_basedir;

@synthesize log = _log;

@synthesize pathToFile = _pathToFile;

@synthesize items = _items,
bookInProgress = _bookInProgress, keyInProgress = _keyInProgress, textInProgress = _textInProgress;

@synthesize enclosingElements = _enclosingElements, enclosingElementsIds = _enclosingElementsIds;

@synthesize output = _output, jsOutput = _jsOutput, jsOLClassesOutput = _jsOLClassesOutput, jQueryOutput0 = _jQueryOutput0, jQueryOutput = _jQueryOutput, jsHeadOutput = _jsHeadOutput, jsHead2Output = _jsHead2Output, jsComputedValuesOutput = _jsComputedValuesOutput, jsConstraintValuesOutput = _jsConstraintValuesOutput, cssOutput = _cssOutput, externalJSFilesOutput = _externalJSFilesOutput, collectedContentOfClass = _collectedContentOfClass;

@synthesize errorParsing = _errorParsing, verschachtelungstiefe = _verschachtelungstiefe, rollUpDownVerschachtelungstiefe = _rollUpDownVerschachtelungstiefe;

@synthesize baselistitemCounter = _baselistitemCounter, idZaehler = _idZaehler, elementeZaehler = _elementeZaehler, element_merker = _element_merker;

@synthesize simplelayout_y = _simplelayout_y, simplelayout_y_spacing = _simplelayout_y_spacing;
@synthesize firstElementOfSimpleLayout_y = _firstElementOfSimpleLayout_y, simplelayout_y_tiefe = _simplelayout_y_tiefe;

@synthesize simplelayout_x = _simplelayout_x, simplelayout_x_spacing = _simplelayout_x_spacing;
@synthesize firstElementOfSimpleLayout_x = _firstElementOfSimpleLayout_x, simplelayout_x_tiefe = _simplelayout_x_tiefe;

@synthesize zuletztGesetzteID = _zuletztGesetzteID;

@synthesize last_resource_name_for_frametag = _last_resource_name_for_frametag, collectedFrameResources = _collectedFrameResources;

@synthesize datasetItemsCounter = _datasetItemsCounter, rollupDownElementeCounter = _rollupDownElementeCounter;

@synthesize animDuration = _animDuration, lastUsedTabSheetContainerID = _lastUsedTabSheetContainerID, rememberedID4closingSelfDefinedClass = _rememberedID4closingSelfDefinedClass, defaultplacement = _defaultplacement, lastUsedNameAttributeOfMethod = _lastUsedNameAttributeOfMethod, lastUsedNameAttributeOfClass = _lastUsedNameAttributeOfClass, lastUsedNameAttributeOfFont = _lastUsedNameAttributeOfFont, lastUsedNameAttributeOfDataPointer = _lastUsedNameAttributeOfDataPointer;

@synthesize allJSGlobalVars = _allJSGlobalVars, allImgPaths = _allImgPaths;

@synthesize allFoundClasses = _allFoundClasses;

@synthesize attributeCount = _attributeCount;

@synthesize issueWithRecursiveFileNotFound = _issueWithRecursiveFileNotFound;

@synthesize weAreInTheTagSwitchAndNotInTheFirstWhen = _weAreInTheTagSwitchAndNotInTheFirstWhen;
@synthesize weAreCollectingTextAndThereMayBeHTMLTags = _weAreCollectingTextAndThereMayBeHTMLTags;
@synthesize weAreInDatasetAndNeedToCollectTheFollowingTags = _weAreInDatasetAndNeedToCollectTheFollowingTags;
@synthesize weAreInRollUpDownWithoutSurroundingRUDContainer = _weAreInRollUpDownWithoutSurroundingRUDContainer;
@synthesize weAreCollectingTheCompleteContentInClass = _weAreCollectingTheCompleteContentInClass;
@synthesize weAreSkippingTheCompleteContentInThisElement = _weAreSkippingTheCompleteContentInThisElement;

@synthesize ignoreAddingIDsBecauseWeAreInClass = _ignoreAddingIDsBecauseWeAreInClass, onInitInHandler = _onInitInHandler, referenceAttributeInHandler = _referenceAttributeInHandler, methodAttributeInHandler = _methodAttributeInHandler;




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
        [[self log] appendFormat:s,@""];
    }

    va_end(arguments);
     */

    if ([self log])
    {
        [[self log] appendString:s];
        [[self log] appendString:@"\n"];

        // Diese Zeile nur beim debuggen drin, damit ich nicht scrollen muss
        // (verlangsamt sonst extrem den Converter-Lauf)
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


#define ID_REPLACE_STRING @"@!JS,PLZ!REPLACE!ME!@"

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

        self.pathToFile_basedir = @"";

        self.items = [[NSMutableArray alloc] init];
        self.textInProgress = [[NSMutableString alloc] initWithString:@""];

        self.enclosingElements = [[NSMutableArray alloc] init];
        self.enclosingElementsIds = [[NSMutableArray alloc] init];

        self.output = [[NSMutableString alloc] initWithString:@""];
        self.jsOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsOLClassesOutput = [[NSMutableString alloc] initWithString:@""];
        self.jQueryOutput0 = [[NSMutableString alloc] initWithString:@""];
        self.jQueryOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsHeadOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsHead2Output = [[NSMutableString alloc] initWithString:@""];

        self.jsComputedValuesOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsConstraintValuesOutput = [[NSMutableString alloc] initWithString:@""];

        self.cssOutput = [[NSMutableString alloc] initWithString:@""];
        self.externalJSFilesOutput = [[NSMutableString alloc] initWithString:@""];
        self.collectedContentOfClass = [[NSMutableString alloc] initWithString:@""];

        self.errorParsing = NO;
        self.verschachtelungstiefe = 0;
        self.rollUpDownVerschachtelungstiefe = 0;
        self.baselistitemCounter = 0;
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

        self.zuletztGesetzteID = ID_REPLACE_STRING;

        self.last_resource_name_for_frametag = [[NSString alloc] initWithString:@""];
        self.collectedFrameResources = [[NSMutableArray alloc] init];

        self.animDuration = @"slow";
        self.lastUsedTabSheetContainerID = @"";
        self.rememberedID4closingSelfDefinedClass = [[NSMutableArray alloc] init];
        self.defaultplacement = @"";
        self.lastUsedDataset = @"";
        self.lastUsedNameAttributeOfMethod = @"";
        self.lastUsedNameAttributeOfClass = @"";
        self.lastUsedNameAttributeOfFont = @"";
        self.lastUsedNameAttributeOfDataPointer = @"";

        self.datasetItemsCounter = 0;
        self.rollupDownElementeCounter = [[NSMutableArray alloc] init];

        self.issueWithRecursiveFileNotFound = @"";

        self.weAreInTheTagSwitchAndNotInTheFirstWhen = NO;
        self.weAreCollectingTextAndThereMayBeHTMLTags = NO;
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
        self.weAreInRollUpDownWithoutSurroundingRUDContainer = NO;
        self.weAreCollectingTheCompleteContentInClass = NO;
        self.weAreSkippingTheCompleteContentInThisElement = NO;
        self.ignoreAddingIDsBecauseWeAreInClass = NO;
        self.onInitInHandler = NO;
        self.referenceAttributeInHandler = NO;
        self.methodAttributeInHandler = @"";

        self.allJSGlobalVars = [[NSMutableDictionary alloc] initWithCapacity:200];
        self.allFoundClasses = [[NSMutableDictionary alloc] initWithCapacity:200];

        self.allImgPaths = [[NSMutableArray alloc] init];
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
        if ([s isEqualToString:@""])
        {
            // Create a parser from file
            self.parser = [[NSXMLParser alloc] initWithContentsOfURL:self.pathToFile];
        }
        else
        {
            // Create a parser from string
            NSData* d = [s dataUsingEncoding:NSUTF8StringEncoding];
            self.parser = [[NSXMLParser alloc] initWithData:d];
        }

        [self.parser setDelegate:self];

        // You may need to turn some of these on depending on the type of XML file you are parsing
        /*
         [parser setShouldProcessNamespaces:NO];
         [parser setShouldReportNamespacePrefixes:NO];
         [parser setShouldResolveExternalEntities:NO];
         */

        // Do the parse
        [self.parser parse];

        // Zur Sicherheit mache ich von allem ne Copy.
        // Nicht, dass es beim Verlassen der Rekursion zerstört wird
        NSArray *r = [NSArray arrayWithObjects:[self.output copy],[self.jsOutput copy],[self.jsOLClassesOutput copy],[self.jQueryOutput0 copy],[self.jQueryOutput copy],[self.jsHeadOutput copy],[self.jsHead2Output copy],[self.cssOutput copy],[self.externalJSFilesOutput copy],[self.allJSGlobalVars copy],[self.allFoundClasses copy],[[NSNumber numberWithInt:self.idZaehler] copy],[self.defaultplacement copy],[self.jsComputedValuesOutput copy],[self.jsConstraintValuesOutput copy],[self.allImgPaths copy], nil];
        return r;
    }
}


-(NSArray*) start
{
    return [self startWithString:@""];
}



- (void) rueckeMitLeerzeichenEin:(NSInteger)n
{
    n--;
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




-(NSMutableArray *) getTheDependingVarsOfTheConstraint:(NSString*)s
{
    NSError *error = NULL;


    NSMutableArray *vars = [[NSMutableArray alloc] init];

    s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
    s = [self removeOccurrencesofBracketsIn:s];


    // Remove everything between ' (including the ')
    NSString* pattern = @"'[^']*'";
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSUInteger numberOfMatches = [regexp numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])];
    if (numberOfMatches > 0)
        s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:@""];

    // Remove everything between " (including the ")
    pattern = @"\"[^\"]*\"";
    regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    numberOfMatches = [regexp numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])];
    if (numberOfMatches > 0)
        s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:@""];


    // Okay, falls es ein ? : Ausdruck ist, remove nun alles nach dem ? (inklusive dem ?)
    s = [[s componentsSeparatedByString: @"?"] objectAtIndex:0];


    // Remove leading and ending Whitespaces and NewlineCharacters
    s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];



    // so get all var-names, that are left
    // Auch per Punkt verkettete Vars erlauben ( _ ist automatisch mit drin bei \W )
    pattern = @"[^\\W\\d](\\w|[.]{1,2}(?=\\w))*";

    regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];

    numberOfMatches = [regexp numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])];

    if (numberOfMatches > 0)
    {
        NSArray *matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];

        for (NSTextCheckingResult *match in matches)
        {
            NSRange matchRange = [match range];
            // NSRange varNameRange = [match rangeAtIndex:1];
            // NSRange defaultValueRange = [match rangeAtIndex:2];

            NSString *varName = [s substringWithRange:matchRange];

            // Dann noch eventuelle spezielle Wörter austauschen
            varName = [self modifySomeExpressionsInJSCode:varName];

            // Falls ganz vorne jetzt getTheParent() steht, dann muss ich unser aktuelles Element davorsetzen
            // Weil jetzt nochmal extra mit with () {} zu arbeiten ist wohl nicht nötig, da wir ja auf Ebene der
            // einzelnen Variable sind und individuell reagieren können
            if ([varName hasPrefix:@"getTheParent("])
                varName = [NSString stringWithFormat:@"%@.%@",self.zuletztGesetzteID,varName];

            [vars addObject:varName];
        }
    }

    return vars;
}




// Alle Aufrufe hier drin leitern weiter zu setAttribute_()
// setAttribute_() wird zur absolutern PRIORITY-Function. Über die läuft alles!
- (void) setTheValue:(NSString *)s ofAttribute:(NSString*)attr
{
    NSLog(@"Setting the attribute with jQuery + we watch it, if necessary!");

    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

    [o appendFormat:@"\n  // Setting the Attribute '%@' of '%@' with the value '%@'\n",attr,self.zuletztGesetzteID,s];

    BOOL nochVorDOMAusfuehren = NO;
    if ([s hasPrefix:@"$immediately{"])
    {
        nochVorDOMAusfuehren = YES;
        s = [s substringFromIndex:12];

        // Damit er unten richtig reingeht
        s = [NSString stringWithFormat:@"$%@",s];
    }

    BOOL nichtWatchen = NO;
    if ([s hasPrefix:@"$once{"])
    {
        nichtWatchen = YES;
        s = [s substringFromIndex:5];

        // Damit er unten richtig reingeht
        s = [NSString stringWithFormat:@"$%@",s];
    }

    if ([s hasPrefix:@"$always{"])
    {
        s = [s substringFromIndex:7];

        // Damit er unten richtig reingeht
        s = [NSString stringWithFormat:@"$%@",s];
    }



    // Alle Variablen ermitteln, die die zu setzende Variable beeinflussen können...
    NSMutableArray *vars = [self getTheDependingVarsOfTheConstraint:s];



    BOOL constraintValue = NO;
    BOOL weNeedQuotes = YES;
    BOOL thatWasAPath = NO;

    if ([s hasPrefix:@"$path{"])
    {
        thatWasAPath = YES;

        // Ein relativer Pfad zum vorher gesetzen XPath Ich nehme Bezug zum letzten lastDP und dem dort gesetzten Pfad.
        s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
        // Die Variable 'lastDP' ist bekannt, da die Ausgabe hier in 'jsComputedValuesOutput' erfolgt.
        // Genau da (und kurz vohrer) erfolgt auch das setzen von lastDP
        [o appendFormat:@"  setRelativeDataPathIn(%@,%@,lastDP,'%@');\n",self.zuletztGesetzteID,s,attr];
    }
    else if ([s hasPrefix:@"$"])
    {
        constraintValue = YES;


        // ...jetzt erst s computable machen...
        s = [self makeTheComputedValueComputable:s];


        if (nochVorDOMAusfuehren)
        {
            // Dann muss ich undefined-Werte für alle gefunden Vars in den Code injecten.
            // Denn eigentlich ist der DOM und alle Vars noch gar nicht initialisiert
            // Den Code aber WIRKLICH vor dem DOM auszuführen würde jetzt zu weit führen
            for (id object in vars)
            {
                // auf jedenfall mit vorangestelltem var, damit nur lokal!
                NSString *sToInsert = [NSString stringWithFormat:@" var %@ = undefined;", object];
                NSMutableString *sToInject = [NSMutableString stringWithString:s];
                [sToInject insertString:sToInsert atIndex:13];
                s = [NSString stringWithString:sToInject];
            }
        }

        weNeedQuotes = NO;
    }

    if (!thatWasAPath)
    {
        // setAttribute_() aufrufen (gilt für alle Arten von Attributen - Keine Fallunterscheidung)
        if (weNeedQuotes)
            [o appendFormat:@"  %@.setAttribute_('%@','%@');\n",self.zuletztGesetzteID,attr,s];
        else
            [o appendFormat:@"  %@.setAttribute_('%@',%@);\n",self.zuletztGesetzteID,attr,s];
    }


    // Wenn die $once-Angabe erfolgt, ist es gar kein constraint
    if (constraintValue && !nichtWatchen && !nochVorDOMAusfuehren)
    {
        [o appendString:@"  // Zusätzlich bei change aktualisieren bzw. auf ein event horchen, da constraint-value\n"];
        [o appendFormat:@"  // Der zu setzende Wert ist abhängig von %d woanders gesetzten Variable(n)\n",[vars count]];

        // '__strong', damit ich object modifizieren kann
        for (id __strong object in vars)
        {
            // Okay, folgendes:
            // Wenn wir ein Objekt sind dann achten wir auf das onchange-Event
            // Sind wir aber eine Variable, dann müssen wir watchen

            // Falls wir mit 'this.' starten muss ich this durch die aktuelle ID ersetzen.
            if ([object hasPrefix:@"this."])
            {
                object = [object substringFromIndex:4];
                object = [NSString stringWithFormat:@"%@%@",self.zuletztGesetzteID,object];
            }
            // Falls wir mit 'parent.' oder 'immediateparent' starten, muss ich die aktuelle ID
            // davor setzen.
            if ([object hasPrefix:@"parent."] || [object hasPrefix:@"immediateparent."])
            {
                object = [NSString stringWithFormat:@"%@.%@",self.zuletztGesetzteID,object];
            }


            [o appendFormat:@"  if (typeof %@ === 'object')\n",object];

            [o appendFormat:@"    $(%@).on('change', function() { %@.setAttribute_('%@',%@); } );\n",object,self.zuletztGesetzteID,attr,s];




            // resize sendet doch bei drag ein event, hmmm. Deswegen das hier großer Unsinn:
            /*
            if ([object  hasSuffix:@"myWidth_NO_BrichtZuViel"] || [object hasSuffix:@"myHeight_NO_BrichtZuViel"])
            {
                [o appendString:@"  else\n"];

                // Ganz hinten das myWidth oder das myHeight muss dann wegfallen
                NSArray *array = [object componentsSeparatedByString: @"."];
                object = @"";
                for (int i=0;i<[array count]-1;i++)
                {
                    if ([object length] > 0)
                        object = [NSString stringWithFormat:@"%@.%@", object, [array objectAtIndex:i]];
                    else // dann erster Durchlauf und deswegen ohne altes s und ohne Punkt
                        object = [NSString stringWithFormat:@"%@", [array objectAtIndex:i]];
                }
                object = [object stringByReplacingOccurrencesOfString:@"getTheParent(true)" withString:@"getTheParent()"];
                s = [s stringByReplacingOccurrencesOfString:@"getTheParent(true)" withString:@"getTheParent()"];
                [o appendFormat:@"    $(%@).resize(function() { %@.setAttribute_('%@',%@); } );\n",object,self.zuletztGesetzteID,attr,s];
            }
            else
             */

            //[o appendFormat:@"    window.watch('%@', function() { %@.setAttribute_('%@',%@); } );\n",object,self.zuletztGesetzteID,attr,s];
            // Das mit dem watchen klappt nicht wirklich...
            // Neuer Code, indem ich auf die von setAttribute_ abgeschickten Events horche:

            // Erstmal Property von Objekt isolieren
            NSArray *tempArray = [object componentsSeparatedByString: @"."];

            // wenn es gar keinen . gibt, ist es wohl ein vergessenes this vor der Property z.B.
            // Wir brauchen also mindestens ein Objekt und eine Property
            if ([tempArray count] > 1)
            {
                NSString *theObject = [tempArray objectAtIndex:0];
                NSString *theProperty = [tempArray objectAtIndex:[tempArray count]-1];

                // Falls es mehr als 2 Element im Array gibt, alle mittleren Elemente
                // dem objekt hinzufügen.
                if ([tempArray count] > 2)
                {
                    for (int i=1;i<[tempArray count]-1;i++)
                    {
                        theObject = [NSString stringWithFormat:@"%@.%@",theObject,[tempArray objectAtIndex:i]];
                    }
                }


                // setAttribute_ verschickt events nur an 'onheight' oder an 'onwidth'
                if ([theProperty isEqualToString:@"myWidth"])
                    theProperty = @"width";
                if ([theProperty isEqualToString:@"myHeight"])
                    theProperty = @"height";

                // Wenn wir selber wir sind, dann nicht. Darauf brauche ich nicht reagieren
                // Das dient dann wohl nur der Berechnung. z. B. "irgendwas - this.height".
                // Nein, dann bricht Beispiel 7.5. Auch auf this müssen wir achten
                //if (![theObject isEqualToString:@"this"])
                // Habe weiter oben this durch das aktuelle Element ersetzt, dann ist das 'this auch
                // schon in der if-abfrage korrigiert (sonst würde 'this' auf 'window' verweisen).
                [o appendString:@"  else\n"];
                [o appendFormat:@"    $(%@).on('on%@', function() { %@.setAttribute_('%@',%@); } );\n",theObject,theProperty,self.zuletztGesetzteID,attr,s];
            }
        }
        
    }

    if (constraintValue)
    {
        [self.jsConstraintValuesOutput appendString:o];
    }
    else
    {
        [self.jsComputedValuesOutput appendString:o];
    }
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

    if ([attributeDict valueForKey:@"multiline"])
    {
        self.attributeCount++;

        // False ist wohl der in '.div_text' definierte CSS-Wert 'white-space:nowrap;'
        // Nur bei true muss ich es abändern auf 'white-space:normal;'
        if ([[attributeDict valueForKey:@"multiline"] isEqualToString:@"true"])
        {
            NSLog(@"Setting the attribute 'multiline:true' as CSS 'white-space:normal'.");
            [style appendString:@"white-space:normal;"];
        }
    }
    
    if ([attributeDict valueForKey:@"bgcolor"])
    {
        self.attributeCount++;

        //NSLog(@"Setting the attribute 'bgcolor' as CSS 'background-color'.");
        //[style appendString:@"background-color:"];
        //[style appendString:[attributeDict valueForKey:@"bgcolor"]];
        //[style appendString:@";"];

        // Lieber so, weil nicht immer sind die übergebenen Farbwerte kompatibles CSS
        // Und setAttribute_ biegt alle Farbwerte vorher richtig um
        [self setTheValue:[attributeDict valueForKey:@"bgcolor"] ofAttribute:@"bgcolor"];
    }
    
    if ([attributeDict valueForKey:@"opacity"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'opacity' as CSS 'opacity'.");
        [style appendString:@"opacity:"];
        [style appendString:[attributeDict valueForKey:@"opacity"]];
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"fgcolor"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'fgcolor' as CSS 'color'.");

        if ([[attributeDict valueForKey:@"fgcolor"] hasPrefix:@"$"])
        {
            [self setTheValue:[attributeDict valueForKey:@"fgcolor"] ofAttribute:@"color"];
        }
        else
        {
            [style appendString:@"color:"];
            [style appendString:[attributeDict valueForKey:@"fgcolor"]];
            [style appendString:@";"];
        }
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
            [self.jQueryOutput appendString:@"\n  // 'valign=middle' wurde als Attribut gefunden: Richte das Element entsprechend mittig (vertikal) aus\n"];

            // [self.jQueryOutput appendFormat:@"  $('#%@').css('top',toInt((parseInt($('#%@').parent().css('height'))-parseInt($('#%@').css('height')))/3));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
            // So wohl korrekter:
            [self.jQueryOutput appendFormat:@"  $('#%@').css('top',toIntFloor((parseInt($('#%@').parent().css('height'))-parseInt($('#%@').outerHeight()))/2));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
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
            [self.jQueryOutput appendString:@"\n  // 'valign=bottom' wurde als Attribut gefunden: Richte das Element entsprechend am Boden aus\n"];
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

    // speichern, falls height schon gesetz wurde (für Attribut resource)
    BOOL heightGesetzt = NO;
    if ([attributeDict valueForKey:@"height"])
    {
        self.attributeCount++;

        NSLog(@"Setting the attribute 'height' as CSS 'height'.");

        NSString *s = [attributeDict valueForKey:@"height"];

        // Bei text/inputtext bei px-Werten den margin-Wert abziehen
        if ([s rangeOfString:@"%"].location == NSNotFound)
        {
            NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-1];
            
            if ([elemTyp isEqualToString:@"text"] || [elemTyp isEqualToString:@"inputtext"])
            {
                int temp = [s intValue];
                // Nur 2 px abziehen mal. Sonst bricht Beispiel 9.4
                temp -= 2;
                s = [NSString stringWithFormat:@"%d",temp];
            }
        }

        // Diese Sonderbehandlung ist wohl hinfällig:
        // Wir beobachten sonst ja nicht die Änderungen! ist ja ein Constraint! (bzw. inherit reagiert zu langsam)
        //if ([s rangeOfString:@"${parent.height}"].location != NSNotFound ||
        //    [s rangeOfString:@"${immediateparent.height}"].location != NSNotFound)
        //{
        //    [style appendString:@"height:inherit;"];
        //}
        //else
        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:s ofAttribute:@"height"];
        }
        else
        {
            [style appendString:@"height:"];
            [style appendString:s];
            if ([s rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        heightGesetzt = YES;
    }

    if ([attributeDict valueForKey:@"boxheight"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'boxheight' as CSS 'height'.");

        NSString *s = [attributeDict valueForKey:@"boxheight"];

        //if ([s rangeOfString:@"${parent.height}"].location != NSNotFound)
        //{
        //    [style appendString:@"height:inherit;"];
        //}
        //else
        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:s ofAttribute:@"height"];
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

    // speichern, falls width schon gesetzt wurde (für Attribut resource)
    BOOL widthGesetzt = NO;
    if ([attributeDict valueForKey:@"width"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'width' as CSS 'width'.");

        NSString *s = [attributeDict valueForKey:@"width"];

        // Bei text/inputtext bei px-Werten den margin-Wert abziehen
        if ([s rangeOfString:@"%"].location == NSNotFound)
        {
            NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-1];

            if ([elemTyp isEqualToString:@"text"] || [elemTyp isEqualToString:@"inputtext"])
            {
                int temp = [s intValue];
                // Nur 2 px abziehen mal. Sonst bricht Beispiel 9.4
                temp -= 2;
                s = [NSString stringWithFormat:@"%d",temp];
            }
        }

        // Diese Sonderbehandlung ist wohl hinfällig:
        // Wir beobachten sonst ja nicht die Änderungen! ist ja ein Constraint! (bzw. inherit reagiert zu langsam)
        //if ([s rangeOfString:@"${parent.width}"].location != NSNotFound ||
        //    [s rangeOfString:@"${immediateparent.width}"].location != NSNotFound)
        //{
        //    [style appendString:@"width:inherit;"];
        //}
        //else
        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:[attributeDict valueForKey:@"width"] ofAttribute:@"width"];
        }
        else
        {
            [style appendString:@"width:"];
            [style appendString:s];
            if ([s rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        widthGesetzt = YES;
    }

    if ([attributeDict valueForKey:@"controlwidth"]) // ToDo - Seems to be a self defined attribute of BDScombobox / BDSeditdate
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'controlwidth' as CSS 'width'.");

        NSString *s = [attributeDict valueForKey:@"controlwidth"];

        [style appendString:@"width:"];

        //if ([s rangeOfString:@"${parent.width}"].location != NSNotFound)
        //{
        //    [style appendString:@"inherit"];
        //}
        //else
        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:s ofAttribute:@"width"];
        }
        else
        {
            [style appendString:s];
            if ([s rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
        }
        [style appendString:@";"];
    }

    if ([attributeDict valueForKey:@"x"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'x' as CSS 'left'.");

        NSString *s = [attributeDict valueForKey:@"x"];

        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:s ofAttribute:@"x"];
        }
        else
        {
            [style appendString:@"left:"];
            [style appendString:s];
            if ([s rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        if (positionAbsolute == NO)
            [style appendString:@"float:none;position:absolute;"];
    }

    if ([attributeDict valueForKey:@"y"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'y' as CSS 'top'.");

        NSString *s = [attributeDict valueForKey:@"y"];

        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:s ofAttribute:@"y"];
        }
        else
        {
            [style appendString:@"top:"];
            [style appendString:s];
            if ([s rangeOfString:@"%"].location == NSNotFound)
                [style appendString:@"px"];
            [style appendString:@";"];
        }

        if (positionAbsolute == NO)
            [style appendString:@"float:none;position:absolute;"];
    }


    if ([attributeDict valueForKey:@"yoffset"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'yoffset' as CSS 'top' (adding a offset).");

        [self.jQueryOutput appendString:@"\n  // Adding a value to 'top', because I found the attribute 'yoffset'.\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').css('top','-=%@');\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"yoffset"]];
    }

    if ([attributeDict valueForKey:@"xoffset"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'xoffset' as CSS 'left' (adding a offset).");

        [self.jQueryOutput appendString:@"\n  // Adding a value to 'left', because I found the attribute 'xoffset'.\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').css('left','-=%@');\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"xoffset"]];
    }


    if ([attributeDict valueForKey:@"fontsize"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'fontsize' as CSS 'font-size'.");

        [style appendString:@"font-size:"];
        [style appendString:[attributeDict valueForKey:@"fontsize"]];
        [style appendString:@"px;"];


        if (![elemName isEqualToString:@"canvas"])
        {
            NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

            // Die Eigenschaft font-size überträgt sich auf alle Kinder und Enkel
            [s appendString:@"  // Alle Kinder und Enkel kriegen ebenfalls die font-size-Eigenschaft mit\n"];
            [s appendFormat:@"  $('#%@').find('.div_text').css('font-size','%@px');\n\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"fontsize"]];

            // Muss GANZ Am Anfang stehen, da die width-eigenschaft, die ausgelesen wird,
            // von der Schriftgröße abhängt. Diese muss aber vorher korrekt gesetzt werden!!
            // Oh man, das endlich herausgefunden zu haben!
            [self.jsOutput insertString:s atIndex:0];
        }
    }



    if ([attributeDict valueForKey:@"fontstyle"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'fontstyle' as CSS 'font-weight'.");
        
        [style appendString:@"font-weight:"];
        [style appendString:[attributeDict valueForKey:@"fontstyle"]];
        [style appendString:@";"];
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
            NSLog(@"Setting the attribute 'align=center' as offset for 'left'.");
            // Funktioniert leider nicht:
            //[style appendString:@"margin-left:auto; margin-right:auto;"];

            [self.jQueryOutput appendString:@"\n  // align wurde als Attribut gefunden: Richte das Element entsprechend mittig (horizontale Achse) aus"];
            [self.jQueryOutput appendFormat:@"\n  $('#%@').css('left',toIntFloor((parseInt($('#%@').parent().css('width'))-parseInt($('#%@').outerWidth()))/2));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        }


        if ([[attributeDict valueForKey:@"align"] isEqual:@"left"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'align=left', because this is the default-value.");
        }



        if ([[attributeDict valueForKey:@"align"] isEqual:@"right"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'align=right' as offset for 'left'.");

            [self.jQueryOutput appendString:@"\n  // align wurde als Attribut gefunden: Richte das Element entsprechend rechts (horizontale Achse) aus"];
            [self.jQueryOutput appendFormat:@"\n  $('#%@').css('left',toIntFloor((parseInt($('#%@').parent().width())-$('#%@').outerWidth())));\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        }


        if ([[attributeDict valueForKey:@"align"] hasPrefix:@"$"])
        {
            NSString *s = [self makeTheComputedValueComputable:[attributeDict valueForKey:@"align"]];

            self.attributeCount++;
            NSLog(@"Computed value, so accessing the setter of 'align'.");

            [self.jQueryOutput appendString:@"\n  // setting align by using the built-in JS-property"];
            [self.jQueryOutput appendFormat:@"\n  %@.align = %@;\n",self.zuletztGesetzteID,s];
        }
    }


    if ([attributeDict valueForKey:@"clip"])
    {
        if ([[attributeDict valueForKey:@"clip"] isEqual:@"false"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'clip' CSS 'overflow'.");

            [self.jQueryOutput appendString:@"\n  // clip='false', just in case, set overflow back to default."];
            [self.jQueryOutput appendFormat:@"\n  $('#%@').css('overflow','visible');\n",self.zuletztGesetzteID];
        }

        if ([[attributeDict valueForKey:@"clip"] isEqual:@"true"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'clip' as CSS 'clip' and CSS 'overflow'.");
            [self.jQueryOutput appendString:@"\n  // clip='true', so clipping to width and height."];
            //[self.jQueryOutput appendFormat:@"\n  $('#%@').css('clip','rect(0px, '+$('#%@').width()+'px, '+$('#%@').height()+'px, 0px)');",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
            // clip macht zu oft Ärger. Passt sich nicht an, wenn sich Höhe oder Breite ändert. Erstmal
            // ganz rausgenommem, weil es auch sehr gut nur mit der overflow-Angabe klappt. Falls clip doch
            // irgendwo unbedingt erforderlich ist, wäre eine Alternative width und height zu watchen.
            [self.jQueryOutput appendFormat:@"\n  $('#%@').css('overflow','hidden');\n",self.zuletztGesetzteID];
        }
    }





    if ([attributeDict valueForKey:@"stretches"])
    {
        self.attributeCount++;

        [self setTheValue:[attributeDict valueForKey:@"stretches"] ofAttribute:@"stretches"];
    }



    if ([attributeDict valueForKey:@"initstage"])
    {
        // Damit kann der Ladezeitpunkt von Elementen beeinflusst werden
        // Letzen Endes spielt nur initstage=defer eine Rolle, weil es dann GAR NICHT
        // geladen wird, sondern erst später nach Aufruf von 'completeInstantiation'


        if ([[attributeDict valueForKey:@"initstage"] isEqual:@"immediate"] ||
            [[attributeDict valueForKey:@"initstage"] isEqual:@"early"] ||
            [[attributeDict valueForKey:@"initstage"] isEqual:@"normal"] ||
            [[attributeDict valueForKey:@"initstage"] isEqual:@"late"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'initstage'.");
        }

        if ([[attributeDict valueForKey:@"initstage"] isEqual:@"defer"])
        {
            self.attributeCount++;

            NSLog(@"Attribute 'initstage=defer' so hiding the Element, because it shoudn't be loaded right now (trick).");

            [self.jQueryOutput appendString:@"\n  // 'initstage=defer' so hiding the Element, because it shoudn't be loaded right now (trick).\n"];
            //[self.jQueryOutput appendFormat:@"  $('#%@').hide();\n",self.zuletztGesetzteID];
            // Noch auskommentiert, zeigt dann noch ganze Tabs nicht an. To Check
        }
    }






    // Neuerding kann auch in 'source' der Pfad zu einer Datei enthalten sein, nicht nur in resource
    if ([attributeDict valueForKey:@"resource"] || [attributeDict valueForKey:@"source"])
    {
        // frame ermitteln, falls einer gesetzt wurde
        NSUInteger index = 0;
        if ([attributeDict valueForKey:@"frame"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'frame' as aray-index.");

            index = [[attributeDict valueForKey:@"frame"] intValue];

            // Weil frame ist nicht 0-indexiert, sondern 1-indexiert.
            index--;
        }



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


        if ([src hasPrefix:@"http:"] && ![src hasPrefix:@"http://"])
        {
            // Wenn ich Example 8.6 richtig verstehe, muss ich in diesem Fall das 'http:' entfernen
            // Es ist bei einer lokalen Datei lediglich  ein Hinweis darauf, dass es erst ab
            // run-time geladen werden darf.
            src = [src substringFromIndex:5];
        }



        self.attributeCount++;
        NSString *s = @"";


        //if ([src rangeOfString:@"classroot"].location != NSNotFound)
        if ([src hasPrefix:@"$"])
        {
            // Dann wurde es per <attribute> gesetzt -
            // Nur dafür speichere ich alle <attribute>'s intern mit...
            src = [self removeOccurrencesOfDollarAndCurlyBracketsIn:src];
            src = [src stringByReplacingOccurrencesOfString:@"classroot" withString:@""];
            src = [src stringByReplacingOccurrencesOfString:@"." withString:@""];
            if (![src isEqualToString:@"resource"])
            {
                // Hier greife ich das erste mal auf die intern gespeicherten Vars zu,
                // und gleich nochmal (Doppelt referenzierte Variable).
                src = [self.allJSGlobalVars valueForKey:src];
            }
        }

        // Dann erfolgt ein Zugriff auf die interne resource-Var, aber puh...
        // ... to think about. ToDo
        if ([src isEqualToString:@"resource"])
        {
            //[self instableXML:[self makeTheComputedValueComputable:@"${classroot.stateres}"]];
        }
        else
        {
            // Ich setze es per setAttribute_ auf JS-Ebene.
            // Geht wohl nur dann wenn ich DIESE CSS-Angaben noch vor alles andere setze, sonst
            // ist width und height nicht früh genug gesetzt und SA's verschieben sich!
            [self.jsOutput appendString:@"\n  // Setting 'resource'\n"];
            if ([src rangeOfString:@"."].location != NSNotFound)
            {
                [self.jsOutput appendFormat:@"  %@.setAttribute_('resource', '%@');\n",self.zuletztGesetzteID,src];
            }
            else 
            {
                [self.jsOutput appendFormat:@"  %@.setAttribute_('resource', %@);\n",self.zuletztGesetzteID,src];
            }

            if ([attributeDict valueForKey:@"frame"])
            {
                [self.jsOutput appendString:@"\n  // Setting 'frame'\n"];
                [self.jsOutput appendFormat:@"  %@.setAttribute_('frame', %d);\n",self.zuletztGesetzteID,index+1];
            }




// Dieser Code ist nicht mehr nötig, aber würde auch nichts schaden mit ausgeführt zu werden.
// Es gibt irgendwie noch Probs mit dem Code. Er lädt css-Bilder nicht korrekt beim startup... WHY??
 
            // Wenn ein Punkt enthalten ist, ist es wohl eine Datei
            if ([src rangeOfString:@"."].location != NSNotFound ||
            // ... Keine Ahnung wo diese Res herkommenen sollen. Super nervig sowas.
            [src isEqualToString:@"lzgridsortarrow_rsrc"])
            {
                // Möglichkeit 1: Resource wird direkt als String angegeben!
                
                // <----- (hier mit '' setzen, da ja ein String!
                //[self.jsOutput appendFormat:@"\n  $('#%@').get(0).resource = '%@';\n",self.zuletztGesetzteID,src];
                
                s = src;
            }
            else
            {
                // Möglichkeit 2: Resource wurde vorher extern gesetzt+
                
                // <-----
                //[self.jsOutput appendFormat:@"\n  $('#%@').get(0).resource = %@;\n",self.zuletztGesetzteID,src];
                
                // Namen des Bildes aus eigener vorher angelegter Res-DB ermitteln
                if ([[self.allJSGlobalVars valueForKey:src] isKindOfClass:[NSArray class]])
                {
                    s = [[self.allJSGlobalVars valueForKey:src] objectAtIndex:index];
                }
                else
                {
                    s = [self.allJSGlobalVars valueForKey:src];
                }
            }



            if (s == nil || [s isEqualToString:@""])
            {
                // Release: Rausnehmen, es entspricht der OL-Logik, keinen Fehler zu werfen.
                // [self instableXML:[NSString stringWithFormat:@"ERROR: The image-path '%@' isn't valid.",src]];
            }
            else
            {
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
                    [style appendFormat:@"width:%dpx;",w];
                if (!heightGesetzt)
                    [style appendFormat:@"height:%dpx;",h];

                [style appendFormat:@"background-image:url(%@);",s];
            }
 
        }
    }





    // Bestimmte Attribute werden in canvas anders (oder nur dort) behandelt
    if ([elemName isEqualToString:@"canvas"])
    {
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

            // Wenn wir Taxango sind, dann das Hintergrundbild aus dem HTML-File direkt setzen
            if ([[[self.pathToFile lastPathComponent] stringByDeletingPathExtension] isEqualToString:@"Taxango"])
            {
                [self.cssOutput appendString:@"  /* Hintergrundbild von Taxango-HTML-File */\n"];
                [self.cssOutput appendString:@"  background-image:url(images/bg1.jpg);\n"];
            }

            [self.cssOutput appendString:@"}\n\n"];


            // auch für .div_text muss ich font-size und font-family übernehmen
            [self.cssOutput appendString:@".div_text\n{\n  font-size: "];
            [self.cssOutput appendString:fontsize];
            [self.cssOutput appendString:@"px;\n"];
            [self.cssOutput appendString:@"  font-family: "];
            [self.cssOutput appendString:font];
            [self.cssOutput appendString:@", Verdana, Helvetica, sans-serif, Arial;\n"];
            [self.cssOutput appendString:@"}\n\n"];
        }


        // Debug-Konsole aktivieren, falls gewünscht
        if ([attributeDict valueForKey:@"debug"])
        {
            self.attributeCount++;
            if ([[attributeDict valueForKey:@"debug"] isEqualToString:@"true"])
            {
                [self.jQueryOutput appendString:@"\n  // Debug-Konsole aktivieren\n"];
                [self.jQueryOutput appendString:@"  $('div:first').append('<div id=\"debugWindow\"><div style=\"background-color:black;color:white;width:100%;\">DEBUG WINDOW</div><div id=\"debugInnerWindow\"></div></div>');\n"];
                [self.jQueryOutput appendString:@"  // Mach Debug-Fenster so breit wie Fenster abzgl. 2x die Top-Angabe\n"];
                [self.jQueryOutput appendString:@"  $('#debugWindow').width($('div:first').width()-100);\n"];
                [self.jQueryOutput appendString:@"  $('#debugInnerWindow').width($('div:first').width()-100);\n"];
                [self.jQueryOutput appendString:@"  $('#debugWindow').draggable();\n"];

                // Soll relativ am Anfang stehen, diese Variable, falls schon andere Sachen
                // davon abhängig sind (deswegen jsOutput).
                [self.jsOutput appendString:@"\n  // Debug-Mode wurde aktiviert! Anhand dieser Variable kann im Skript erkannt werden, dass wir im Debugmode sind\n"];
                [self.jsOutput appendString:@"  $debug = true;\n\n"];
            }
        }

        // Skipping this attributes
        if ([attributeDict valueForKey:@"scriptlimits"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'scriptlimits'.");
        }
        if ([attributeDict valueForKey:@"xmlns"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'xmlns'.");
        }
        if ([attributeDict valueForKey:@"proxied"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'proxied'.");
        }
        if (![attributeDict valueForKey:@"width"])
        {
            [self setTheValue:@"100%" ofAttribute:@"width"];
        }
        if (![attributeDict valueForKey:@"height"])
        {
            [self setTheValue:@"100%" ofAttribute:@"height"];
        }
    }







    if (positionAbsolute == YES)
    {
        // Aus Sicht des umgebenden Divs gelöst.


        NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

        // Bei Windows muss auch der content vergrößert werden
        if ([elemName isEqualToString:@"window"])
        {
            [s appendString:@"\n  // Höhe/Breite des umgebenden Elements u. U. vergrößern\n"];
            [s appendFormat:@"  adjustHeightAndWidth(%@_content);\n",self.zuletztGesetzteID];
        }

        [s appendString:@"\n  // Höhe/Breite des umgebenden Elements u. U. vergrößern\n"];
        [s appendFormat:@"  adjustHeightAndWidth(%@);\n",self.zuletztGesetzteID];



        // ... dann ganz am Anfang adden (damit die Kinder immer vorher bekannt sind)
        [self.jQueryOutput insertString:s atIndex:0];

/*
 // Aus Sicht des Kindes (Dieser Code hatte zu viel Schwächen):

    [self.jQueryOutput appendString:@"\n  // Eine x- oder y-Angabe! Wir müssen eventuell deswegen die Höhe des Eltern-Elements anpassen, da absolute-Elemente\n  // nicht im Fluss auftauchen, aber das umgebende Element trotzdem mindestens so hoch sein muss, dass es dieses mit umfasst.\n  // Wir überschreiben jedoch keinen explizit vorher gesetzten Wert,\n  // deswegen test auf '' (nur mit JS möglich, nicht mit jQuery) \n"];

    [self.jQueryOutput appendFormat:@"  var h = $('#%@').position().top+($('#%@').outerHeight('true'));\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
    [self.jQueryOutput appendFormat:@"  if (h > $('#%@').parent().height())\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
    [self.jQueryOutput appendFormat:@"    $('#%@').parent().height(h);\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];

        [self.jQueryOutput appendString:@"  // Analog muss die Breite gesetzt werden\n"];
        [self.jQueryOutput appendFormat:@"  var w = parseInt($('#%@').position().left)+($('#%@').outerWidth('true'));\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
        [self.jQueryOutput appendFormat:@"  if ($('#%@').parent().get(0).style.width == '' && w > $('#%@').parent().width())\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
        [self.jQueryOutput appendFormat:@"    $('#%@').parent().width(w);\n\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
 */
    }



    return style;
}


// Vor jede gesetzte class muss ein Leerzeichen, damit es aufgeht
- (NSMutableString*) addCSSClasses:(NSDictionary*) attributeDict
{
    // Alle CSSClasses in einem eigenen String sammeln, könnte nochmal nützlich werden
    NSMutableString *css = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"selectable"])
    {
        self.attributeCount++;

        if ([[attributeDict valueForKey:@"selectable"] isEqualToString:@"false"])
        {
            NSLog(@"Setting the attribute 'selectable=false' as CSS-class 'noTextSelection'.");
            [css appendString:@" noTextSelection"];
        }
        else
        {
            NSLog(@"Skipping the attribute 'selectable' (true is standard).");
        }
    }

    return css;
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
        //[titlewidth appendString:@"px;top:3px;"]; // vom Rand wegrücken damit es zentriert ist
        [titlewidth appendString:@"px\""];
    }
    else
    {
        // vom Rand wegrückenm damit es zentriert ist
        //[titlewidth appendString:@" style=\"top:3px;\""];
    }

    return titlewidth;
}




- (NSString *) escapeSomeCharsInAttributeValues:(NSString*)s
{
    // Es ist mir folgendes passiert: XML-Parser beschwert sich über '<'-Zeichen im
    // Attribut. Dies ist tatsächlich ein XML-Verstoß. Tatsächlich steht im OL-Code
    // auch '&lt;' und nicht '<'. Warum wandelt der Parser dies um????
    // Jedenfalls muss ich durch alle Attribute durch und dort '<' durch '&lt;'
    // wieder zurück ersetzen. Das gleiche gilt für & und &amp;
    // Und Eventuelle " müssen durch ' ersetzt werden
    // (Wegen Beispiel 2 bei <text>, bei OL kommt sowas nicht vor)

    // Das &-ersetzen muss natürlich als erstes kommen, weil ich danach ja wieder
    // welche einfüge (durch die Entitys).
    s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"'"];

    return s;
}



// Remove all occurrences of $,{,}
- (NSString *) removeOccurrencesOfDollarAndCurlyBracketsIn:(NSString*)s
{
    s = [s stringByReplacingOccurrencesOfString:@"$path" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@"$once" withString:@""];
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



- (void) changeMouseCursorOnHoverOverElement:(NSString*)idName
{
    [self.jQueryOutput appendString:@"\n  // Maus-Funktionalität, deswegen anderer Mauscursor\n"];
    //if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
    if (NO)
    {
        [self.jQueryOutput appendFormat:@"  $('#%@').find('*').andSelf().hover(function(e) { $(this).css('cursor','pointer'); }, function(e) { $(this).css('cursor','auto');});\n",idName];
    }
    else
    {
        [self.jQueryOutput appendFormat:@"  $('#%@').hover(function(e) { if (this == e.target) $(this).css('cursor','pointer'); }, function(e) { if (this == e.target) $(this).css('cursor','auto');});\n",idName];
    }
}



// Genauso wie die ID muss auch das Name-Attribut global im JS-Raum vefügbar sein
// Muss immer nach addIdToElement aufgerufen werden, weil ich auf self.zuletztgesetzteID
// zurückgreife.

// Dies war mal in jQueryOutput0, aber die Name-Attrbute müssen von Anfang an bekannt sein,
// damit auch Klassen, die instanziert werden, darauf zugreifen können (Klassen werden
// ebenfalls in jQueryOutput0 deklariert)
// Deswegen müssen alle name-Attribute noch davor global deklariert werden!
// => Deswegen ab nach jsOutput damit.
- (void) convertNameAttributeToGlobalJSVar:(NSDictionary*) attributeDict
{
    if ([attributeDict valueForKey:@"name"])
    {
        NSString *name = [attributeDict valueForKey:@"name"];

        self.attributeCount++;
        NSLog(@"Setting the attribute 'name' as global JS variable.");

        [self.jsOutput appendString:@"\n  // All 'name'-attributes, set by OpenLaszlo, need to be global JS-Variables...\n"];
        // Das ist Unsinn, weil ich das name-tag ja gerade nicht setze:
        // [self.jsOutput appendFormat:@"  var %@ = document.getElementsByName('%@');\n",name, name];

        // Ich verzichte hier bewusst auf das var, weil ich es in der Funktion
        // $(window).load(function() { ... }); deklariere!
        // Mit var davor wird es nur lokal. Ohne var wird es global.
        // Alternative um es global zu machen:
        // "window.Gewerbesteuerpflicht = ...;" bzw. "window['Gewerbesteuerpflicht'] = ...;"
        [self.jsOutput appendFormat:@"  %@ = document.getElementById('%@');\n",name, self.zuletztGesetzteID];


        [self.jsOutput appendString:@"  // All 'name'-attributes, can be referenced by its parent Element...\n"];
        // So nicht: !!!!!
        // [self.jsOutput appendFormat:@"  $('#%@').parent().get(0).%@ = %@;\n",self.zuletztGesetzteID,name, name];
        // Denn das jQuery-Parent berücksichtigt ja nicht den Doppelsprung bei <input> und <select>
        // Deswegen getTheParent benutzen. (Was ja intern auch jQuery-parent nimmt, aber notfalls
        // auch doppelt!)

        // Wenn wir in einer Klasse in der ersten Ebene sind, dann ist der Parent immer das
        // umgebende Element der Klasse
        NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];
        if ([elemTyp isEqualToString:@"evaluateclass"])
        {
            [self.jsOutput appendFormat:@"  %@.%@ = %@;\n",ID_REPLACE_STRING, name, name];
        }
        else
        {
            [self.jsOutput appendFormat:@"  document.getElementById('%@').getTheParent().%@ = %@;\n",self.zuletztGesetzteID, name, name];
        }

        [self.jsOutput appendString:@"  // ...save 'name'-attribute internally, so it can be retrieved by the getter.\n"];
        [self.jsOutput appendFormat:@"  $(%@).data('name','%@');\n",self.zuletztGesetzteID, name];

        //[self.jsOutput appendString:@"  // ...and all 'name'-attributes, can be referenced by canvas.*\n"];
        //[self.jsOutput appendFormat:@"  canvas.%@ = %@;\n",name, name];
        // Nein... das stimmt nicht so generell. Es kann nur sein, dass sich dies ergibt, weil
        // der parent halt 'canvas' ist. Deswegen musste diese Anweisung raus, hat sonst Sachen
        // überschrieben, wenn es mehrere name-Attribute im Dokument mit gleichem Namen gab
    }
}



// http://stackoverflow.com/questions/2700953/a-regex-to-match-a-comma-that-isnt-surrounded-by-quotes
- (NSString*) inString:(NSString*)s searchFor:(NSString*)f andReplaceWith:(NSString*)r ignoringTextInQuotes:(BOOL)b
{
    if (s == nil)
        return s;

    if (!b)
    {
        s = [s stringByReplacingOccurrencesOfString:f withString:r];
    }
    else
    {
        NSError *error = NULL;

        // Ein paar Character müssen vor der Suche escaped werden für den RegExp:
        f = [f stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]; // <-- MUSS als erstes
        f = [f stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
        f = [f stringByReplacingOccurrencesOfString:@"}" withString:@"\\}"];
        f = [f stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
        f = [f stringByReplacingOccurrencesOfString:@"?" withString:@"\\?"];
        f = [f stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
        f = [f stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
        f = [f stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
        f = [f stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
        f = [f stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
        f = [f stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
        f = [f stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
        f = [f stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        f = [f stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];

        NSString* pattern = [NSString stringWithFormat:@"%@\\s*(?=([^\"]*\"[^\"]*\")*[^\"]*$)",f];

        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:/*NSRegularExpressionCaseInsensitive*/0 error:&error];

        /*************** Für die Debug-Ausgabe ***************/
        NSUInteger numberOfMatches = [regexp numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])];
        if (numberOfMatches > 0)
            NSLog([NSString stringWithFormat:@"%d mal hat ein RegExp gematcht und hat %@ ausgetauscht.",numberOfMatches,f]);
        /*************** Für die Debug-Ausgabe ***************/

        if (numberOfMatches > 0)
            s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:r];
    }

    return s;
}



- (NSString*) makeTheComputedValueComputable:(NSString*)s
{
    s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
    s = [self modifySomeExpressionsInJSCode:s];


    // s = [NSString stringWithFormat:@"%@.%@",self.zuletztGesetzteID,s];
    // Nachfolgende Lösung ist besser, weil Scope erhalten bleibt, aber nicht fix ist.
    // s = [NSString stringWithFormat:@"function() { with (%@) { return %@; } }",self.zuletztGesetzteID,s];
    // Nachfolgende Lösung ist NOCH besser, weil zusätzlich sie auch dort eingesetzt werden kann, wo fixe
    // Return-Werte erwartet werden, und nicht nur Funktionen (diese sind meist nur in jQuery okay)
    // Und zwar handelt es sich um eine sich selbst ausführende Funktion
    // und dadurch den Return-Wert zurückliefert, als sei es ein fixer Wert!
    // s = [NSString stringWithFormat:@"(function() { with (%@) { return %@; } })()",self.zuletztGesetzteID,s];
    // NOCH NOCH Besser: Zusätzlich noch bind anfügen. Dann wird auch 'this' richtig ausgewertet und muss
    // nicht mehr ersetzt werden!
    // this von OpenLaszlo musste früher ersetzt werden
    // s = [s stringByReplacingOccurrencesOfString:@"this" withString:[NSString stringWithFormat:@"$('#%@').get(0)",self.zuletztGesetzteID]];

    s = [NSString stringWithFormat:@"(function() { with (%@) { return %@; } }).bind(%@)()",self.zuletztGesetzteID,s,self.zuletztGesetzteID];

    return s;
}



// Ne, wir definieren einfach ein globales setAttribute_ mit defineProperty
// Dazu muss ich dann nur das this immer aktualisieren, da es auch passieren kann, dass
// setAttribute ohne vorangehende Variable aufgerufen wird.
// Neu: Nicht mehr nötig. Wir beachten einfach den Scope von dem aus es aufgerufen wurde.
- (NSString*) modifySomeExpressionsInJSCode:(NSString*)s
{
    if (s == nil)
        [self instableXML:@"Sag mal, so kannst du mich nicht aufrufen. Brauche schon nen String!"];

    // Diese Methode kann nicht überschrieben werden, da intern benutzt von jQuery
    // Hatte ich mal als 'setAttribute(', aber die Klamemr bricht natürlich den RegExp
    s = [self inString:s searchFor:@"setAttribute" andReplaceWith:@"setAttribute_" ignoringTextInQuotes:YES];

    //s = [self inString:s searchFor:@"immediateparent" andReplaceWith:@"getTheParent(true)" ignoringTextInQuotes:YES];
    // --> Neu als getter gelöst

    //s = [self inString:s searchFor:@"parent" andReplaceWith:@"getTheParent()" ignoringTextInQuotes:YES];
    // --> Neu als getter gelöst


    // Das OpenLaszlo-'height' muss ersetzt werden (über getter klappt nicht)
    // Der getter muss neu benannt werden, da intern von jQuery benutzt
    // und wenn ich den getter probiere zu überschreiben, gibt es eine Rekursion.
    // Mit '.' davor, sonst würde er auch Variablen wie 'titlewidth' modifizieren
    s = [self inString:s searchFor:@".height" andReplaceWith:@".myHeight" ignoringTextInQuotes:YES];

    // Das OpenLaszlo-'width' muss ersetzt werden (über getter klappt nicht)
    // Der getter muss neu benannt werden, da intern von jQuery benutzt
    // und wenn ich den getter probiere zu überschreiben, gibt es eine Rekursion.
    s = [self inString:s searchFor:@".width" andReplaceWith:@".myWidth" ignoringTextInQuotes:YES];

    // dataset ist eine interne Property von ECMAScript 5. Keine Property darf so heißen.
    s = [self inString:s searchFor:@".dataset" andReplaceWith:@".myDataset" ignoringTextInQuotes:YES];

    // Das OpenLaszlo-'name' muss ersetzt werden (über getter klappt nicht)
    // Der getter muss neu benannt werden, da intern von jQuery benutzt
    // und wenn ich den getter probiere zu überschreiben, gibt es eine Rekursion.
    //s = [self inString:s searchFor:@".name" andReplaceWith:@".myName" ignoringTextInQuotes:YES];
    // Ne, neu wird in $(el).data('name') gespeichert;

    // classroot taucht nur in Klassen auf und bezeichnet die Wurzel der Klasse
    if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
        s = [self inString:s searchFor:@"classroot" andReplaceWith:ID_REPLACE_STRING ignoringTextInQuotes:YES];


    // Remove leading and ending Whitespaces and NewlineCharacters
    s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return s;
}



- (NSString *) somePropertysNeedToBeRenamed:(NSString*)s
{
    if ([s isEqualToString:@"height"])
        s = @"myHeight";

    if ([s isEqualToString:@"width"])
        s = @"myWidth";

    if ([s isEqualToString:@"dataset"])
        s = @"myDataset";

    return s;
}



// Das eigentliche onClick wird in 'addJS' behandelt, hier nur das pointer-event korrigieren!
// pointer-events: auto; setzen, weil es war vorher auf none gesetzt, damit verschachtelte
// divs, welche keine Kind-Eltern-Beziehung haben, nicht die Klicks wegnehmen können von
// da drunter liegenden Elementen. Warum auch immer das in OL so ist:
// Beweis samplecode:
// <canvas height="500" width="500"><view width="120" height="120" bgcolor="yellow">
// <view width="100" height="100" bgcolor="red" clip="true">
// <view width="80" height="80" bgcolor="purple">
// <view width="30" height="30" bgcolor="blue" onclick="this.mask.setAttribute('bgcolor','green');"/><view width="10" height="10" bgcolor="white" />
// </view></view></view></canvas>
- (void) pointerEventsZulassenBeiId:(NSString*)idName
{
    [self.jQueryOutput appendString:@"\n  // Pointer-Events zulassen\n"];
    [self.jQueryOutput appendFormat:@"  $('#%@').css('pointer-events','auto');",idName];
}



- (void) addJSCode:(NSDictionary*) attributeDict withId:(NSString*)idName
{
    // 'name'-Attribut auswerten und als Leading jQuery Code davorschalten
    // Weil Zugriff auf die Variable von Anfang an sicher gestellt sein muss.
    // Von Datapointer das 'name'-Attribut haben wir schon ausgewertet!
    if (![[self.enclosingElements objectAtIndex:[self.enclosingElements count]-1] isEqualToString:@"datapointer"])
        [self convertNameAttributeToGlobalJSVar:attributeDict];

    if (kompiliereSpeziellFuerTaxango)
    if ([attributeDict valueForKey:@"visible"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'visible' as JS.");


        NSString *s = [attributeDict valueForKey:@"visible"];

        s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];


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
                [self.jQueryOutput appendString:@"\n  // Die Visibility ändert sich abhängig von dem Wert einer woanders gesetzten Variable (Bei jeder Änderung, deswegen watchen der Variable).\n"];
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


                // Wenn !='',=='' oder ==0 auftaucht, dieses rausschmeißen,
                // weil wir nur die Variable brauchen zum setzen.
                s = [s stringByReplacingOccurrencesOfString:@"!=''" withString:@""];
                s = [s stringByReplacingOccurrencesOfString:@"==''" withString:@""];
                s = [s stringByReplacingOccurrencesOfString:@"==0" withString:@""];
                // Puh, ich denke das ist totaler quatsch; dies sind boolesche ausdrücke, die können
                // direkt ausgewertet werden und gehören nach oben zu der abfrage nach true oder false ToDo


                // Negationszeichen aus 's' entfernen, falls wir hier drin sind weil ein '!canvas' vorliegt
                s = [s stringByReplacingOccurrencesOfString:@"!" withString:@""];

                [self.jQueryOutput appendString:@"  // Und einmal sofort die Visibility anpassen durch setzen der Variable mit sich selber\n"];
                [self.jQueryOutput appendFormat:@"  %@ = %@;\n\n",s,s];
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

                    [self.jQueryOutput appendString:@"  });\n"];

                    [self.jQueryOutput appendString:@"  // Und einmal sofort die Visibility anpassen\n"];
                    [self.jQueryOutput appendFormat:@"  toggleVisibility('#%@', '#%@",idName,idVonDerEsAbhaengigIst];
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

    else

    if ([attributeDict valueForKey:@"visible"])
    {
        self.attributeCount++;

        // ToDo - Diese werden noch nicht unterstützt:
        // Beim Abarbeiten vorne anfangen, da Abhängigkeiten nach hinten
        if (![self.zuletztGesetzteID isEqualToString:@"element65"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element66"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element106"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element107"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element252"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element303"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element333"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element375"] &&
            ![self.zuletztGesetzteID isEqualToString:@"element376"])
            [self setTheValue:[attributeDict valueForKey:@"visible"] ofAttribute:@"visible"];
    }


    if ([attributeDict valueForKey:@"focusable"])
    {
        self.attributeCount++;

        if ([[attributeDict valueForKey:@"focusable"] isEqualToString:@"false"])
        {
            NSLog(@"Setting the attribute 'focusable=false' as jQuery.");

            [self.jQueryOutput appendString:@"\n  // focusable=false\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').on('focus.blurnamespace', function() { this.blur(); });\n",idName];
        }

        if ([[attributeDict valueForKey:@"focusable"] isEqualToString:@"true"])
        {
            NSLog(@"Setting the attribute 'focusable=true' as jQuery.");

            // Eventuell falls die vorher auf false gesetzte Eigenschaft überschrieben werden soll
            // Deswegen auch hier Code ausführen. Aber im Prinzip wohl unnötig, da true = Standardwert.
            [self.jQueryOutput appendString:@"\n  // focusable=true (einen eventuell vorher gesetzten focus-Handler, der blur() ausführt, entfernen"];
            [self.jQueryOutput appendFormat:@"\n  $('#%@').off('focus.blurnamespace');\n",idName];
        }
    }



    if ([attributeDict valueForKey:@"layout"])
    {
        NSString *s = [attributeDict valueForKey:@"layout"];

        // Eventuelle spaces im Attribut rausschmeißen, damit der String-Vergleich nicht scheitert
        s = [s stringByReplacingOccurrencesOfString:@" " withString:@""];

        if ([s rangeOfString:@"class:"].location != NSNotFound)
        {
            [self instableXML:@"Upps, ich muss dieses Layout noch korrekt auswerten."];
        }

        // "axis:y; spacing:2";
        NSString *spacing = @"0";
        if ([s rangeOfString:@"spacing:"].location != NSNotFound)
        {
            NSError *error = NULL;
            NSString* pattern = @"\\bspacing\\b:(\\d+)";

            NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];

            NSTextCheckingResult *match = [regexp firstMatchInString:s options:0 range:NSMakeRange(0, [s length])];

            if (match)
            {
                /* NSRange matchRange = [match range]; */
                NSRange dollar_1 = [match rangeAtIndex:1];

                spacing = [s substringWithRange:dollar_1];
            }
        }


        if ([s rangeOfString:@"axis:x"].location != NSNotFound)
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'layout' as simplelayout with axis:x.");

            [self becauseOfSimpleLayoutXMoveTheChildrenOfElement:self.zuletztGesetzteID withSpacing:spacing andAttributes:attributeDict];
        }
        else if ([s rangeOfString:@"axis:y"].location != NSNotFound)
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'layout' as simplelayout with axis:y.");

            [self becauseOfSimpleLayoutYMoveTheChildrenOfElement:self.zuletztGesetzteID withSpacing:spacing andAttributes:attributeDict];
        }
        else if ([s rangeOfString:@"x"].location != NSNotFound) // kann auch ohne 'axis' stehen
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'layout' as simplelayout with axis:x.");

            [self becauseOfSimpleLayoutXMoveTheChildrenOfElement:self.zuletztGesetzteID withSpacing:spacing andAttributes:attributeDict];
        }
        else if ([s rangeOfString:@"y"].location != NSNotFound) // kann auch ohne 'axis' stehen
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'layout' as simplelayout with axis:y.");

            [self becauseOfSimpleLayoutYMoveTheChildrenOfElement:self.zuletztGesetzteID withSpacing:spacing andAttributes:attributeDict];
        }
    }



    if ([attributeDict valueForKey:@"onclick"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onclick' as jQuery.");

        NSString *s = [attributeDict valueForKey:@"onclick"];

        // s = [self removeOccurrencesofDollarAndCurlyBracketsIn:s];
        // Nein! Der Code in event-Handlern ist nicht von ${ ... } umgeben
        // Und deswegen kann ich removeOccurrencesofDollarAndCurlyBracketsIn und
        // modifySomeExpressionsInJSCode auch nicht in einer Methode zusammenfassen!

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-click-event (anstelle des Attributs onclick)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').click(function(){ with (this) { %@ } });\n",idName,s];

        // Wenn es ein onclick gibt, soll sich der Mauszeiger ändern.
        if (![attributeDict valueForKey:@"showhandcursor"] || [[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
            [self changeMouseCursorOnHoverOverElement:idName];
    }


    if ([attributeDict valueForKey:@"ondblclick"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'ondblclick' as jQuery.");

        NSString *s = [attributeDict valueForKey:@"ondblclick"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-dblclick-event (anstelle des Attributs ondblclick)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').dblclick(function(){ with (this) { %@ } });\n",idName,s];

        // Wenn es ein ondblclick gibt, soll sich der Mauszeiger ändern.
        if (![attributeDict valueForKey:@"showhandcursor"] || [[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
            [self changeMouseCursorOnHoverOverElement:idName];
    }


    if ([attributeDict valueForKey:@"onfocus"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onfocus' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onfocus"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-focus-event (anstelle des Attributs onfocus)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').focus(function(){ with (this) { %@ } });\n",idName,s];
    }


    if ([attributeDict valueForKey:@"onblur"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onblur' as jQuery.");

        NSString *s = [attributeDict valueForKey:@"onblur"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-blur-event (anstelle des Attributs onblur)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').blur(function(){ with (this) { %@ } });\n",idName,s];
    }


    if ([attributeDict valueForKey:@"onvalue"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onvalue' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onvalue"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self.jQueryOutput appendString:@"\n  // jQuery-change-event (anstelle des Attributs onchange)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').change(function(){ with (this) { %@ } });\n",idName,s];
    }


    if ([attributeDict valueForKey:@"onmousedown"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onmousedown' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onmousedown"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-mousedown-event (anstelle des Attributs onmousedown)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').mousedown(function(){ with (this) { %@ } });\n",idName,s];

        if (![attributeDict valueForKey:@"showhandcursor"] || [[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
            [self changeMouseCursorOnHoverOverElement:idName];
    }


    if ([attributeDict valueForKey:@"onmouseup"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onmouseup' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onmouseup"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-mouseup-event (anstelle des Attributs onmouseup)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').mouseup(function(){ with (this) { %@ } });\n",idName,s];

        if (![attributeDict valueForKey:@"showhandcursor"] || [[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
            [self changeMouseCursorOnHoverOverElement:idName];
    }


    if ([attributeDict valueForKey:@"onmouseout"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onmouseout' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onmouseout"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-mouseout-event (anstelle des Attributs onmouseout)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').mouseout(function(){ with (this) { %@ } });\n",idName,s];

        if (![attributeDict valueForKey:@"showhandcursor"] || [[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
            [self changeMouseCursorOnHoverOverElement:idName];
    }


    if ([attributeDict valueForKey:@"onmouseover"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onmouseover' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onmouseover"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self pointerEventsZulassenBeiId:idName];
        [self.jQueryOutput appendString:@"\n  // jQuery-mouseover-event (anstelle des Attributs onmouseover)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').mouseover(function(){ with (this) { %@ } });\n",idName,s];

        if (![attributeDict valueForKey:@"showhandcursor"] || [[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
            [self changeMouseCursorOnHoverOverElement:idName];
    }


    if ([attributeDict valueForKey:@"onkeyup"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onkeyup' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onkeyup"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self.jQueryOutput appendString:@"\n  // jQuery-keyup-event (anstelle des Attributs onkeyup)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').keyup(function(){ with (this) { %@ } });\n",idName,s];
    }


    if ([attributeDict valueForKey:@"onkeydown"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'onkeydown' as jQuery-change-event.");

        NSString *s = [attributeDict valueForKey:@"onkeydown"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self.jQueryOutput appendString:@"\n  // jQuery-keydown-event (anstelle des Attributs onkeydown)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').keydown(function(){ with (this) { %@ } });\n",idName,s];
    }


    if ([attributeDict valueForKey:@"oninit"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'oninit' as self-invoking function.");

        NSString *s = [attributeDict valueForKey:@"oninit"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self.jQueryOutput appendString:@"\n  // self-invoking function with with and with bind (anstelle des Attributs oninit)\n"];
        [self.jQueryOutput appendFormat:@"  (function(){ with (this) { %@ } }).bind(%@)();\n",s,idName];
    }


    if ([attributeDict valueForKey:@"ondata"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'ondata' as self-invoking function AND as onchange-Event.");

        NSString *s = [attributeDict valueForKey:@"ondata"];

        s = [self modifySomeExpressionsInJSCode:s];

        [self.jQueryOutput appendString:@"\n  // self-invoking function with with and with bind (anstelle des Attributs ondata)\n"];
        // asbfnalbjfas WARUM AUCH IMMER, muss da nochmal ein ready drum herum. Irgendwas ist
        // da was out of sync. Problem trat auf bei Beispiel 11.4 (mit embeded dataset aber...)!
        [self.jQueryOutput appendString:@"  $(window).ready(function() {\n"];
        [self.jQueryOutput appendFormat:@"    (function(){ with (this) { %@ } }).bind(%@)();\n",s,idName];
        [self.jQueryOutput appendString:@"  });\n"];
        [self.jQueryOutput appendString:@"  // UND jQuery-change-event (noch anstelle des Attributs ondata)\n"];
        [self.jQueryOutput appendFormat:@"  $(%@).change(function(){ with (this) { %@ } });\n",idName,s];
    }




    if ([attributeDict valueForKey:@"datapath"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'datapath' by accessing a temporary datapointer.");

        NSString *dp = [attributeDict valueForKey:@"datapath"];
        if ([dp hasPrefix:@"$"])
            dp = [self makeTheComputedValueComputable:dp];
        else
            dp = [NSString stringWithFormat:@"'%@'",dp];

        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        if ([dp rangeOfString:@":"].location != NSNotFound)
        {
            [o appendString:@"\n  // datapath-Attribut mit : im String (also ein absoluter XPath). Ich werte die XPath-Angabe über einen temporär angelegten Datapointer aus.\n"];
            [o appendString:@"  // Das Ergebnis des XPath-Requests wird als text des Elements gesetzt\n"];
            [o appendString:@"  // Aber nur, wenn es eine Text-Node ist. Denn es kann auch nur ein Pfad angegeben sein, auf den sich dann tiefer verschachtelte Elemente beziehen.\n"];
            [o appendString:@"  // Liefert der XPath-Request mehrere Ergebnisse zurück, muss ich hingegen das Div entsprechend oft duplizieren.\n"];
            [o appendString:@"  // Außerdem XPath speichern, damit Kinder darauf zugreifen können.\n"];
            [o appendFormat:@"  $('#%@').data('XPath',%@);\n",idName,dp];
            [o appendFormat:@"  var lastDP = new lz.datapointer(%@,false);\n",dp];
            [o appendString:@"  if (lastDP.getXPathIndex() > 1)\n"];
            [o appendString:@"  {\n"];
            [o appendString:@"    // Markieren, weil dies Auswirkungen auf viele Dinge hat...\n"];
            [o appendFormat:@"    $('#%@').data('IAmAReplicator',true);\n",idName];
            [o appendString:@"\n"];
            [o appendString:@"    // Counter\n"];
            [o appendString:@"    var c = 0;\n"];
            [o appendString:@"    // Klon erzeugen inklusive Kinder\n"];
            [o appendFormat:@"    var clone = $('#%@').clone(true);\n",idName];
            //[o appendString:@"    // Alle Kinder im Orignal-Element löschen\n"];
            //[o appendFormat:@"    $('#%@').empty();\n",idName];
            //Neu:
            [o appendString:@"    // Das komplette Element löschen,vorher parent sichern\n"];
            [o appendFormat:@"    var p = $('#%@').parent();\n",idName];
            [o appendFormat:@"    $('#%@').remove();\n",idName];
            [o appendString:@"\n"];
            [o appendString:@"    for (var i=0;i<lastDP.getXPathIndex();i++)\n"];
            [o appendString:@"    {\n"];
            [o appendString:@"      c++;\n"];
            [o appendString:@"      // Muss es jedes mal nochmal klonen, sonst wäre der Klon-Vorgang nur 1x erfolgreich\n"];
            [o appendString:@"      var clone2 = clone.clone(true);\n"];
            //[o appendString:@"      // Alle id's austauschen, damit es diese nicht doppelt gibt\n"];
            //[o appendString:@"      clone2.attr('id',clone2.attr('id')+'_repl'+c);\n"];
            //[o appendString:@"      // Ab dem 2. mal auch die der Kinder austauschen, damit ich später geklonte Zwillinge erkennen kann und damit es id's nicht doppelt gibt\n"];
            [o appendString:@"      // Ab dem 2. mal alle id's austauschen, damit ich später geklonte Zwillinge erkennen kann und damit es id's nicht doppelt gibt\n"];
            [o appendFormat:@"      if (i >= 1)\n",idName];
            [o appendString:@"      {\n"];
            [o appendString:@"          clone2.find('*').andSelf().each(function() {\n"];
            [o appendString:@"              $(this).attr('id',$(this).attr('id')+'_repl'+c);\n"];
            [o appendString:@"              // Die neu geschaffene id noch global bekannt machen\n"];
            [o appendString:@"              window[$(this).attr('id')] = this;\n"];
            [o appendString:@"          });\n"];
            [o appendString:@"      }\n"];
            [o appendString:@"      else\n"];
            [o appendString:@"      {\n"];
            [o appendString:@"          // Ansonsten nur die Elemente neu bekannt geben (ohne var, damit global)\n"];
            [o appendString:@"          clone2.find('*').andSelf().each(function() {\n"];
            [o appendString:@"              window[$(this).attr('id')] = this;\n"];
            [o appendString:@"          });\n"];
            [o appendString:@"\n"];
            [o appendString:@"      }\n"];
            //[o appendString:@"      // Den Klon an das Original-Element anfügen\n"];
            [o appendString:@"      // Den Klon an das parent-Element anfügen\n"];
            //[o appendFormat:@"      clone2.appendTo('#%@');\n",idName];
            // Neu:
            [o appendFormat:@"      clone2.appendTo(p);\n",idName];
            [o appendString:@"    }\n"];
            [o appendString:@"  }\n"];
            [o appendString:@"  else\n"];
            [o appendString:@"  {\n"];
            [o appendFormat:@"    if (lastDP.getNodeType() == 3)\n",idName];
            [o appendFormat:@"      $('#%@').html(lastDP.getNodeText());\n",idName];
            [o appendString:@"  }\n"];
        }
        else
        {
            if (!kompiliereSpeziellFuerTaxango)
            {
                [o appendString:@"\n  // Ein relativer Pfad! Dann nehme ich Bezug zum letzten lastDP und dem dort gesetzten Pfad.\n"];
                [o appendFormat:@"  setRelativeDataPathIn(%@,%@,lastDP,'text');\n",idName,dp];
            }
        }


        [self.jsComputedValuesOutput appendString:o];
    }



    // <splash view> -> Nur <view>'s innerhalb von <splash> haben dieses Attribute
    if ([attributeDict valueForKey:@"center"])
    {
        self.attributeCount++;

        if ([[attributeDict valueForKey:@"center"] isEqualToString:@"true"])
        {
            NSLog(@"Setting the attribute 'center=true' as setAttribute('align','center');");

            [self.jQueryOutput appendString:@"\n  // the Splashscreen should be in the center\n"];
            [self.jQueryOutput appendFormat:@"  %@.setAttribute_('align','center');\n",self.zuletztGesetzteID];
        }

    }
    // <splash view> -> Nur <view>'s innerhalb von <splash> haben dieses Attribute
    // Scheint mir unwichtig
    if ([attributeDict valueForKey:@"ratio"])
    {
        self.attributeCount++;
        NSLog(@"Skipping the attribute 'ratio'.");
    }


    if ([attributeDict valueForKey:@"clickable"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'clickable' as css 'pointer-events'.");

        [self setTheValue:[attributeDict valueForKey:@"clickable"] ofAttribute:@"clickable"];
    }


    // steht erst am Ende, falls onClick oder so etwas den Cursor setzt, wir er hier removed
    if ([attributeDict valueForKey:@"showhandcursor"])
    {
        if ([[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"true"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'showhandcursor=true' by doing nothing. If the element is clickable it will get the handcursor anyway.");
        }

        if ([[attributeDict valueForKey:@"showhandcursor"] isEqualToString:@"false"])
        {
            self.attributeCount++;

            NSLog(@"Setting the attribute 'showhandcursor=false' by not adding a hover-effect (previously considered).");
        }
    }



    // 'mask' ist intern read-only, wird aber von GFlender überschrieben, ein Spezialfall.
    //  -> Im Prinzip muss ich es wohl als eigene Var auffassen und dem entsprechend auswerten
    // d. h. die Variable genauso wie jetzt gelöst, einfach zuweisen.
    if ([attributeDict valueForKey:@"mask"])
    {
        self.attributeCount++;

        NSString *s = [attributeDict valueForKey:@"mask"];

        if ([s hasPrefix:@"$"])
            s = [self makeTheComputedValueComputable:s];

        NSLog([NSString stringWithFormat:@"Setting the var 'mask' with the value '%@'.",s]);
        [self.jQueryOutput appendString:@"\n  // setting the var 'mask'"];
        [self.jQueryOutput appendFormat:@"\n  %@.mask = %@;\n",self.zuletztGesetzteID,s];
    }
}




// Die ID ermitteln
// self.zuletztGesetzteID wird hier gesetzt
// und die ID wird global verfügbar gemacht.
- (NSString*) addIdToElement:(NSDictionary*) attributeDict
{
    // Erstmal auch dann setzen, wenn wir eine gegebene ID von OpenLaszlo haben, evtl. zu ändern
    self.idZaehler++;

    if ([attributeDict valueForKey:@"id"])
    {
        self.attributeCount++;
        self.zuletztGesetzteID = [attributeDict valueForKey:@"id"];
    }
    else
    {
        self.zuletztGesetzteID = [NSString stringWithFormat:@"element%d",self.idZaehler];
    }


    // Wenn wir gerade rekursiv eine <class></class> auswerten, darf es keine fixen IDs geben
    // Es handelt sich ja um generelle Klassen. Deswegen hier mit einem Replace-String arbeiten,
    // welcher später beim auslesen der Klasse ersetzt werden muss.
    // (Es sei denn es wurde wirklich vom Benutzer explizit eine ID vergeben)
    if (self.ignoreAddingIDsBecauseWeAreInClass && ![attributeDict valueForKey:@"id"])
        self.zuletztGesetzteID = [NSString stringWithFormat:@"%@_%d",ID_REPLACE_STRING,self.idZaehler];

    [self.output appendString:@" id=\""];
    [self.output appendString:self.zuletztGesetzteID];
    [self.output appendString:@"\""];


    NSLog([NSString stringWithFormat:@"Setting the (attribute 'id' as) HTML-attribute 'id'. Id = '%@'.",self.zuletztGesetzteID]);




    // Alle von OpenLaszlo vergebenen IDs müssen auch global verfügbar sein!
    // Insbesondere auch wegen Firefox
    // Bewusst ohne var davor! Damit es global verfügbar ist.
    // => Anders gelöst, Schleife durch alle IDs direkt Am Anfang des <script>-Quellcodes.
    // Nur bei nachträglich hinzugefügten Klassen ist es nachwievor nötig!
    if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
    {
        [self.jsOutput appendString:@"\n  // Alle von OpenLaszlo vergebenen IDs müssen auch global verfügbar sein.\n"];
        [self.jsOutput appendFormat:@"  %@ = document.getElementById('%@');\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
    }


    return self.zuletztGesetzteID;
}




// Muss immer nach addIDToElement aufgerufen werden,
// da wir auf die zuletzt gesetzte id zurückgreifen.
// Das attributeDict brauchen wir nur, falls Y-Wert in Simplelayout Y gesetzt wurde.
// => Dann muss ich diesen Wert überschreiben, da er keine Auswirkung haben darf.
- (void) check4Simplelayout:(NSDictionary*) attributeDict
{
    // Tote Funktion
    return;


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
        NSLog(@"'top' korrigieren, weil 2 ineinander verschachtelte Y-Simplelayouts.");

        [self.jsOutput appendString:@"  // Korrektur von 'top' wegen zweier ineinander verschachtelteter Simplelayout Y:\n"];
        [self.jsOutput appendString:@"  if ("];
        [self.jsOutput appendFormat:@"($('#%@').prev().length > 0) && ",id];
        [self.jsOutput appendFormat:@"$('#%@').prev().get(0).lastElementChild)\n",id];

        [self.jsOutput appendString:@"    document.getElementById('"];
        [self.jsOutput appendString:id];

        // parseInt() removes the "px" at the end
        [self.jsOutput appendString:@"').style.top = ("];

        [self.jsOutput appendFormat:@"parseInt($('#%@').prev().get(0).lastElementChild.offsetTop)+",id];

        [self.jsOutput appendFormat:@"parseInt($('#%@').prev().get(0).lastElementChild.offsetHeight)+",id];

        [self.jsOutput appendFormat:@"%d", spacing_y];
        [self.jsOutput appendString:@") + 'px';\n\n"];

        wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_Y = NO;
    }
    else if (self.simplelayout_y == self.verschachtelungstiefe)  // > 0)
    {
        // Da Simplelayout Y sich selbst an der Y-Achse ausrichtet, muss eine eventuelle
        // Y-Angabe in den Attributen ignoriert werden. Deswegen nulle ich hier Y per jQuery.
        // X-Attribut darf sich hingegen auswirken und darf nicht genullt werden!
        if ([attributeDict valueForKey:@"y"])
        {
            [self.jsOutput appendFormat:@"\n  // top-css-Eigenschaft nullen, da ein y-wert gesetzt wurde,\n  // obwohl wir in einem Simplelayout Y sind, welches top automatisch ausrichtet.\n",id];
            // Eigenschaft entfernen verwirrt JS etwas (wenn gleich auch nicht jQuery)
            //[self.jsOutput appendFormat:@"\n$('#%@').css('top','');\n\n",id];
            // Deswegen einfach auf 0 setzen
            [self.jsOutput appendFormat:@"  $('#%@').css('top','0');\n\n",id];
        }


        if (!self.firstElementOfSimpleLayout_y)
        {
            // Seit wir von absolute auf relative umgestiegen sind und zusätzlich auch noch auf
            // float:left umgestellt haben, müssen wir die width nur korrigieren, wenn das Element
            // position:absolute ist. Dann müssen wir es doch immer noch verrücken.

            // Den allerersten sibling auslassen
            [self.jsOutput appendString:@"  // Für den Fall, dass wir position:absolute sind nehmen wir keinen Platz ein\n  // und rücken somit nicht automatisch auf. Dies müssen wir hier nachkorrigieren. Inklusive spacing.\n"];
            [self.jsOutput appendString:@"  if ("];
            // Test ob es überhaupt ein vorheriges Geschwisterelement gibt, muss drin sein,
            // sonst Absturz (wohl kein Absturz mehr seit Umstieg auf jQuery 'prev' auch IN dem
            // if-Zweig
            [self.jsOutput appendFormat:@"($('#%@').prev().length > 0) && ",id];
            [self.jsOutput appendString:@"$('#"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').css('position') == 'absolute')\n"];

            [self.jsOutput appendFormat:@"    document.getElementById('%@').style.top = (",id];

            [self.jsOutput appendFormat:@"$('#%@').prev().get(0).offsetTop+",id];

            // Nur bei relative: Dann könnte man die eingerückte Zeilen auskommentieren
            // Aber sie scheint auch nichts zu schaden.
            // Bei position:absolute ist sie definitiv erforderlich!
                [self.jsOutput appendFormat:@"$('#%@').prev().outerHeight()+",id];

            // Spacing-Angabe auch gleich hier mitkorrigieren
            [self.jsOutput appendFormat:@"%d", spacing_y];
            [self.jsOutput appendString:@") + 'px';\n"];

            // Ansonsten müssen wir halt nur entsprechend des spacing-Wertes nach unten
            // rücken. Mit top klappt es nicht (zumindestens nicht bei mehr als 2 Elementen)
            // mit padding klappt es auch nicht, aber mit margin... zum Glück
            // Korrektur: margin bricht position:absolute, weil es dann eventuell rechts runter in die nächste
            // Zeile fallen kann, deswegen doch mit left arbeiten. Einfach multiplizieren mit Anzahl der sipplings!
            // Dann klappt left.
            [self.jsOutput appendString:@"  else\n"];
            [self.jsOutput appendString:@"    // ansonsten wegen 'spacing' nach unten rücken (spacing * Anzahl vorheriger Geschwister)\n"];
            [self.jsOutput appendString:@"    $('#"];
            [self.jsOutput appendString:id];
            // [self.jsOutput appendString:@"').css('margin-top','"];
            // [self.jsOutput appendFormat:@"%d", spacing_y];
            // [self.jsOutput appendString:@"px');\n\n"];
            [self.jsOutput appendString:@"').css('top',"];
            // += funzt nicht wegen der Startvorgabe 'auto'. Da kann man nicht draufaddieren. Aber klappt auch ohne +=
            // [self.jsOutput appendString:@"'+=' + "];
            [self.jsOutput appendFormat:@"%d", spacing_y];
            [self.jsOutput appendFormat:@" * $('#%@').prevAll().length);\n\n",id];
        }
        self.firstElementOfSimpleLayout_y = NO;
    }



    // Simplelayout X
    if (wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X)
    {
        NSLog(@"'left' korrigieren, weil 2 ineinander verschachtelte X-Simplelayouts.");

        [self.jsOutput appendString:@"  // Korrektur von 'left' wegen zweier ineinander verschachtelteter Simplelayout X:\n"];
        [self.jsOutput appendString:@"  if ("];
        [self.jsOutput appendFormat:@"($('#%@').prev().length > 0) && ",id];
        [self.jsOutput appendFormat:@"$('#%@').prev().get(0).lastElementChild)\n",id];

        [self.jsOutput appendString:@"    document.getElementById('"];
        [self.jsOutput appendString:id];

        // parseInt() removes the "px" at the end
        [self.jsOutput appendString:@"').style.left = ("];

        [self.jsOutput appendFormat:@"parseInt($('#%@').prev().get(0).lastElementChild.offsetLeft)+",id];

        [self.jsOutput appendFormat:@"parseInt($('#%@').prev().get(0).lastElementChild.offsetWidth)+",id];

        [self.jsOutput appendFormat:@"%d", spacing_x];
        [self.jsOutput appendString:@") + 'px';\n\n"];

        wirVerlassenGeradeEinTieferVerschachteltesSimpleLayout_X = NO;
    }
    else if (self.simplelayout_x == self.verschachtelungstiefe) // > 0)
    {
        // Da Simplelayout X sich selbst an der X-Achse ausrichtet, muss eine eventuelle
        // X-Angabe in den Attributen ignoriert werden. Deswegen nulle ich hier X per jQuery.
        // Y-Attribut darf sich hingegen auswirken und darf nicht genullt werden!
        if ([attributeDict valueForKey:@"x"])
        {
            [self.jsOutput appendFormat:@"\n  // left-css-Eigenschaft nullen, da ein x-wert gesetzt wurde,\n  // obwohl wir in einem Simplelayout X sind, welches left automatisch ausrichtet.\n",id];
            [self.jsOutput appendFormat:@"  $('#%@').css('left','0');\n\n",id];
        }

        if (!self.firstElementOfSimpleLayout_x)
        {
            // Seit wir von absolute auf relative umgestiegen sind und zusätzlich auch noch auf
            // float:left umgestellt haben, müssen wir die width GAR NICHT mehr korrigieren
            // Stopp: Es gibt eine Ausnahme: Wenn unser Element position:absolute ist dann
            // müssen wir es doch immer noch verrücken.

            // Den allerersten sibling auslassen
            [self.jsOutput appendString:@"  // Für den Fall, dass wir position:absolute sind nehmen wir keinen Platz ein\n  // und rücken somit nicht automatisch auf. Dies müssen wir hier nachkorrigieren. Inklusive spacing.\n"];
            [self.jsOutput appendString:@"  if ("];
            // Test ob es überhaupt ein vorheriges Geschwisterelement gibt, muss drin sein,
            // sonst Absturz (wohl kein Absturz mehr seit Umstieg auf jQuery 'prev' auch IN dem
            // if-Zweig
            [self.jsOutput appendFormat:@"($('#%@').prev().length > 0) && ",id];
            [self.jsOutput appendString:@"$('#"];
            [self.jsOutput appendString:id];
            [self.jsOutput appendString:@"').css('position') == 'absolute')\n"];

            [self.jsOutput appendString:@"    document.getElementById('"];
            [self.jsOutput appendString:id];


            [self.jsOutput appendString:@"').style.left = ("];

            // Nur bei relative: Dann könnte man die eingerückte Zeilen auskommentieren
            // Aber sie scheint auch nichts zu schaden.
            // Bei position:absolute ist sie definitiv erforderlich!
                [self.jsOutput appendFormat:@"$('#%@').prev().get(0).offsetLeft+",id];

            //[self.jsOutput appendFormat:@"$('#%@').prev()[0].offsetWidth+",id];
            // entspricht:
            //[self.jsOutput appendFormat:@"$('#%@').prev().get(0).offsetWidth+",id];
            // Lieber per jQuery:
            [self.jsOutput appendFormat:@"$('#%@').prev().outerWidth()+",id];

            // Spacing-Angabe auch gleich hier mitkorrigieren
            [self.jsOutput appendFormat:@"%d", spacing_x];

            [self.jsOutput appendString:@") + 'px';\n"];

            // ...Deswegen kommt hier auch ein Else hin
            [self.jsOutput appendString:@"  else\n"];

            // Ansonsten müssen wir halt nur entsprechend des spacing-Wertes nach rechts
            // rücken. Mit left klappt es nicht (zumindestens nicht bei mehr als 2 Elementen)
            // mit padding klappt es auch nicht, aber mit margin... zum Glück
            // Korrektur: margin bricht position:absolute, weil es dann eventuell rechts runter in die nächste
            // Zeile fallen kann, deswegen doch mit left arbeiten. Einfach multiplizieren mit Anzahl der sipplings!
            // Dann klappt left.
            [self.jsOutput appendString:@"    // ansonsten wegen 'spacing' nach rechts rücken (spacing * Anzahl vorheriger Geschwister)\n"];
            [self.jsOutput appendString:@"    $('#"];
            [self.jsOutput appendString:id];
            // [self.jsOutput appendString:@"').css('margin-left','"];
            // [self.jsOutput appendFormat:@"%d", spacing_x];
            // [self.jsOutput appendString:@"px');\n\n"];
            [self.jsOutput appendString:@"').css('left',"];
            // += klappt nicht wegen der Startvorgabe 'auto'. Da kann man nicht draufaddieren. Aber klappt auch ohne +=
            // [self.jsOutput appendString:@"'+=' + "];
            [self.jsOutput appendFormat:@"%d", spacing_x];
            [self.jsOutput appendFormat:@" * $('#%@').prevAll().length);\n\n",id];
        }
        self.firstElementOfSimpleLayout_x = NO;
    }
}


- (void) instableXML:(NSString*)s
{
    NSLog([NSString stringWithFormat:@"%@",s]);

    // NSLog([NSString stringWithFormat:@"Collected Frame Resources: %@",self.allJSGlobalVars]);

    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Exception geworfen" userInfo:nil];
}




-(void) callMyselfRecursive:(NSString*)relativePath
{
    NSURL *path = [self.pathToFile URLByDeletingLastPathComponent];
    NSURL *pathToFile = [NSURL URLWithString:relativePath relativeToURL:path];

    xmlParser *x = [[xmlParser alloc] initWith:pathToFile recursiveCall:YES];

    // Den Pfad zur base-nicht-rekursiven-Datei muss ich mitspeichern
    if (self.isRecursiveCall)
        x.pathToFile_basedir = self.pathToFile_basedir;
    else
        x.pathToFile_basedir = [[self.pathToFile URLByDeletingLastPathComponent] relativeString];

    // Wenn es eine Datei ist, die Items für ein Dataset enthält, dann muss das rekursiv
    // aufgerufene Objekt das letzte DataSet wissen, damit es die Items richtig zuordnen kann
    x.lastUsedDataset = self.lastUsedDataset;
    // Zur Zeit ignorieren wir Datasets mit eigenen bennannten Tags, deswegen müssen wir
    // falls diese in einer eigenen Datei definiert sind, dies mitteilen
    x.weAreInDatasetAndNeedToCollectTheFollowingTags = self.weAreInDatasetAndNeedToCollectTheFollowingTags;

    // Manchmal greift die rekursive Datei auf vorher nicht-rekursiv definierte Res zurück.
    // Deswegen muss ich das Dictionary, welches alle gesammelten Resourcen enthält,
    // hier mit übergeben.
    // x.allJSGlobalVars = self.allJSGlobalVars;
    [x.allJSGlobalVars addEntriesFromDictionary:self.allJSGlobalVars];

    // Die soweit erkannten Klassen müssen auch später rekursiv aufgerufenen Dateien bekannt sein!
    [x.allFoundClasses addEntriesFromDictionary:self.allFoundClasses];

    // id-Zähler übergeben, sonst werden IDs doppelt vergeben!
    x.idZaehler = self.idZaehler;

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

        // [self.allJSGlobalVars addEntriesFromDictionary:[result objectAtIndex:9]];
        // [self.allFoundClasses addEntriesFromDictionary:[result objectAtIndex:10]];
        // Ich kann nicht adden, sonst verdoppeln und verdreifachen sich die Einträge immer weiter
        // Ich habe ja vorher schon die Einträge geaddet beim übergeben an die Rekursion.
        [self.allJSGlobalVars setDictionary:[result objectAtIndex:9]];
        [self.allFoundClasses setDictionary:[result objectAtIndex:10]];

        // id-Zähler wieder übernehmen, sonst werden IDs doppelt vergeben!
        self.idZaehler = [[result objectAtIndex:11] integerValue];

        // ka, ob wirklich nötig, aber schadet wohl auch nicht und ist Erinnerung,
        // dass Array im index 12 was zurückliefert.
        self.defaultplacement = [result objectAtIndex:12];

        [self.jsComputedValuesOutput appendString:[result objectAtIndex:13]];
        [self.jsConstraintValuesOutput appendString:[result objectAtIndex:14]];

        // Hier adden, weil ich NICHT die Werte aus diesem Array mit an die
        // Rekursions-Stufe übergeben hatte
        [self.allImgPaths addObjectsFromArray:[result objectAtIndex:15]];
    }

    NSLog(@"Leaving recursion");
}



// Muss rückwärts gesetzt werden, weil die Höhe der Kinder ja bereits bekannt sein muss!
-(void) korrigiereHoeheDesUmgebendenDivBeiSimpleLayout
{
    NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

    [s appendString:@"\n  // Höhe anpassen, wegen Simplelayout\n"];
    [s appendFormat:@"  adjustHeightOfEnclosingDivWithHeighestChildOnSimpleLayout(%@);\n",self.zuletztGesetzteID];

    // An den Anfang des Strings setzen!
    // Die Höhe muss bekannt sein, bevor das Simplelayout als solches ausgeführt wird!
    [self.jsConstraintValuesOutput insertString:s atIndex:0];
}



// Muss rückwärts gesetzt werden, weil die Breite der Kinder ja bereits bekannt sein muss!
-(void) korrigiereBreiteDesUmgebendenDivBeiSimpleLayout
{
    NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

    [s appendString:@"\n  // Breite anpassen, wegen Simplelayout\n"];
    [s appendFormat:@"  adjustWidthOfEnclosingDivWithWidestChildOnSimpleLayout(%@);\n",self.zuletztGesetzteID];

    // An den Anfang des Strings setzen!
    // Die Breite muss bekannt sein, bevor das Simplelayout als solches ausgeführt wird!
    [self.jsConstraintValuesOutput insertString:s atIndex:0];
}



// Bindestriche werden intern bei der css-width-Berechnung anscheinend umgebrochen.
// Deswegen wird der Bindestrich hier durch einen non breaking hyphen ersetzt.
// Alternative wäre per css eine '.nobr { white-space: nowrap;}'-Angabe
// http://stackoverflow.com/questions/8753296/how-to-prevent-line-break-at-hyphens-on-all-browsers
// Wird von BDSText beim gesammelten und bei der direkten Text-Eingabe aufgerufen
- (NSString *) replaceHyphenWithNonBreakingHyphen:(NSString*)s
{
    return s;
    // Update: Diese Methode ist seit 'white-space:nowrap' in CSS '.div_text' nicht mehr nötig!

    // Verkürzt den Bindestrich dann leider um einen Pixel.
    s = [s stringByReplacingOccurrencesOfString:@"-" withString:@"&#8209;"];
    return s;
}



-(void) erhoeheVerschachtelungstiefe:(NSString *)elementName merkeDirID:(NSString *)theId
{
    self.verschachtelungstiefe++;

    // 'method' und 'attribute' müssen wissen in welchem umschließenen Tag mit welcher ID wir uns befinden
    // Ich muss dazu die ganze Hierachie-Stufe speichern, weil wenn ich aus tiefer verschachtelten
    // Ebenen zurückkehre, ist sonst das umgebende Element + die ID davon nicht mehr bekannt.
    // NSLog([NSString stringWithFormat:@"\n\n\n\n\n XX Hierachiestufe umgebender Elemente: %@",self.enclosingElements]);
    [self.enclosingElements addObject:elementName];
    if (theId != nil)
    {
        [self.enclosingElementsIds addObject:theId];
    }
    else
    {
        // Es gibt auch Methoden, die sind in einem Element definiert, die haben gar keine ID...
        // Wie soll man die dann ansprechen? Wohl nur über this oder parent dann.
        // Jedenfalls müssen wir die Methode trotzdem irgendwie koppeln.
        // Wir erraten dazu die gleich gesetzte ID...
        // Etwas tricky, aber es funktioniert...
        if (self.ignoreAddingIDsBecauseWeAreInClass)
        {
            // Wenn wir ganz außen sind, dann gilt die originäre ID der Klasse, ansonsten die einer Subview.
            if ([elementName isEqualToString:@"evaluateclass"])
            {
                [self.enclosingElementsIds addObject:[NSString stringWithFormat:@"%@",ID_REPLACE_STRING]];
            }
            else
            {
                [self.enclosingElementsIds addObject:[NSString stringWithFormat:@"%@_%d",ID_REPLACE_STRING,self.idZaehler+1]];
            }
        }
        else
        {
            [self.enclosingElementsIds addObject:[NSString stringWithFormat:@"element%d",self.idZaehler+1]];
        }
    }
}



-(void) reduziereVerschachtelungstiefe
{
    self.verschachtelungstiefe--;

    [self.enclosingElements removeLastObject];
    [self.enclosingElementsIds removeLastObject];
}


- (NSString*) korrigiereElemBeiWindow:(NSString*)s
{
    if ([self.enclosingElements count] > 1)
    {
        NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];

        if ([elemTyp isEqualToString:@"window"])
        {
            s = [NSString stringWithFormat:@"%@_content",s];
        }
    }

    return s;
}



- (void) becauseOfSimpleLayoutXMoveTheChildrenOfElement:(NSString*)elem withSpacing:(NSString*)spacing andAttributes:(NSDictionary*)attributeDict
{
    // Bricht Beispiel 27.6
    //elem = [self korrigiereElemBeiWindow:elem];

    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"inset"])
    {
        self.attributeCount++;
        NSLog(@"Using the attribute 'inset' as spacing for the first element.");

        [o appendString:@"\n  // 'inset' for the first element of this 'simplelayout' (axis:x)\n"];
        [o appendFormat:@"  $('#%@').children().first().get(0).setAttribute_('x','%@px');\n",elem,[attributeDict valueForKey:@"inset"]];
    }



    [o appendFormat:@"\n  // Setting a 'simplelayout' (axis:x) in '%@':\n",elem];
    [o appendFormat:@"  setSimpleLayoutXIn(%@,%@);\n",elem,spacing];


    // Das war in self.jsOutput, damit das umgebende DIV richtig gesetzt wird
    // [self.jsOutput appendString:o];
    // Anscheinend doch nicht, es muss in jQuery (ans Ende), weil erst dann die width und height von selbst
    // definierten Klassen bekannt ist (Example 28.9. Extending the built-in text classes)
    // puh, puh, muss es derzeit wirklich doppelt setzen, auch wegen Bsp. 11.2
    // Neu: nein, wegen Bsp. 11.3 darf ich es NICHT doppelt setzen, sonst klappt beim 2. mal die Abfrage
    // die nur in JS möglich ist, ob Wert schon gesetzt ist, nicht. (weil ist ja schon gesetzt)
    [self.jQueryOutput appendString:o];
}




- (void) becauseOfSimpleLayoutYMoveTheChildrenOfElement:(NSString*)elem withSpacing:(NSString*)spacing andAttributes:(NSDictionary*)attributeDict
{
    // Bricht Beispiel 27.6
    //elem = [self korrigiereElemBeiWindow:elem];

    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"inset"])
    {
        self.attributeCount++;
        NSLog(@"Using the attribute 'inset' as spacing for the first element.");

        [o appendString:@"\n  // 'inset' for the first element of this 'simplelayout' (axis:y)\n"];
        [o appendFormat:@"  $('#%@').children().first().get(0).setAttribute_('y','%@px');\n",elem,[attributeDict valueForKey:@"inset"]];
    }



    [o appendFormat:@"\n  // Setting a 'simplelayout' (axis:y) in '%@':\n",elem];
    [o appendFormat:@"  setSimpleLayoutYIn(%@,%@);\n",elem,spacing];



    // Das war in self.jsOutput, damit das umgebende DIV richtig gesetzt wird
    // [self.jsOutput appendString:o];
    // Anscheinend doch nicht, es muss in jQuery (ans Ende), weil erst dann die width und height von
    // selbst definierten Klassen bekannt ist (Example 28.9. Extending the built-in text classes)
    [self.jQueryOutput appendString:o];
}



- (void) addEnclosingElementsToDatasetProperty
{
    if ([self.enclosingElements count] > 0)
    {
        int i = 0;
        // -1, weil wir uns selber hier nicht hinzufügen
        while (i < [self.enclosingElements count]-1)
        {
            if ([[self.enclosingElements objectAtIndex:i] isEqualToString:@"dataset"] ||
                [[self.enclosingElements objectAtIndex:i] isEqualToString:@"library"] ||
                [[self.enclosingElements objectAtIndex:i] isEqualToString:@"canvas"])
            {
                i++;
                continue;
            }

            [self.jsHead2Output appendFormat:@".%@",[self.enclosingElements objectAtIndex:i]];
            i++;
        }
    }
}



- (void) evaluateTextOnlyAttributes:(NSDictionary*)attributeDict
{
    // Aus der OpenLaszlo-Doku:
    // If true, the width of the text field will be recomputed each time text is changed,
    // so that the text view is exactly as wide as the width of the widest line.
    // Defaults to true.
    // Falls sich der Textinhalt ändert, soll sich bei true, die Größe also mitändern
    // true = default, und auch in HTML default
    NSString *resize = @"true";
    if ([attributeDict valueForKey:@"resize"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'resize' as the property of this text-element.");

        resize = [attributeDict valueForKey:@"resize"];
    }
    [self.jQueryOutput appendFormat:@"\n  // All <text>'s have the 'property' resize\n"];
    [self.jQueryOutput appendFormat:@"  %@.setAttribute_('resize',%@);\n",self.zuletztGesetzteID,resize];


    if ([attributeDict valueForKey:@"text"])
    {
        self.attributeCount++;

        if ([[attributeDict valueForKey:@"text"] hasPrefix:@"$"])
        {
            // MUSS derzeit noch rein, sonst verschwindet Schriftzug "Seine Steuererklärung 2011"
            // Ich vermute, weil er sonst bestimmte Simplelayouts nicht richtig berechnen kann (ToDo?)
            [self.output appendString:@"CODE! - Wird dynamisch mit jQuery ersetzt."];

            [self setTheValue:[attributeDict valueForKey:@"text"] ofAttribute:@"text"];
        }
        else
        {
            NSLog(@"Setting the attribute 'text' as text between opening and closing tag.");
            [self.output appendString:[attributeDict valueForKey:@"text"]];
        }
    }
}



- (void) evaluateTextInputOnlyAttributes:(NSDictionary*)attributeDict
{
    if ([attributeDict valueForKey:@"text"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'text' as value for the inputfield.");

        [self.jQueryOutput appendFormat:@"\n  // Setting the value-attribute (comes from OL-'text'-attribute)\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').val('%@');\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"text"]];
    }
}



// Gibt es 2 mal im Code, deswegen als eigene Methode
- (void) legeDatasetAnUndInitMitOeffnendemTag
{
    [self.jsHead2Output appendString:@"\n// Dieses Dataset wird als XML-Struktur angelegt und in einem JS-String gespeichert.\n"];
    [self.jsHead2Output appendFormat:@"var %@ = new lz.dataset('%@');\n",self.lastUsedDataset,self.lastUsedDataset];

    [self.jsHead2Output appendFormat:@"%@.rawdata = '<%@>';\n",self.lastUsedDataset,self.lastUsedDataset];
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
    // Hat derzeit nur rein statistische Zwecke bzw. keinen Zweck
    self.elementeZaehler++;

    [self erhoeheVerschachtelungstiefe:elementName merkeDirID:[attributeDict valueForKey:@"id"]];

    // Potentielle HTML-Elemente innerhalb von Text müssen abgefangen werden.
    // Es darf nicht die unbekannten Elemente die von dataset eingesammelt werden, brechen.
    if (self.weAreCollectingTextAndThereMayBeHTMLTags)
    {
        if ([elementName isEqualToString:@"br"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendFormat:@"<%@ />",elementName];
            return;
        }

        if ([elementName isEqualToString:@"a"] ||
            [elementName isEqualToString:@"b"] ||
            [elementName isEqualToString:@"i"] ||
            [elementName isEqualToString:@"p"] ||
            [elementName isEqualToString:@"u"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendFormat:@"<%@>",elementName];
            return;
        }

        if ([elementName isEqualToString:@"font"] ||
            [elementName isEqualToString:@"img"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendFormat:@"<%@",elementName];
            for (id e in attributeDict)
            {
                // Alle Elemente in 'font' (color usw...) oder 'img' (src usw...) einfach ausgeben
                // Nur bei size muss ich gesondert drauf reagieren. Da die HTML-Logik dahinter eine andere ist
                if ([e isEqualToString:@"size"])
                    [self.textInProgress appendFormat:@" style=\"font-size:%@px;\"",[attributeDict valueForKey:e]];
                else
                    [self.textInProgress appendFormat:@" %@=\"%@\"",e,[attributeDict valueForKey:e]];
            }
            [self.textInProgress appendString:@">"];
            return;
        }
    }


    if (werteItemUndItemsAlsArrayAus)
    if ([elementName isEqualToString:@"items"])
    {
        element_bearbeitet = YES;


        // markierung für den Beginn der item-Liste
        self.datasetItemsCounter = 0;


        // Derzeit werden <items>-Listen als Array behandelt.
        // Eventuell sollten das ebenfalls Objekte werden (To Think - ToDo)
        NSLog(@"Using the datasets attribute 'name' as name for a new JS-Array().");
        [self.jsHead2Output appendString:@"\n// Überschreiben der eben gesetzten var:\n// Ein Array mit dem Namen des gefundenen datasets und den dataset-items als Elementen\n"];
        [self.jsHead2Output appendString:@"var "];
        [self.jsHead2Output appendString:self.lastUsedDataset];
        [self.jsHead2Output appendString:@" = new Array();\n"];


        // Hier muss ich auch die Var auf NO setzen, denn dann sind es nur normale 'items', die
        // ich einsammeln kann und keine tags die im Tag-Namem den Variablennamen haben
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
    }


    // Alle Elemente in dataset, die nicht 'items' sind, werden in Objekt-Propertys des zugehörigen
    // Objektes umgewandelt (Der Objektname kommt aus dem dataset-'name'-Attribut)
    // Neu: Sie werden in eine XML-Struktur überführt
    if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
    {

        NSString *gesammelterText = [self holDenGesammeltenTextUndLeereIhn];

        // Da wir es in ' einschließen, müssen diese escaped werden:
        gesammelterText = [gesammelterText stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
        // Auch newlines müssen escaped werden
        gesammelterText = [gesammelterText stringByReplacingOccurrencesOfString:@"\n" withString:@"\\\n"];


        // Galt nur für die alte JS-Objekte-Logik
        // elementName = [elementName stringByReplacingOccurrencesOfString:@"-" withString:@"_"];

        // Ganz am Anfang erstmal das Objekt an sich anlegen
        if (self.datasetItemsCounter == 0)
        {
            //[self.jsHead2Output appendString:@"\n// Dieses Dataset wird als Objekt angelegt und bekommt alle Elemente als neue Objekt-Propertys mit\n"];
            //[self.jsHead2Output appendString:@"var "];
            //[self.jsHead2Output appendString:self.lastUsedDataset];
            //[self.jsHead2Output appendString:@" = new lz.dataset();\n"];
        }



        [self.jsHead2Output appendFormat:@"%@.rawdata += '%@<%@", self.lastUsedDataset, gesammelterText, elementName];

        NSArray *keys = [attributeDict allKeys];
        if ([keys count] > 0)
        {
            for (NSString *key in keys)
            {
                [self.jsHead2Output appendFormat:@" %@=\"",key];
                
                NSString *s = [attributeDict valueForKey:key];
                
                s = [self escapeSomeCharsInAttributeValues:s];
                
                [self.jsHead2Output appendFormat:@"%@\"",s];
            }
        }
        
        [self.jsHead2Output appendString:@">';\n"];



        /* Wirklich schade um den schönen Code, aber ein Dataset wird
        nur als XML-Struktur benötigt, nicht mehr als JS-Objekt

        // Jetzt alle <tags> dem Objekt als Property, welches wieder ein Objekt ist, hinzufügen
        // Wenn das <tag> jedoch ein Attribut 'id' hat, dann mach doch ein Array.
        if ([attributeDict valueForKey:@"id"])
        {
            [self.jsHead2Output appendString:self.lastUsedDataset];
            [self addEnclosingElementsToDatasetProperty];
            [self.jsHead2Output appendFormat:@".%@ = ['%@'];\n",elementName,[attributeDict valueForKey:@"id"]];
        }
        else
        {
            [self.jsHead2Output appendString:self.lastUsedDataset];
            [self addEnclosingElementsToDatasetProperty];
            [self.jsHead2Output appendFormat:@".%@ = {};\n",elementName];
        }


        // Dann bekommen die internen Objekt-Propertys die Attribute als Propertys mit
        NSArray *keys = [attributeDict allKeys];
        if ([keys count] > 0)
        {
            for (NSString *key in keys)
            {
                NSString *s = [attributeDict valueForKey:key];

                s = [self escapeSomeCharsInAttributeValues:s];

                // Weil wir 'id' ja weiter oben berücksichtigt haben
                if (![key isEqualToString:@"id"])
                {
                    [self.jsHead2Output appendString:self.lastUsedDataset];
                    [self addEnclosingElementsToDatasetProperty];
                    [self.jsHead2Output appendFormat:@".%@.%@ = \"%@\";\n",elementName,key,s];
                }
            }
        }
        */






        self.datasetItemsCounter++;

        // In den Strings von datasets können auch <br />'s drin sein, usw.
        self.weAreCollectingTextAndThereMayBeHTMLTags = YES;


        // Aber das muss ich hier noch aufrufen, wegen dem vorzeitigen return:
        [self initTextAndKeyInProgress:elementName];


        // Nicht weiter auswerten hier! Das sind selbst definierte Tags. Die werden nicht matchen
        // Es wurde eh alles erledigt (dataset-Eintrag wurde als property in das Objekt übernommen)
        return;
    }


    // skipping all Elements in fileUpload (ToDo) (and other elements)
    if (self.weAreCollectingTheCompleteContentInClass)
    {
        // Wenn wir in <class> sind, sammeln wir alles (wird erst später rekursiv ausgewertet)


        // Erst eventuell gefundenen Text hinzufügen
        NSString *s = [self holDenGesammeltenTextUndLeereIhn];
        // Alle '&' und '<' müssen ersetzt werden, sonst meckert der XML-Parser
        // Das &-ersetzen muss natürlich als erstes kommen, weil ich danach ja wieder
        // welche einfüge (durch die Entitys).
        s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
        if ([s length] > 0)
            [self.collectedContentOfClass appendString:s];



        // Dann den Elementnamen hinzufügen
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

                NSString *v = [attributeDict valueForKey:key];

                v = [self escapeSomeCharsInAttributeValues:v];

                [self.collectedContentOfClass appendString:v];
                [self.collectedContentOfClass appendString:@"\""];
            }
        }

        [self.collectedContentOfClass appendString:@">"];

        // Falls der unverändert bleibt, muss ich das eben gesetzte '>' wieder entfernen und durch '/>' ersetzen
        self.element_merker = elementName;


        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@!", elementName]);

        // Ohne das hier war textInProgress = nil und es gab massive Probleme beim auslesen
        // von Funktionstext... (<handler>-Funktionstext-</handler>) 3 Stunden Zeit....
        [self initTextAndKeyInProgress:elementName];

        return;
    }



    if (self.weAreSkippingTheCompleteContentInThisElement)
    {
        NSLog([NSString stringWithFormat:@"\nSkipping the Element %@", elementName]);
        return;
    }


    // Skipping the elements in all when-truncs, except the first one
    if (self.weAreInTheTagSwitchAndNotInTheFirstWhen)
    {
        NSLog([NSString stringWithFormat:@"\nSkipping the opening Element %@, (Because we are in <switch>, but not in the first <when>)", elementName]);
        return;
    }

    // Muss nach dieser when-truncs-Abfrage kommen, deswegen oben teilweise
    // nochmal diese Initialisierung
    [self initTextAndKeyInProgress:elementName];


    NSLog([NSString stringWithFormat:@"\nOpening Element: %@ (Neue Verschachtelungstiefe: %d)", elementName,self.verschachtelungstiefe]);
    NSLog([NSString stringWithFormat:@"with these attributes: %@\n", attributeDict]);




    if ([elementName isEqualToString:@"window"] ||
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"radiogroup"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"rotateNumber"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"BDSedit"] ||
        [elementName isEqualToString:@"BDStext"] ||
        [elementName isEqualToString:@"statictext"] ||
        [elementName isEqualToString:@"text"] ||
        [elementName isEqualToString:@"inputtext"] ||
        [elementName isEqualToString:@"button"] ||
        [elementName isEqualToString:@"rollUpDownContainer"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"baselist"] ||
        [elementName isEqualToString:@"list"] ||
        [elementName isEqualToString:@"baselistitem"] ||
        [elementName isEqualToString:@"textlistitem"] ||
        [elementName isEqualToString:@"rollUpDown"])
            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];




    // Sollte als erstes stehen, damit der zuletzt gesetzte Zähler, auf den hier zurückgegriffen wird, noch stimmt.
    if ([elementName isEqualToString:@"simplelayout"])
    {
        element_bearbeitet = YES;

        NSString* spacing = @"0";
        if ([attributeDict valueForKey:@"spacing"])
        {
            self.attributeCount++;

            spacing = [attributeDict valueForKey:@"spacing"];

            if ([spacing hasPrefix:@"$"])
            {
                spacing = [self makeTheComputedValueComputable:spacing];
            }
        }


        // Name... puh... dabei hat SimpleLayout gar kein eigenes div..
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'name'.");
        }

        // Falls kein Wert für axis gesetzt ist, ist es immer y

        // Simplelayout mit Achse Y berücksichtigen
        if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"y"] || ![attributeDict valueForKey:@"axis"])
        {
            if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"y"])
                self.attributeCount++;


            // Anstatt nur TRUE gleichzeitig darin die Verschachtelungstiefe speichern
            // somit wird simplelayout nur in der richtigen Element-Ebene angewandt
            self.simplelayout_y = self.verschachtelungstiefe;


            // spacing müssen wir auch sichern und später berücksichtigen
            [self.simplelayout_y_spacing addObject:spacing];


            // SimpleLayout-Tiefenzähler (y) um 1 erhöhen
            self.simplelayout_y_tiefe++;


            /*******************/
            // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Breite
            // der beinhaltenden Elemente an.
            // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
            // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
            [self korrigiereBreiteDesUmgebendenDivBeiSimpleLayout];
            /*******************/


            // Auch noch die Höhe setzen! (Damit die Angaben im umgebenden Div stimmen)
            // Da sich valign=middle auf die Höhenangabe bezieht, muss diese mit jQueryOutput0
            // noch vor allen anderen Angaben gesetzt werden.
            // Jedoch darf die Höhe nicht bei RollUpDownContainern gesetzt werden, da diese immer
            // auf 'auto' gestellt sein müssen, damit es gescheit mit scrollt.

            // Erst sammeln:
            NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

            [s appendString:@"\n  // SA Y:\n"];
            [s appendFormat:@"  adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY(%@,%@);\n",self.zuletztGesetzteID,[self.simplelayout_y_spacing lastObject]];

            // An den Anfang des Strings setzen
            // Die Breite muss bekannt sein, bevor das Simplelayout als solches ausgeführt wird!
            // Andererseits muss es nach evtl. klonen (multiple datapaths) kommen, die in ComputeValues stecken.
            // Beispiel 11.3
            // Außerdem muss es vor adjustHeightAndWidth bekannt sein, damit hier diese Korrektur als erstes
            // ausgeführt wird (aufaddieren von children, im Gegensatz zu nur dem breitesten children).
            // Denn SA-Korrekturen haben immer Vorrang vor dem normalen adjustHeightAndWidth().
            [self.jsConstraintValuesOutput insertString:s atIndex:0];
            //[self.jsOutput insertString:s atIndex:0];



            [self becauseOfSimpleLayoutYMoveTheChildrenOfElement:[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2] withSpacing:spacing andAttributes:attributeDict];
        }



        // Simplelayout mit Achse X berücksichtigen
        if ([[attributeDict valueForKey:@"axis"] hasSuffix:@"x"])
        {
            self.attributeCount++;


            // Anstatt nur TRUE gleichzeitig darin die Verschachtelungstiefe speichern
            // somit wird simplelayout nur in der richtigen Element-Ebene angewandt
            self.simplelayout_x = self.verschachtelungstiefe;

            // spacing müssen wir auch sichern und später berücksichtigen
            [self.simplelayout_x_spacing addObject:spacing];


            // SimpleLayout-Tiefenzähler (x) um 1 erhöhen
            self.simplelayout_x_tiefe++;


            /*******************/
            // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Höhe
            // der beinhaltenden Elemente an.
            // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
            // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
            [self korrigiereHoeheDesUmgebendenDivBeiSimpleLayout];
            /*******************/


            // Auch noch die Breite setzen! (Damit die Angaben im umgebenden Div stimmen)
            // Da sich valign=middle auf die Höhenangabe bezieht, muss diese mit jQueryOutput0
            // noch vor allen anderen Angaben gesetzt werden.
            // Update: Bricht Element9 (z.B.), es wird dann zu breit, deswegen bei
            // position:absolute es sich per CSS-Angabe -> width:Auto und float:left sich selbst
            // optimal ausrichten lassen.
            // Nur bei position:relative muss ich nachhelfen, weil es dort sonst 0 wäre
            // Auf sowas erstmal zu kommen.... oh man.
            // Neu: Ich richte es immer korrekt aus, selbst bei position:absolute muss ich nachhelfen!
            // Deswegen die Einschränkung auf position:relative unten auskommentiert

            // Erst sammeln:
            NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

            [s appendString:@"\n  // SA X:\n"];
            [s appendFormat:@"  adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX(%@,%@);\n",self.zuletztGesetzteID,[self.simplelayout_x_spacing lastObject]];


            // An den Anfang des Strings setzen
            // Die Breite muss bekannt sein, bevor das Simplelayout als solches ausgeführt wird!
            // Andererseits muss es nach evtl. klonen (multiple datapaths) kommen, die in ComputeValues stecken.
            // Beispiel 11.3
            // Außerdem muss es vor adjustHeightAndWidth bekannt sein, damit hier diese Korrektur als erstes
            // ausgeführt wird (aufaddieren von children, im Gegensatz zu nur dem breitesten children).
            // Denn SA-Korrekturen haben immer Vorrang vor dem normalen adjustHeightAndWidth().
            [self.jsConstraintValuesOutput insertString:s atIndex:0];



            [self becauseOfSimpleLayoutXMoveTheChildrenOfElement:[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2] withSpacing:spacing andAttributes:attributeDict];
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
    // face auch noch wegen example 9.9
    if ([elementName isEqualToString:@"font"] || [elementName isEqualToString:@"face"])
    {
        element_bearbeitet = YES;
        NSLog(@"Setting the element 'font' as CSS '@font-face'.");

        NSString *name = @"";
        if (![attributeDict valueForKey:@"name"])
        {
            if ([elementName isEqualToString:@"face"])
                name = self.lastUsedNameAttributeOfFont;
            else
                [self instableXML:@"ERROR: No attribute 'name' given in font- or face-tag"];
        }
        else
        {
            self.attributeCount++;

            name = [attributeDict valueForKey:@"name"];
            self.lastUsedNameAttributeOfFont = name;
        }

        if ([attributeDict valueForKey:@"src"])
            self.attributeCount++;

        if ([attributeDict valueForKey:@"style"])
            self.attributeCount++;


        NSString *weight;
        if ([attributeDict valueForKey:@"style"])
            weight = [attributeDict valueForKey:@"style"];
        else
            weight = @"normal";


        [self.cssOutput appendString:@"@font-face {\n  font-family: "];
        [self.cssOutput appendString:name];
        [self.cssOutput appendString:@";\n"];

        if ([attributeDict valueForKey:@"src"])
            [self.cssOutput appendFormat:@"  src: url('%@');\n",[attributeDict valueForKey:@"src"]];

        [self.cssOutput appendString:@"  font-style: normal;\n"];
        [self.cssOutput appendString:@"  font-weight: "];
        [self.cssOutput appendString:weight];
        [self.cssOutput appendString:@";\n}\n\n"];
    }


    if ([elementName isEqualToString:@"canvas"])
    {
        element_bearbeitet = YES;


        //if (![attributeDict valueForKey:@"id"])
        if (NO)
        {
            self.zuletztGesetzteID = @"canvas";

            [self.output appendFormat:@"<div id=\"%@\"",self.zuletztGesetzteID];
        }
        else
        {
            [self.output appendString:@"<div"];

            [self addIdToElement:attributeDict];

            // Falls er selber für canvas eine id setzt, muss trotzdem die Referenz auf canvas
            // erhalten bleiben (ungetestet)
            // Keine Ahnung ob das so stimmt, ansonsten diesen If-Else-Zweig einfach entfernen
            // Und nur das was im if steht behalten!?
            //[self.jQueryOutput0 appendFormat:@"  var canvas = document.getElementById('%@');\n",self.zuletztGesetzteID];
            // Puh, ich kann dich 'canvas' nicht einfach überschreiben...
        }

        [self.output appendString:@" class=\"canvas_standard\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict toElement:elementName]];

        [self.output appendString:@"\">\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];
    }

    if ([elementName isEqualToString:@"debug"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"x"])
        {
            self.attributeCount++;

            [self.jQueryOutput appendString:@"\n  // Debug-Fenster soll eine andere x-Position haben\n"];
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').css('left','%@px');\n\n",[attributeDict valueForKey:@"x"]];
        }

        if ([attributeDict valueForKey:@"y"])
        {
            self.attributeCount++;

            [self.jQueryOutput appendString:@"\n  // Debug-Fenster soll eine andere y-Position haben\n"];
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').css('top','%@');\n\n",[attributeDict valueForKey:@"y"]];
        }

        if ([attributeDict valueForKey:@"height"])
        {
            self.attributeCount++;
            
            [self.jQueryOutput appendString:@"\n  // Debug-Fenster soll eine andere Höhe haben\n"];
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').height('%@');\n",[attributeDict valueForKey:@"height"]];
            // Mindestens bei %-Angaben, aber vermutlich immer, muss ich auch noch
            // den Rahmen (oben+unten) abziehen und Padding (oben+unten) (Bsp. lz.Formatter - Beispiel 5)
            [self.jQueryOutput appendString:@"  // Abzüglich Padding oben+unten (2*10) und border-width (2*5);\n"];
            [self.jQueryOutput appendString:@"  $('#debugWindow').height($('#debugWindow').height()-30);\n"];

            // Bricht bei %-Angaben:
            //[self.jQueryOutput appendFormat:@"  $('#debugInnerWindow').css('height','%dpx');\n\n",[[attributeDict valueForKey:@"height"] intValue]-30];
            // Deswegen einfach direkt auf den eben ausgerechneten Wert beziehen:
            [self.jQueryOutput appendString:@"  $('#debugInnerWindow').height($('#debugWindow').height()-30);\n\n"];
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






        // Alle nachfolgenden Tags in eine eigene Data-Struktur überführen
        // und diese Tags nicht auswerten lassen vom XML-Parser.
        // Aber wieder rückgängig machen in <items>, falls wir darauf stoßen und
        // das dataset also damit strukturiert ist (und nicht mit eigenen Begriffen)!
        // Muss (logischerweise) vor der Rekursion stehen, deswegen steht es hier oben
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = YES;






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
            if ([attributeDict valueForKey:@"querytype"])
            {
                self.attributeCount++;
                NSLog(@"Skipping the attribute 'querytype'.");
                if ([[attributeDict valueForKey:@"querytype"] isEqualToString:@"POST"])
                    NSLog(@"I will ignore this src-file for now (it's a POST-Request).");
                else
                    NSLog(@"I will ignore this src-file for now (it's a GET-Request).");

                // Trotzdem anlegen, damit das Programm nicht laufend abstürzt.
                [self.jsHead2Output appendString:@"\n// Ein Dataset, welches noch ausgewertet werden muss (ToDo). Aber ich lege trotzdem schonmal ein Objekt an, damit Attribute und Methoden erfolgreich daran gebunden werden können.\n"];
                [self.jsHead2Output appendFormat:@"%@ = new lz.dataset('%@'); // muss vom Typ dataset sein, damit er auf die Methode 'setQueryParam' z. B. zugreifen kann\n",self.lastUsedDataset, self.lastUsedDataset, self.lastUsedDataset];
            }
            else
            {
                NSLog([NSString stringWithFormat:@"'src'-Attribute in dataset found! So I am calling myself recursive with the file %@",[attributeDict valueForKey:@"src"]]);

                [self legeDatasetAnUndInitMitOeffnendemTag];

                [self callMyselfRecursive:[attributeDict valueForKey:@"src"]];
            }

            // Nach dem Verlassen der Rekursion müssen wir nicht länger ein Dataset auswerten
            self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
        }
        else
        {
            [self legeDatasetAnUndInitMitOeffnendemTag];

            // Legacy-Code: Falls ich auf <items> stoße, wird die Var noch überschrieben
            // Und ich speichere es weiter als Array. (ToDo - Muss auch wohl XML werden!)
        }
    }


    if ([elementName isEqualToString:@"datapointer"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as JS-var-name for the datapointer.");
        }

        if ([attributeDict valueForKey:@"id"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'id' as JS-var-name for the datapointer.");
        }


        if ([attributeDict valueForKey:@"xpath"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'xpath' as argument for the datapointer.");
        }
        else
        {
            [self instableXML:@"Ein datapointer ohne 'xpath'-Attribut macht wohl keinen Sinn."];
        }
        NSString *dp = [attributeDict valueForKey:@"xpath"];
        // In Anführungszeichen setzen:
        if ([dp length] > 0)
            dp = [NSString stringWithFormat:@"'%@'",dp];


        // Den Namen für den Datapointer ermitteln. Entweder anhand 'name' oder 'id'.
        // Wenn beides dann id bevorzugen
        NSString *name = @"";
        if ([attributeDict valueForKey:@"name"])
            name = [attributeDict valueForKey:@"name"];
        if ([attributeDict valueForKey:@"id"])
            name = [attributeDict valueForKey:@"id"];

        // Ich lege jeden datapointer als globales Objekt an, auf welches zugegriffen werden kann
        if ([name length] > 0)
        {
            [self.jQueryOutput appendString:@"\n  // Ein Datapointer (bewusst ohne var, damit global verfügbar)\n"];
            [self.jQueryOutput appendFormat:@"  %@ = new lz.datapointer(%@);\n",name,dp];
        }
        else
        {
            name = @"pointerWithoutName";

            [self.jQueryOutput0 appendString:@"\n  // Ein Datapointer ohne 'name'- oder 'id'-Attribut. Wohl nur um ein Handler daran zu binden oder so... hmmm\n"];
            [self.jQueryOutput0 appendFormat:@" %@ = new lz.datapointer(%@);\n",name,dp];

            // Dann jQueryOutput0, sonst kann die Methode sich nicht daran binden
            // Beispiel 11.4
        }

        // Falls gleich eine Methode kommt, die sich an diesen Pointer binden möchte
        self.lastUsedNameAttributeOfDataPointer = name;


        [self addJSCode:attributeDict withId:name];
    }





    // ToDo falls kommerziell: Die gefunden Attribute automatisch hinzufügen zur Klasse und
    // nicht wie hier, weil wir wissen welche Attribute es alles gibt bei 'item'
    if (werteItemUndItemsAlsArrayAus)
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
                [self.jsHead2Output appendFormat:@"%d",self.datasetItemsCounter];
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


            NSString *src = [attributeDict valueForKey:@"src"];

            src = [self onRecursionEnsureValidPath:src];

            
            [self.jsHeadOutput appendString:@"var "];
            [self.jsHeadOutput appendString:[attributeDict valueForKey:@"name"]];
            [self.jsHeadOutput appendString:@" = \""];
            [self.jsHeadOutput appendString:src];
            [self.jsHeadOutput appendString:@"\";\n"];



            // Auch intern die Var speichern
            [self.allJSGlobalVars setObject:src forKey:[attributeDict valueForKey:@"name"]];

            // Für das preloaden auch den Pfad der Bilddatei nochmal extra sichern.
            [self.allImgPaths addObject:src];
        }
        else if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;

            // Ansonsten machen wir im tag 'frame' weiter
            self.last_resource_name_for_frametag = [attributeDict valueForKey:@"name"];
        }
    }




    // Attribute beziehen sich immer auf das Element in dem sie sich befinden.
    // <view width="50"></view> entspricht
    //
    // <view>
    //   <attribute name="width" value="50"/>
    // </view>
    // => Gelöst über setter/getter in JS mittels Object.defineProperty
    // ToDo: Noch für alle Eigenschaften von OpenLaszlo anlegen.
    if ([elementName isEqualToString:@"attribute"])
    {
        element_bearbeitet = YES;


        if (![attributeDict valueForKey:@"name"])
            [self instableXML:@"ERROR: No attribute 'name' given in attribute-tag"];
        else
            self.attributeCount++;


        NSString* a = [attributeDict valueForKey:@"name"];

        // Es gibt 2 Attribute, die ich ja austausche, 'height' und 'width', sonst bricht soooo viel
        // irgendwie greift auch jQuery intern auf diese Werte zu.
        // Deswegen ersetzen, falls sie per Attribute gesetzt werden.
        // (wenn sie direkt im tag stehen (<tag width="20">), ist es natürlich okay,
        // wird ja dann direkt verarbeitet)
        a = [self somePropertysNeedToBeRenamed:a];


        // Es gibt auch attributes ohne type, dann mit 'number' initialisieren...
        // ... das klappt leider nicht. Weil es auch Nichtzahlen gibt ohne 'type'
        // Deswegen doch lieber als 'string' initialisieren.
        // Das klappt auch nicht...
        // ich muss dann das Element direkt untersuchen und entscheiden
        NSString *type_;
        if ([attributeDict valueForKey:@"type"])
        {
            NSLog(@"Using the attribute 'type' to determine if we need quotes.");
            self.attributeCount++;
            type_ = [attributeDict valueForKey:@"type"];
        }
        else
        {
            if (isNumeric([attributeDict valueForKey:@"value"]))
                type_ = @"number";
            else
                type_ = @"string";
        }


        // Es gibt auch attributes ohne Startvalue, dann mit einem leeren String initialisieren
        NSString *value;
        if ([attributeDict valueForKey:@"value"])
        {
            NSLog(@"Setting the attribute 'value' as value of the class-member (see next line).");
            self.attributeCount++;
            value = [attributeDict valueForKey:@"value"];

            // Bei width und height muss ich es anpassen, wegen Beispiel 12 - Using getAttribute
            // to retrieve an attribute value:
            // <canvas height="40" debug="false">
            // <simplelayout/>
            // <view name="myView" width="20" height="20" bgcolor="red"/>
            // <attribute name="whatAttr" type="string" value="height"/>
            // <text oninit="this.format('myView.%s = %d', canvas.whatAttr, myView[canvas.whatAttr])"/>
            // </canvas>
            // Das Beispiel zeigt, dass auf height und width auch per Objekt-Property zugegriffen
            // werden kann per String-Access (die eckigen Klammern)
            // Deswegen müssen alle Variablennamen  die den String-Wert 'height' oder 'width'
            // haben, angepasst werden
            if ([type_ isEqualToString:@"string"])
                value = [self somePropertysNeedToBeRenamed:value];
        }
        else
        {
            value = @""; // Quotes werden dann automatisch unten reingesetzt
        }


        // Das Attribut 'setter' hmmm, ToDo
        if ([attributeDict valueForKey:@"setter"])
        {
            NSLog(@"Skipping the attribute 'setter' (ToDo).");
            self.attributeCount++;
        }


        if ([attributeDict valueForKey:@"when"])
        {
            if ([[attributeDict valueForKey:@"when"] isEqualToString:@"once"])
            {
                NSLog(@"Skipping the attribute 'when'.");
                self.attributeCount++;
            }
        }



        NSLog([NSString stringWithFormat:@"Setting '%@' as object-attribute in JavaScript-object.",a]);

        BOOL weNeedQuotes = YES;
        if ([type_ isEqualTo:@"boolean"] || [type_ isEqualTo:@"number"])
            weNeedQuotes = NO;

        // Wenn er schon in einfachen Hochkommata ist, dann nicht zusätzliche drum.
        // Sonst bricht Beispiel 10.17
        if ([value hasPrefix:@"'"] && [value hasSuffix:@"'"])
            weNeedQuotes = NO;

        // Kann auch ein berechneter Werte sein ($ davor). Wenn ja dann $ usw. entfernen
        // und wir arbeiten dann natürlich ohne Quotes.
        BOOL berechneterWert = NO;
        if ([value hasPrefix:@"$"])
        {
            value = [self makeTheComputedValueComputable:value];

            weNeedQuotes = NO;

            berechneterWert = YES;
        }



        // Wenn wir in einer Klasse sind, alle Attribute der Klasse intern mitspeichern
        // Denn sie müssen vor jedem instanzieren der Klasse mit ihren Startwerten
        // initialisiert werden (spätere Überschreibungen sind möglich).
        if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
        {
            NSString *className = self.lastUsedNameAttributeOfClass;
            
            if (![self.allFoundClasses objectForKey:className])
                [self instableXML:@"Nunja, das geht so nicht. Wenn ich Attribute hinzufüge zu einer Klasse, muss ich ja vorher auf diese Klasse gestoßen sein!"];

            NSMutableDictionary *attrDictOfClass = [self.allFoundClasses objectForKey:className];

            if (berechneterWert)
            {
                [attrDictOfClass setObject:[NSString stringWithFormat:@"@§.BERECHNETERWERT.§@%@",value] forKey:a];
            }
            else
            {
                [attrDictOfClass setObject:value forKey:a];
            }
        }
        else
        {
            NSString *elem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

            NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];

            if ([elemTyp isEqualToString:@"canvas"] || [elemTyp isEqualToString:@"library"])
                elem = @"canvas";

            // Hier drin sammle ich erstmal alle Ausgaben
            NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


            // Folgendes Szenario: Wenn eine selbst definierte Klasse ein Attribut definiert, aber gleichzeitig
            // dieses erbt, dann hat das selbst definierte Vorrang. Deswegen überschreibe ich das Attribut
            // innerhalb der Klasse nicht! Dazu teste ich einfach vorher, ob es auch wirklich undefined ist!
            // Puh, ka, ob das so zu halten ist, zumindest schon mal bei 'title' bricht es, weil von JS vordefiniert
            // Auch bei 'bgcolor' bricht es, weil von openLaszlo vordefiniert! Und ich deswegen
            // dafür einen getter angelegt habe. Da der getter existiert, kann es nie undefined
            // geben!
            // => Deswegen habe ich die ganze Abfrage rausgenommen.
            // => Es ist wohl nur bei methoden nötig.
            //if (![[attributeDict valueForKey:@"name"] isEqualToString:@"title"])
            //    [o appendFormat:@"\n  if (%@.%@ == undefined)",elem,a];



            // Wenn wir ein Attribut eines Datasets haben, dann binde ich an self.lastUsedDataset
            // Denn Datasets werden oft nur per 'name' gesetzt und nicht per 'id'
            if ([elemTyp isEqualToString:@"dataset"])
            {
                [o appendFormat:@"\n// Ein per <attribute> gesetztes Attribut des Elements %@ (Objekttyp: %@)", self.lastUsedDataset, elemTyp];
                [o appendFormat:@"\n%@.",self.lastUsedDataset];
            }
            else
            {
                [o appendFormat:@"\n  // Ein per <attribute> gesetztes Attribut des Elements %@ (Objekttyp: %@)", elem, elemTyp];
                [o appendFormat:@"\n  %@.",elem];
            }




            [o appendFormat:@"%@ = ",a];
            if (weNeedQuotes)
                [o appendString:@"\""];
            [o appendString:value];
            if (weNeedQuotes)
                [o appendString:@"\""];
            [o appendString:@";\n"];


            // Erstmal mir hier drin. Eventuell aber auch erst nach der geschweiften Klammer
            // Und erstmal nicht, wenn wir in canvas sind (globale Attribute)
            if (berechneterWert)
            {
                NSString *orignalValueString = [attributeDict valueForKey:@"value"];
                orignalValueString = [self removeOccurrencesOfDollarAndCurlyBracketsIn:orignalValueString];
                // Damit width zu myWidth wird z. B.:
                orignalValueString = [self modifySomeExpressionsInJSCode:orignalValueString];


                // ToDo ToDo ToDo
                // Wenn ein '+' enthalten ist, das wird noch nicht unterstützt
                // Mögliches Vorgehen: Methode auslagern bei ConstraintValue und hier auch aufrufen
                if ([orignalValueString rangeOfString:@"+"].location == NSNotFound)
                {
                    /*
                    NSRange positionDesPunktes = [orignalValueString rangeOfString:@"."];
                    NSString *zuWatchendeVar = [orignalValueString substringFromIndex:positionDesPunktes.location+1];

                    [o appendString:@"  // Zusätzlich watchen der Variable, da es ein berechneter Wert ist\n"];
                    [o appendFormat:@"  %@.watch('%@', function(prop, oldval, newval) { %@.%@ = newval; })\n",elem,zuWatchendeVar,elem,a];
                    */
                    // Neu:
                    NSArray *tempArray = [orignalValueString componentsSeparatedByString: @"."];
                    NSString *theObject = [tempArray objectAtIndex:0];
                    NSString *theProperty = [tempArray objectAtIndex:[tempArray count]-1];
                    // Falls es mehr als 2 Element im Array gibt, alle mittleren Elemente
                    // dem objekt hinzufügen.
                    if ([tempArray count] > 2)
                    {
                        for (int i=1;i<[tempArray count]-1;i++)
                        {
                            theObject = [NSString stringWithFormat:@"%@.%@",theObject,[tempArray objectAtIndex:i]];
                        }
                    }
                    [o appendString:@"  // Zusätzlich auf event horchen, da es ein berechneter Wert ist und triggern, falls jemand auf UNS horcht\n"];
                    [o appendFormat:@"  $(%@.%@).on('on%@', function(prop, newval) { %@.%@ = newval; $(%@).triggerHandler('on%@',newval); });\n",elem,theObject,theProperty,elem,a,elem,a];
                }
            }


            // War früher mal jsHeadOutput, aber die Elemente sind ja erst nach Instanzierung
            // bekannt, deswegen jQueryOutput0
            // (damit es noch vor den Computed Values und Constraint Values bekannt ist)
            // canvas zu, die ja bereits bekannt sein müssen!
            // Wenn wir ein Attribut eines Datasets haben, dann direkt hinter das dataset schreiben
            if ([elemTyp isEqualToString:@"dataset"])
            {
                [self.jsHead2Output appendString:o];
            }
            else
            {
                [self.jQueryOutput0 appendString:o];
            }
        }





        // 'defaultplacement' wird, falls wir in einer Klasse sind, ausgelesen und gesetzt.
        // ToDo: Das ist wohl nicht mehr nötig, seitdem ich ALLE Attribute eh vor dem instanzieren
        // der Klasse schreibe
        if (self.ignoreAddingIDsBecauseWeAreInClass && [a isEqualToString:@"defaultplacement"])
            self.defaultplacement = [attributeDict valueForKey:@"value"];




        // Auch intern die Var speichern? Erstmal nein. Wir wollen bewusst per JS/jQuery immer
        // drauf zugreifen! Weil die Variablen nach dem Export noch benutzbar sein sollen.
        // Wenn in einer Klasse mittels Variable auf eine resource zugegriffen wird, dann muss
        // ich doch auf diese Variable später zugreifen können! Deswegen alle Vars intern mitspeichern
        // Vermutlich etwas overhead, da bisher nur für diesen einen Anwendungsfall. Aber es funktioniert.
        [self.allJSGlobalVars setObject:value forKey:a];
    }






    if ([elementName isEqualToString:@"frame"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"src"])
            [self instableXML:@"ERROR: No attribute 'src' given in frame-tag"];
        else
            self.attributeCount++;

        NSString *src = [attributeDict valueForKey:@"src"];

        src = [self onRecursionEnsureValidPath:src];


        // Erstmal alle frame-Einträge sammeln, weil wir nicht wissen wie viele noch kommen
        [self.collectedFrameResources addObject:src];

        // Für das preloaden auch den Pfad der Bilddatei nochmal extra sichern.
        [self.allImgPaths addObject:src];
    }



    if ([elementName isEqualToString:@"window"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div class=\"div_window ui-corner-all\""];

        [self addIdToElement:attributeDict];

        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict toElement:elementName]];

        [self.output appendString:@"\">\n"];


        NSString *title = @"";
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' as title of the window.");

            title = [attributeDict valueForKey:@"title"];
        }

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendFormat:@"<div id=\"%@_title\" class=\"div_text div_windowTitle\">%@</div>\n", self.zuletztGesetzteID, title];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendFormat:@"<div id=\"%@_content\" class=\"div_windowContent\">\n", self.zuletztGesetzteID];

        if ([attributeDict valueForKey:@"height"])
        {
            // Ich muss auch von windowContent die Height anpassen, falls diese gesetzt wurde.
            [self.jQueryOutput appendString:@"\n  // Wenn bei <window> die height gesetzt wurde: Auch vom div_windowContent die Height dann anpassen"];
            [self.jQueryOutput appendFormat:@"\n  $(%@_content).height(%@-25);\n",self.zuletztGesetzteID, [attributeDict valueForKey:@"height"]];

            title = [attributeDict valueForKey:@"title"];
        }

        if ([attributeDict valueForKey:@"width"])
        {
            // Ich muss auch von windowContent die width anpassen, falls diese gesetzt wurde.
            [self.jQueryOutput appendString:@"\n  // Wenn bei <window> die width gesetzt wurde: Auch vom div_windowContent die width dann anpassen"];
            [self.jQueryOutput appendFormat:@"\n  $(%@_content).width(%@);\n",self.zuletztGesetzteID, [attributeDict valueForKey:@"width"]];

            title = [attributeDict valueForKey:@"title"];
        }

        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"closeable"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'closeable' for now.");
        }

        if ([attributeDict valueForKey:@"resizable"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'resizable' as resizable window.");

            [self.jQueryOutput appendFormat:@"\n  // Window is resizable\n"];
            [self.jQueryOutput appendFormat:@"  %@.setAttribute_('resizable','true');\n",self.zuletztGesetzteID];
            /* Code steckt jetzt in setAttrbute_
            [self.jQueryOutput appendFormat:@"  $('#%@').resizable();\n",self.zuletztGesetzteID];
            [self.jQueryOutput appendFormat:@"  $('#%@').on('resize', function(event,ui) {\n    %@_content.setAttribute_('width',ui.size.width);\n    %@_content.setAttribute_('height',ui.size.height-20);\n    $(this).triggerHandler('onwidth',ui.size.width);\n    $(this).triggerHandler('onheight',ui.size.height);\n  });\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
            [self.jQueryOutput appendFormat:@"  $('#%@').on('resizestop', function(event,ui) {\n    %@_content.setAttribute_('width',ui.size.width);\n    %@_content.setAttribute_('height',ui.size.height-20);\n    $(this).triggerHandler('onwidth',ui.size.width);\n    $(this).triggerHandler('onheight',ui.size.height);\n  });\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
             */
        }

        [self.jQueryOutput appendFormat:@"\n  // Window is draggable\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').draggable();\n",self.zuletztGesetzteID];
        [self.jQueryOutput appendFormat:@"  $('#%@').on('drag', function(event,ui) {\n    $(this).triggerHandler('ony',ui.position.top);\n    $(this).triggerHandler('onx',ui.position.left);\n  });\n",self.zuletztGesetzteID];
        [self.jQueryOutput appendFormat:@"  $('#%@').on('dragstop', function(event,ui) {\n    $(this).triggerHandler('ony',ui.position.top);\n    $(this).triggerHandler('onx',ui.position.left);\n  });\n",self.zuletztGesetzteID];


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];
    }





    if ([elementName isEqualToString:@"html"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];

        [self.output appendString:@" class=\"iframe_standard\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\" />\n"];

        if ([attributeDict valueForKey:@"history"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'history' for now.");
        }

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];
    }






    if ([elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"radiogroup"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"rotateNumber"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];


        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];


        // Wird derzeit noch übersprungen (ToDo)
        if ([attributeDict valueForKey:@"ignoreplacement"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'ignoreplacement' on view (ToDo).");
        }


        if ([attributeDict valueForKey:@"placement"])
        {
            self.attributeCount++;

            // Es gibt nur einmal im gesamten Code das Attribut placement mit _info
            // Die zugehörige Klasse '_info' ist in BDSlib.lzx definiert
            if ([[attributeDict valueForKey:@"placement"] isEqualToString:@"_info"])
            {
                [self.jQueryOutput appendString:@"\n  // Anstatt 'placement' auszuwerten...\n"];
                [self.jQueryOutput appendFormat:@"  $('#%@').css('background-color','#D3964D');\n",theId];
                // [self.jQueryOutput appendFormat:@"  $('#%@').css('border-right','#D29860 1px solid');\n",id];
                [self.jQueryOutput appendFormat:@"  $('#%@').css('left','2px');\n",theId];
                [self.jQueryOutput appendFormat:@"  $('#%@').css('top','39px');\n",theId]; // 39 anstatt 40, damit der Strich am iPad verschwindet
                [self.jQueryOutput appendFormat:@"  $('#%@').css('width','inherit');\n",theId];
                [self.jQueryOutput appendFormat:@"  $('#%@').css('height','50px');\n",theId];
                [self.jQueryOutput appendFormat:@"  $('#%@').children().filter(':last').css('top','8px');\n",theId];
            }
        }


        [self.output appendString:@" class=\"div_standard noPointerEvents\" style=\""];


        [self.output appendString:[self addCSSAttributes:attributeDict]];


        [self.output appendString:@"\">\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];


        // ToDo Weg damit
        if ([attributeDict valueForKey:@"negativecolor"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"positivecolor"])
            self.attributeCount++;


        if ([elementName isEqualToString:@"hbox"])
        {
            NSString *spacing = @"0";
            if ([attributeDict valueForKey:@"spacing"])
            {
                self.attributeCount++;
                spacing = [attributeDict valueForKey:@"spacing"];
            }

            [self becauseOfSimpleLayoutXMoveTheChildrenOfElement:theId withSpacing:spacing andAttributes:attributeDict];
        }
    }





    if ([elementName isEqualToString:@"button"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<button type=\"button\""];

        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];

        [self.output appendString:@" class=\"input_standard\" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        [self.output appendString:@"\">"];

        // Den Text als Beschriftung für den Button setzen
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' as the label of the button.");

            if ([[attributeDict valueForKey:@"text"] hasPrefix:@"$"])
            {
                [self setTheValue:[attributeDict valueForKey:@"text"] ofAttribute:@"text"];
            }
            else
            {
                //[self.output appendString:@" value=\""];
                //[self.output appendString:[attributeDict valueForKey:@"text"]];
                //[self.output appendString:@"\""];
                // das war früher nötig, als wir noch <input type="button"> hatten
                // Jetzt neu einfach ausgeben:
                [self.output appendString:[attributeDict valueForKey:@"text"]];
            }
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
        if ([attributeDict valueForKey:@"doesenter"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'doesenter' for now.");
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


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }




    if ([elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"])
    {
        element_bearbeitet = YES;


        if ([elementName isEqualToString:@"basebutton"])
            [self.output appendString:@"<!-- Basebutton: -->\n"];
        else
            [self.output appendString:@"<!-- Imagebutton: -->\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];


        [self.output appendString:@"<div"];

        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];


        [self.output appendString:@" class=\"div_standard\" style=\""];


        [self.output appendString:[self addCSSAttributes:attributeDict]];


        [self.output appendString:@"\">\n"];


        // ToDo: Wird derzeit nicht ausgewertet - ist zum ersten mal bei einem imgbutton aufgetaucht (nur da?)
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text' for now.");
        }
        // ToDo: Wird derzeit nicht ausgewertet - ist zum ersten mal bei einem imgbutton aufgetaucht (nur da?)
        if ([attributeDict valueForKey:@"isdefault"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'isdefault' for now.");
        }

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }




    // ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand
    // der definierten Klasse erkannt werden.
    if ([elementName isEqualToString:@"BDStext"] || [elementName isEqualToString:@"statictext"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];


        [self.output appendString:@" class=\"div_text"];

        [self.output appendString:[self addCSSClasses:attributeDict]];

        [self.output appendString:@"\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];

        self.weAreCollectingTextAndThereMayBeHTMLTags = YES;
        NSLog(@"We won't include possible following HTML-Tags, because it is content of the text.");

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];

        [self evaluateTextOnlyAttributes:attributeDict];
    }


    // ToDo ToDo ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand der definierten Klasse erkannt werden
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
                    [self.output appendFormat:@"<input type=\"email\""];
                else
                    [self.output appendFormat:@"<input type=\"text\" pattern=\"%@\"",[attributeDict valueForKey:@"pattern"]];
            }
            else
            {
                [self.output appendString:@"<input type=\"text\""];
            }
        }


        [self addIdToElement:attributeDict];

        [self.output appendString:@"class=\"input_standard\" style=\""];

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

        [self evaluateTextInputOnlyAttributes:attributeDict];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];
    }

    if ([elementName isEqualToString:@"tooltip"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;

            NSLog(@"Setting the attribute 'text' as text for textInProgress.");
            [self.textInProgress appendString:[attributeDict valueForKey:@"text"]];
        }
    }

    // Original von OpenLaszlo eingebautes HTML-<select>-Element
    if ([elementName isEqualToString:@"baselist"] || [elementName isEqualToString:@"list"])
    {
        element_bearbeitet = YES;

        // erstmal size="1" setzen, damit ein Wert existiert, wird beim schließen von </baselist> anhand der
        // gezählten <baselistitem>'s korrigiert (oder anhand des gesetzten Wertes 'shownitems'.
        self.baselistitemCounter = 0;
        [self.output appendString:@"<select class=\"select_standard\" size=\"1\""];

        [self addIdToElement:attributeDict];

        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

        NSString *shownitems = @"-1";
        if ([attributeDict valueForKey:@"shownitems"])
        {
            self.attributeCount++;
            NSLog(@"Saving the attribute 'shownitems' per jQuerys data().");
            shownitems = [attributeDict valueForKey:@"shownitems"];
        }

        [self.jsComputedValuesOutput appendString:@"\n  // Saving the value 'shownitems' of the <select>-element\n"];
        [self.jsComputedValuesOutput appendFormat:@"  $('#%@').data('shownitems',%@);\n",self.zuletztGesetzteID,shownitems];
    }



    // Original von OpenLaszlo eingebautes HTML-<option>-Element
    if ([elementName isEqualToString:@"baselistitem"] || [elementName isEqualToString:@"textlistitem"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<option"];

        [self addIdToElement:attributeDict];

        if ([attributeDict valueForKey:@"selected"] && [[attributeDict valueForKey:@"selected"] isEqualToString:@"true"])
        {
            self.attributeCount++;

            [self.output appendString:@" selected=\"selected\""];
        }

        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];

        self.baselistitemCounter++;


        // datapth-Attribut MUSS zuerst ausgewertet, falls sich Attribut 'text' auf den dort gesetzten Pfad bezieht
        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];


        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' as text between opening and closing tag.");
            
            // [self.output appendString:[attributeDict valueForKey:@"text"]];
            // Kann nicht direkt gesetzt werden, falls constraint oder $path
            [self setTheValue:[attributeDict valueForKey:@"text"] ofAttribute:@"text"];
        }


        if ([attributeDict valueForKey:@"value"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'value' as jQuerys val().");

            [self.jQueryOutput appendFormat:@"\n  // Setting the value of '%@'",self.zuletztGesetzteID];
            [self.jQueryOutput appendFormat:@"  $('#%@').val(%@);\n",self.zuletztGesetzteID,[attributeDict valueForKey:@"value"]];
        }
    }



    if ([elementName isEqualToString:@"BDScombobox"] ||
        [elementName isEqualToString:@"comboboxxxx"]) // ToDo -  als Klasse auslesen
    {
        element_bearbeitet = YES;


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];


        // Umgebendes <Div> für die komplette Combobox inklusive Text
        // WOW, dieses vorangehende <br /> als Lösung zu setzen, hat mich 3 Stunden Zeit gekostet...
        // Quatsch, jetzt nach der neuen Lösung.
        [self.output appendString:@"<div class=\"div_combobox\">\n"];
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

        [self.output appendString:@"<select class=\"select_standard\" size=\"1\""];

        NSString *theId =[self addIdToElement:attributeDict];



        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];

            code = [self makeTheComputedValueComputable:code];

            [self.jQueryOutput appendString:@"\n  // combobox-Text wird hier dynamisch gesetzt\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').prev().text(%@);\n",theId,code];
        }




        [self.output appendString:@" style=\""];


        // Im Prinzip nur wegen controlwidth
        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

if (![elementName isEqualToString:@"combobox"])
{
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
        // Falls es ein Ausdruck ist, muss ich $,{,} entfernen
        // Ich lasse den Ausdruck dann von JS auswerten
        // Aber klappt das auch mit dem Attribut '.value' im Ausdruck? (ToDo)
        dataset = [self removeOccurrencesOfDollarAndCurlyBracketsIn:dataset];

        [self.jQueryOutput appendString:@"\n  // Dynamisch gesetzter Inhalt bezüglich combobox "];
        [self.jQueryOutput appendString:theId];
        [self.jQueryOutput appendString:@"__CodeMarker\n"];
        [self.jQueryOutput appendString:@"  $.each("];
        [self.jQueryOutput appendString:dataset];
        [self.jQueryOutput appendString:@", function(index, option)\n  {\n    $('#"];
        [self.jQueryOutput appendString:theId];
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
        [self.output appendString:theId];
        [self.output appendString:@"__CodeMarker -->\n"];
}



        // Select auch wieder schließen
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"</select>\n"];


        if ([attributeDict valueForKey:@"simple"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'simple'.");
        }
        if ([attributeDict valueForKey:@"listwidth"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'listwidth'.");
        }



        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n\n"];


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }







    // ToDo: Puh, title ist ein selbst erfundenes Attribut von BDScheckbox!
    // Das gibt es nämlich gar nicht laut Doku und Test mit OL-Editor!
    if ([elementName isEqualToString:@"BDScheckbox"] ||
        [elementName isEqualToString:@"checkbox"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];

        // Bei onclick die this-Abfrage damit es keine unendlichkeits-Schleige gibt, falls man gleichzeitig auch auf
        // den Button oder das span innerhalb des divs kommt
        [self.output appendString:@"<div class=\"div_checkbox\" onclick=\"if (this == event.target) $(this).children(':first').trigger('click');\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];




        [self.output appendString:@"<input class=\"input_checkbox\" type=\"checkbox\""];

        NSString *theId =[self addIdToElement:attributeDict];



        [self.output appendString:@" style=\""];
        
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        
        [self.output appendString:@"vertical-align: middle;\" />\n"];



        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"<span class=\"div_text\" onclick=\"$(this).prev().trigger('click');\""];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@">"];



        // Wenn im Attribut title Code auftaucht, dann müssen wir es dynamisch setzen
        // müssen aber erst abwarten bis wir die ID haben, weil wir die für den Zugriff brauchen.
        // <span> drum herum, damit ich per jQuery darauf zugreifen kann
        BOOL titelDynamischSetzen = NO;
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' in <span>-tags as text after the checkbox.");

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

        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' in <span>-tags after the checkbox.");

            [self.output appendString:[attributeDict valueForKey:@"text"]];
        }

        [self.output appendString:@"</span>\n"];





        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];

            code = [self makeTheComputedValueComputable:code];

            [self.jQueryOutput appendString:@"\n  // checkbox-Text wird hier dynamisch gesetzt\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').next().text(%@);\n",theId,code];
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
        if ([attributeDict valueForKey:@"checked"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'checked'.");
        }


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];

        // Javascript aufrufen hier, für z.B. Visible-Eigenschaften usw.
        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }



    if ([elementName isEqualToString:@"radiobutton"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];

        [self.output appendString:@"<div class=\"div_checkbox\" onclick=\"$(this).children(':first').attr('checked',true);\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];


        [self.output appendString:@"<input class=\"input_checkbox\" type=\"radio\""];

        [self.output appendFormat:@" name=\"%@_radiogroup\"",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2]];

        NSString *theId =[self addIdToElement:attributeDict];


        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\" />\n"];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"<span class=\"div_text\">"];

        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' in <span>-tags after the checkbox.");

            [self.output appendString:[attributeDict valueForKey:@"text"]];
        }

        [self.output appendString:@"</span>\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }



    // ToDo: Bei BDSeditnumber nur Ziffern zulassen als Eingabe inkl. wohl '.' + ','
    // Aber nochmal checken (To Check).
    if ([elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        if ([attributeDict valueForKey:@"title"])
            [self.output appendString:@"<div class=\"div_textfield\">\n"];
        else
            [self.output appendString:@"<div class=\"div_textfield_ohne_vorangehenden_text\">\n"];


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

        if ([attributeDict valueForKey:@"multiline"] && [[attributeDict valueForKey:@"multiline"] isEqualToString:@"true"])
            [self.output appendString:@"<textarea class=\"input_textfield\" type=\"text\""];
        else
            [self.output appendString:@"<input class=\"input_textfield\" type=\"text\""];

        NSString *id =[self addIdToElement:attributeDict];


        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];

            code = [self makeTheComputedValueComputable:code];

            [self.jQueryOutput appendString:@"\n  // textfield-Text wird hier dynamisch gesetzt\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').prev().text(%@);\n",id,code];
        }


        [self.output appendString:@" style=\""];


        // Die Width ist bei input-Feldern regelmäßig zu lang, vermutlich wegen interner
        // border-/padding-/margin-/Angaben bei OpenLaszlo. Deswegen hier vorher Wert abändern.
        if ([attributeDict valueForKey:@"width"])
        {
            int neueW = [[attributeDict valueForKey:@"width"] intValue]-14;
            [attributeDict setValue:[NSString stringWithFormat:@"%d",neueW] forKey:@"width"];
        }


        [self.output appendString:[self addCSSAttributes:attributeDict]];


        if ([attributeDict valueForKey:@"multiline"] && [[attributeDict valueForKey:@"multiline"] isEqualToString:@"true"])
            [self.output appendString:@"\" /></textarea>\n"];
        else
            [self.output appendString:@"\" />\n"];



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


        [self evaluateTextInputOnlyAttributes:attributeDict];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id]];
    }







    if ([elementName isEqualToString:@"BDSeditdate"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<div class=\"div_datepicker\" >\n"];
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

        NSString *theId =[self addIdToElement:attributeDict];



        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];

            code = [self makeTheComputedValueComputable:code];

            [self.jQueryOutput appendString:@"\n  // Datepicker-Text wird hier dynamisch gesetzt\n"];
            [self.jQueryOutput appendFormat:@"  $('#%@').prev().text(%@);\n",theId,code];
        }


        [self.output appendString:@" style=\""];


        // Im Prinzip nur wegen controlwidth
        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"margin-left:4px;\" />\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n\n"];


        // Jetzt noch den jQuery-Code für den Datepicker
        [self.jQueryOutput appendString:@"\n  // Für das mit dieser id verbundene input-Field setzen wir einen jQuery UI Datepicker\n"];
        [self.jQueryOutput appendString:@"  // Aber bei iOS-Devices nutzen wir den eingebauten Datepicker\n"];
        [self.jQueryOutput appendFormat:@"  if (isiOS())\n    document.getElementById('%@').setAttribute('type', 'date');\n  else\n    $('#%@').datepicker();\n",theId,theId];





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


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }






    if ([elementName isEqualToString:@"slider"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<div class=\"div_slider\">\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];

        [self.output appendString:@"<input type=\"range\""];

        NSString *theId =[self addIdToElement:attributeDict];

        NSString *value  = @"50";
        if ([attributeDict valueForKey:@"value"])
        {
            value = [attributeDict valueForKey:@"value"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'value' as 'value' for the slider.");
        }

        NSString *minvalue  = @"0";
        if ([attributeDict valueForKey:@"minvalue"])
        {
            minvalue = [attributeDict valueForKey:@"minvalue"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'minvalue' as 'minvalue' for the slider.");
        }

        NSString *maxvalue  = @"100";
        if ([attributeDict valueForKey:@"maxvalue"])
        {
            maxvalue = [attributeDict valueForKey:@"maxvalue"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'maxvalue' as 'maxvalue' for the slider.");
        }

        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendFormat:@"\" onchange=\"%@_output.value=parseInt(this.value)\" value=\"%@\" min=\"%@\" max=\"%@\" step=\"1\" />\n",self.zuletztGesetzteID,value,minvalue,maxvalue];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        // id ist Fallback für alte Browser
        [self.output appendFormat:@"<output name=\"%@_output\" id=\"%@_output\" for=\"%@\" style=\"position:absolute;left:150px;top:0px;\"></output>\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"</div>\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
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



        [self.output appendString:@"<div class=\"div_rudContainer\""];

        [self addIdToElement:attributeDict];



        // Im Prinzip nur wegen boxheight müssen wir in addCSSAttributes rein
        [self.output appendString:@" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict forceWidthAndHeight:YES]];
        [self.output appendString:@"\">\n"];


        // Javascript aufrufen hier, im Prinzip nur wegen name
        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];


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


        [self.output appendString:@"<div class=\"div_rudElement\""];


        // Das umgebende Div bekommt die Haupt-ID, Panel und Leiste 2 Unter-IDs
        NSString *id4rollUpDown =[self addIdToElement:attributeDict];

        NSString *id4flipleiste = [NSString stringWithFormat:@"%@_flipleiste",id4rollUpDown];
        NSString *id4panel = [NSString stringWithFormat:@"%@_panel",id4rollUpDown];



        // Den Counter aus dem Array rausziehen und als int auslesen
        int counter = [[self.rollupDownElementeCounter objectAtIndex:self.rollUpDownVerschachtelungstiefe-2] intValue];

        [self.output appendString:@" style=\""];
        [self.output appendString:@"top:"];

        // [self.output appendFormat:@"%d",counter*111];
        // wtf...
        [self.output appendString:@"6"];

        // Und Zähler um eins erhöhen an der richtigen Stelle im Array
        [self.rollupDownElementeCounter replaceObjectAtIndex:self.rollUpDownVerschachtelungstiefe-2 withObject:[NSNumber numberWithInt:(counter+1)]];

        [self.output appendString:@"px;"];
        [self.output appendString:@"width:"];
        [self.output appendFormat:@"%d",breiteVonRollUpDown];
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
                if ([code hasPrefix:@"$"])
                    code = [self makeTheComputedValueComputable:code];

                [self.jQueryOutput appendString:@"\n  // Der Titel (header) von rollUpDown wird hier dynamisch gesetzt\n"];
                [self.jQueryOutput appendFormat:@"  $('#%@').html('<span style=\"margin-left:8px;\">'+%@+'</span>');\n",id4flipleiste,code];
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
        [self.output appendFormat:@"%dpx; height:%dpx; background-color:lightblue; line-height: %dpx; vertical-align:middle;\" class=\"ui-corner-top\" id=\"",breiteVonRollUpDown,heightOfFlipBar];
        [self.output appendString:id4flipleiste];
        [self.output appendString:@"\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"<span style=\"margin-left:8px;\">"];
        [self.output appendString:title];
        [self.output appendString:@"</span>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<!-- Das aufklappende Panel -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1]; // overflow, damit es scrollt, falls zu viel drin
        [self.output appendFormat:@"<div style=\"width:%dpx; ",breiteVonRollUpDown-4];

        // Bei ganz äußeren RUDs soll die Höhe fix sein, ansonsten nicht
        if (self.rollUpDownVerschachtelungstiefe-2 == 0)
            [self.output appendString:@"height:350px; "];
        else
            [self.output appendString:@"height:auto; "];
        [self.output appendString:@"\" class=\"div_rudPanel ui-corner-bottom\" id=\""];
        [self.output appendString:id4panel];
        [self.output appendString:@"\">\n"];


        // Die jQuery-Ausgabe
        if (callback)
            [self.jQueryOutput appendString:@"\n  // Animation bei Klick auf die Leiste (mit callback)"];
        else
            [self.jQueryOutput appendString:@"\n  // Animation bei Klick auf die Leiste (ohne callback)"];

        [self.jQueryOutput appendString:@"\n  // Vorher alle Panels gleicher Ebene schließen, aber nicht unser aktuell geklicktes"];

        [self.jQueryOutput appendFormat:@"\n  $('#%@').click(function(){ $('#%@').parent().parent().children().children('.div_rudPanel:not(\"#%@\")').slideUp(%@); $('#%@').slideToggle(%@",id4flipleiste,id4flipleiste,id4panel,self.animDuration,id4panel,self.animDuration];
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
        // Dieser Code funktioniert nicht....
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


        // CSS-MouseHover-Anpssung vornehmen
        [self changeMouseCursorOnHoverOverElement:id4flipleiste];


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",id4rollUpDown]];


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



        [self.output appendString:@"<div class=\"div_tsc\""];

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
        [self.jQueryOutput appendString:@"\n  // Ein TabSheetContainer. Jetzt wird's kompliziert. Wir legen ihn hier an.\n  // Die einzelnen Tabs werden, sobald sie im Code auftauchen, per add hinzugefügt\n  // Mit der Option 'tabTemplate' legen wir die width fest\n  // Mit der Option 'fx' legen wir eine Animation für das Wechseln fest\n"];

        [self.jQueryOutput appendFormat:@"  $('#%@').tabs({ tabTemplate: '<li style=\"width:%dpx;\"><a href=\"#{href}\" style=\"width:%dpx;\"><span>#{label}</span></a></li>' });\n",self.lastUsedTabSheetContainerID,tabwidth,tabwidthForLink];
        [self.jQueryOutput appendFormat:@"  $('#%@').tabs({ fx: { opacity: 'toggle' } });\n",self.lastUsedTabSheetContainerID];
        [self.jQueryOutput appendFormat:@"  $('#%@').tabs();\n",self.lastUsedTabSheetContainerID];


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

        [self.output appendString:@"<div class=\"div_standard\""];

        NSString* geradeVergebeneID = [self addIdToElement:attributeDict];

        // Sonst verrutscht es alles wegen der zwischengeschobenen Leiste
        // Etwas geschummelt, aber nun gut.
        // Auch das width muss ich hier explizit übernehmen.
        [self.output appendString:@" style=\"top:50px;width:inherit;height:inherit;\""];

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
        [self.jQueryOutput appendFormat:@"  $('#%@').tabs('add', '#%@', '%@');\n",self.lastUsedTabSheetContainerID,geradeVergebeneID,[attributeDict valueForKey:@"title"]];
    }



    if ([elementName isEqualToString:@"splash"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div id=\"splashtag_\" style=\"width:100%;height:100%;z-index:10001;\">\n"];
    }



    // Nichts zu tun
    if ([elementName isEqualToString:@"library"] ||
        [elementName isEqualToString:@"passthrough"] ||
        [elementName isEqualToString:@"evaluateclass"])
    {
        element_bearbeitet = YES;
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


    if ([elementName isEqualToString:@"class"])
    {
        element_bearbeitet = YES;


        // Theoretisch könnte auch eine id gesetzt worden sein, auch wenn OL-Doku davon abrät!
        // http://www.openlaszlo.org/lps4.9/docs/developers/tutorials/classes-tutorial.html (1.1)
        // Dann hier aussteigen
        if ([attributeDict valueForKey:@"id"])
        {
            [self instableXML:@"ID attribute on class found!!! It's important to note that you should not assign an id attribute in a class definition. Each id should be unique; ids are global and if you were to include an id assignment in the class definition, then creating several instances of a class would several views with the same id, which would cause unpredictable behavior. http://www.openlaszlo.org/lps4.9/docs/developers/tutorials/classes-tutorial.html (1.1)"];
        }


        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;

            NSString *name = [attributeDict valueForKey:@"name"];

            // Wir sammeln alle gefundenen 'name'-Attribute von class in einem eigenen Dictionary.
            // Weil die names können später eigene <tags> werden! Ich muss dann später darauf testen
            // ob das ELement vorher definiert wurde.
            // Als Objekt setzen wir ein NSDictionary, in dem alle Attribute der Klasse gesammelt
            // werden. Dies ist wichtig, weil ich beim instanzieren einer Klasse, alle Attribute
            // mit ihren Initial-Werten setzen muss.

            NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:200];
            [self.allFoundClasses setObject:dict forKey:name];

            // Damit ich in <evaluateclass> die Attribute korrekt zuordnen kann,
            // muss ich mir den Namen der Klasse merken:
            self.lastUsedNameAttributeOfClass = name;


            // Auserdem speichere ich die gefunden Klasse als JS-Objekt und schreibe es nach
            // collectedClasses.js
            // Die Attribute speichere ich einzeln ab und lese sie durch jQuery aus, sobald sie
            // instanziert wird.


            NSArray *keys_ = [attributeDict allKeys];
            NSMutableArray *keys = [[NSMutableArray alloc] initWithArray:keys_];


            [self.jsOLClassesOutput appendString:@"\n\n"];
            [self.jsOLClassesOutput appendString:@"///////////////////////////////////////////////////////////////\n"];
            [self.jsOLClassesOutput appendFormat:@"// class = %@ (from %@)",name,[self.pathToFile lastPathComponent]];

            for (int i=(42-([name length]+[[self.pathToFile lastPathComponent] length])); i > 0; i--)
            {
                [self.jsOLClassesOutput appendFormat:@" "];
            }

            [self.jsOLClassesOutput appendFormat:@"//\n"];
            [self.jsOLClassesOutput appendString:@"///////////////////////////////////////////////////////////////\n"];
            [self.jsOLClassesOutput appendFormat:@"oo.%@ = function(textBetweenTags) {\n",name];


            [self.jsOLClassesOutput appendFormat:@"  this.name = '%@';\n",name];

            // Das Attribut 'name' brauchen wir jetzt nicht mehr.
            int i = [keys count]; // Test, ob es auch klappt
            [keys removeObject:@"name"];
            if (i == [keys count])
                [self instableXML:@"Konnte Attribut 'name' in <class> nicht löschen."];

            // extends auslesen und speichern, dann extends aus der Attribute-liste löschen
            NSString *inherit = [attributeDict valueForKey:@"extends"];
            if (inherit == nil || inherit.length == 0)
            {
                [self.jsOLClassesOutput appendString:@"  this.inherit = new oo.view();\n\n"];
            }
            else
            {
                self.attributeCount++;

                if ([inherit isEqualToString:@"window"])
                    inherit = @"basewindow";

                [self.jsOLClassesOutput appendFormat:@"  this.inherit = new oo.%@(textBetweenTags);\n\n",inherit];
            }
            [keys removeObject:@"extends"];

            // Dass klappt so nicht, weil es auch CSS-Eigenschaften gibt, die sich erst auswerten
            // lassen, wenn ein Objekt instanziert wurde. (z.B. Breite, Höhe des Parents)
            // Deswegen werden dort die CSS-Eigenschaften ausgewertet
            // Dazu gebe ich die CSS-Eigenschaften einzeln (!) der Klasse mit (s.u.)
            // CSS-Eigenschaften auswerten...
            // NSString *styles = [self addCSSAttributes:attributeDict];
            // ...und der Klasse mitgeben
            // [self.jsOLClassesOutput appendFormat:@"  this.style = '%@';\n\n",styles];

            // Mit JS-Eigenschaften klappt es auch nicht..., da hier keine Rekursion am Start ist,
            // schreibt die Funktion in das Output-File. Ich löse es jetzt so, indem ich die JS-Attribute ebenfalls
            // auf JS-Ebene in der Funktion interpretObject() auswerte.
            // [self.output appendString:[self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",ID_REPLACE_STRING]]];

            // Falls keine Attribute vorhanden, muss trotdzem ein leeres Array erzeugt werden!
            // Denn deleteAttributesPreviousDeclared() verlässt sich auf die Existenz.
            // if ([keys count] > 0)
            {
                // Alle Attributnamen als Array hinzufügen
                [self.jsOLClassesOutput appendString:@"  this.attributeNames = ['textBetweenTags_'"];

                int i = 0;
                for (NSString *key in keys)
                {
                    i++;

                    [self.jsOLClassesOutput appendString:@", "];

                    // Es gibt Attribute mit ' drin, deswegen hier "
                    [self.jsOLClassesOutput appendString:@"\""];
                    [self.jsOLClassesOutput appendString:key];
                    [self.jsOLClassesOutput appendString:@"\""];

                    //if (i < [keys count])
                    //    [self.jsOLClassesOutput appendString:@", "];

                    // Die Attribute werden erst später ausgelesen, deswegen hier hochzählen
                    // Sie werden aktuell ja nicht weiter bearbeitet.
                    self.attributeCount++;
                }

                [self.jsOLClassesOutput appendString:@"];\n"];


                // Und alle Attributwerte als Array hinzufügen
                [self.jsOLClassesOutput appendString:@"  this.attributeValues = [textBetweenTags"];

                i = 0;
                for (NSString *key in keys)
                {
                    i++;

                    [self.jsOLClassesOutput appendString:@", "];

                    // Es gibt Attribute mit ' drin, deswegen hier "
                    [self.jsOLClassesOutput appendString:@"\""];
                    [self.jsOLClassesOutput appendString:[attributeDict valueForKey:key]];
                    [self.jsOLClassesOutput appendString:@"\""];

                    //if (i < [keys count])
                    //    [self.jsOLClassesOutput appendString:@", "];
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


        // Alles was in class definiert wird, wird extra gesammelt
        self.weAreCollectingTheCompleteContentInClass = YES;
    }

    if ([elementName isEqualToString:@"fileUpload"]) // ToDo (ist selbst defnierte Klasse)
    {
        element_bearbeitet = YES;
        self.weAreCollectingTheCompleteContentInClass = YES;

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

        // ToDo
        // Alles was hier definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreCollectingTheCompleteContentInClass = YES;
    }
    // ToDo
    if ([elementName isEqualToString:@"dlginfo"] || [elementName isEqualToString:@"dlgwarning"] || [elementName isEqualToString:@"dlgyesno"] || [elementName isEqualToString:@"nicepopup"] || [elementName isEqualToString:@"nicedialog"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"id"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"info"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"initstage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"height"])
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
        // Alles was in diesen Dialogen definiert wird, wird derzeit übersprungen, später ändern und Sachen abarbeiten.
        self.weAreCollectingTheCompleteContentInClass = YES;
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
        self.weAreCollectingTheCompleteContentInClass = YES;
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
        self.weAreCollectingTheCompleteContentInClass = YES;
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
        self.weAreCollectingTheCompleteContentInClass = YES;
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
        self.weAreSkippingTheCompleteContentInThisElement = YES;
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
        self.weAreSkippingTheCompleteContentInThisElement = YES;
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
        // ToDo
        if ([attributeDict valueForKey:@"from"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"start"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"duration"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"target"])
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



    // Erfordert 3 Kind-Elemente. Das erste Element kommt links an die Wand,
    // das 3. Element kommt rechts an die Wand,
    // das mittlere nimmt den Platz in er Mitte ein, der übrig bleibt.
    // Wenn nur 1 Kind-Element vorhanden, kommt dieses einfach links an die Wand
    // Wenn nur 2 Kind-Elemente vorhanden, bekommt das 2. Element eine Breite von 0.
    // Alles eben gesagte gilt für axis=x. Bei axis=y entsprechend analog, nur vertikal.
    if ([elementName isEqualToString:@"stableborderlayout"])
    {
        element_bearbeitet = YES;

        NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        NSLog([NSString stringWithFormat:@"Setting a 'stableborderlayout' in '%@' with jQuery",idUmgebendesElement]);

        if ([attributeDict valueForKey:@"axis"] && ([[attributeDict valueForKey:@"axis"] isEqualToString:@"x"] || [[attributeDict valueForKey:@"axis"] isEqualToString:@"y"]))
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'axis' of 'stableborderlayout' to determine the axis.");
        }


        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Ignoring the attribute 'name' of 'stableborderlayout'.");
        }

        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        if ([[attributeDict valueForKey:@"axis"] isEqualToString:@"x"])
        {
            [o appendFormat:@"\n  // Setting a 'stableborderlayout' (axis:x) in '%@':\n",idUmgebendesElement];
            [o appendFormat:@"  setStableBorderLayoutXIn(%@);\n",idUmgebendesElement];
        }
        else
        {
            [o appendFormat:@"\n  // Setting a 'stableborderlayout' (axis:y) in '%@':\n",idUmgebendesElement];
            [o appendFormat:@"  setStableBorderLayoutYIn(%@);\n",idUmgebendesElement];
        }


        [self.jQueryOutput appendString:o];
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
    if ([elementName isEqualToString:@"scrollview"])
    {
        element_bearbeitet = YES;

        // ToDo
        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"hidescrollbar"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"leftmargin"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"topmargin"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"visible"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"width"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"BDStabsheetselected"])
    {
        element_bearbeitet = YES;


        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"x"])
            self.attributeCount++;
    }
    if ([elementName isEqualToString:@"ftdynamicgrid"])
    {
        element_bearbeitet = YES;
        
        
        // ToDo
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"rowheight"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"trashcol"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"multiselect"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"metadatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"height"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"headerheight"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"focusable"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"datapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"contentdatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"_columnclass"])
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

            if ([[attributeDict valueForKey:@"src"] isEqualToString:@"app-includes/steuerberechnung.jsToDoTakeMeOut"] ||
                [[attributeDict valueForKey:@"src"] isEqualToString:@"app-includes/taxango.jsToDoTakeMeOut"])
            {
                // Skippen, weil es da drin einen JS-Bug gibt
                NSLog(@"Skipping this script (ToDo).");
            }
            else
            {
                [self.externalJSFilesOutput appendString:@"<script type=\"text/javascript\" src=\""];
                // ToDo: ***** Stars einfügen und Dateinamen
                [self.externalJSFilesOutput appendString:[attributeDict valueForKey:@"src"]];
                [self.externalJSFilesOutput appendString:@"\"></script>\n"];
            }
        }
        else
        {
            // JS-Code mit foundCharacters sammeln und beim schließen übernehmen
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


    // <text> und <inputtext> sind die einzigen beiden Elemente, die Text enthalten dürfen.
    // <text> darf zusätzlich bestimmte HTML-Tags enthalten (<b>, <i>, usw), inputtext nicht!
    if ([elementName isEqualToString:@"text"] ||
        [elementName isEqualToString:@"inputtext"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];



        [self.output appendString:@" class=\"div_text\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];


        [self evaluateTextOnlyAttributes:attributeDict];


        // Dann Text mit foundCharacters sammeln und beim schließen anzeigen




        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];


        if ([elementName isEqualToString:@"text"])
        {
            self.weAreCollectingTextAndThereMayBeHTMLTags = YES;
            NSLog(@"We won't include possible following HTML-Tags, because it is content of the text.");
        }
    }


    // Ich füge alle gefundenen Methoden in das richtige Objekt ein.
    if ([elementName isEqualToString:@"method"])
    {
        element_bearbeitet = YES;

        if (![attributeDict valueForKey:@"name"])
        {
            [self instableXML:@"ERROR: No attribute 'name' given in method-tag"];
        }
        else
        {
            NSLog([[NSString alloc] initWithFormat:@"Using the attribute 'name' as method-name for a JS-Function, that is added to the class %@",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2]]);
            self.attributeCount++;
            self.lastUsedNameAttributeOfMethod = [attributeDict valueForKey:@"name"];
        }

        // Es gibt nicht immer args
        NSString *args = @"";
        // Falls es default Values gibt, muss ich diese in JS extra setzen
        NSMutableString *defaultValues = [[NSMutableString alloc] initWithString:@""];
        if ([attributeDict valueForKey:@"args"])
        {
            self.attributeCount++;

            if (![[attributeDict valueForKey:@"args"] isEqualToString:@"...ignore"])
            {
                NSLog(@"Using the attribute 'args' as arguments for this prototyped JS-Function.");

                args = [attributeDict valueForKey:@"args"];
                args = [args stringByReplacingOccurrencesOfString:@" " withString:@""];


                // Überprüfen ob es default values gibt im Handler direkt (mit RegExp)...
                NSError *error = NULL;
                NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"([\\w]+)=([\\w]+)" options:NSRegularExpressionCaseInsensitive error:&error];

                NSUInteger numberOfMatches = [regexp numberOfMatchesInString:args options:0 range:NSMakeRange(0, [args length])];

                if (numberOfMatches > 0)
                {
                    NSMutableString *neueArgs = [[NSMutableString alloc] initWithString:@""];

                    // Es kann ja auch eine Mischung geben, von sowohl Argumenten mit
                    // Defaultwerten als auch solchen ohne. Deswegen hier erstmal ohne
                    // Defaultargumente setzen und dann gleich die alle mit.
                    neueArgs = [self holAlleArgumentDieKeineDefaultArgumenteSind:args];

                    NSLog([NSString stringWithFormat:@"There is/are %d argument(s) with a default argument. I will regexp them.",numberOfMatches]);

                    NSArray *matches = [regexp matchesInString:args options:0 range:NSMakeRange(0, [args length])];

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
                        [defaultValues appendFormat:@"    if(typeof(%@)==='undefined') ",varName];
                        [defaultValues appendFormat:@"%@ = %@;\n",varName,defaultValue];
                        ///////////////////// Default- Variablen für JS setzen - Ende /////////////////////
                    }
                    // ... und hier setzen
                    args = neueArgs;
                }
            }
            else
            {
                NSLog(@"Ignoring the attribute 'args' as arguments because I was told so.");
            }
        }


        NSString *elem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];
        NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];


        // http://www.openlaszlo.org/lps4.9/docs/reference/ <method> => s. Attribut 'name'
        // Deswegen bei canvas und library 'method' als Funktionen global verfügbar machen
        // UND an canvas binden.
        // Ansonsten 'method' als Methode an das umgebende Objekt koppeln.

        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        [o appendFormat:@"\n  // Ich binde eine Methode an das genannte Objekt (Objekttyp: %@)\n", elemTyp];


        NSString *benutzMich = @""; // Um nur einen s für dataset und datapointer zu haben
        BOOL wirBrauchenWith = NO;

        if ([elemTyp isEqualToString:@"canvas"] || [elemTyp isEqualToString:@"library"])
        {
            //[o appendFormat:@"  if (window.%@ == undefined)\n  ",[attributeDict valueForKey:@"name"]];
            // Neue Logik: Methoden werden erst nach ausgewerteten Klassen gesetzt.
            // Deswegen MUSS jetzt sogar überschrieben werden
        }
        else
        {
            // Dann sind wir in einem anderen Scope und brauchen 'with'
            wirBrauchenWith = YES;

            // Folgendes Szenario: Wenn eine selbst definierte Klasse eine Methode definiert,
            // aber gleichzeitig diese erbt, dann hat die selbst definierte Vorrang! Deswegen
            // überschreibe ich mit der Methode innerhalb der Klasse nicht! Dazu teste ich
            // einfach vorher ob sie auch wirklich undefined ist!

            // Tja... auch Datasets können jetzt Methoden haben...
            // In so einem Fall immer an das letzte Dataset binden, nicht an die ID.
            // Denn Datasets werden unter Umständen auch per 'name'-Attribut angesprochen!
            // (und nicht per id)
            // Tja....... sogar Datapointer können auch Methoden haben...
            // ich nutze bei Datapointer auch die Variable lastUsedDataset heimlich mit.
            if ([elemTyp isEqualToString:@"dataset"] || [elemTyp isEqualToString:@"datapointer"])
            {
                if ([elemTyp isEqualToString:@"dataset"])
                    benutzMich = self.lastUsedDataset;
                else
                    benutzMich = self.lastUsedNameAttributeOfDataPointer;

                //if ([elemTyp isEqualToString:@"evaluateclass"]) // Weil ich dort rückwärts auswerte
                //    [o appendFormat:@"  if (%@.%@ == undefined)\n",benutzMich,[attributeDict valueForKey:@"name"]];
                // Unsinn! Ich wärte vorwärts aus! Methoden sollen BEWUSST überschrieben werden
                [o appendFormat:@"  %@.",benutzMich];
            }
            else
            {
                //if ([elemTyp isEqualToString:@"evaluateclass"]) // Weil ich dort rückwärts auswerte
                //    [o appendFormat:@"  if (%@.%@ == undefined)\n",elem,[attributeDict valueForKey:@"name"]];
                // Unsinn! Ich wärte vorwärts aus! Methoden sollen BEWUSST überschrieben werden
                [o appendFormat:@"  %@.",elem];
            }
        }

        [o appendString:[attributeDict valueForKey:@"name"]];
        [o appendFormat:@" = function(%@)\n  {\n",args];
        if (wirBrauchenWith)
        {
            if ([elemTyp isEqualToString:@"dataset"] || [elemTyp isEqualToString:@"datapointer"])
                [o appendFormat:@"    with (%@) {\n",benutzMich];
            else
                [o appendFormat:@"    with (%@) {\n",elem];
        }

        // Falls es default values für die Argumente gibt, muss ich diese hier setzen
        if (![defaultValues isEqualToString:@""])
        {
            [o appendString:defaultValues];
            [o appendString:@"\n"];
        }

        // OL benutzt 'classroot' als Variable für den Zugriff auf das erste in einer Klasse
        // definierte Elemente. Deswegen, falls wir eine Klasse auswerten, einfach die Var setzen
        if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
            [o appendFormat:@"    var classroot = %@;\n\n",ID_REPLACE_STRING];

        // Um es auszurichten mit dem Rest
        [o appendString:@" "];


        // jQueryOutput0, damit es noch vor den Computed Values und Constraint Values bekannt ist
        // Denn diese greifen u. U. schon auf Methoden zu
        [self.jQueryOutput0 appendString:o];


        // Okay, jetzt Text der Methode sammeln und beim schließen einfügen
    }



    if ([elementName isEqualToString:@"handler"])
    {
        element_bearbeitet = YES;

        NSString *enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];


        [self.jQueryOutput appendString:@"\n  // pointer-events zulassen, da ein Handler an dieses Element gebunden ist."];
        [self.jQueryOutput appendFormat:@"\n  $('#%@').css('pointer-events','auto');\n",enclosingElem];

        if (![attributeDict valueForKey:@"name"])
            [self instableXML:@"Ein Handler ohne name-Attribut. Das geht so nicht!"];

        NSLog(@"Using the 'name'-attribute as the name for the handler.");


        NSString *name = [attributeDict valueForKey:@"name"];

        NSString *args = @"";

        BOOL alsBuildInEventBearbeitet = NO;


        if ([attributeDict valueForKey:@"method"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'method' as method to call in this handler.");

            self.methodAttributeInHandler = [attributeDict valueForKey:@"method"];
        }
        else
        {
            self.methodAttributeInHandler = @"";
        }


        if ([name isEqualToString:@"onclick"])
        {
            // Muss ganz am Anfang stehen, damit sich die Codezeilen nicht gegenseitig beeinflussen
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-click-event.");

            [self.jQueryOutput appendFormat:@"\n  // onclick-Handler für %@\n",enclosingElem];

            // 'e', weil 'event' würde wohl das event-Objekt zugreifen. Auf dieses kann man so und so zugreifen.
            [self.jQueryOutput appendFormat:@"  $('#%@').click(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"ondblclick"])
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-dblclick-event.");

            [self.jQueryOutput appendFormat:@"\n  // ondblclick-Handler für %@\n",enclosingElem];

            // 'e', weil 'event' würde wohl das event-Objekt zugreifen. Auf dieses kann man so und so zugreifen.
            [self.jQueryOutput appendFormat:@"  $('#%@').dblclick(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onchanged"] ||
            [name isEqualToString:@"onvalue"] ||
            [name isEqualToString:@"onnewvalue"] ||
            [name isEqualToString:@"ondata"])
            // "The ondata script is executed when the data selected by a view's datapath changes."
            // Aber auch einmal ganz am Anfang wohl... ToDo.
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-change-event.");

            [self.jQueryOutput appendFormat:@"\n  // change-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').change(function(e)\n  {\n    ",enclosingElem];


            // Extra Code, um den alten Value speichern zu können (s. als Erklärung auch
            // unten bei gegebenenem Attribut args)
            if ([name isEqualToString:@"onnewvalue"] ||
                [name isEqualToString:@"onvalue"])
            {
                [self.jQueryOutput appendString:@"var oldvalue = $(this).data('oldvalue') || '';\n"];
                [self.jQueryOutput appendString:@"    $(this).data('oldvalue', $(this).val());\n\n    "];
            }

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onerror"] ||
            [name isEqualToString:@"ontimeout"])
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-error-event.");

            [self.jQueryOutput appendFormat:@"\n  // error-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').error(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }


        if ([name isEqualToString:@"oninit"])
        {
            self.attributeCount++;
            // NSLog(@"Binding the method in this handler to a jQuery-load-event.");
            // Nein, load-event gibt es nur bei window (also body und frameset)
            // alles was in init ist einfach direkt ausführen
            // Falls es doch mal das init eines windows (canvas) sein sollte, nicht schlimm,
            // denn wir führen schon von vorne herein den gesamten Code in
            // $(window).load(function() aus!
            NSLog(@"NOT Binding the method in this handler. Direct execution of code.");

            [self.jQueryOutput appendFormat:@"\n  // oninit-Handler für %@ (wir führen den Code direkt aus)\n  // Aber korrekten Scope berücksichtigen! Deswegen in einer Funktion mit bind() ausführen\n  // Zusätzlich ist auch noch with (this) {} erforderlich, puh...\n",enclosingElem];

            // [self.jQueryOutput appendFormat:@"  $('#%@').load(function()\n  {\n    ",self.zuletztGesetzteID];
            [self.jQueryOutput appendFormat:@"  var bindMeToCorrectScope = function () {\n    with (this) {\n      "];


            if ([attributeDict valueForKey:@"args"])
            {
                self.attributeCount++;

                [self.jQueryOutput appendFormat:@"var %@ = this;\n\n      ",[attributeDict valueForKey:@"args"]];
            }


            self.onInitInHandler = YES;

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onfocus"] ||
            [name isEqualToString:@"onisfocused"])
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-focus-event.");

            [self.jQueryOutput appendFormat:@"\n  // focus-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').focus(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onselect"] ||
            [name isEqualToString:@"onitemselected"])
        {
            if ([attributeDict valueForKey:@"args"])
            {
                self.attributeCount++;
                args = [NSString stringWithFormat:@",%@",[attributeDict valueForKey:@"args"]];
            }


            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-select-event.");

            [self.jQueryOutput appendFormat:@"\n  // select-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').select(function(e%@)\n  {\n    ",enclosingElem,args];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onblur"])
        {
            if ([attributeDict valueForKey:@"args"])
            {
                self.attributeCount++;
                args = [NSString stringWithFormat:@",%@",[attributeDict valueForKey:@"args"]];
            }


            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-blur-event.");

            [self.jQueryOutput appendFormat:@"\n  // blur-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').blur(function(e%@)\n  {\n    ",enclosingElem,args];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmousedown"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mousedown-event.");

            [self.jQueryOutput appendFormat:@"\n  // mousedown-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').mousedown(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmouseup"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mouseup-event.");

            [self.jQueryOutput appendFormat:@"\n  // mouseup-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').mouseup(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmouseover"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mouseover-event.");

            [self.jQueryOutput appendFormat:@"\n  // mouseover-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').mouseover(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmouseout"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mouseout-event.");

            [self.jQueryOutput appendFormat:@"\n  // mouseout-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').mouseout(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onkeyup"])
        {
            if ([attributeDict valueForKey:@"args"] &&
                ([[attributeDict valueForKey:@"args"] isEqualToString:@"k"]))
            {
                self.attributeCount++;
                NSLog(@"Considering the argument 'k' as 'var k = e.keyCode;'.");
            }
            if ([attributeDict valueForKey:@"args"] &&
                ([[attributeDict valueForKey:@"args"] isEqualToString:@"key"]))
            {
                self.attributeCount++;
                NSLog(@"Considering the argument 'key' as 'var key = e.keyCode;'.");
            }


            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-keyup-event.");

            [self.jQueryOutput appendFormat:@"\n  // keyup-Handler für %@\n",enclosingElem];

            // die Variable k wird von OpenLaszlo einfach so benutzt. Das muss der keycode sein.
            [self.jQueryOutput appendFormat:@"  $('#%@').keyup(function(e)\n  {\n    var k = e.keyCode;\n    var key = e.keyCode;\n\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }



        if ([name isEqualToString:@"onkeydown"])
        {
            if ([attributeDict valueForKey:@"args"] &&
                ([[attributeDict valueForKey:@"args"] isEqualToString:@"k"]))
            {
                self.attributeCount++;
                NSLog(@"Considering the argument 'k' as 'var k = e.keyCode;'.");
            }
            if ([attributeDict valueForKey:@"args"] &&
                ([[attributeDict valueForKey:@"args"] isEqualToString:@"key"]))
            {
                self.attributeCount++;
                NSLog(@"Considering the argument 'key' as 'var key = e.keyCode;'.");
            }

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-keydown-event.");

            [self.jQueryOutput appendFormat:@"\n  // keydown-Handler für %@\n",enclosingElem];

            [self.jQueryOutput appendFormat:@"  $('#%@').keydown(function(e)\n  {\n    var k = e.keyCode;\n    var key = e.keyCode;\n\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }



        // Wenn 'reference' gesetzt, dann Bezug nehmen und DARAN binden
        // Aber gleichzeitig muss das this beim alten bleiben, deswegen mit bind() arbeiten
        if ([attributeDict valueForKey:@"reference"])
        {
            self.attributeCount++;

            self.referenceAttributeInHandler = YES;

            //[self.jQueryOutput appendFormat:@"\n  // 'reference'-Attribut, deswegen addEventListener\n"];
            //[self.jQueryOutput appendFormat:@"  %@.addEventListener('%@',function() { alert('Hmmm'); }, false);\n",[attributeDict valueForKey:@"reference"],name];

            NSLog(@"Using the referenced element to bind the handler, not the enclosing Element.");
        }



        // Wenn es vorher nicht gematcht hat, dann ist es wohl ein self-defined event.
        // Irgend jemand anderes muss das event dann per triggerHandler() aufrufen
        if (!alsBuildInEventBearbeitet)
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a custom jQuery-event (has to be triggered).");

            if ([attributeDict valueForKey:@"args"])
            {
                self.attributeCount++;
                args = [NSString stringWithFormat:@",%@",[attributeDict valueForKey:@"args"]];
            }

            // args = IMMER 2. Argument, weil lz.Event diesen über triggerHandler als 2. übergibt
            // ebenso 'setAttribute_'.
            // Das erste Argument (e) ist immer automatisch das event-Objekt.
            // (Siehe Beispiel <event>, Example 28)
            if ([attributeDict valueForKey:@"reference"])
            {
                [self.jQueryOutput appendFormat:@"\n  // 'custom'-Handler für %@\n",[attributeDict valueForKey:@"reference"]];
                [self.jQueryOutput appendFormat:@"  $(%@).on('%@',function(e%@)\n  {\n    ",[attributeDict valueForKey:@"reference"],name,args];
            }
            else
            {
                [self.jQueryOutput appendFormat:@"\n  // 'custom'-Handler für %@\n",enclosingElem];
                [self.jQueryOutput appendFormat:@"  $('#%@').on('%@',function(e%@)\n  {\n    ",enclosingElem,name,args];
            }


            // Okay, jetzt Text sammeln und beim schließen einfügen
        }





        // Wenn args gesetzt ist, wird derzeit nur der Wert 'oldvalue' unterstützt
        // und auch nur wenn als event 'onnewvalue' gesetzt wurde
        // Dazu wird der 'onnewvalue' oder 'onvalue'-Handler um Code ergänzt der stets
        // den alten Wert in der Variable 'oldvalue' speichert
        if ([attributeDict valueForKey:@"args"])
        {

            if ([[attributeDict valueForKey:@"args"] isEqualToString:@"oldvalue"])
            {
                if ([name isEqualToString:@"onnewvalue"] ||
                    [name isEqualToString:@"onvalue"])
                {
                    self.attributeCount++;
                    NSLog(@"Found the attribute 'args' with value 'oldvalue'.");
                    NSLog(@"Setting extra-code in the handler to retrieve the oldvalue");
                }
            }
        }
    }


    // s. http://www.openlaszlo.org/lps4.9/docs/developers/methods-events-attributes.html
    // Alles da drin ToDo

    if ([elementName isEqualToString:@"event"])
    {
        element_bearbeitet = YES;

        NSString *enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Declaring an event with the given name.");

            [self.jQueryOutput appendFormat:@"\n  // <event> für %@\n",enclosingElem];
            [self.jQueryOutput appendFormat:@"  %@.%@ = new lz.event(null,%@,'%@');\n",enclosingElem, [attributeDict valueForKey:@"name"], enclosingElem, [attributeDict valueForKey:@"name"]];
        }
        else
        {
            [self instableXML:@"Ein event ohne Name-Attribut. Das geht so nicht!"];
        }
    }





    // Okay, letzte Chance: Wenn es vorher nicht gematcht hat.
    // Dann war es eventuell eine selbst definierte Klasse?
    // Haben wir die Klasse auch vorher aufgesammelt? Nur dann geht es hier weiter.
    if (!element_bearbeitet && ([self.allFoundClasses objectForKey:elementName] != nil))
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        NSLog(@"Öffnendes Tag einer selbst definierten Klasse gefunden!");
        // NSLog([NSString stringWithFormat:@"%@",elementName]);
        // NSLog([NSString stringWithFormat:@"%@",[self.allFoundClasses objectForKey:elementName]]);


        if ([attributeDict valueForKey:@"text"] && [attributeDict valueForKey:@"title"])
        {
            [self instableXML:@"Dann haben wir ein Problem..."];
        }
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' as 'textBetweenTags'-Parameter of the object.");

            // Wird dann beim schließen ausgelesen
            self.textInProgress = [[NSMutableString alloc] initWithString:[attributeDict valueForKey:@"text"]];
        }
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'title' as 'textBetweenTags'-Parameter of the object.");

            // Wird dann beim schließen ausgelesen
            self.textInProgress = [[NSMutableString alloc] initWithString:[attributeDict valueForKey:@"title"]];
        }

        // Ich muss die Stelle einmal markieren...
        // standardmäßig wird immer von 'view' geerbt, deswegen hier als class 'div_standard'.
        // Wird falls nötig auf Javascript-Ebene von der Funktion interpretObject() mit Attributen erweitert.
        [self.output appendString:@"<div"];
        [self addIdToElement:attributeDict];
        [self.output appendString:@" class=\"div_standard noPointerEvents\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];


        // Okay, außerdem muss ich alle Variablen der Klasse setzen mit ihren Defaultwerten
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

        [o appendFormat:@"\n  // Klasse '%@' wurde instanziert in '%@'",elementName,self.zuletztGesetzteID];


        NSArray *keys = [self.allFoundClasses objectForKey:elementName];
        if ([keys count] > 0)
        {
            [o appendString:@"\n  // Setzen aller Attribute der Klasse mit den Defaultwerten"];
            [o appendString:@"\n  // Falls er hier schon auf eine Var zugreift, die erst in einer parent-Klasse definiert wird, nicht schlimm. Dann ist es undefined"];
            [o appendString:@"\n  // Und da undefined, wird es in interpretObject() dann 'überschrieben'"];

            for (NSString *key in keys)
            {
                NSString *value = [keys valueForKey:key];

                BOOL weNeedQuotes = YES;

                if (isNumeric(value) || isJSArray(value))
                    weNeedQuotes = NO;

                // Falls es ein berechneter Wert war, erkennen wir es an der Markierung
                // Dann Markierung raushauen und wir brauchen dann keine Quotes
                // Außerdem das korrekte Element für this ersetzen
                if ([value hasPrefix:@"@§.BERECHNETERWERT.§@"])
                {
                    value = [value substringFromIndex:21];

                    value = [value stringByReplacingOccurrencesOfString:ID_REPLACE_STRING withString:self.zuletztGesetzteID];

                    weNeedQuotes = NO;
                }

                if (weNeedQuotes)
                {
                    [o appendFormat:@"\n  %@.%@ = '%@';",self.zuletztGesetzteID,key,value];
                }
                else
                {
                    [o appendFormat:@"\n  %@.%@ = %@;",self.zuletztGesetzteID,key,value];
                }
            }
        }
        else
        {
            [o appendString:@"\n  // Keine Attribute vorhanden, die gesetzt werden müssen"];
        }

        //[o appendString:@"\n  // Je nach Verschachtelung kann die tatsächliche Instanzierung erst weiter unten sein\n"];
        // nicht mehr, seitdem ich das schreiben der Klasse wieder hier her geholt habe.


        // Erst alle Build-in-Attribute raushauen...
        NSMutableDictionary *d = [[NSMutableDictionary alloc] initWithDictionary:attributeDict];
        // CSS
        [d removeObjectForKey:@"id"];
        [d removeObjectForKey:@"name"];
        [d removeObjectForKey:@"multiline"];
        [d removeObjectForKey:@"bgcolor"];
        [d removeObjectForKey:@"fgcolor"];
        [d removeObjectForKey:@"topmargin"];
        [d removeObjectForKey:@"valign"];
        [d removeObjectForKey:@"height"];
        [d removeObjectForKey:@"width"];
        [d removeObjectForKey:@"x"];
        [d removeObjectForKey:@"y"];
        [d removeObjectForKey:@"yoffset"];
        [d removeObjectForKey:@"xoffset"];
        [d removeObjectForKey:@"fontsize"];
        [d removeObjectForKey:@"fontstyle"];
        [d removeObjectForKey:@"font"];
        [d removeObjectForKey:@"align"];
        [d removeObjectForKey:@"clip"];
        [d removeObjectForKey:@"scriptlimits"];
        [d removeObjectForKey:@"stretches"];
        [d removeObjectForKey:@"initstage"];
        [d removeObjectForKey:@"resource"];
        [d removeObjectForKey:@"source"];
        [d removeObjectForKey:@"debug"];
        // JS
        [d removeObjectForKey:@"visible"];
        [d removeObjectForKey:@"focusable"];
        [d removeObjectForKey:@"layout"];
        [d removeObjectForKey:@"onclick"];
        [d removeObjectForKey:@"ondblclick"];
        [d removeObjectForKey:@"onfocus"];
        [d removeObjectForKey:@"onblur"];
        [d removeObjectForKey:@"onvalue"];
        [d removeObjectForKey:@"onmousedown"];
        [d removeObjectForKey:@"onmouseup"];
        [d removeObjectForKey:@"onmouseout"];
        [d removeObjectForKey:@"onmouseover"];
        [d removeObjectForKey:@"onkeyup"];
        [d removeObjectForKey:@"onkeydown"];
        [d removeObjectForKey:@"datapath"];
        [d removeObjectForKey:@"clickable"];
        [d removeObjectForKey:@"showhandcursor"];
        [d removeObjectForKey:@"mask"];
        [d removeObjectForKey:@"ignoreplacement"];

        /* [d removeObjectForKey:@"value"]; Auskommentieren, bricht sonst Beispiel <basecombobox> */
        [d removeObjectForKey:@"text"];


        // Really Build-In-Values??
        [d removeObjectForKey:@"boxheight"];
        [d removeObjectForKey:@"listwidth"];
        [d removeObjectForKey:@"controlwidth"];








        // ...dann die übrig gebliebenen Attribute (die von der Klasse selbst definierten) setzen
        if ([d count] > 0)
        {
            [o appendString:@"\n  // Nach dem setzen der Defaultwerte nun setzen der Klassen-Variablen, die diese Angaben überschreiben"];

            // '__strong', damit ich object modifizieren kann
            for (NSString __strong *key in d)
            {
                self.attributeCount++;

                NSString *s = [d valueForKey:key];

                BOOL weNeedQuotes = YES;

                if (isNumeric(s) || isJSArray(s))
                    weNeedQuotes = NO;

                if ([s hasPrefix:@"$"])
                {
                    s = [self makeTheComputedValueComputable:s];
                    weNeedQuotes = NO;
                }

                key = [self somePropertysNeedToBeRenamed:key];

                if (weNeedQuotes)
                {
                    [o appendFormat:@"\n  %@.%@ = '%@';",self.zuletztGesetzteID,key,s];
                }
                else
                {
                    [o appendFormat:@"\n  %@.%@ = %@;",self.zuletztGesetzteID,key,s];
                }
            }

            [o appendString:@"\n"];
        }


        // ToDo
        if ([attributeDict valueForKey:@"ignoreplacement"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'ignoreplacement'.");
        }

        // Es können ja verschachtelte Klassen auftreten, deswegen muss ich die IDs
        // hier draufpushen, und später wegholen.
        [self.rememberedID4closingSelfDefinedClass addObject:self.zuletztGesetzteID];


        // Okay, jQuery-Code mache ich beim schließen, weil ich erst den eventuellen Text der
        // zwischen den Tags steht, aufsammeln muss, und dann als Parameter übergebe.

        // Okay, das geht so nicht, habe den Code wieder nach vorne geholt, denn sonst würde bei ineinander
        // verschschachtelten Klassen, erst die innere Klasse ausgeführt werden. Aber die innere Klasse muss
        // bereits die width vom parent wissen (für align)
        // Falls ich dann doch mal text zwischen den tags habe, dann füge ich ihn dadurch ein, dass ich wieder
        // hinten was vom Output entferne. Es kann ja nie beides geben. Entweder es gibt ineinander verschachtelte
        // Klassen ODER es gibt einen Textstring, der zwischen öffnendem und schließendem Tag liegt.


        NSString *idUmgebendesElement = [self.rememberedID4closingSelfDefinedClass lastObject];

        // Und dann kann ich es per jQuery flexibel einfügen.
        // Okay, hier muss ich jetzt per jQuery die Objekte
        // auslesen aus der JS-Datei collectedClasses.js

        //[o appendFormat:@"\n  // Klasse '%@' wurde instanziert in '%@' (Fortsetzung - tatsächliche Instanzierung - vorher wurden nur die Attribute gesetzt)",elementName,idUmgebendesElement];
        [o appendFormat:@"\n  // Instanz erzeugen, id holen, Objekt auswerten"];
        [o appendFormat:@"\n  var id = document.getElementById('%@');",idUmgebendesElement];
        [o appendFormat:@"\n  var obj = new oo.%@('');",elementName];
        [o appendString:@"\n  interpretObject(obj,id);\n"];




        // in jQueryOutput0! Damit a) keine weiteren Elemente überschrieben werden,
        // weil anhand der gesetzten css wird erkannt, welche überschrieben werden dürfen
        // und welche nicht.
        // b) damit Simplelayout hiernach NICHT EINMAL ausgeführt werden kann
        // War früher jQueryOutput.
        // analog auch beim beenden beachten. (Falls es hier geändert wird, dort mitändern!)
        [self.jQueryOutput0 appendString:o];


        // Hoffentlich ist das nicht zu lax, aber wir erlauben zwischen Klassen erstmal immer
        // HTML-Attribute. Streng genommen dürften nur dann HTMl-Attribute auftauchen, wenn die
        // Klasse von <text> (direkt oder indirekt) erbt. Oder wenn es ein 'text'- oder ein 'html'-
        // Attribut enthält (Example 28.10. Defining new text classes)
        self.weAreCollectingTextAndThereMayBeHTMLTags = YES;
    }





    /////////////////////////////////////////////////
    // Abfragen ob wir alles erfasst haben (Debug) //
    /////////////////////////////////////////////////
    if (debugmode)
    {
        if (!element_bearbeitet)
            [self instableXML:[NSString stringWithFormat:@"\nERROR: Nicht erfasstes öffnendes Element: '%@'", elementName]];

        NSLog([NSString stringWithFormat:@"Es wurden %d von %d Attributen berücksichtigt.",self.attributeCount,[attributeDict count]]);

        if (self.attributeCount != [attributeDict count])
        {
            [self instableXML:[NSString stringWithFormat:@"\nERROR: Nicht alle Attribute verwertet."]];
        }
    }
    /////////////////////////////////////////////////
    // Abfragen ob wir alles erfasst haben (Debug) //
    /////////////////////////////////////////////////
}


-(NSString*) onRecursionEnsureValidPath:(NSString*)s
{
    // Dann muss ich das aktuelle Verzeichnis erst ermitteln, weil es abweichend kann
    // Die rekursiv aufgerufene Datei kann schließlich woanders sein
    if ([s hasPrefix:@"./"] && self.isRecursiveCall)
    {
        // Ich ziehe einfach so viele Zeichen ab, wie das basedir hat,
        // so komme ich an den relativen Pfad.
        // Dies könnte brechen, wenn es kein Unterverzeichnis ist, sondern ein paralleles
        // Eine solche Ordner-projekt-struktur ist aber eher unwahrscheinlicher. Hoffe ich?!

        int n1 = [self.pathToFile_basedir length];

        // int n2 = [[[self.pathToFile URLByDeletingLastPathComponent] absoluteString] length];

        NSString *relativePath = [[[self.pathToFile URLByDeletingLastPathComponent] absoluteString] substringFromIndex:n1];

        // Den leading Punkt und Slash entfernen
        s = [s substringFromIndex:2];

        // Den gewonnenen relativen Pfad davor schalten
        s = [NSString stringWithFormat:@"%@%@",relativePath,s];

        return s;
    }
    else if (self.isRecursiveCall)
    {
        // Auch ohne './' kann es natürlich auf den relativen Pfad verweisen.
        // Dann muss ich n1 und n2 vergleichen, ob wir in einem anderen Pfad sind.

        int n1 = [self.pathToFile_basedir length];

        int n2 = [[[self.pathToFile URLByDeletingLastPathComponent] absoluteString] length];

        if (n1 != n2)
        {
            NSString *relativePath = [[[self.pathToFile URLByDeletingLastPathComponent] absoluteString] substringFromIndex:n1];

            // Den gewonnenen relativen Pfad davor schalten
            s = [NSString stringWithFormat:@"%@%@",relativePath,s];
        }

        return s;
    }

    return s;
}


-(NSMutableString*) holAlleArgumentDieKeineDefaultArgumenteSind:(NSString*)args
{
    NSError *error = NULL;

    // Auf Default values untersuchen...
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"\\w+[=]\\w+" options:NSRegularExpressionCaseInsensitive error:&error];


    NSUInteger numberOfMatches;
    do {
        numberOfMatches = [regexp numberOfMatchesInString:args options:0 range:NSMakeRange(0, [args length])];

        if (numberOfMatches > 0)
        {
            NSArray *matches = [regexp matchesInString:args options:0 range:NSMakeRange(0, [args length])];

            // Ein match nach dem anderen, weil sich sonst die range ja verschiebt
            //for (NSTextCheckingResult *match in matches)
            {
                NSRange matchRange = [[matches objectAtIndex:0] range];

                NSString *argumentWithDefaultvalue = [args substringWithRange:matchRange];

                args = [args stringByReplacingOccurrencesOfString:argumentWithDefaultvalue withString:@""];
            }
        }
    } while (numberOfMatches > 0);


    // Noch die Kommas zurecht stutzen
    args = [args stringByReplacingOccurrencesOfString:@",," withString:@","];

    if ( [args length] > 0 && [args hasSuffix:@","])
        args = [args substringToIndex:[args length] - 1];

    NSMutableString* ms = [[NSMutableString alloc] initWithString:args];
    return ms;
}



static inline BOOL isEmpty(id thing)
{
    return thing == nil
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0);
}


BOOL isNumeric(NSString *s)
{
    if (s == nil)
    {
        return NO;
    }
    NSScanner *sc = [NSScanner scannerWithString: s];
    if ( [sc scanFloat:NULL] )
    {
        return [sc isAtEnd];
    }
    return NO;
}



BOOL isJSArray(NSString *s)
{
    // Mit Sicherheit noch verbesserungswürdig, aber erstmal funktioniert es
    if ([s hasPrefix:@"["] && [s hasSuffix:@"]"])
        return YES;
    else
        return NO;
}



- (NSString*) indentTheCode:(NSString*)s
{
    // Tabs eliminieren
    while ([s rangeOfString:@"\t"].location != NSNotFound)
    {
        s = [s stringByReplacingOccurrencesOfString:@"\t" withString:@"  "];
    }

    // Leerzeichen zusammenfassen
    while ([s rangeOfString:@"  "].location != NSNotFound)
    {
        s = [s stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }

    // Damit er in jeder Code-Zeile korrekt einrückt
    s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\n       "];

    return s;
}



-(void) initTextAndKeyInProgress:(NSString*)elementName
{
    NSString *s = [self holDenGesammeltenTextUndLeereIhn];
    if ([s length] > 0)
    {
        // Wenn wir gerade eh nur sammeln (und erst später auswerten), dann bitte nicht testen,
        if (!self.weAreCollectingTheCompleteContentInClass)
        {
            //[self instableXML:[NSString stringWithFormat:@"Hoppala, das sollte aber nicht passieren, dass ich hier noch nicht ausgewerteten Text habe (textInProgress: '%@' - Länge textInProgress: %d - keyInProgress: '%@')",s,[s length],self.keyInProgress]];

            // Okay bei GFlender-Code kommt das zwar nicht vor, aber es kann gemäß OL
            // trotzdem passieren (Example 28.16.):
            // z.B.: <button>Make window red <handler name="onclick">code</handler></button>
            // wenn so etwas passiert, einfach Text ausgeben... Hoffe das geht in allen Fällen gut
            //[self.output appendString:s];
            // Nein, geht es nicht. Z. B. nicht in Example 27 - der mißglückte comment)
            // Deswegen nur ausgeben, wenn ein Button vorliegt
            NSString *enclosingElem = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];

            if ([enclosingElem isEqualToString:@"button"] ||
                [enclosingElem isEqualToString:@"text"] ||
                [enclosingElem isEqualToString:@"inputtext"])
                    [self.output appendString:s];

            // Oder: bei jeder selbst definierten Klasse zuschlagen
            if ([self.allFoundClasses objectForKey:enclosingElem] != nil)
            {
                // Da ich den string mit ' umschlossen habe, muss ich eventuelle ' im String escapen
                s = [s stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"];
                s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

                // Dann IN den jQueryOutput hinein injecten
                [self.jQueryOutput0 insertString:s atIndex:[self.jQueryOutput0 length]-31];
            }
        }
    }


    // This is a string we will append to as the text arrives
    self.textInProgress = [[NSMutableString alloc] init];

    // Kann ich eventuell noch gebrauchen um das aktuelle Tag abzufragen
    self.keyInProgress = [elementName copy];
}



// Der Text der zwischen den <tags> gefunden wurde, kann hier einfach entnommen werden
// Mit jeder Entnahme (und somit Verwertung) ist ein Zurücksetzen des Textes verbunden.
- (NSString*) holDenGesammeltenTextUndLeereIhn
{
    NSString *s = @"";

    // Immer auf nil testen, sonst kann es abstürzen hier
    if (self.textInProgress != nil)
    {
        s = self.textInProgress;

        self.textInProgress = nil;
    }

    // Remove leading and ending Whitespaces and NewlineCharacters
    s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return s;
}



- (void) parser:(NSXMLParser *)parser
  didEndElement:(NSString *)elementName
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
{
    // Zum internen testen, ob wir alle Elemente erfasst haben
    BOOL element_geschlossen = NO;

    // Schließen von baselist
    // Noch schnell BEVOR ich reduziereVerschachtelungstiefe aufrufe,
    // weil ich auf die ID des Elements zurückgreife!
    if ([elementName isEqualToString:@"baselist"] || [elementName isEqualToString:@"list"])
    {
        element_geschlossen = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"</select>\n"];

        [self.jsComputedValuesOutput appendString:@"\n  // setting the attribute 'size' of <select>-Box\n"];
        [self.jsComputedValuesOutput appendFormat:@"  setSizeOfSelectBoxIn(%@);\n",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1]];
    }


    [self reduziereVerschachtelungstiefe];


    NSLog([NSString stringWithFormat:@"Closing Element: %@ (Neue Verschachtelungstiefe: %d)\n", elementName,self.verschachtelungstiefe]);


    // Alle einzeln durchgehen, damit wir besser fehlende überprüfen können,
    // deswegen ist hier drin kein redundanter Code
    if (self.weAreCollectingTextAndThereMayBeHTMLTags)
    {
        if ([elementName isEqualToString:@"br"])
        {
            element_geschlossen = YES;

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"a"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</a>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"b"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</b>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"i"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</i>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"p"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</p>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"u"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</u>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"font"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</font>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"img"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</img>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }
    }



    // Neu eingeführt, seitdem wir datasets als xml-struktur auswerten
    // Wenn wir <items> hatten, haben wir bisher immer ein Array angelegt.
    // Jedenfalls hier jetzt setzen der Var auf NO, damit er im schließenden
    // Dataset nicht das schließende Tag der XML-Struktur auch bei Arrays anlegt
    // Langfristig eh überdenken, ob es noch sinnvoll ist Arrays anzulegen.
    // Am besten IMMER xml-struktur, wenn möglich.
    if (werteItemUndItemsAlsArrayAus)
    if ([elementName isEqualToString:@"items"])
        element_geschlossen = YES;
    



    // Schließen von dataset
    if ([elementName isEqualToString:@"dataset"])
    {
        element_geschlossen = YES;

        self.datasetItemsCounter = 0;

        if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
        {
            [self.jsHead2Output appendFormat:@"%@.rawdata += '</%@>';\n",self.lastUsedDataset, self.lastUsedDataset];

            self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
        }
        else
        {
            [self.jsHead2Output appendString:@"\n"];
        }
    }

    // Handle unknown closing Elements in dataset
    if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
    {
        element_geschlossen = YES;

        self.weAreCollectingTextAndThereMayBeHTMLTags = NO;

        NSString *gesammelterText = [self holDenGesammeltenTextUndLeereIhn];

        // Da wir es in ' einschließen, müssen diese escaped werden:
        gesammelterText = [gesammelterText stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
        // Auch newlines müssen escaped werden
        gesammelterText = [gesammelterText stringByReplacingOccurrencesOfString:@"\n" withString:@"\\\n"];


        [self.jsHead2Output appendFormat:@"%@.rawdata += '%@</%@>';\n",self.lastUsedDataset, gesammelterText, elementName];


        /* Seit Umstieg auf XML-Struktur (und kein JS-Objekt mehr) nicht mehr nötig
        if ([gesammelterText length] > 0)
        {
            // Dann ist es doch kein Objekt... sondern es wird ein Inhalt erfasst.
            if ([self.jsHead2Output length] > 0)
            {
                // self.jsHead2Output = [NSMutableString stringWithFormat:[self.jsHead2Output substringToIndex:[self.jsHead2Output length] - 4]];
            }
            
            // Und hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde.
            //[self.jsHead2Output appendFormat:@"%@;\n",gesammelterText];
        }
        */






        // Das sind selbstdefinierte Tags. Raus hier. Die werden niemals matchen
        // Es wurde ja alles erledigt.
        return;
    }







    // Okay, beim schließen den gesammelten String rekursiv auswerten und dann das Ergebnis
    // der analogen JS-Klasse hinzufügen.
    // Die 2. Bedingung muss rein, sonst wertet er den 2. <when>-Zweig hier mit aus...
    if ([elementName isEqualToString:@"class"] && (!self.weAreInTheTagSwitchAndNotInTheFirstWhen))
    {
        NSLog(@"Starting recursion (with String, not file, because of <class>) Content of string:");


        // Es muss ein gesamtumfassendes Tag geben, sonst ist es kein valides XML.
        // <library>, weil dies einerseits bereits in OL vorkommt und andererseits neutral ist.
        // Falsch!! <library> ist nicht neutral! Es beeinflusst ob methods global sind oder nicht!
        // Das war ein ziemlich fieser Bug.
        // Deswegen lieber mit eigenem Tag 'evaluateclass' arbeiten, das ist wirklich neutral.
        self.collectedContentOfClass = [[NSMutableString alloc] initWithFormat:@"<evaluateclass>%@",self.collectedContentOfClass];
        [self.collectedContentOfClass appendString:@"</evaluateclass>"];


        NSLog(self.collectedContentOfClass);
        xmlParser *x = [[xmlParser alloc] initWith:self.pathToFile recursiveCall:YES];

        // In <class> definierte Elemente greifen auch auf extern definierte Ressourcen zurück.
        // Muss ich deswegen hier übertragen.
        // x.allJSGlobalVars = self.allJSGlobalVars; // Natürlich nicht so....
        [x.allJSGlobalVars addEntriesFromDictionary:self.allJSGlobalVars]; // sondern so

        // Wenn wir <class> auswerten dann haben wir generelle Klassen und dürfen keine
        // festen IDs vergeben!
        x.ignoreAddingIDsBecauseWeAreInClass = YES;

        // Es kann natürlich auch in Klassen Klassen geben
        x.allFoundClasses = self.allFoundClasses;

        // Damit ich die Attribute der Klasse korrekt zuordnen kann,
        // muss ich den Namen der Klasse wissen!
        x.lastUsedNameAttributeOfClass = self.lastUsedNameAttributeOfClass;

        NSArray* result = [x startWithString:self.collectedContentOfClass];
        NSLog(@"Leaving recursion (with String, not file, because of <class>)");

        // Nachdem es benutzt wurde, sofort nullen.
        self.collectedContentOfClass = [[NSMutableString alloc] initWithString:@""];




        // NATÜRLICH DARF ICH HIER NICH APPENDEN, bzw. nicht immer. :-)
        // Ich nehme die einzelnen Resultate und muss schauen was davon relevant ist.
        NSString *rekursiveRueckgabeOutput = [result objectAtIndex:0];
        if (![rekursiveRueckgabeOutput isEqualToString:@""])
            NSLog(@"String 0 aus der Rekursion wird unser HTML-content für das JS-Objekt.");

        NSString *rekursiveRueckgabeJsOutput = [result objectAtIndex:1];
        if (![rekursiveRueckgabeJsOutput isEqualToString:@""])
            NSLog(@"String 1 aus der Rekursion wird unser JS-content für JS-Objekt.");

        NSString *rekursiveRueckgabeJsOLClassesOutput = [result objectAtIndex:2];
        if (![rekursiveRueckgabeJsOLClassesOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 2 zurück. Da muss ich mir was überlegen!"];

        NSString *rekursiveRueckgabeJQueryOutput0 = [result objectAtIndex:3];
        if (![rekursiveRueckgabeJQueryOutput0 isEqualToString:@""])
            NSLog(@"String 3 aus der Rekursion wird unser Leading-jQuery-content für das JS-Objekt.");

        NSString *rekursiveRueckgabeJQueryOutput = [result objectAtIndex:4];
        if (![rekursiveRueckgabeJQueryOutput isEqualToString:@""])
            NSLog(@"String 4 aus der Rekursion wird unser jQuery-content für das JS-Objekt.");

        NSString *rekursiveRueckgabeJsHeadOutput = [result objectAtIndex:5];
        if (![rekursiveRueckgabeJsHeadOutput isEqualToString:@""])
            NSLog(@"String 5 aus der Rekursion wird unser Leading-JS-Head-content für JS-Objekt");

        NSString *rekursiveRueckgabeJsHead2Output = [result objectAtIndex:6];
        if (![rekursiveRueckgabeJsHead2Output isEqualToString:@""])
            NSLog(@"String 6 aus der Rekursion wird unser JS-Head2-content für JS-Objekt");

        NSString *rekursiveRueckgabeCssOutput = [result objectAtIndex:7];
        if (![rekursiveRueckgabeCssOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 7 zurück. Da muss ich mir was überlegen!"];

        NSString *rekursiveRueckgabeExternalJSFilesOutput = [result objectAtIndex:8];
        if (![rekursiveRueckgabeExternalJSFilesOutput isEqualToString:@""])
            [self instableXML:@"<class> liefert was in 8 zurück. Da muss ich mir was überlegen!"];

        NSDictionary *rekursiveRueckgabeAllJSGlobalVars = [result objectAtIndex:9];
        if ([rekursiveRueckgabeAllJSGlobalVars count] > 0)
        {
            // Wir sollten hier immer reinkommen, weil wir unser nicht-rekursives Dictionary
            // vorher ja in die Rekursion übertragen haben.
            // Hier setze ich es wieder zurück falls Einträge hinzugefügt wurden
            ////////////////////////////////////////////////////////////////////
            // [self.allJSGlobalVars setDictionary:rekursiveRueckgabeAllJSGlobalVars];
            ////////////////////////////////////////////////////////////////////
            // Dies kann Probleme geben, wenn in <class> 'lokal' definierte res hier reinkommen
            // Denn es kann passieren, dass andere Einträge überschrieben werden.
            // Deswegen erstmal rausnehmen
        }

        // NSDictionary *rekursiveRueckgabeAllFoundClasses = [result objectAtIndex:10];
        // Ich gehe erstmal nicht davon aus, dass man Klassen in Klassen definieren kann.
        // Deswegen ist das hier auskommentiert. Falls doch müsste man das Dictionary hier nehmen
        // und das Dictionary auf dieser Ebene damit ersetzen.
        //if ([rekursiveRueckgabeAllFoundClasses count] > 0)
        //   [self instableXML:@"<class> liefert was in 10 zurück. Da muss ich mir was überlegen!"];

        self.defaultplacement = [result objectAtIndex:12];

        NSString *rekursiveRueckgabeJsComputedValuesOutput = [result objectAtIndex:13];
        if (![rekursiveRueckgabeJsComputedValuesOutput isEqualToString:@""])
            NSLog(@"String 13 aus der Rekursion wird unser JS-Computed-Values-content für JS-Objekt");

        NSString *rekursiveRueckgabeJsConstraintValuesOutput = [result objectAtIndex:14];
        if (![rekursiveRueckgabeJsConstraintValuesOutput isEqualToString:@""])
            NSLog(@"String 14 aus der Rekursion wird unser JS-Constraint-Values-content für JS-Objekt");

        [self.allImgPaths addObjectsFromArray:[result objectAtIndex:15]];




        // Falls im HTML-Code Text mit ' auftaucht, müssen wir das escapen.
        rekursiveRueckgabeOutput = [rekursiveRueckgabeOutput stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];


        // In manchen JS/jQuery tauchen " auf, die müssen escaped werden
        rekursiveRueckgabeJQueryOutput = [rekursiveRueckgabeJQueryOutput stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        rekursiveRueckgabeJsHead2Output = [rekursiveRueckgabeJsHead2Output stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];


        // In manchen JS/jQuery tauchen \n auf, die müssen zu <br /> werden
        rekursiveRueckgabeJQueryOutput = [rekursiveRueckgabeJQueryOutput stringByReplacingOccurrencesOfString:@"\\n" withString:@"<br />"];



        // Ich muss im Quellcode bereits vorab geschriebene Escape-Sequenzen berücksichtigen:
        // In JQueryOutput0 taucht folgendes auf: "\"", aber auch "\\" 
        // Ich muss erst \\” suchen und ersetzen mit temporären string
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"\\\\\"" withString:@"ugly%$§§$%ugly1"];
        // Jetzt muss ich \” suchen und ersetzen mit temporären string
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"\\\"" withString:@"ugly%$§§$%ugly2"];
        // Jetzt normales ersetzen von \"
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        // Jetzt kann ich nach \" bzw den ersetzten String suchen und ersetzen
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"ugly%$§§$%ugly2" withString:@"\\\\\\\""];
        // Jetzt kann ich nach \\" bzw den ersetzten String suchen und ersetzen
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"ugly%$§§$%ugly1" withString:@"\\\\\\\\\\\""];





        // Newlines innherhalb von Strings sind in JS nicht zulässig
        // Deswegen muss ich diese aus dem String entfernen.
        // Eine wirklich gute Multi-Line-String-Lösung gibt es wohl nicht.
        // Siehe auch: http://google-styleguide.googlecode.com/svn/trunk/javascriptguide.xml?showone=Multiline_string_literals#Multiline_string_literals
        // Am Ende innerhalb der JS-String-Zeile muss ein \\n stehen, damit Kommentare nur für eine Zeile gelten
        rekursiveRueckgabeOutput = [rekursiveRueckgabeOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n' + \n  '"];
        rekursiveRueckgabeJQueryOutput = [rekursiveRueckgabeJQueryOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsHead2Output = [rekursiveRueckgabeJsHead2Output stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsOutput = [rekursiveRueckgabeJsOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsHeadOutput = [rekursiveRueckgabeJsHeadOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsComputedValuesOutput = [rekursiveRueckgabeJsComputedValuesOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsConstraintValuesOutput = [rekursiveRueckgabeJsConstraintValuesOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];


        [self.jsOLClassesOutput appendString:@"  // Die selfDefinedAttributes sind nun sehr wichtig und werden stets verwertet\n"];


/* // Dieser alte Code war zu ungenau, und hat z.B. Arrays nicht als Arrays erkannt, sondern nur als Strings.
        NSString *newlyIntroducedAttributes = [NSString stringWithFormat:@"%@",[self.allFoundClasses objectForKey:self.lastUsedNameAttributeOfClass]];

        // Alle Newlines außerhalb von String ersetzen, damit es JS-Objekt-konform wird
        newlyIntroducedAttributes= [self inString:newlyIntroducedAttributes searchFor:@"\n" andReplaceWith:@", " ignoringTextInQuotes:YES];

        // Das Komma ganz am Anfang entfernen
        newlyIntroducedAttributes= [self inString:newlyIntroducedAttributes searchFor:@"{," andReplaceWith:@"{" ignoringTextInQuotes:YES];

        // Das Komma ganz am Ende entfernen
        newlyIntroducedAttributes= [self inString:newlyIntroducedAttributes searchFor:@", }" andReplaceWith:@" }" ignoringTextInQuotes:YES];

        // Verbleibende Newlines (auch) IN Strings escapen
        newlyIntroducedAttributes = [newlyIntroducedAttributes stringByReplacingOccurrencesOfString:@"\n" withString:@"\\\n"];
        newlyIntroducedAttributes = [newlyIntroducedAttributes stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"];
        // Um es zu einem JS-Objekt zu machen:
        newlyIntroducedAttributes= [self inString:newlyIntroducedAttributes searchFor:@"=" andReplaceWith:@":" ignoringTextInQuotes:YES];
        newlyIntroducedAttributes= [self inString:newlyIntroducedAttributes searchFor:@";" andReplaceWith:@"" ignoringTextInQuotes:YES];
        newlyIntroducedAttributes= [self inString:newlyIntroducedAttributes searchFor:@"  " andReplaceWith:@" " ignoringTextInQuotes:YES];

        [self.jsOLClassesOutput appendFormat:@"  this.selfDefinedAttributes = %@;\n\n",newlyIntroducedAttributes];
*/


        [self.jsOLClassesOutput appendFormat:@"  this.selfDefinedAttributes = { "];

        NSArray *keys = [self.allFoundClasses objectForKey:self.lastUsedNameAttributeOfClass];
        if ([keys count] > 0)
        {
            for (NSString *key in keys)
            {
                NSString *value = [keys valueForKey:key];


                BOOL weNeedQuotes = YES;

                if (isNumeric([keys valueForKey:key]) || isJSArray([keys valueForKey:key]))
                    weNeedQuotes = NO;


                // Falls es ein berechneter Wert war, erkennen wir es an der Markierung
                // Dann Markierung raushauen und wir brauchen dann keine Quotes
                // Außerdem das korrekte Element für this ersetzen
                if ([value hasPrefix:@"@§.BERECHNETERWERT.§@"])
                {
                    //value = [value substringFromIndex:21];

                    // Wieder zurück an 'this' binden. Ka. Alternative wäre es zu lassen und zur Laufzeit auszuwerten
                    //value = [value stringByReplacingOccurrencesOfString:ID_REPLACE_STRING withString:@"this"];

                    //weNeedQuotes = NO;
                    // Neu: Nichts machen. Wir müssen es erst zur Laufzeit auswerten, weil wir erst
                    // dann this korrekt setzen können (this == das aktuelle Objekt)
                }


                if (!weNeedQuotes)
                {
                    [self.jsOLClassesOutput appendFormat:@" %@ : %@,", key, value];
                }
                else
                {
                    // ' und Newlines escapen bei Strings:
                    value = [value stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"];
                    value = [value stringByReplacingOccurrencesOfString:@"\n" withString:@"\\\n"];

                    [self.jsOLClassesOutput appendFormat:@" %@ : '%@',", key, value];
                }
            }
        }
        else
        {
            // Keine Attribute vorhanden, die gesetzt werden müssen
        }
        // Das letzte Komma wieder entfernen
        if ([self.jsOLClassesOutput hasSuffix:@","])
            self.jsOLClassesOutput = [[NSMutableString alloc] initWithString:[self.jsOLClassesOutput substringToIndex:[self.jsOLClassesOutput length] - 1]];

        [self.jsOLClassesOutput appendFormat:@" };\n\n"];


        // defaultplacement immer mit speichern, damit es besser ausgelesen werden kann,
        // falls gesetzt.
        [self.jsOLClassesOutput appendFormat:@"  this.defaultplacement = '%@';\n\n",self.defaultplacement];
        // Nachdem ausgelesen, wieder zurücksetzen:
        self.defaultplacement = @"";


        [self.jsOLClassesOutput appendString:@"  this.contentHTML = '"];
        if ([rekursiveRueckgabeOutput length] > 0)
            [self.jsOLClassesOutput appendString:@"' +\n  '"];
        // Überträgt den gesammelten OL-Code in die Datei
        // [self.jsOLClassesOutput appendString:self.collectedContentOfClass];
        // Aber wir wollen ja den schon ausgewerteten Code übertragen:
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeOutput];
        [self.jsOLClassesOutput appendString:@"';\n\n"];


        [self.jsOLClassesOutput appendString:@"  this.contentLeadingJSHead = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsHeadOutput];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];

        [self.jsOLClassesOutput appendString:@"  this.contentJSHead = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsHead2Output];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];
        
        [self.jsOLClassesOutput appendString:@"  this.contentJS = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsOutput];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];

        [self.jsOLClassesOutput appendString:@"  this.contentLeadingJQuery = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJQueryOutput0];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];

        [self.jsOLClassesOutput appendString:@"  this.contentJSComputedValues = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsComputedValuesOutput];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];

        [self.jsOLClassesOutput appendString:@"  this.contentJSConstraintValues = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsConstraintValuesOutput];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];


        [self.jsOLClassesOutput appendString:@"  this.contentJQuery = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJQueryOutput];
        [self.jsOLClassesOutput appendString:@"\";\n"];


        [self.jsOLClassesOutput appendString:@"};\n"];

        
        [self.jsOLClassesOutput appendString:@"// Jede Klasse kann auch per Skript erzeugt werden\n"];
        [self.jsOLClassesOutput appendFormat:@"lz_MetaClass.prototype.%@ = function(scope,attributes) { return createObjectFromScript('%@',scope,attributes); };\n",self.lastUsedNameAttributeOfClass,self.lastUsedNameAttributeOfClass];

        // marker - eventuell kann das wieder entfernt werden
        self.textInProgress = nil;
    }

    if ([elementName isEqualToString:@"class"] ||
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

        self.weAreCollectingTheCompleteContentInClass = NO;
    }
    // If we are still skipping All Elements, let's return here
    if (self.weAreCollectingTheCompleteContentInClass)
    {
        // Wenn wir in <class> sind, sammeln wir alles (wird erst später rekursiv ausgewertet)

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Alle '&' und '<' müssen ersetzt werden, sonst meckert der XML-Parser
        // Das &-ersetzen muss natürlich als erstes kommen, weil ich danach ja wieder
        // welche einfüge (durch die Entitys).
        s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];


        [self.collectedContentOfClass appendString:s];
        [self.collectedContentOfClass appendFormat:@"</%@>",elementName];


        return;
    }

    if ([elementName isEqualToString:@"BDSinputgrid"] ||
        [elementName isEqualToString:@"BDSreplicator"])
    {
        element_geschlossen = YES;

        self.weAreSkippingTheCompleteContentInThisElement = NO;
    }
    // If we are still skipping All Elements, let's return here
    if (self.weAreSkippingTheCompleteContentInThisElement)
        return;




    // Dies hier MUSS wirklich als erstes kommen... Hat mich 3 Stunden Zeit gekostet...
    // Insbesondere muss es vor '</class>' kommen!!
    // Damit wir nur einen when-Zweig berücksichtigen,
    // überspringen wir ab jetzt alle weiteren Elemente.
    if ([elementName isEqualToString:@"when"])
    {
        element_geschlossen = YES;

        // Spezialfall: Wenn wir gerade den Inhalt einer <class> sammeln,
        // dann muss ich das </when> natürlich zu der Sammlung hinzufügen.
        // Sonst fehlt uns genau dieses </when> in unserem String und das rekursive
        // auslesen des Strings platzt (XML-Fehler)
        //if (self.weAreSkippingTheCompleteContenInThisElement)
        //    [self.collectedContentOfClass appendString:@"</when>"];
        // Ne, klappt so nicht. Muss ich über oben direkt in "class" lösen.


        self.weAreInTheTagSwitchAndNotInTheFirstWhen = YES;
    }
    if ([elementName isEqualToString:@"switch"])
    {
        element_geschlossen = YES;
        self.weAreInTheTagSwitchAndNotInTheFirstWhen = NO;

        // Einmal extra Verschachtelungstiefe reduzieren, für das erste schließende when
        // Für das korrespondierende öffnende tag wurde die Verschachtelungstiefe nämlich vorher erhöht!
        //[self reduziereVerschachtelungstiefe];
        // Neu: Nicht mehr nötig seid reduziereVerschachtelungstiefe ganz am Anfang steht
    }
    // wenn wir aber trotzdem immer noch drin sind, dann raus hier, sonst würde er Elemente
    // schließend bearbeiten, die im 'when'-Zweig drin liegen
    if (self.weAreInTheTagSwitchAndNotInTheFirstWhen)
    {
        NSLog([NSString stringWithFormat:@"\nSkipping the closing Element %@, (Because we are in <switch>, but not in the first <when>)", elementName]);
        return;
    }





    if ([elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"radiogroup"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"rotateNumber"] ||
        [elementName isEqualToString:@"rollUpDownContainer"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"baselist"] ||
        [elementName isEqualToString:@"list"] ||
        [elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"] ||
        [elementName isEqualToString:@"imgbutton"])
            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];





    if ([elementName isEqualToString:@"text"] ||
        [elementName isEqualToString:@"inputtext"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        [self.output appendString:s];
        [self.output appendString:@"</div>\n"];

        if ([elementName isEqualToString:@"text"])
        {
            // Ab jetzt dürfen wieder Tags gesetzt werden.
            self.weAreCollectingTextAndThereMayBeHTMLTags = NO;
            NSLog(@"<text> was closed. I will not any longer skip tags.");
        }
    }




    if ([elementName isEqualToString:@"resource"])
    {
        element_geschlossen = YES;


        // Dann gab es keine frame-tags
        if ([self.collectedFrameResources count] == 0)
            return;

        [self.jsHeadOutput appendString:@"// 'resourcen' -> Diese werden später an das korrekte Objekt gebunden.\n"];
        [self.jsHeadOutput appendString:@"// Bewusst ohne 'var', damit beim auswerten einer <class> verfügbar.\n"];

        // Erst nachdem die Resource beendet wurde wissen wir ob wir ein Array anlegen müssen oder nicht
        if ([self.collectedFrameResources count] == 1)
        {
            // [self.jsHeadOutput appendString:@"var "];
            [self.jsHeadOutput appendString:self.last_resource_name_for_frametag];
            [self.jsHeadOutput appendString:@" = \""];
            [self.jsHeadOutput appendString:[self.collectedFrameResources objectAtIndex:0]];
            [self.jsHeadOutput appendString:@"\";\n"];
        }
        else // Okay, mehrere Einträge vorhanden, also müssen wir ein Array anlegen
        {
            // [self.jsHeadOutput appendString:@"var "];
            [self.jsHeadOutput appendString:self.last_resource_name_for_frametag];
            [self.jsHeadOutput appendString:@" = new Array();\n"];
            for (int i=0; i<[self.collectedFrameResources count]; i++)
            {
                [self.jsHeadOutput appendString:self.last_resource_name_for_frametag];
                [self.jsHeadOutput appendString:@"["];
                [self.jsHeadOutput appendFormat:@"%d" ,i];
                [self.jsHeadOutput appendString:@"] = '"];
                [self.jsHeadOutput appendString:[self.collectedFrameResources objectAtIndex:i]];
                [self.jsHeadOutput appendString:@"';\n"];
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
    if ([elementName isEqualToString:@"simplelayout"] ||
        [elementName isEqualToString:@"BDSedit"] ||
        [elementName isEqualToString:@"BDSeditdate"] ||
        [elementName isEqualToString:@"BDScombobox"] ||
        [elementName isEqualToString:@"BDScheckbox"] ||
        [elementName isEqualToString:@"checkbox"] ||
        [elementName isEqualToString:@"radiobutton"] ||
        [elementName isEqualToString:@"BDSFinanzaemter"] ||
        [elementName isEqualToString:@"frame"] ||
        [elementName isEqualToString:@"font"] ||
        [elementName isEqualToString:@"face"] ||
        [elementName isEqualToString:@"library"] ||
        [elementName isEqualToString:@"html"] ||
        [elementName isEqualToString:@"audio"] ||
        [elementName isEqualToString:@"include"] ||
        [elementName isEqualToString:@"datapointer"] ||
        [elementName isEqualToString:@"attribute"] ||
        [elementName isEqualToString:@"infobox_notsupported"] ||
        [elementName isEqualToString:@"infobox_euerhinweis"] ||
        [elementName isEqualToString:@"infobox_stnr"] ||
        [elementName isEqualToString:@"infobox_plausi"] ||
        [elementName isEqualToString:@"state"] ||
        [elementName isEqualToString:@"animatorgroup"] ||
        [elementName isEqualToString:@"animator"] ||
        [elementName isEqualToString:@"datapath"] ||
        [elementName isEqualToString:@"int_vscrollbar"] ||
        [elementName isEqualToString:@"combobox"] ||
        [elementName isEqualToString:@"datacombobox"] ||
        [elementName isEqualToString:@"multistatebutton"] ||
        [elementName isEqualToString:@"stableborderlayout"] ||
        [elementName isEqualToString:@"scrollview"] ||
        [elementName isEqualToString:@"BDStabsheetselected"] ||
        [elementName isEqualToString:@"ftdynamicgrid"] ||
        [elementName isEqualToString:@"calcDisplay"] ||
        [elementName isEqualToString:@"calcButton"] ||
        [elementName isEqualToString:@"debug"] ||
        [elementName isEqualToString:@"event"] ||
        [elementName isEqualToString:@"slider"] ||
        [elementName isEqualToString:@"evaluateclass"])
    {
        element_geschlossen = YES;
    }




    // Nur schließen des Div's
    if ([elementName isEqualToString:@"canvas"] || 
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"radiogroup"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"rotateNumber"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"])
    {
        element_geschlossen = YES;

        [self.output appendString:@"</div>\n"];
    }


    if ([elementName isEqualToString:@"window"])
    {
        element_geschlossen = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
        [self.output appendString:@"</div>\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];
    }


    // Schließen von passthrough
    if ([elementName isEqualToString:@"passthrough"])
    {
        element_geschlossen = YES;

        // Ich muss in dem Fall den gesammelten Text leeren, da ich diesen nicht verwerte
        self.textInProgress = nil;
    }


    // Schließen von baselistitem
    // Schließen von textlistitem
    if ([elementName isEqualToString:@"baselistitem"] ||
        [elementName isEqualToString:@"textlistitem"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        if ([s length] > 0)
        {
            [self.output appendString:s];
        }

        [self.output appendString:@"</option>\n"];
    }



    // Schließen von Button
    if ([elementName isEqualToString:@"button"])
    {
        element_geschlossen = YES;

        [self.output appendString:@"</button>\n"];

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];


        if (![s isEqualToString:@""])
        {
            //s = [NSString stringWithFormat:@"'%@'",s];
            [self setTheValue:s ofAttribute:@"text"];
        }
    }



    // Schließen von tooltip
    if ([elementName isEqualToString:@"tooltip"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        [self.jQueryOutput appendString:@"\n  // Tooltip setzen, wird per CSS aus dem HTML5-data-Attribut ausgelesen\n"];
        [self.jQueryOutput appendFormat:@"  if ($('#%@').offset().top < 40)\n",self.zuletztGesetzteID];
        [self.jQueryOutput appendFormat:@"    $('#%@').attr('data-tooltip-bottom','%@');\n",self.zuletztGesetzteID,s];
        [self.jQueryOutput appendString:@"  else\n"];
        [self.jQueryOutput appendFormat:@"    $('#%@').attr('data-tooltip','%@');\n",self.zuletztGesetzteID,s];
    }



    // Schließen von BDStext
    if ([elementName isEqualToString:@"BDStext"] || [elementName isEqualToString:@"statictext"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        [self.output appendString:s];

        // Ab jetzt dürfen wieder Tags gesetzt werden.
        self.weAreCollectingTextAndThereMayBeHTMLTags = NO;
        NSLog(@"BDStext/statictext was closed. I will not any longer skip HTML-tags.");

        [self.output appendString:@"</div>\n"];
    }



    // Schließen von edittext
    if ([elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        if (s.length > 0)
            [self setTheValue:s ofAttribute:@"text"];

        [self.output appendString:@"  </div>\n"];
    }


    // Schließen von item
    if (werteItemUndItemsAlsArrayAus)
    if ([elementName isEqualToString:@"item"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Hinzufügen von gesammelten Text
        [self.jsHead2Output appendString:s];
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

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];


        // Natürlich auch hier setAttribute durch setAttribute_ ersetzen usw.
        s = [self modifySomeExpressionsInJSCode:s];


        // Jetzt wird's richtig schmutzig, ich muss defaultarguments raus-regexpen, weil es die in JS nicht gibt
        NSError *error = NULL;
        // Ich muss die öffnende Klammer der Funktion mitnehmen, damit ich später korrekt die defaultArgs injecten kann
        // * nach dem Leerzeichen und dem \w, und kein +, damit er auch anonyme Funktionen ohne Namen matcht...
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"function[ ]*\\w*\\((.+)\\)\\s\\{" options:NSRegularExpressionCaseInsensitive error:&error];

        NSArray *matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];

        for (NSTextCheckingResult *match in matches)
        {
            NSString *funktionskopf = [s substringWithRange:[match rangeAtIndex:0]];



            NSRange argsRange = [match rangeAtIndex:1];

            NSString *args = [s substringWithRange:argsRange];
            args = [args stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            args = [args stringByReplacingOccurrencesOfString:@" " withString:@""];
            NSLog([NSString stringWithFormat:@"Found argsString: %@. I will continue my work now.",args]);






            // Falls es default Values gibt, muss ich diese in JS extra setzen
            NSMutableString *defaultValues = [[NSMutableString alloc] initWithString:@""];

            // Überprüfen ob es default values gibt im Handler direkt (mit RegExp)...
            NSError *error = NULL;
            NSRegularExpression *regexp2 = [NSRegularExpression regularExpressionWithPattern:@"([\\w]+)=([\\w]+)" options:NSRegularExpressionCaseInsensitive error:&error];

            NSUInteger numberOfMatches = [regexp2 numberOfMatchesInString:args options:0 range:NSMakeRange(0, [args length])];
            if (numberOfMatches > 0)
            {
                NSMutableString *neueArgs = [[NSMutableString alloc] initWithString:@""];
                // Es kann ja auch eine Mischung geben, von sowohl Argumenten mit
                // Defaultwerten als auch solchen ohne. Deswegen hier erstmal ohne
                // Defaultargumente setzen und dann gleich die alle mit.
                neueArgs = [self holAlleArgumentDieKeineDefaultArgumenteSind:args];
                NSLog([NSString stringWithFormat:@"There is/are %d argument(s) with a default argument. I will regexp them.",numberOfMatches]);

                NSArray *matches = [regexp2 matchesInString:args options:0 range:NSMakeRange(0, [args length])];

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
                    [defaultValues appendFormat:@"\n    if(typeof(%@)==='undefined') ",varName];
                    [defaultValues appendFormat:@"%@ = %@;\n",varName,defaultValue];
                    ///////////////////// Default- Variablen für JS setzen - Ende /////////////////////
                }

                // ... und hier setzen
                args = neueArgs;

                // Den funktionskopf von oben jetzt benutzen. In diesem die Argumente ersetzen...
                int posOeffnendeKlammer = [funktionskopf rangeOfString:@"("].location;
                funktionskopf = [funktionskopf substringToIndex:posOeffnendeKlammer];
                funktionskopf = [NSString stringWithFormat:@"%@(%@) {",funktionskopf,neueArgs];

                // ... dann den alten Funktionskopf komplett ersetzen. Dazu auf das alte regexp von oben  zugreifen
                s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:funktionskopf];


                // Jetzt muss ich 'nur noch' die defaultwerte injecten
                // Dazu kurz mit einem NSMutableString arbeiten
                // Und wir greifen auf den 'match' und dessen Länge vo ganz oben zu um die genaue Stelle zu ermitteln
                int n_entfernteZeichen = [match rangeAtIndex:0].length - funktionskopf.length;

                NSMutableString *t = [NSMutableString stringWithFormat:@"%@",s];
                [t insertString:defaultValues atIndex:[match rangeAtIndex:0].location+[match rangeAtIndex:0].length-n_entfernteZeichen];
                s = [NSString stringWithFormat:t];
            }
        }


        // Die Variablen auf die zugegriffen wird, sind teils HTMLDivElemente
        // und müssen bekannt sein, deswegen kann es nicht im Head stehen (alte Lösung)
        // [self.jsHead2Output appendString:s];
        // statt dessen:
        // War jQueryOutput, aber es muss vor den SimpleLayouts bekannt sein, da diese sich auch auf
        // per Skript gesetzte Elemente mit beziehen
        // Deswegen jQueryOutput0
        [self.jQueryOutput0 appendString:@"\n  /***** ausgewertetes <script>-Tag - Anfang *****/\n"];
        [self.jQueryOutput0 appendFormat:@"  %@",s];
        [self.jQueryOutput0 appendString:@"\n  /***** ausgewertetes <script>-Tag - Ende *****/\n"];
    }






    if ([elementName isEqualToString:@"handler"])
    {
        element_geschlossen = YES;

        if ([self.methodAttributeInHandler length] > 0)
        {
            [self.jQueryOutput appendString:@"if (this == e.target) {\n      "];

            [self.jQueryOutput appendFormat:@"this.%@();\n    }\n",self.methodAttributeInHandler];

            [self.jQueryOutput appendString:@"  });\n"];
        }
        else
        {
            NSString *s = [self holDenGesammeltenTextUndLeereIhn];

            NSLog([NSString stringWithFormat:@"Original code defined in handler: \n**********\n%@\n**********",s]);


            s = [self indentTheCode:s];


            s = [self modifySomeExpressionsInJSCode:s];


            // OL benutzt 'classroot' als Variable für den Zugriff auf das erste in einer Klasse
            // definierte Element. Deswegen, falls wir eine Klasse auswerten, einfach diese Var setzen
            if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
                [self.jQueryOutput appendFormat:@"var classroot = %@;\n    ",ID_REPLACE_STRING];

            if (self.onInitInHandler)
            {
                [self.jQueryOutput appendString:s];
                [self.jQueryOutput appendFormat:@"\n    }\n  }\n  bindMeToCorrectScope.bind(%@)();\n",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1]];
            }
            else
            {
                // Gemäß OpenLaszlo reagieren, entgegen JS, eventuelle Kinder nicht auf das Ereignis
                // Deswegen diese Zeile davorschalten. Variable 'e' wurde vorher als Argument gesetzt
                // Wenn ich innerhalb einer Klasse bin, kann ich nicht so restriktiv sein, weil ich derzeit ja zu dem
                // außenstehenden Element appende, anstatt es zu ersetzen. (2. Beispiel von <text> in der OL-Doku)
                // Ich denke es klappt jetzt auch so, seitdem ich das äußerste Elemente bei <class extends="text">
                // ersetze, anstatt zu appenden. Dadurch spreche ich automatisch das richtige Element an!

                // bei reference ist es ein anderes this, und gleichzeitig kann ich dann nicht auf
                // e.target testen. Der Witz ist ja gerade, dass es wo anders dran gebunden wurde.
                if (self.referenceAttributeInHandler)
                {
                    [self.jQueryOutput appendString:@"  // Wegen 'reference'-Attribut falsches this. Dieses korrigieren mit selbst ausführender Funktion und bind()\n"];                
                    [self.jQueryOutput appendString:@"      (function() {\n      with (this) {\n        "];
                }
                else
                {
                    [self.jQueryOutput appendString:@"if (this == e.target) {\n      with (this) {\n        "];
                }

                [self.jQueryOutput appendString:s];

                [self.jQueryOutput appendString:@"\n      }\n"];

                if (self.referenceAttributeInHandler)
                    [self.jQueryOutput appendFormat:@"    }).bind(%@)();\n",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1]];
                else
                    [self.jQueryOutput appendString:@"    }\n"];

                [self.jQueryOutput appendString:@"  });\n"];
            }
        }

        // Erkennungszeichen für oninit in jedem Fall zurücksetzen
        self.onInitInHandler = NO;
        // Erkennungszeichen für 'reference'-Attribut auf jeden Fall zurücksetzen
        self.referenceAttributeInHandler = NO;
        // Erkennungszeichen für 'method'-Attribut auf jeden Fall zurücksetzen
        self.methodAttributeInHandler = @"";
    }





    if ([elementName isEqualToString:@"method"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        NSLog([NSString stringWithFormat:@"Original code defined in method: \n**********\n%@\n**********",s]);


        // Tabs eliminieren
        while ([s rangeOfString:@"\t"].location != NSNotFound)
        {
            s = [s stringByReplacingOccurrencesOfString:@"\t" withString:@"  "];
        }
        // Leerzeichen zusammenfassen
        while ([s rangeOfString:@"  "].location != NSNotFound)
        {
            s = [s stringByReplacingOccurrencesOfString:@"  " withString:@" "];
        }

        s = [self modifySomeExpressionsInJSCode:s];
        // In String auftauchende '\n' müssen ersetzt werden, sonst JS-Error. Gilt das sogar global?
        s = [s stringByReplacingOccurrencesOfString:@"\\n" withString:@"\\\\n"];

        // super ist nicht erlaubt in JS und gibt es auch nicht.
        // Ich ersetze es erstmal durch this.getTheParent(). Sollte funktionieren.
        s = [s stringByReplacingOccurrencesOfString:@"super" withString:@"this.getTheParent()"];


        // Damit er in jeder Code-Zeile korrekt einrückt
        s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\n   "];

        NSLog([NSString stringWithFormat:@"Modified code changed to in method: \n**********\n%@\n**********",s]);


        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        [o appendString:@"   "];
        [o appendString:s];


        // Falls wir in canvas/library sind, dann muss es nicht nur global verfügbar sein
        // sondern auch über 'canvas.' ansprechbar sein.
        if ([[self.enclosingElements objectAtIndex:[self.enclosingElements count]-1] isEqualToString:@"canvas"] ||
            [[self.enclosingElements objectAtIndex:[self.enclosingElements count]-1] isEqualToString:@"library"])
        {
            [o appendString:@"\n  }\n"];
            [o appendString:@"  // Diese Methode ebenfalls an canvas binden\n"];
            [o appendFormat:@"  canvas.%@ = %@;\n",self.lastUsedNameAttributeOfMethod,self.lastUsedNameAttributeOfMethod];
        }
        else
        {
            // Dann hatten wir wegen anderem scope ein 'with (x) {' gesetzt.
            // Dieses müssen wir hier einmal extra schließen
            [o appendString:@"\n    }"];
            [o appendString:@"\n  }\n"];
        }

        // jQueryOutput0 (Begründung siehe öffnendes Tag)
        [self.jQueryOutput0 appendString:o];
    }





    // Okay, letzte Chance: Wenn es vorher nicht gematcht hat. Dann war es eventuell eine
    // selbst definierte Klasse?
    // Haben wir die Klasse auch vorher aufgesammelt? Nur dann geht es hier weiter.
    if (!element_geschlossen && ([self.allFoundClasses objectForKey:elementName] != nil))
    {
        element_geschlossen = YES;

        NSLog(@"Schließendes Tag einer selbst definierten Klasse gefunden!");


        // Schließen
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];


        NSString *s = [self holDenGesammeltenTextUndLeereIhn];


        // Benötigte ID vom stack holen, und danach Element entfernen.
        // (nötig, weil es ineinander verschachtelte Klassen geben kann)
        // NSString *idUmgebendesElement = [self.rememberedID4closingSelfDefinedClass lastObject];
        [self.rememberedID4closingSelfDefinedClass removeLastObject];


        // Wenn wir einen String gefunden haben, dann IN den existierenden Output injecten:
        if ([s length] > 0)
        {
            // Da ich den string mit ' umschlossen habe, muss ich eventuelle ' im String escapen
            s = [s stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"];
            s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

            [self.jQueryOutput0 insertString:s atIndex:[self.jQueryOutput0 length]-31];
        }

        self.weAreCollectingTextAndThereMayBeHTMLTags = NO;
    }







    // Bei den HTML-Tags innerhalb von BDS-(text) darf ich self.textInProgress nicht auf nil setzen,
    // da ich den Text ja weiter ergänze. Erst ganz am Ende beim Schließen von BDSText mache ich das
    if (!self.weAreCollectingTextAndThereMayBeHTMLTags)
    {
        if (self.textInProgress != nil && [[self.textInProgress stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0)
        {
            // Von den hier genannten Tags wird der Text zwischen den Tags noch nichts ausgewertet
            if (![self.keyInProgress isEqualToString:@"BDSinputgrid"] &&
                ![self.keyInProgress isEqualToString:@"BDSreplicator"] &&
                // Text oder Newlines DIREKT zwischen den canvas-Tags wird immer ignoriert
                ![self.keyInProgress isEqualToString:@"canvas"])
            {
                [self instableXML:@"Hoppala, das sollte aber nicht passieren, dass ich hier noch nicht ausgewerteten Text habe."];
            }
        }

        // Okay, element closed! So clear the text, that was found between tags and the elementName
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

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    NSString *s = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    self.textInProgress = [[NSMutableString alloc] initWithString:s];
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

    // Damit IE 9 auf jeden Fall im IE 9-Modus lädt und nicht irgendeinen Kompatibilitäts-modus
    [pre appendString:@"<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\">\n"];

    // Nicht HTML5-Konform, aber zum testen um sicherzustellen, dass wir nichts aus dem Cache laden
    [pre appendString:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n<meta http-equiv=\"pragma\" content=\"no-cache\" />\n<meta http-equiv=\"cache-control\" content=\"no-cache\" />\n<meta http-equiv=\"expires\" content=\"0\" />\n"];

    // Viewport für mobile Devices anpassen...
    // ...width=device-width funktioniert nicht im Portrait-Modus.
    // initial-scale baut links und rechts einen kleinen Abstand ein. Wollen wir das?
    // Er springt dann etwas immer wegen adjustOffsetOnBrowserResize - To Check
     [pre appendString:@"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n"];
    //      [pre appendString:@"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.024\" />\n"]; // => Dann perfekte Breite, aber Grafiken wirken etwas verwaschen.ToDo@End
    //[pre appendString:@"<meta name=\"viewport\" content=\"\" />\n"];


    // Als <title> nutzen wir den Dateinamen der Datei
    NSString *titleForDebug = @"";

    if (debugmode && positionAbsolute)
        titleForDebug = @" (PositionAbsolute = YES)";
    if (debugmode && !positionAbsolute)
        titleForDebug = @" (PositionAbsolute = NO)";

    [pre appendFormat:@"<title>%@%@</title>\n",[[self.pathToFile lastPathComponent] stringByDeletingPathExtension],titleForDebug];

    // CSS-Stylesheet-Datei für das Layout der TabSheets (wohl leider nicht CSS-konform, aber
    // die CSS-Konformität herzustellen ist wohl leider zu viel Aufwand, von daher greifen wir
    // auf diese fertige Lösung zurück)
    [pre appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.21/themes/humanity/jquery-ui.css\">\n"];

    // CSS-Stylesheet-Datei // Diese MUSS nach der Humanity-css kommen, da ich bestimmte Sachen
    // überschreibe
    [pre appendString:@"<link rel=\"stylesheet\" type=\"text/css\" href=\"styles.css\">\n"];

    // IE-Fallback für canvas (falls ich es benutze)
    // [pre appendString:@"<!--[if IE]><script src=\"excanvas.js\"></script><![endif]-->\n"];


    // jQuery laden
    [pre appendString:@"<script type=\"text/javascript\" src=\"https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js\"></script>\n"];

    // Falls latest jQuery-Version gewünscht:
    // '<script type="text/javascript" src="http://code.jquery.com/jquery-latest.min.js"></script>'
    // einbauen, aber dann kein Caching!

    // jQuery UI laden (wegen TabSheet)
    [pre appendString:@"<script type=\"text/javascript\" src=\"https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.21/jquery-ui.min.js\"></script>\n"];

    // Warum auch immer: general.js wird automatisch importiert
    [pre appendString:@"<script type=\"text/javascript\" src=\"includes/general.js\"></script>\n"];

    // Unser eigenes Skript lieber zuerst
    [pre appendString:@"<script type=\"text/javascript\" src=\"jsHelper.js\"></script>\n"];

    if (![self.jsOLClassesOutput isEqualToString:@""])
    {
        // Erst nach jsHelper die Klassen importieren. Den lz_MetaClass muss bekannt sein
        [pre appendString:@"<script type=\"text/javascript\" src=\"collectedClasses.js\"></script>\n"];
    }


    // Dann erst externe gefundene Skripte
    [pre appendString:self.externalJSFilesOutput];

    if (![self.cssOutput isEqualToString:@""])
    {
        [pre appendString:@"\n<style type='text/css'>\n"];
        [pre appendString:self.cssOutput];
        [pre appendString:@"</style>\n"];
    }

    [pre appendString:@"\n<script type=\"text/javascript\">\n"];

    // Muss auch ausgegeben werde! Auf die resourcen wird per JS unter Umständen zugegriffen
    [pre appendString:self.jsHeadOutput];

    // erstmal nur die mit resource gesammelten globalen vars ausgeben
    // (+ globale Funktionen + globales JS)
    [pre appendString:self.jsHead2Output];
    [pre appendString:@"\n</script>\n\n</head>\n\n<body>\n"];

    // Splashscreen vorschalten
    if ([[[self.pathToFile lastPathComponent] stringByDeletingPathExtension] isEqualToString:@"Taxango"])
    {
        [pre appendString:@"<span id=\"splashscreen_\" style=\"position:absolute;top:0px;left:0px;background-color:white;width:100%;height:100%;z-index:10000;background-image:url(resources/logo.png);font-size:80px;text-align:center;\">LOADING...</span>\n\n"];
    }
    else
    {
        [pre appendString:@"<span id=\"splashscreen_\" style=\"position:absolute;top:0px;left:0px;background-color:white;width:100%;height:100%;z-index:10000;font-size:80px;text-align:center;\">LOADING...</span>\n\n"];
    }

    // Kurzer Tausch damit ich den Header davorschalten kann
    NSMutableString *temp = [[NSMutableString alloc] initWithString:self.output];
    self.output = [[NSMutableString alloc] initWithString:pre];
    [self.output appendString:temp];



    // Ich muss alle verwendeten css-background-images auf CSS-Ebene preloaden, sonst werden sie
    // nicht korrekt dargestellt (gerade auch die, die in Klassen erst instanziert werden).
    // Es klappt nicht in Firefox mehr als 200 Divs übereinander zu stapeln. WTF Firefox???
    // Deswegen als 'img'-Tag gelöst
    [self.output appendString:@"\n"];
    for(id object in self.allImgPaths)
    {
        // Falls Flash-Dateien als Resource gesetzt wurde, diese ignorieren
        if (![object hasSuffix:@".swf"])
        {
            [self.output appendFormat:@"<img class=\"img_preload\" src=\"%@\" />\n",object];
        }
    }
    [self.output appendString:@"\n"];



    // Füge noch die nötigen JS ein:
    [self.output appendString:@"\n<script type=\"text/javascript\">\n"];

    [self.output appendString:@"// Make all id's global (For Firefox) and init 'canvas'\n"];
    [self.output appendString:@"makeIDsGlobalAndInitStuff();\n\n\n"];


    // Die jQuery-Anweisungen:

    //[self.output appendString:@"\n\n// '$(function() {' ist leider zu unverlässig. Bricht z. B. das korrekte setzen der Breite von element9, weil es die direkten Kinder-Elemente nicht richtig auslesen kann\n// Dieses Problem trat nur beim Reloaden auf, nicht beim direkten Betreten der Seite per URL. Very strange!\n// Jedenfalls lässt sich das Problem über '$(window).load(function() {});' anstatt '$(document).ready(function() {});' lösen.\n// http://stackoverflow.com/questions/6504982/jquery-behaving-strange-after-page-refresh-f5-in-chrome\n// Dadurch muss ich auch nicht mehr alle width/height-Startwerte per css auf 'auto' setzen.\n"];
    [self.output appendString:@"$(window).load(function()\n{\n"];


    [self.output appendString:@"  if (window['tabsMain']) tabsMain.selecttab = function(index) { $(this).tabs('select', index ) } // ToDo\n"];
    [self.output appendString:@"  if (window['tabsMain']) tabsMain.next = function() { $(this).tabs('select', 2 ) } // ToDo\n"];
    [self.output appendString:@"  if (window['rudStpfl']) rudStpfl.rolldown = function() {} // ToDo\n"];
    [self.output appendString:@"  if (window['rudWeitereInfos']) rudWeitereInfos.isvalid = true; // ToDo\n"];
    [self.output appendString:@"  var globalcalendar = {}; // ToDo\n\n"];

    [self.output appendString:@"  var dlgsave = new dlg();"];
    [self.output appendString:@"  var dlgwaitonline = new dlg();"];
    [self.output appendString:@"  ShowError = function(x) { /* alert(x); */ };"];
    [self.output appendString:@"  // dlgFamilienstandSingle heimlich als Objekt einführen (diesmal direkt im Objekt, ohne prototype)\n"];
    [self.output appendString:@"  function dlg()\n  {\n    // Extern definiert\n    this.open = open;\n    // Intern definiert (beides möglich)\n"];
    [self.output appendString:@"    //this.completeInstantiation = function completeInstantiation() { };\n  }\n"];
    [self.output appendString:@"  function open()\n  {\n    alert('Willst du wirklich deine Ehefrau löschen? Usw...');\n  }\n"];
    //[self.output appendString:@"  var dlgFamilienstandSingle = new dlg();\n\n"];
    [self.output appendString:@"  var dlgsave = new dlg();\n\n"];


    
    
    // Normale Javascript-Anweisungen
    if (![self.jsOutput isEqualToString:@""])
    {
        [self.output appendString:self.jsOutput];

        [self.output appendString:@"\n\n  /*******************************************************************/\n"];
        [self.output appendString:@"  /***************************** Grenze ******************************/\n"];
        [self.output appendString:@"  /********* Grundlagen legende JS-Anweisungen sind hier vor *********/\n"];
        [self.output appendString:@"  /***Diese müssen zwingend vor folgenden JS/jQuery-Ausgaben kommen***/\n"];
        [self.output appendString:@"  /*******************************************************************/\n\n\n"];
    }


    // Vorgezogene jQuery-Ausgaben:
    if (![self.jQueryOutput0 isEqualToString:@""])
    {
        [self.output appendString:self.jQueryOutput0];
        
        [self.output appendString:@"\n\n  /*******************************************************************/\n"];
        [self.output appendString:@"  /***************************** Grenze ******************************/\n"];
        [self.output appendString:@"  /************ Vorgezogene JQuery-Ausgaben sind hier vor ************/\n"];
        [self.output appendString:@"  /***Diese müssen zwingend vor folgenden JS/jQuery-Ausgaben kommen***/\n"];
        [self.output appendString:@"  /*******************************************************************/\n\n\n"];
    }


    // Computed Values
    if (![self.jsComputedValuesOutput isEqualToString:@""])
    {
        [self.output appendString:self.jsComputedValuesOutput];

        [self.output appendString:@"\n\n  /*******************************************************************/\n"];
        [self.output appendString:@"  /***************************** Grenze ******************************/\n"];
        [self.output appendString:@"  /********************* Computed sind hier vor **********************/\n"];
        [self.output appendString:@"  /***Diese müssen zwingend vor folgenden JS/jQuery-Ausgaben kommen***/\n"];
        [self.output appendString:@"  /*******************************************************************/\n\n\n"];
    }


    // Alle Constraint Values direkt hinterher
    if (![self.jsConstraintValuesOutput isEqualToString:@""])
    {
        [self.output appendString:self.jsConstraintValuesOutput];

        [self.output appendString:@"\n\n  /*******************************************************************/\n"];
        [self.output appendString:@"  /***************************** Grenze ******************************/\n"];
        [self.output appendString:@"  /***************** Constraint Values sind hier vor *****************/\n"];
        [self.output appendString:@"  /***Diese müssen zwingend vor folgenden JS/jQuery-Ausgaben kommen***/\n"];
        [self.output appendString:@"  /*******************************************************************/\n\n\n"];
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
    // Remove Splashscreen
    [self.output appendString:@"\n  $('#splashtag_').remove(); // The Build-In-SplashTag"];
    [self.output appendString:@"\n  $('#splashscreen_').remove();\n"];

    [self.output appendString:@"});\n</script>\n\n"];



    // Und nur noch die schließenden Tags
    [self.output appendString:@"</body>\n</html>"];

    // Path zum speichern ermitteln
    // Download-Verzeichnis war es mal, aber Problem ist, dass dann die Ressourcen fehlen...
    // NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    // NSString *dlDirectory = [paths objectAtIndex:0];
    // NSString * path = [[NSString alloc] initWithString:dlDirectory];
    //... deswegen ab jetzt immer im gleichen Verzeichnis wie das OpenLaszlo-input-File
    // Die Dateien dürfen dann nur nicht zufälligerweise genau so heißen wie welche im Verzeichnis
    // (ToDo bei Public Release)
    NSString *path = [[self.pathToFile URLByDeletingLastPathComponent] relativePath];


    NSString *pathToCSSFile = [NSString stringWithFormat:@"%@/styles.css",path];
    NSString *pathToJSFile = [NSString stringWithFormat:@"%@/jsHelper.js",path];
    NSString *pathToCollectedClassesFile = [NSString stringWithFormat:@"%@/collectedClasses.js",path];
    NSString *pathToLogile = [NSString stringWithFormat:@"%@/log_OL2HTML5.txt",path];


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


    // Writing Log-File to File-System
    [[globalAccessToTextView string] writeToFile:pathToLogile atomically:NO encoding:NSUTF8StringEncoding error:NULL];



    [self jumpToEndOfTextView];
}




- (void) createCSSFile:(NSString*)path
{
    NSString *css = @"/* FILE: styles.css */\n"
    "\n"
    "/* Enthaelt standard-Definitionen, die das Aussehen von OpenLaszlo simulieren */\n"
    "/*\n"
    "Known issues:\n"
    "inherit => Not supported by IE6 & IE 7\n"
    "\n"
    "\n"
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
    "}\n"
    "\n"
    ".img_preload\n"
    "{\n"
    "    /* display: none; Auskommentieren, sonst kein preload bei Firefox. */\n"
    "    position: absolute;\n"
    "    left: -9999px;\n"
    "    top: -9999px;\n"
    "    z-index: -30;\n"
    "    background-repeat: no-repeat;\n"
    "}\n"
    "\n"
    "/* Der button, wie er ungefähr in OpenLaszlo aussieht */\n"
    "input[type=\"button\"], button\n"
    "{\n"
    "    white-space:nowrap;\n" // Damit er wie in Bsp. 7.2 beim klein machen des Fensters nicht umbricht
    "    border: 1px solid #333; /* fixes a 'can't set height-bug' on webkit */\n"
    "    margin: 0; /* Only for webkit... */\n"
    "    padding: 5px 10px;\n"
    "    background: #dedede;\n"
    "    background: -moz-linear-gradient(top, #ffffff, #afafaf);\n"
    "    background: -webkit-linear-gradient(top, #ffffff, #afafaf);\n"
    "    background: -ms-linear-gradient(top, #ffffff, #afafaf);\n"
    "    background: -o-linear-gradient(top, #ffffff, #afafaf);\n"
    "}\n"
    "input[type=\"button\"]:hover, button:hover\n"
    "{\n"
    "    background: #bfbfbf;\n"
    "    background: -moz-linear-gradient(top, #ffffff, #bfbfbf);\n"
    "    background: -webkit-linear-gradient(top, #ffffff, #bfbfbf);\n"
    "    background: -ms-linear-gradient(top, #ffffff, #bfbfbf);\n"
    "    background: -o-linear-gradient(top, #ffffff, #bfbfbf);\n"
    "}\n"
    "input[type=\"button\"]:active, button:active\n"
    "{\n"
    "    background: #cbcbcb;\n"
    "    background: -moz-linear-gradient(top, #535353, #cbcbcb);\n"
    "    background: -webkit-linear-gradient(top, #535353, #cbcbcb);\n"
    "    background: -ms-linear-gradient(top, #535353, #cbcbcb);\n"
    "    background: -o-linear-gradient(top, #535353, #cbcbcb);\n"
    "}\n"
    "\n"
    "/* Damit der Hintergrund weiß wird, entgegen der Angabe in Humanity.css */\n"
    ".ui-widget-content { border: 1px solid #e0cfc2; background: #ffffff; color: #1e1b1d; }\n"
    "\n"
    "img\n"
    "{\n"
    "    position:absolute;\n"
    "    border: 0 none;\n"
    "}\n"
    "\n"
    "div, span, input, select, button, textarea\n"
    "{\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
    "}\n"
    "\n"
    "/* Das Standard-Canvas, welches den Rahmen darstellt */\n"
    ".canvas_standard\n"
    "{\n"
    "    background-color:white;\n"
	"    height:100%;\n"
	"    width: 100%;\n"
	"    position:absolute;\n"
	"    top:0px;\n"
	"    left:0px;\n"
    "    text-align:left;\n"
	"    padding:0px;\n"
    "    overflow:hidden; /* Damit es am iPad in der Queransicht unten richtig abschließt */\n"
    "}\n"
    "\n"
    "/* Das Standard-Window, wie es ungefähr in OpenLaszlo aussieht */\n"
    ".div_window\n"
    "{\n"
    "    background-color:lightgrey;\n"
	"    height:40px;\n"
	"    width:50px;\n"
	"    position:relative;\n"
	"    top:20px;\n"
	"    left:20px;\n"
    "    text-align:left;\n"
    // Gemäß Beispiel 7.8 gibt es kein Padding
	//"    padding:4px;\n"
    "    cursor:pointer;\n"
    "    overflow:hidden;\n"
    "    border-style:solid;\n"
    "    border-width:3px;\n"
    "}\n"
    ".div_windowContent\n"
    "{\n"
	"    position:relative;\n"
	"    top:22px;\n"
    "    width:inherit;\n"
    "    height:18px;\n"
    "    overflow:hidden;\n"
    "}\n"
    "\n"
    "/* Das Standard-OL-HTML-Element (=iframe) */\n"
    ".iframe_standard\n"
    "{\n"
	"    position:relative;\n"
	"    top:0px;\n"
	"    left:0px;\n"
    "}\n"
    "\n"
    "/* Das Standard-View, wie es ungefähr in OpenLaszlo aussieht */\n"
    ".div_standard\n"
    "{\n"
	"    height:auto; /* Wirklich wichtig. Damit es einen Startwert gibt.   */\n"
	"    width:auto;  /* Sonst kann JS die Variable nicht richtig auslesen. */\n"
    "\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
	"    position:relative;\n"
	"    top:0px;\n"
	"    left:0px;\n"
    "\n"
    "    border-style:solid;\n"
    "    border-width:0;\n"
    "\n"
    "    background-repeat:no-repeat; /* Falls eine Res gesetzt wird, diese standardmäßig nicht wiederholen */\n"
    "}\n"
    "\n"
    "/* Das Standard-input-Feld (Der Rand darf nicht überschrieben werden)*/\n"
    ".input_standard\n"
    "{\n"
	"    height:auto;\n"
	"    width:auto;\n"
    "\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
	"    position:relative;\n"
	"    top:0px;\n"
	"    left:0px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "\n"
    "    /* cursor:pointer; bricht Text-input-Felder. Da muss natürlich der Caret bleiben */\n"
    "}\n"
    "\n"
    "/* TabSheetContainer (Der Rand darf nicht gesetzt werden, bzw. doch. hmmm) */\n"
    ".div_tsc\n"
    "{\n"
    "    height:auto;\n"
    "    width:auto;\n"
    "    position:relative;\n"
    "    top:0px;\n"
    "    left:0px;\n"
    "\n"
    "    border-style:solid; /* Bei Bedarf auskommentieren */\n"
    "    border-width:0; /* Bei Bedarf auskommentieren */\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* CSS-Angaben für den RollUpDownContainer */\n"
    ".div_rudContainer\n"
    "{\n"
    "    margin-left:14px;\n"
    "}\n"
    "\n"
    "/* CSS-Angaben für ein RollUpDownElement */\n"
    ".div_rudElement\n"
    "{\n"
    "    position: relative;\n"
    "    height:auto;\n" // War mal 'inherit', aber 'auto' erscheint mir logischer, ob was bricht?
    "    margin-bottom:6px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* CSS-Angaben für ein RollUpDownPanel (gleichzeit Erkennungszeichen für getTheParent() */\n"
    ".div_rudPanel\n"
    "{\n"
    "    position: relative;\n"
    "    overflow-y:auto;\n"
    "    overflow-x:hidden;\n"
    "    top:0px;\n"
    "    left:0px;\n"
    "    margin-bottom:6px;\n"
    "    border-width:2px;\n"
    "    border-color:lightgrey;\n"
    "    border-style:solid;\n"
    "    background-color:white;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-datepicker (das umgebende Div) */\n"
    ".div_datepicker\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    width:100%; /* Ein datepicker soll immer die ganze Zeile einnehmen. */\n"
    "    height:30px; /* Sonst ist er nicht richtig anklickbar. */\n"
    "    line-height:26px; /* Damit der Text vor dem Datepicker vertikal zentriert ist. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    margin-top:8px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-checkbox (das umgebende Div) */\n"
    "/* Standard-radiobutton (das umgebende Div) */\n"
    ".div_checkbox\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    width:100%; /* Eine checkbox soll immer die ganze Zeile einnehmen. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "\n"
    "    cursor:pointer;\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-checkbox (die checkbox selber) */\n"
    "/* Standard-radiobutton (der button selber) */\n"
    ".input_checkbox\n"
    "{\n"
    "    margin-right:8px;\n"
    "    vertical-align:middle;\n"
    "\n"
    "    cursor:pointer;\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-combobox (das umgebende Div) */\n"
    ".div_combobox\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    width:100%; /* Eine combobox soll immer die ganze Zeile einnehmen. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    margin-top: 8px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-Select-combobox (die combobox selber) */\n"
    ".select_standard\n"
    "{\n"
    "    position:relative;\n"
    "    width:100px;\n"
    "\n"
    "    margin-left:5px;\n"
    "\n"
    "    cursor:pointer;\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-Textfield (das umgebende Div) */\n"
    "/* Standard-Slider (das umgebende Div) */\n"
    ".div_textfield, .div_slider\n"
    "{\n"
    "    width:100%; /* Eine combobox soll immer die ganze Zeile einnehmen. */\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    text-align:left;\n"
    "    padding:4px;\n"
    "    margin-top: 8px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Das Search-field, welches keinen vorangehenden Text hat, braucht derzeit noch eine Sonderbehandlung */\n"
    "/* Das darf nicht width:100% sein, sonst fällt der Search-Button hinten runter. */\n"
    ".div_textfield_ohne_vorangehenden_text\n"
    "{\n"
    "    position:relative; /* relative! Damit es Platz einnimmt, sonst staut es sich im Tab. */\n"
    "                       /* Und nur so wird bei Änderung der Visibility aufgerückt. */\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
    "    text-align:left;\n"
    "    padding:2px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-checkbox (die checkbox selber) */\n"
    ".input_textfield\n"
    "{\n"
    "    margin-left:5px;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-Text (Text/BDStext) */\n"
    ".div_text\n"
    "{\n"
    "    float:left; /* Nur soviel Platz einnehmen, wie das Element auch braucht. */\n"
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
    "\n"
    "    white-space:nowrap;\n"
    "    word-wrap:break-word;\n"
    "\n"
    // Beispiel 9.2 sagt overflow:hidden
    "    overflow:hidden;\n"
    "}\n"
    "\n"
    ".noTextSelection, .div_text, span, img\n"
    "{\n"
    "    cursor: default;\n"
    "    -webkit-touch-callout: none;\n"
    "    -webkit-user-select: none;\n"
    "    -khtml-user-select: none;\n"
    "    -moz-user-select: none;\n"
    "    -ms-user-select: none;\n"
    "    -o-user-select: none;\n"
    "    user-select: none;\n"
    "}\n"
    "\n"
    ".noPointerEvents\n"
    "{\n"
    "    pointer-events: none; /* Sonst kann ein drüber liegendes div Click-Events wegnehmen */\n"
    "                         /* Wird auf 'auto' gesetzt, wenn wirklich ein event dort ist.*/\n"
    "                         /* Won't work on IE */\n"
    "}\n"
    "\n"
    // Muss nach div_text kommen, damit es dieses überschreiben kann
    ".div_windowTitle\n"
    "{\n"
    // "    background-color: darkgray;\n"
	"    overflow:hidden;\n"
    "    font-weight:bold;\n"
    "    text-decoration:underline;\n"
	"    left:14px;\n"
    "    height:16px; /* 4 weg wegen margin vom Text */\n"
    "}\n"
    "\n"
    "/* Ermögliche Tooltips! */\n"
    "*[data-tooltip]:before\n"
    "{\n"
    "    position: absolute;\n"
    "    z-index: 1000;\n"
    "    left: 10px;\n"
    "    top: -40px;\n"
    "    background-color: orange;\n"
    "    color: white;\n"
    "    height: 30px;\n"
    "    font-size: 10px;\n"
    "    line-height: 30px;\n"
    "    border-radius: 5px;\n"
    "    padding: 0 15px;\n"
    "    content: attr(data-tooltip);\n"
    "    white-space: nowrap;\n"
    "    display: none;\n"
    "}\n"
    "*[data-tooltip]:after\n"
    "{\n"
    "    position: absolute;\n"
    "    z-index: 1000;\n"
    "    left: 25px;\n"
    "    top: -10px;\n"
    "    border-top: 7px solid orange;\n"
    "    border-left: 7px solid transparent;\n"
    "    border-right: 7px solid transparent;\n"
    "    content: \"\";\n"
    "    display: none;\n"
    "}\n"
    "*[data-tooltip]:hover:after, *[data-tooltip]:hover:before\n"
    "{\n"
    "    display: block;\n"
    "}\n"
    "/* Tooltips unten anzeigen, falls oben kein Platz */\n"
    "*[data-tooltip-bottom]:before\n"
    "{\n"
    "    position: absolute;\n"
    "    z-index: 1000;\n"
    "    left: 10px;\n"
    "    bottom: -40px;\n"
    "    background-color: orange;\n"
    "    color: white;\n"
    "    height: 30px;\n"
    "    font-size: 10px;\n"
    "    line-height: 30px;\n"
    "    border-radius: 5px;\n"
    "    padding: 0 15px;\n"
    "    content: attr(data-tooltip-bottom);\n"
    "    white-space: nowrap;\n"
    "    display: none;\n"
    "}\n"
    "*[data-tooltip-bottom]:after\n"
    "{\n"
    "    position: absolute;\n"
    "    z-index: 1000;\n"
    "    left: 25px;\n"
    "    bottom: -10px;\n"
    "    border-bottom: 7px solid orange;\n"
    "    border-left: 7px solid transparent;\n"
    "    border-right: 7px solid transparent;\n"
    "    content: \"\";\n"
    "    display: none;\n"
    "}\n"
    "*[data-tooltip-bottom]:hover:after, *[data-tooltip-bottom]:hover:before\n"
    "{\n"
    "    display: block;\n"
    "}\n"
    "\n"
    "#debugWindow\n"
    "{\n"
    "    width: 300px;\n"
    "    height: 115px;\n"
    "    padding: 10px;\n"
    "    position: absolute;\n"
    "    right: 50px;\n"
    "    top: 50px;\n"
    "    background-color: white;\n"
    "    z-index: 100000;\n"
    "    border-color: black;\n"
    "    border-style: solid;\n"
    "    border-width: 5px;\n"
    "\n"
    "    cursor: pointer;\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "#debugInnerWindow\n"
    "{\n"
    "    position:absolute;\n"
    "    top:30px;\n"
    "    height: 85px;\n"
    "    width: 300px;\n"
    "    overflow:scroll;\n"
    "\n"
    "    pointer-events: auto;\n"
    "}";
    if (positionAbsolute)
    {
      css = [css stringByReplacingOccurrencesOfString:@"float:left;" withString:@""];
      css = [css stringByReplacingOccurrencesOfString:@"width:100%;" withString:@""];
      css = [css stringByReplacingOccurrencesOfString:@"position:relative;" withString:@"position:absolute;"];
    }
    else
    {
        NSString *css2 = @"\n\n"
        //"/* Ziemlich dirty Trick um '<input>', '<select>' und 'Text' innerhalb der TabSheets besser */\n"
        //"/* ausrichten zu können. So, dass sie nicht umbrechen, weil Sie position: absolute sind. */\n"
        //"/* div > div > div > div > div > div > div > div > input, */\n"
        //"/* div > div > div > div > div > div > div > div > select,*/\n"
        //"/* div > div > div > div > div > div > div > div[class=\"div_text\"] */\n"
        //".div_rudPanel .div_text /* wenn ein div_text in einem div_rudPanel ist */\n"
        //"{\n"
        //"    width:100%;\n"
        //"}\n"
        "/* Übergangsweise, damit der Kalender die Überschrift mittig anzeigt, */\n"
        "/* für alle Elemente im Kalender die float-Angabe aufheben */\n"
        ".ui-datepicker *\n"
        "{\n"
        "    float:none;\n"
        "}\n";

        css = [NSString stringWithFormat:@"%@%@",css,css2];
    }

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
    "// jQuery UI Datepicker auf Deutsch setzen               \n"
    "/////////////////////////////////////////////////////////\n"
    "jQuery(function($) {\n"
    "    $.datepicker.regional['de'] = {\n"
	"        closeText: 'schließen',\n"
	"        prevText: '&#x3c;zurück',\n"
	"        nextText: 'Vor&#x3e;',\n"
	"        currentText: 'heute',\n"
	"        monthNames: ['Januar','Februar','März','April','Mai','Juni',\n"
    "                     'Juli','August','September','Oktober','November','Dezember'],\n"
	"        monthNamesShort: ['Jan','Feb','Mär','Apr','Mai','Jun',\n"
    "                          'Jul','Aug','Sep','Okt','Nov','Dez'],\n"
	"        dayNames: ['Sonntag','Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag'],\n"
	"        dayNamesShort: ['So','Mo','Di','Mi','Do','Fr','Sa'],\n"
	"        dayNamesMin: ['So','Mo','Di','Mi','Do','Fr','Sa'],\n"
	"        weekHeader: 'Wo',\n"
	"        dateFormat: 'dd.mm.yy',\n"
	"        firstDay: 1,\n"
	"        isRTL: false,\n"
	"        showMonthAfterYear: false,\n"
    "        yearSuffix: ''};\n"
    "    $.datepicker.setDefaults($.datepicker.regional['de']);\n"
    "});\n"
    //"\n"
    //"\n"
    //"/////////////////////////////////////////////////////////\n"
    //"// All color-code are available as constants? NO!      //\n"
    //"/////////////////////////////////////////////////////////\n"
    //"var white = 'white';\n"
    //"var black = 'black';\n"
    //"var red = 'red';\n"
    //"var green = 'green';\n"
    //"var blue = 'blue';\n"
    //"var yellow = 'yellow';\n"
    //"var magenta = 'magenta';\n"
    //"var purple = 'purple';\n"
    //"var brown = 'brown';\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// bind() für ältere Browser nachrüsten                  \n"
    "// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Function/bind\n"
    "/////////////////////////////////////////////////////////\n"
    "if (!Function.prototype.bind) {\n"
    "    Function.prototype.bind = function (oThis) {\n"
    "        if (typeof this !== 'function') {\n"
    "            // closest thing possible to the ECMAScript 5 internal IsCallable function\n"
    "            throw new TypeError('Function.prototype.bind - what is trying to be bound is not callable');\n"
    "        }\n"
    "\n"
    "        var aArgs = Array.prototype.slice.call(arguments, 1),\n"
    "        fToBind = this,\n"
    "        fNOP = function () {},\n"
    "        fBound = function () {\n"
    "            return fToBind.apply(this instanceof fNOP\n"
    "                                 ? this\n"
    "                                 : oThis,\n"
    "                                 aArgs.concat(Array.prototype.slice.call(arguments)));\n"
    "        };\n"
    "\n"
    "        fNOP.prototype = this.prototype;\n"
    "        fBound.prototype = new fNOP();\n"
    "\n"
    "        return fBound;\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// keys() für ältere Browser nachrüsten                  \n"
    "// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Object/keys\n"
    "/////////////////////////////////////////////////////////\n"
    "if (!Object.keys) {\n"
    "    Object.keys = (function () {\n"
    "        var hasOwnProperty = Object.prototype.hasOwnProperty,\n"
    "        hasDontEnumBug = !({toString: null}).propertyIsEnumerable('toString'),\n"
    "        dontEnums = [\n"
    "                     'toString',\n"
    "                     'toLocaleString',\n"
    "                     'valueOf',\n"
    "                     'hasOwnProperty',\n"
    "                     'isPrototypeOf',\n"
    "                     'propertyIsEnumerable',\n"
    "                     'constructor'\n"
    "                     ],\n"
    "        dontEnumsLength = dontEnums.length\n"
    "\n"
    "        return function (obj) {\n"
    "            if (typeof obj !== 'object' && typeof obj !== 'function' || obj === null) throw new TypeError('Object.keys called on non-object')\n"
    "\n"
    "                var result = []\n"
    "\n"
    "                for (var prop in obj) {\n"
    "                    if (hasOwnProperty.call(obj, prop)) result.push(prop)\n"
    "                        }\n"
    "\n"
    "            if (hasDontEnumBug) {\n"
    "                for (var i=0; i < dontEnumsLength; i++) {\n"
    "                    if (hasOwnProperty.call(obj, dontEnums[i])) result.push(dontEnums[i])\n"
    "                        }\n"
    "            }\n"
    "            return result\n"
    "        }\n"
    "    })()\n"
    "};\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// sprintf() für format()                                \n"
    "/////////////////////////////////////////////////////////\n"
    "/**\n"
    " sprintf() for JavaScript 0.7-beta1\n"
    " http://www.diveintojavascript.com/projects/javascript-sprintf\n"
    "\n"
    " Copyright (c) Alexandru Marasteanu <alexaholic [at) gmail (dot] com>\n"
    " All rights reserved.\n"
    "\n"
    " Redistribution and use in source and binary forms, with or without\n"
    " modification, are permitted provided that the following conditions are met:\n"
    " * Redistributions of source code must retain the above copyright\n"
    " notice, this list of conditions and the following disclaimer.\n"
    " * Redistributions in binary form must reproduce the above copyright\n"
    " notice, this list of conditions and the following disclaimer in the\n"
    " documentation and/or other materials provided with the distribution.\n"
    " * Neither the name of sprintf() for JavaScript nor the\n"
    " names of its contributors may be used to endorse or promote products\n"
    " derived from this software without specific prior written permission.\n"
    "\n"
    " THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND\n"
    " ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED\n"
    " WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE\n"
    " DISCLAIMED. IN NO EVENT SHALL Alexandru Marasteanu BE LIABLE FOR ANY\n"
    " DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES\n"
    " (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;\n"
    " LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND\n"
    " ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT\n"
    " (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS\n"
    " SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n"
    "\n"
    "**/\n"
    "\n"
    "var sprintf = (function() {\n"
    "    function get_type(variable) {\n"
    "        return Object.prototype.toString.call(variable).slice(8, -1).toLowerCase();\n"
    "    }\n"
    "    function str_repeat(input, multiplier) {\n"
    "        for (var output = []; multiplier > 0; output[--multiplier] = input) {/* do nothing */}\n"
    "        return output.join('');\n"
    "    }\n"
    "\n"
    "    var str_format = function() {\n"
    "\n"
    "        /******** ADDED - %w durch %s ersetzen, wird noch nicht unterstützt ********/\n"
    "        arguments[0] = arguments[0].replace(/%w/g,'%s');\n"
    "        /******** ADDED - %w durch %s ersetzen, wird noch nicht unterstützt ********/\n"
    "\n"
    "        if (!str_format.cache.hasOwnProperty(arguments[0])) {\n"
    "            str_format.cache[arguments[0]] = str_format.parse(arguments[0]);\n"
    "        }\n"
    "        return str_format.format.call(null, str_format.cache[arguments[0]], arguments);\n"
    "    };\n"
    "\n"
    "    str_format.format = function(parse_tree, argv) {\n"
    "        var cursor = 1, tree_length = parse_tree.length, node_type = '', arg, output = [], i, k, match, pad, pad_character, pad_length;\n"
    "        for (i = 0; i < tree_length; i++) {\n"
    "            node_type = get_type(parse_tree[i]);\n"
    "            if (node_type === 'string') {\n"
    "                output.push(parse_tree[i]);\n"
    "            }\n"
    "            else if (node_type === 'array') {\n"
    "                match = parse_tree[i]; // convenience purposes only\n"
    "                if (match[2]) { // keyword argument\n"
    "                    arg = argv[cursor];\n"
    "                    for (k = 0; k < match[2].length; k++) {\n"
    "                        if (!arg.hasOwnProperty(match[2][k])) {\n"
    "                            throw(sprintf('[sprintf] property \"%s\" does not exist', match[2][k]));\n"
    "                        }\n"
    "                        arg = arg[match[2][k]];\n"
    "                    }\n"
    "                }\n"
    "                else if (match[1]) { // positional argument (explicit)\n"
    "                    arg = argv[match[1]];\n"
    "                }\n"
    "                else { // positional argument (implicit)\n"
    "                    arg = argv[cursor++];\n"
    "                }\n"
    "\n"
    "                if (/[^s]/.test(match[8]) && (get_type(arg) != 'number')) {\n"
    "                    throw(sprintf('[sprintf] expecting number but found %s', get_type(arg)));\n"
    "                }\n"
    "                switch (match[8]) {\n"
    "                    case 'b': arg = arg.toString(2); break;\n"
    "                    case 'c': arg = String.fromCharCode(arg); break;\n"
    "                    case 'd': arg = parseInt(arg, 10); break;\n"
    "                    case 'e': arg = match[7] ? arg.toExponential(match[7]) : arg.toExponential(); break;\n"
    "                    case 'f': arg = match[7] ? parseFloat(arg).toFixed(match[7]) : parseFloat(arg); break;\n"
    "                    case 'o': arg = arg.toString(8); break;\n"
    "                    case 's': arg = ((arg = String(arg)) && match[7] ? arg.substring(0, match[7]) : arg); break;\n"
    "                    case 'u': arg = Math.abs(arg); break;\n"
    "                    case 'x': arg = arg.toString(16); break;\n"
    "                    case 'X': arg = arg.toString(16).toUpperCase(); break;\n"
    "                }\n"
    "                arg = (/[def]/.test(match[8]) && match[3] && arg >= 0 ? '+'+ arg : arg);\n"
    "                pad_character = match[4] ? match[4] == '0' ? '0' : match[4].charAt(1) : ' ';\n"
    "                pad_length = match[6] - String(arg).length;\n"
    "                pad = match[6] ? str_repeat(pad_character, pad_length) : '';\n"
    "                output.push(match[5] ? arg + pad : pad + arg);\n"
    "            }\n"
    "        }\n"
    "        return output.join('');\n"
    "    };\n"
    "\n"
    "    str_format.cache = {};\n"
    "\n"
    "    str_format.parse = function(fmt) {\n"
    "        var _fmt = fmt, match = [], parse_tree = [], arg_names = 0;\n"
    "        while (_fmt) {\n"
    "            if ((match = /^[^\\x25]+/.exec(_fmt)) !== null) {\n"
    "                parse_tree.push(match[0]);\n"
    "            }\n"
    "            else if ((match = /^\\x25{2}/.exec(_fmt)) !== null) {\n"
    "                parse_tree.push('%');\n"
    "            }\n"
    "            else if ((match = /^\\x25(?:([1-9]\\d*)\\$|\\(([^\\)]+)\\))?(\\+)?(0|'[^$])?(-)?(\\d+)?(?:\\.(\\d+))?([b-fosuxX])/.exec(_fmt)) !== null) {\n"
    "              if (match[2]) {\n"
    "                arg_names |= 1;\n"
    "                var field_list = [], replacement_field = match[2], field_match = [];\n"
    "                if ((field_match = /^([a-z_][a-z_\\d]*)/i.exec(replacement_field)) !== null) {\n"
    "                  field_list.push(field_match[1]);\n"
    "                while ((replacement_field = replacement_field.substring(field_match[0].length)) !== '') {\n"
    "                  if ((field_match = /^\\.([a-z_][a-z_\\d]*)/i.exec(replacement_field)) !== null) {\n"
    "                    field_list.push(field_match[1]);\n"
    "                  }\n"
    "                  else if ((field_match = /^\\[(\\d+)\\]/.exec(replacement_field)) !== null) {\n"
    "                    field_list.push(field_match[1]);\n"
    "                  }\n"
    "                  else {\n"
    "                    throw('[sprintf] huh?');\n"
    "                  }\n"
    "                }\n"
    "              }\n"
    "              else {\n"
    "                throw('[sprintf] huh?');\n"
    "              }\n"
    "              match[2] = field_list;\n"
    "            }\n"
    "            else {\n"
    "              arg_names |= 2;\n"
    "            }\n"
    "            if (arg_names === 3) {\n"
    "              throw('[sprintf] mixing positional and named placeholders is not (yet) supported');\n"
    "            }\n"
    "            parse_tree.push(match);\n"
    "          }\n"
    "          else {\n"
    "            throw('[sprintf] huh?');\n"
    "          }\n"
    "          _fmt = _fmt.substring(match[0].length);\n"
    "        }\n"
    "        return parse_tree;\n"
    "      };\n"
    "\n"
    "    return str_format;\n"
    "})();\n"
    "\n"
    "var vsprintf = function(fmt, argv) {\n"
    "  argv.unshift(fmt);\n"
    "  return sprintf.apply(null, argv);\n"
    "};\n"
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
    "        enumerable: false,\n"
    "        configurable: true,\n"
    "        writable: false,\n"
    "        value: function (prop, handler) {\n"
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
    "        enumerable: false,\n"
    "        configurable: true,\n"
    "        writable: false,\n"
    "        value: function (prop) {\n"
    "            var val = this[prop];\n"
    "            delete this[prop]; // remove accessors\n"
    "            this[prop] = val;\n"
    "        }\n"
    "    });\n"
    "}"
    "\n"
    "\n"
    //"/*\n"
    //" * jQuery resize event - v1.1 - 3/14/2010\n"
    //" * http://benalman.com/projects/jquery-resize-plugin/\n"
    //" *\n"
    //" * Copyright (c) 2010 \"Cowboy\" Ben Alman\n"
    //" * Dual licensed under the MIT and GPL licenses.\n"
    //" * http://benalman.com/about/license/\n"
    //" */\n"
    //"(function($,h,c){var a=$([]),e=$.resize=$.extend($.resize,{}),i,k=\"setTimeout\",j=\"resize\",d=j+\"-special-event\",b=\"delay\",f=\"throttleWindow\";e[b]=250;e[f]=true;$.event.special[j]={setup:function(){if(!e[f]&&this[k]){return false}var l=$(this);a=a.add(l);$.data(this,d,{w:l.width(),h:l.height()});if(a.length===1){g()}},teardown:function(){if(!e[f]&&this[k]){return false}var l=$(this);a=a.not(l);l.removeData(d);if(!a.length){clearTimeout(i)}},add:function(l){if(!e[f]&&this[k]){return false}var n;function m(s,o,p){var q=$(this),r=$.data(this,d);r.w=o!==c?o:q.width();r.h=p!==c?p:q.height();n.apply(this,arguments)}if($.isFunction(l)){n=l;return m}else{n=l.handler;l.handler=m}}};function g(){i=h[k](function(){a.each(function(){var n=$(this),m=n.width(),l=n.height(),o=$.data(this,d);if(m!==o.w||l!==o.h){n.trigger(j,[o.w=m,o.h=l])}});g()},e[b])}})(jQuery,this);\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// move an array element from one position to another  //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Array.prototype, 'move', {\n"
    "    enumerable: false, // Darf nicht auf 'true' gesetzt werden! Sonst bricht jQuery!\n"
    "    configurable: true,\n"
    "    writable: false,\n"
    "    value: function(pos1, pos2) {\n"
    "        // local variables\n"
    "        var i, tmp;\n"
    "        // cast input parameters to integers\n"
    "        pos1 = parseInt(pos1, 10);\n"
    "        pos2 = parseInt(pos2, 10);\n"
    "        // if positions are different and inside array\n"
    "        if (pos1 !== pos2 && 0 <= pos1 && pos1 <= this.length && 0 <= pos2 && pos2 <= this.length) {\n"
    "            // save element from position 1\n"
    "            tmp = this[pos1];\n"
    "            // move element down and shift other elements up\n"
    "            if (pos1 < pos2) {\n"
    "                for (i = pos1; i < pos2; i++) {\n"
    "                    this[i] = this[i + 1];\n"
    "                }\n"
    "            }\n"
    "            // move element up and shift other elements down\n"
    "            else {\n"
    "                for (i = pos1; i > pos2; i--) {\n"
    "                    this[i] = this[i - 1];\n"
    "                }\n"
    "            }\n"
    "            // put element from position 1 to destination\n"
    "            this[pos2] = tmp;\n"
    "        }\n"
    "    }\n"
    "});\n"
    "\n"
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
    "// ! A fix for the iOS orientationchange zoom bug.     //\n"
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
    "//Beginnt ein String mit einer bestimmten Zeichenfolge?//\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof String.prototype.startsWith != 'function') {\n"
    "    String.prototype.startsWith = function(str) {\n"
    "        return this.lastIndexOf(str,0) === 0;\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Endet ein String mit einer bestimmten Zeichenfolge? //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof String.prototype.endsWith != 'function') {\n"
    "    String.prototype.endsWith = function(suffix) {\n"
    "         return this.indexOf(suffix, this.length - suffix.length) !== -1;\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Enthält ein String eine bestimmte Zeichenfolge?     //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof String.prototype.contains != 'function') {\n"
    "    String.prototype.contains = function(str) {\n"
    "        return this.indexOf(str) != -1;\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// better parseInt() in String                         //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof String.prototype.betterParseInt != 'function') {\n"
    "    String.prototype.betterParseInt = function () {\n"
    "        return this.replace(/[^\\d]/g, '');\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// better parseFloat() in String                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof String.prototype.betterParseFloat != 'function') {\n"
    "    String.prototype.betterParseFloat = function() {\n"
    "        return this.replace(/[^\\d.]/g, '');\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// insertAt() position in String                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof String.prototype.insertAt != 'function') {\n"
    "    String.prototype.insertAt = function(index, s) {\n"
    "        return this.substring(0, index) + s + this.substring(index);\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// isEven() in Number                                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof Number.prototype.isEven != 'function') {\n"
    "    Number.prototype.isEven = function() {\n"
    "        return (this%2)==0;\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// isOdd() in Number                                   //\n"
    "/////////////////////////////////////////////////////////\n"
    "if (typeof Number.prototype.isOdd != 'function') {\n"
    "    Number.prototype.isOdd = function() {\n"
    "        return !this.isEven();\n"
    "    };\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Macht alle übergebenen Objekte global per id verfügbar\n"
    "/////////////////////////////////////////////////////////\n"
    "function makeElementsGlobal(all) {\n"
    "    for (var i=0, max=all.length; i < max; i++) {\n"
    "        var idName = $(all[i]).attr('id');\n"
    "        window[idName] = document.getElementById(idName);\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Sobald DOM aufgebaut, wird das 1. Element zu canvas //\n"
    "// Alle Variablen und Methoden die zu canvas gehören,  //\n"
    "// werden hier initialisiert.                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "function makeCanvasAccessible() {\n"
    "    // ohne var, damit global\n"
    "    canvas = $('.canvas_standard').get(0);\n"
    "\n"
    "    if (canvas === undefined)\n"
    "        throw new Error('No element <canvas> found. The root must be <canvas>.');\n"
    "\n"
    "    canvas.lpsrelease = 'XML2HTML5 Converter';\n"
    "    canvas.lpsbuilddate = '2012-07-01';\n"
    "    canvas.lpsversion = '1.0';\n"
    "    canvas.version = '1.0';\n"
    "    canvas.percentcreated = 1;\n"
    "    canvas.runtime = 'html5';\n"
    "    canvas.framerate = 30;\n"
    "    canvas.versionInfoString = function() { return '1.0'; }\n"
    "\n"
    "    canvas.getMouse = function(axis) {\n"
    "        if (typeof axis !== 'string' || (axis !== 'x' && axis !== 'y'))\n"
    "            throw new Error('canvas.getMouse() - No axis or wrong axis.');\n"
    "        return 1;\n"
    "    }\n"
    "\n"
    "    canvas.setDefaultContextMenu = function(contextmenu) {};\n"
    "\n"
    "\n"
    "    // Anhand dieser Variable kann im Skript abgefragt werden, ob wir im Debugmode sind\n"
    "    // ohne 'var', damit global. \n"
    "    $debug = false;\n"
    "    $swf8 = false;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Führt die beiden oben genannten Methoden aus (init) //\n"
    "/////////////////////////////////////////////////////////\n"
    "function makeIDsGlobalAndInitStuff(all) {\n"
    "    // Make all id's from <div>'s global (Firefox)\n"
    "    makeElementsGlobal(document.getElementsByTagName('div'));\n"
    "    // Make all id's from <input>'s global (Firefox)\n"
    "    makeElementsGlobal(document.getElementsByTagName('input'));\n"
    "    // Make all id's from <select>'s global (Firefox)\n"
    "    makeElementsGlobal(document.getElementsByTagName('select'));\n"
    "    // Make all id's from <option>'s global (Firefox)\n"
    "    makeElementsGlobal(document.getElementsByTagName('option'));\n"
    "    // Make all id's from <button>'s global (Firefox)\n"
    "    makeElementsGlobal(document.getElementsByTagName('button'));\n"
    "    // Make all id's from <button>'s global (Firefox)\n"
    "    makeElementsGlobal(document.getElementsByTagName('textarea'));\n"
    "\n"
    "    // Make canvas accessible\n"
    "    makeCanvasAccessible();\n"
    "\n"
    "\n"
    "    // Bei OL hat value von checkboxen eine andere Bedeutung als bei HTML\n"
    "    // Bedeutung HTML: submit-Wert\n"
    "    // Bedeutung OL: Ob checkbox gesetzt oder nicht (true oder false)\n"
    "    // Deswegen bei jeder Änderung des Wertes einfach value auf true oder false setzen\n"
    "    $('input[type=checkbox]').each( function() {\n"
    "        // Einmal jetzt den aktuellen Wert setzen\n"
    "        this.value = $(this).is(':checked');\n"
    "        // und bei jeder Änderung\n"
    "        $(this).on('change',function() {\n"
    "            this.value = $(this).is(':checked');\n"
    "        });\n"
    "\n"
    "        // Den Mousecursor ändern vom benachbarten span\n"
    "        $(this).next().css('cursor','pointer');\n"
    "    });\n"
    "\n"
    "    // Davon unabhängig: Triggern, damit da dran hängende Constraints die Änderung mitbekommen\n"
    "    // Dies gilt sogar für jedes input!\n"
    "    $('input').each( function() {\n"
    "        $(this).on('change',function() {\n"
    "            $(this).triggerHandler('onvalue',$(this).val());\n"
    "        });\n"
    "    });\n"
    "\n"
    "    // Auch bei radio-buttons den Cursor stets anpassen vom benachbarten Text\n"
    "    $('input[type=radio]').each( function() {\n"
    "        // Den Mousecursor ändern vom benachbarten span\n"
    "        $(this).next().css('cursor','pointer');\n"
    "    });\n"
    "\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "//Wandelt einen float in einen korrekt gerundeten Integer\n"
    "/////////////////////////////////////////////////////////\n"
    "function toInt(n){ return Math.round(Number(n)); };\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Wandelt einen float in einen abgerundeten Integer   //\n"
    "/////////////////////////////////////////////////////////\n"
    "function toIntFloor(n){ return Math.floor(Number(n)); };\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Höchste Zahl in Array                               //\n"
    "/////////////////////////////////////////////////////////\n"
    "function getMaxOfArray(numArray)\n"
    "{\n"
    "    return Math.max.apply(null, numArray);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Summer aller Zahlen in einem Array                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "function getSumOfArray(arr)\n"
    "{\n"
    "    var sum = 0;"
    "    $.each(arr,function(){sum+=parseFloat(this) || 0;});\n"
    "    return sum;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Heighest height of all children of an element       //\n"
    "/////////////////////////////////////////////////////////\n"
    "function getHeighestHeightOfChilds(elem)\n"
    "{\n"
    "    var heighestHeight = 0;\n"
    "    $(elem).children().each(function() {\n"
    "        var heightOfChild = $(this).outerHeight(true);\n"
    "        if (heightOfChild > heighestHeight)\n"
    "            heighestHeight = heightOfChild;\n"
    "    });\n"
    "\n"
    "    return heighestHeight;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// true, wenn element2 element1 überlappt              //\n"
    "/////////////////////////////////////////////////////////\n"
    "function isOverlapping(element1, element2) {\n"
    "    return findOverlappingElements(element1, element2).length > 0;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Liefert aus einem Satz von Elementen, alle          //\n"
    "// diejenigen zurück, welche das Zielobjekt überlappen.//\n"
    "/////////////////////////////////////////////////////////\n"
    "function findOverlappingElements(targetSelector, elementsToScanSelector) {\n"
    "    var overlappingElements = [];\n"
    "\n"
    "    var $target = $(targetSelector);\n"
    "    var tAxis = $target.offset();\n"
    "    var t_x = [tAxis.left, tAxis.left + $target.outerWidth()];\n"
    "    var t_y = [tAxis.top, tAxis.top + $target.outerHeight()];\n"
    "\n"
    "    $(elementsToScanSelector).each(function() {\n"
    "        var $this = $(this);\n"
    "        var thisPos = $this.offset();\n"
    "        var i_x = [thisPos.left, thisPos.left + $this.outerWidth()]\n"
    "        var i_y = [thisPos.top, thisPos.top + $this.outerHeight()];\n"
    "\n"
    "        if ( t_x[0] < i_x[1] && t_x[1] > i_x[0] &&\n"
    "            t_y[0] < i_y[1] && t_y[1] > i_y[0]) {\n"
    "            overlappingElements.push($this);\n"
    "        }\n"
    "    });\n"
    "    return overlappingElements;\n"
    "}\n"
    "\n"
    "\n"
    //"/////////////////////////////////////////////////////////\n"
    //"// Hindere IE 9 am seitlichen scrollen mit dem Scrollrad!\n"
    //"/////////////////////////////////////////////////////////\n"
    //"// Bricht das scrollen von RollUpDown-Elementen, deswegen auskommentiert\n"
    //"// Ohnehin nicht mehr nötig\n"
    //"/*\n"
    //"function wheel(event)\n"
    //"{\n"
    //"    if (!event)\n"
    //"        event = window.event;\n"
    //"\n"
    //"    if (event.preventDefault)\n"
    //"    {\n"
    //"        event.preventDefault();\n"
    //"        event.returnValue = false;\n"
    //"    }\n"
    //"}\n"
    //"if (window.addEventListener)\n"
    //"    window.addEventListener('DOMMouseScroll', wheel, false);\n"
    //"window.onmousewheel = document.onmousewheel = wheel;\n"
    //"*/\n"
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
    "  var isvalid = typeof isvalid !== 'undefined' ? isvalid : true; // (ToDo - ist ein Attribut von rud-Container)\n"
    "  var closeable = typeof closeable !== 'undefined' ? closeable : true; // (ToDo - hat was mit nicedialog zu tun)\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "  // Bei checkboxen bezieht sich die Abfrage nach 'value' darauf, ob es 'checked' ist oder nicht\n"
    "  // Und nicht auf das value-Attribut als solches... warum auch immer.\n"
    "  // http://www.openlaszlo.org/lps4.9/docs/reference/lz.checkbox.html (Dortiges Beispiel)\n"
    "  if ($(idAbhaengig).is('input') && $(idAbhaengig).attr('type') === 'checkbox' && bedingungAlsString === 'value')\n"
    "      bedingungAlsString = 'checked';\n"
    "\n"
    "\n"
    "\n"
    "  // 'value' wird intern von OpenLaszlo benutzt! Indem ich auch in JS 'value' in der Zeile\n"
    "  // vorher setze und danach den string auswerte, der 'value' in der Bedingung enthält,\n"
    "  // muss ich das von OpenLaszlo benutzte 'value' nicht intern parsen (nice Trick, I Think)\n"
    "  // => eval(bedingungAlsString) kennt dann die Var value und kann korrekt auswerten\n"
    "  // Das gleiche gilt für 'text', was wohl jQueryhtml() entspricht, da 'text' auch dynamisch mit html() gesetzt wird.\n"
    "  // Das gleiche gilt für 'visible'.\n"
    "  if (idAbhaengig == \"__PARENT__\") //ToDo -> Das kann ja nicht stimmen, dass dann $(idAbhaengig) was findet\n"
    "  {\n"
    "      var value = $(idAbhaengig).parent().val();\n"
    "      // Die nachfolgenden beiden Zeilen helfen mir jetzt bei parent().parent(), oder können sie weg? ToDo\n"
    "      var parent = $(idAbhaengig).parent().parent();\n"
    "      parent.value = $(idAbhaengig).parent().parent().val();\n"
    "\n"
    "      var text = $(idAbhaengig).parent().html();\n"
    "      var visible = $(idAbhaengig).parent().is(':visible')\n"
    "  }\n"
    "  else\n"
    "  {\n"
    "      var value = $(idAbhaengig).val();\n"
    "      // Die nachfolgenden beiden Zeilen helfen mir jetzt bei parent().parent(), oder können sie weg? ToDo\n"
    "      var parent = $(idAbhaengig).parent();\n"
    "      parent.value = $(idAbhaengig).parent().val();\n"
    "\n"
    "      var text = $(idAbhaengig).html();\n"
    "      var visible = $(idAbhaengig).is(':visible')\n"
    "  }\n"
    "\n"
    "\n"
    "  console.log('Bedingung: '+bedingungAlsString)\n"
    "\n"
    "  if (bedingungAlsString === 'checked')\n"
    "    var bedingung = $(idAbhaengig).is(':checked');\n"
    "  else\n"
    "    var bedingung = eval(bedingungAlsString);\n"
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
    "// globale canvas-Methoden                             //\n"
    "/////////////////////////////////////////////////////////\n"
    //"function loadurlchecksave(url)\n"
    //"{\n"
    //"    window.location.href = url;\n"
    //"}\n"
    //"\n"
    "var lasthelpid = 'tabStart';\n"
    "function setglobalhelp(helpid)\n"
    "{\n"
    "    //globalhelp.info.setAttribute_('text',helpid)\n"
    "    //return;\n"
    "  lasthelpid = helpid;\n"
    "  var info='';\n"
    "  var infonode=dpGlobalhelp.xpathQuery(\"info[@id='\"+helpid+\"']\")\n"
    "  // Debug.write(\"infonode\",infonode)\n"
    "  if (infonode && infonode['childNodes']) {\n"
    "      for ( var i = 0; i < infonode.childNodes.length; i++ ) \n"
    "          if (infonode.childNodes[i].nodeValue)\n"
    "            info+=infonode.childNodes[i].nodeValue;\n"
    "          else\n"
    "            info += '<br />';\n"
    "  }\n"
    "  globalhelp.info.setAttribute_('text',info)\n"
    "\n"
    "\n"
    "\n"
    "  // Zusatz-Code -  Das hier muss noch zu ECHTEM generierten Code werden\n"
    "  $(globalhelp_6).height(globalhelp._inner.myHeight+35-35);\n"
    "  $(globalhelp_10).css('top',globalhelp._inner.myHeight+50-50+15);\n"
    "  // Damit der eine blöde Effekt weggeht Hintergrundbild mit sich selbst aktualisieren\n"
    "  $(globalhelp_7).css('background-image',$(globalhelp_7).css('background-image'))\n"
    "  $(globalhelp_8).css('background-image',$(globalhelp_8).css('background-image'))\n"
    "  $(globalhelp_9).css('background-image',$(globalhelp_9).css('background-image'))\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Liest per ?arg=value&arg2=value2 übergebene URL-Parameter aus\n"
    "/////////////////////////////////////////////////////////\n"
    "getInitArg = function getURLParameter(name) {\n"
    "    return decodeURIComponent((new RegExp('[?|&]' + name + '=' + '([^&;]+?)(&|#|;|$)').exec(location.search)||[,\"\"])[1].replace(/\\+/g, '%20'))||null;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Objekte, welche im Skript erzeugt werden            //\n"
    "/////////////////////////////////////////////////////////\n"
    "var objectFromScriptCounter = 1;\n"
    "\n"
    "function createObjectFromScript(name, scope, attributes) {\n"
    "    if (name === undefined)\n"
    "        throw new TypeError('function createObjectFromScript - Neither the name-attribute nor the scope-attribute is allowed to be undefined');\n"
    "\n"
    "    if (scope === undefined)\n"
    "        scope = canvas;\n"
    "\n"
    "    var id = 'objectFromScript'+objectFromScriptCounter;\n"
    "\n"
    "    // Die id mitgeben, damit ich es nach dem Einfügen daran wieder identifizieren und finden kann!\n"
    "    if (name === 'view') {\n"
    "        jQuery('<div/>', {\n"
    "            id: id,\n"
    "            class: 'div_standard noPointerEvents',\n"
    "        }).appendTo(scope);\n"
    "    }\n"
    "    else if (name === 'button') {\n"
    "        jQuery('<button/>', {\n"
    "            id: id,\n"
    "            class: 'input_standard',\n"
    "        }).appendTo(scope);\n"
    "    }\n"
    "    else if (name === 'text') {\n"
    "        jQuery('<div/>', {\n"
    "            id: id,\n"
    "            class: 'div_text',\n"
    //"            text: 'Go to Google!'\n"
    "        }).appendTo(scope);\n"
    "    }\n"
    "    else if (name === 'rotateDigit') { /*ToDo - Warum matcht er das nicht automatisch? */\n"
    "        jQuery('<div/>', {\n"
    "            id: id,\n"
    "            class: 'div_standard noPointerEvents',\n"
    "        }).appendTo(scope);\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        alert('Das muss ich noch unterstützen: '+name);\n"
    "    }\n"
    "\n"
    "    if (attributes)\n"
    "    {\n"
    "        if (attributes.name)\n"
    "        {\n"
    "            // 'name'-Attribut ist initialize-only und kann später nicht geändert werden\n"
    "            // Deswegen gibt es dafür keinen getter/setter\n"
    "            var elem = document.getElementById(id);\n"
    "            elem.getTheParent()[attributes.name] = elem;\n"
    "            // Alle name-Attribute im äußeren Scope sind global. Da <script> immer im\n"
    "            // äußersten Scope sollten eigentlich alle 'name's hier global werden.\n"
    "            window[attributes.name] = elem;\n"
    // Unsinn: http://www.openlaszlo.org/lps4.2/docs/developers/language-preliminaries.html
    // "            canvas[attributes.name] = document.getElementById(id);\n"
    "\n"
    "            delete attributes.name;\n"
    "        }\n"
    "\n"
    "\n"
    "        // Seems to be not possible, when creating an Object from script\n"
    "        if (attributes.onclick)\n"
    "            delete attributes.onclick;\n"
    "\n"
    "\n"
    "        Object.keys(attributes).forEach(function(key) {\n"
    "            $('#'+id).get(0).setAttribute_(key,attributes[key]);\n"
    "        });\n"
    "    }\n"
    "/*\n"
    "    if (attributes.myHeight !== undefined)\n"
    "        $('#'+id).css('height', attributes.myHeight);\n"
    "    if (attributes.myWidth !== undefined)\n"
    "        $('#'+id).css('width', attributes.myWidth);\n"
    "    if (attributes.x !== undefined)\n"
    "        $('#'+id).css('left', attributes.x);\n"
    "    if (attributes.y !== undefined)\n"
    "        $('#'+id).css('top', attributes.y);\n"
    "\n"
    "    if (attributes.bgcolor !== undefined)\n"
    "    {\n"
    "        $('#'+id).setAttribute_('bgcolor',attributes.bgcolor);\n"
    "    }\n"
    "*/\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "    objectFromScriptCounter++;\n"
    "\n"
    "    return $('#'+id).get(0);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// XML-Funktionen, die zu <datapointer> gehören        //\n"
    "/////////////////////////////////////////////////////////\n"
    "function getXMLDocumentFromString(s) {\n"
    //"    if (s === undefined) return undefined;\n" <-- Bricht zu viel. Muss immer ein [Object Document] rurückliefern
    "\n"
    "    if (typeof s !== 'string')\n"
    "        throw new TypeError('function getXMLDocumentFromString - first argument is supposed to be a string.');\n"
    "\n"
    "    var xmlDoc = null;\n"
    "\n"
    // Es MUSS so rum sein, erst die Abfrage nach dem window.ActiveXObject
    // Sonst würde IE 9 unten rein rutschen und das Dokumentformat wäre nicht mehr kompatibel mit dem auslesen
    "    if (window.ActiveXObject) // IE 6 to IE 9 ...\n"
    "    {\n"
    "        xmlDoc = new ActiveXObject('Microsoft.XMLDOM');\n"
    "        xmlDoc.async = false;\n"
    "        xmlDoc.loadXML(s);\n"
    "    }\n"
    "    else if (window.DOMParser) // W3C (Mozilla, Firefox, Safari)\n"
    "    {\n"
    "        var parser = new DOMParser();\n"
    "        xmlDoc = parser.parseFromString(s,'text/xml');\n"
    "    }\n"
    "\n"
    "    return xmlDoc;\n"
    "}\n"
    "\n"
    "\n"
    "function getXMLDocumentFromFile(file) {\n"
    "    if (window.XMLHttpRequest)\n"
    "    { // code for IE7+, Firefox, Chrome, Opera, Safari\n"
    "        var xmlhttp = new XMLHttpRequest();\n"
    "    }\n"
    "    else\n"
    "    { // code for IE6, IE5\n"
    "        var xmlhttp = new ActiveXObject('Microsoft.XMLHTTP');\n"
    "        xmlhttp.async = false;\n"
    //       doc.load(url); <-- Im Internet gefundene Alternative
    //       return doc; <-- "
    "    }\n"
    "    xmlhttp.open('GET',file,false);\n"
    "    xmlhttp.send();\n"
    "    var xmlDoc = xmlhttp.responseXML;\n"
    "\n"
    "    return xmlDoc;\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// DIE lz-Klasse mit allen Services als Klassen.       //\n"
    "//  Die Services definieren darin ihre Methoden.       //\n"
    "/////////////////////////////////////////////////////////\n"
    "function lz_MetaClass() {\n"
    "    this.FocusService = function() {\n"
    "        this.setFocus = function(a) {\n"
    "            $(a).focus();\n"
    "        }\n"
    "        this.getFocus = function() {\n"
    "            return document.activeElement;\n"
    "        }\n"
    "        this.clearFocus = function() {\n"
    "            this.getFocus().blur();\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.CursorService = function() {\n"
    "        this.restoreCursor = function() {\n"
    "            $('body').css('cursor', 'default');\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.TimerService = function() {\n"
    "        this.addTimer = function(handler, millisecs) {\n"
    "            window.setTimeout(function() { handler(); }, millisecs);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.AudioService = function() {\n"
    "        this.playSound = function(res) {\n"
    "            var snd = new Audio(res); // buffers automatically when created\n"
    "            snd.load(); // To play the sound on the iPad!?\n"
    "            snd.play();\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.BrowserService = function() {\n"
    "        this.getInitArg = getInitArg;\n"
    "        this.callJS = function(method,callback,args) {\n"
    "            window[method](args);\n"
    "        }\n"
    "        this.loadJS = function(code,target) {\n"
    "            eval(code);\n"
    "        }\n"
    "        this.loadURL = function(url,target) {\n"
    "            window.open(url, target);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.HistoryService = function() {\n"
    "        this.save = function(scope,prop,val) {\n"
    "        }\n"
    "        this.next = function() {\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    // It is fine to define an event for which no handler exists\n"
    "    this.event = function(eventValue,handler,eventType) {\n"
    "        this.eventHandler = handler;\n"
    "        this.eventType = eventType;\n"
    "\n"
    "        this.sendEvent = function(ev) {\n"
    "            // triggerHandler, weil Point-To-Point-Logik, und kein bubblen stattfinden soll\n"
    "            $(this.eventHandler).triggerHandler(this.eventType, ev);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.Formatter = function() {\n"
    "    }\n"
    "    // Warum auch immer, hängt gemäß OL formatToString direkt im prototype...\n"
    "    this.Formatter.prototype.formatToString = function() { return sprintf.apply(null, arguments); }\n"
    "\n"
    "\n"
    "    // A <dataset> tag defines a local dataset. The name of the dataset is used in the datapath attribute of a view.\n"
    "    this.dataset = function(name) {\n"
    "        this.rawdata = '';\n"
    "        this.name = name;\n"
    "        this.queryParamKeys = [];\n"
    "        this.queryParamVals = [];\n"
    "\n"
    "        this.setQueryParam = function(key, val) {\n"
    "            this.queryParamKeys.push(key);\n"
    "            this.queryParamVals.push(val);\n"
    "        }\n"
    "        this.getPointer = function() {\n"
    "            var pointer = new lz.datapointer(this.name+':'+'/'+'ToDo');\n"
    "            return pointer;\n"
    "        }\n"
    "        this.doRequest = function() {\n"
    "            $(this).triggerHandler('ondata');\n"
    "        }\n"
    "        // Meiner Meinung nach macht das keinen Sinn, dass ein Dataset die Methode\n"
    "        // serialize() aufrufen kann. Diese Methode haben nur Datapointer!\n"
    "        // Aber GFlender ruft serialize() bei Datasets auf.\n"
    "        this.serialize = function() {\n"
    "           return this.rawdata;\n"
    "        }\n"
    "        // Meiner Meinung nach macht das keinen Sinn, dass ein Dataset die Methode\n"
    "        // setAttr() aufrufen kann. Diese Methode gibt es gemäß OL-Doku nicht\n"
    "        // Aber GFlender ruft setAttr() bei Datasets auf.\n"
    "        this.setAttr = function(a,v) {\n"
    "            // this.setAttribute_(a,v);\n"
    "        }\n"
    "        // Analoges gilt für removeAttr():\n"
    "        this.removeAttr = function(a,v) {\n"
    "            //\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    // handlet den Zugriff auf die XML-Datensätze\n"
    "    this.datapointer = function(xpath,rerun) {\n"
    "\n"
    "\n"
    "        this.getElementsXPath = function(el)\n"
    "        {\n"
    "            if (el && el.id)\n"
    "                return '//*[@id=\"' + el.id + '\"]';\n"
    "            else\n"
    "                return this.getElementsTreeXPath(el);\n"
    "        };\n"
    "        this.getElementsTreeXPath = function(el)\n"
    "        {\n"
    "            var paths = [];\n"
    "            for (; el && el.nodeType == 1; el = el.parentNode)\n"
    "            {\n"
    "                var index = 0;\n"
    "                for (var sibling = el.previousSibling; sibling; sibling = sibling.previousSibling)\n"
    "                {\n"
    "                    if (sibling.nodeType == Node.DOCUMENT_TYPE_NODE)\n"
    "                        continue;\n"
    "                    if (sibling.nodeName == el.nodeName)\n"
    "                        index++;\n"
    "                }\n"
    "                var tagName = el.nodeName;/*.toLowerCase();*/\n"
    "                var pathIndex = (index ? '[' + (index+1) + ']' : '');\n"
    "                /******************************************/\n"
    "                // Die allererste Node überspringen, weil wir ja das dataset davorsetzen\n"
    "                if (el.parentNode.parentNode)\n"
    "                /******************************************/\n"
    "                    paths.splice(0, 0, tagName + pathIndex);\n"
    "            }\n"
    "            return paths.length ? '/' + paths.join('/') : null;\n"
    "        };\n"
    "\n"
    "\n"
    "        // Hardcore-Code..... Diese Funktion ist das Arbeitstier\n"
    "        this.setXPath = function(xpath_) {\n"
    "            if (this.xpath === undefined || this.xpath == null) {\n"
    "                // Dann noch nachträglich initialisieren\n"
    "                this.init(xpath_);\n"
    "            }\n"
    "\n"
    "            var pfad = xpath_.substring(xpath_.indexOf(':')+1,xpath_.length);\n"
    "            // Durch das umbilden der speziellen OL-Syntax auf xpath müssen wir einen einzelnen\n"
    "            // Slash (= Root-Element) am Ende ignorieren. Wir fügen den / eh immer hinzu\n"
    "            if (pfad.charAt(pfad.length-1) == '/')\n"
    "                pfad = pfad.substring(0, pfad.length-1);\n"
    "            var xpath = '/' + this.datasetName + pfad;\n"
    "            // '/text()' kann/muss entfernt werden. Es würde auch mit klappen, nur beim counter nicht.\n"
    "            if (xpath.endsWith('/text()'))\n"
    "                xpath = xpath.substr(0,xpath.length-7);\n"
    "\n"
    "            // Gets all nodes: var xpath = '/' + this.datasetName + '//*';\n"
    "\n"
    "            var node = undefined;\n"
    "            var nodeValue = undefined;\n"
    "            var nodeName = undefined;\n"
    "            var nodeType = undefined;\n"
    "            var childrenCounter = 0;\n"
    "            var numberOfNodesPointingTo = 0;\n"
    "\n"
    "            if (window.ActiveXObject /* && typeof this.xml.selectNodes !== 'undefined' */)\n"
    "            {\n"
    "                // IE hat die DOM-Beschreibung nicht genau gelesen...\n"
    "                // xpath arbeitet bei index-Zugriffen 1-basiert! IE hat es aber 0-basiert implementiert\n"
    "                // Deswegen falls ein Index auftritt, immer um eins reduzieren\n"
    "                // That's not that simple as it seems...\n"
    "                var rgx = /\\[(\\d+)\\]/g;\n"
    "                var m = xpath.match(rgx); // Um die Matches an sich zu finden\n"
    "                if (m)\n"
    "                {\n"
    "                    var extraPos = 0; // Wenn er z. B. von [10] auf [9] wechselt\n"
    "                    for (var j=0;j<m.length;j++)\n"
    "                    {\n"
    "                        // Für jeden gefundenen Match...\n"
    "                        var match = m[j];\n"
    "                        // ...finde die Zahl...\n"
    "                        match = match.betterParseInt();\n"
    "                        // ...wandle sie in einen Integer um...\n"
    "                        match = parseInt(match);\n"
    "                        // ...reduziere sie um 1...\n"
    "                        match--;\n"
    "                        // ...mach wieder die eckigen Klammern drum herum...\n"
    "                        match = '['+match+']';\n"
    "                        // ..finde den index... (exec nimmt das jeweils nächste Vorkommen bei erneutem Aufruf, falls mehrere Schleifendurchgänge)\n"
    "                        var m2 = rgx.exec(xpath) // Der Index steckt jetzt in m2.index\n"
    "                        var ind = m2.index - extraPos;\n"
    "                        // ...delete old phrase...\n"
    "                        xpath = xpath.substring(0,ind) + xpath.substring(ind + m[j].length);\n"
    "                        // ...insert new phrase...\n"
    "                        xpath = xpath.insertAt(ind,match);\n"
    "                        // ...done\n"
    "                        // Berücksichtige für die nachfolgenden Elemente einen Abstand weniger, wenn nötig...\n"
    "                        if (match == '[9]' || match == '[99]' || match == '[999]' || match == '[9999]' || match == '[99999]' || match == '[999999]' || match == '[9999999]')\n"
    "                          extraPos++;\n"
    "\n"
    "                        // alert(xpath);\n"
    "                    }\n"
    "                }\n"
    "\n"
    "                var nodes = this.xml.selectNodes(xpath);\n"
    "\n"
    "                // for (var i = 0;i < nodes.length;i++) // No! Immer der erste Match zählt.\n"
    "                numberOfNodesPointingTo = nodes.length;\n"
    "\n"
    "                var i = 0;\n"
    "\n"
    "                if (nodes[i] && nodes[i].childNodes[0] != undefined)\n"
    "                {\n"
    "                    node = nodes[i].childNodes[0].parentNode;\n"
    "                    nodeValue = nodes[i].childNodes[0].nodeValue;\n"
    "                    nodeName = nodes[i].childNodes[0].parentNode.nodeName;\n"
    "                    nodeType = nodes[i].childNodes[0].nodeType;\n"
    "                    childrenCounter = nodes[i].childNodes.length;\n"
    "                }\n"
    "                // Eventuell ist es auch eine Abfrage nach einer Textnode\n"
    "                else if (nodes[i] && nodes[i].nodeName == '#text')\n"
    "                {\n"
    "                    node = nodes[i].parentNode;\n"
    "                    // Dann brauche ich doch wieder die Schleife:\n"
    "                    for (var j = 0;j < nodes[i].length;j++)\n"
    "                    {\n"
    "                        if (nodes[i].parentNode.childNodes[j] != undefined && nodes[i].parentNode.childNodes[j].nodeName == '#text')\n"
    "                        {\n"
    "                            if (nodeValue == undefined)\n"
    "                                nodeValue = nodes[i].parentNode.childNodes[j].nodeValue;\n"
    "                            else\n"
    "                                nodeValue += nodes[i].parentNode.childNodes[j].nodeValue;\n"
    "\n"
    "                            childrenCounter++;\n"
    "                        }\n"
    "                    }\n"
    "                    nodeName = nodes[i].parentNode.nodeName;\n"
    "                    nodeType = nodes[i].nodeType;\n"
    "                }\n"
    "                // Eventuell ist es auch eine Abfrage nach einem direkten Elementknoten\n"
    "                else if (nodes[i] && nodes[i].nodeType == 1)\n"
    "                {\n"
    "                    node = nodes[i];\n"
    "                    nodeValue = nodes[i].nodeValue;\n"
    "                    nodeName = nodes[i].nodeName;\n"
    "                    nodeType = nodes[i].nodeType;\n"
    "                    childrenCounter++;\n"
    "                }\n"
    "            }\n"
    "            else if (document.implementation && document.implementation.createDocument) // code for IE9, Mozilla, Firefox, Opera, etc.\n"
    "            {\n"
    "                var nodes = this.xml.evaluate(xpath, this.xml, null, XPathResult.ANY_TYPE, null);\n"
    "                var result = nodes.iterateNext();\n"
    "\n"
    "                while (result)\n"
    "                {\n"
    "                    numberOfNodesPointingTo++;\n"
    "\n"
    "                    // Wenn der Knoten leer ist, dann belass es bei den oben gesetzen undefined-Werten für node, nodeValue und nodeName.\n"
    "                    if (result.childNodes[0] != undefined)\n"
    "                    {\n"
    "                        node = result.childNodes[0].parentNode;\n"
    "                        nodeValue = result.childNodes[0].nodeValue;\n"
    "                        nodeName = result.childNodes[0].parentNode.nodeName;\n"
    "                        nodeType = result.childNodes[0].nodeType;\n"
    "                        childrenCounter = result.childNodes.length;\n"
    "                    }\n"
    "                    // Eventuell ist es auch eine Abfrage nach einer Textnode\n"
    "                    else if (result.nodeName && result.nodeName == '#text')\n"
    "                    {\n"
    "                        node = result.parentNode;\n"
    "\n"
    "                        if (nodeValue == undefined)\n"
    "                            nodeValue = result.nodeValue;\n"
    "                        else\n"
    "                            nodeValue += result.nodeValue;\n"
    "\n"
    "                        nodeName = result.parentNode.nodeName;\n"
    "                        nodeType = result.nodeType;\n"
    "                        childrenCounter++;\n"
    "                    }\n"
    "                    // Eventuell ist es auch eine Abfrage nach einem direkten Elementknoten\n"
    "                    // (welches keine Kinder hat). Gilt das immer?\n"
    "                    // Codezeile, wo aufgetreten: dpEingaben.setXPath(\"dsEingaben:/\");\n"
    "                    else if (result.nodeName && result.nodeType == 1)\n"
    "                    {\n"
    "                        node = result;\n"
    "                        nodeValue = result.nodeValue;\n"
    "                        nodeName = result.nodeName;\n"
    "                        nodeType = result.nodeType;\n"
    "                        childrenCounter++;\n"
    "                    }\n"
    "\n"
    "                    result = nodes.iterateNext(); // Sonst infinite loop\n"
    "                }\n"
    "            }\n"
    "\n"
    "            this.lastNode = node;\n"
    "            this.lastNodeText = nodeValue;\n"
    "            this.lastNodeName = nodeName;\n"
    "            this.lastNodeType = nodeType;\n"
    "            this.lastQueryChildrenCounter = childrenCounter;\n"
    "            this.lastQueryNumberOfNodesPointingTo = numberOfNodesPointingTo;\n"
    "\n"
    "            return (this.lastNode !== undefined); // ToDo, kann auch undefined zurückliefern\n"
    "        }\n"
    "\n"
    "\n"
    "        // Normalweise wird beim anlegen alles initialisiert anhand des Arguments xpath\n"
    "        // Es gibt jedoch eine Stelle im GFlender-Code (CalcUmzugskostenpauschale)\n"
    "        // wo Quatsch übergeben wird als Argument. Das muss ich abfangen.\n"
    "        // **private** (ToDo - iwie private machen)\n"
    "        this.init = function(xpath) {\n"
    "            this.xpath = xpath;\n"
    "\n"
    "            this.datasetName = xpath.substring(0,xpath.indexOf(':'));\n"
    "\n"
    "            this.dataset = window[this.datasetName];\n"
    "\n"
    "            if (this.dataset && this.dataset.rawdata) // Legacy-Code solange es noch als Array ausgewertete Datasets gibt\n"
    "                this.xml = getXMLDocumentFromString(this.dataset.rawdata);\n"
    "            else\n"
    "                this.xml = getXMLDocumentFromString(''); // Damit auf jeden Fall ein [Object Document] zurückkommt\n"
    "        }\n"
    "\n"
    "\n"
    "        // Das 'object' (DOMWindow), welches GFlender einmal übergibt, lass ich passieren\n"
    "        if (typeof xpath !== 'string' && typeof xpath !== 'object')\n"
    "            throw new TypeError('Constructor function datapointer - first argument is no string.');\n"
    "        if (xpath === '')\n"
    "            throw new TypeError('Constructor function datapointer - first argument should not be empty.');\n"
    "\n"
    "        this.rerunxpath = rerun; // Noch ziemlich oft 'undefined', aber das ist Absicht\n"
    "\n"
    "        this.lastNode = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.lastNodeText = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.lastNodeName = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.lastNodeType = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "\n"
    "        // Wenn dieses blöde Objekt kommt, dann keine Initialisierung\n"
    "        if (typeof xpath !== 'object')\n"
    "        {\n"
    "            this.init(xpath);\n"
    "\n"
    "            // Beim konstruieren des Objekts setXPath auch immer mit aufrufen!\n"
    "            this.setXPath(this.xpath);\n"
    "        }\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "        this.xpathQuery = function(query) {\n"
    "            // Returns the result of an XPath query without changing the pointer.\n"
    "\n"
    "            if (typeof query !== 'string')\n"
    "                throw new TypeError('lz.datapointer.xpathQuery - argument is no string.');\n"
    "\n"
    "            // alte 'pointer' sichern\n"
    "            var lastNode = this.lastNode;\n"
    "            var lastNodeText = this.lastNodeText;\n"
    "            var lastNodeName = this.lastNodeName;\n"
    "            var lastNodeType = this.lastNodeType;\n"
    "\n"
    "\n"
    //"            var originalQuery = query;\n"
    "            // Folgende Logik: Er scheint grundsätzlich immer vom letzten xpath auszugehen\n"
    //"            // taucht jedoch im string ein '/' auf, dann ist es ein komplett neuer xpath.\n"
    //"            if (!query.contains('/'))\n"
    // Dies bricht Beispiel 11.2, deswegen neue Logik über Doppelpunkt
    "            // taucht jedoch im string kein ':' auf, dann ist es ein relativer XPath!\n"
    "            if (!query.contains(':'))\n"
    "              query = this.xpath + '/' + query;\n"
    "            this.setXPath(query);\n"
    "\n"
    "            // Return-Wert ermitteln - Wenn Text gefunden wurde und er ein Attribut z. B. \n"
    "            // abgefragt hat, dann diesen zurückgeben, ansonsten den Knoten selber,\n"
    "            // ansonsten null (Rückwärts-Logik, wenn zutreffend, wird überschrieben)\n"
    "            var returnValue = null;\n"
    "            if (this.lastNode) \n"
    "                returnValue = this.lastNode;\n"
    "            // Wenn Text da ist und es eine Textnode ist\n"
    "            if (this.lastNodeText && this.lastNodeType == 3) \n"
    "                returnValue = this.lastNodeText;\n"
    "\n"
    "            // alte 'pointer' wiederherstellen\n"
    "            this.lastNode = lastNode;\n"
    "            this.lastNodeText = lastNodeText;\n"
    "            this.lastNodeName = lastNodeName;\n"
    "            this.lastNodeType = lastNodeType;\n"
    "\n"
    "            return returnValue;\n"
    "        }\n"
    "        this.setNodeText = function(text) {\n"
    "            // Lieber ohne jQuery, da kein HTML-Dokument, sondern eine Node\n"
    "            if (this.lastNode)\n"
    "            {\n"
    "                this.lastNodeText = text; // Intern aktualisieren\n"
    "                this.lastNode.childNodes[0].nodeValue = text;   // Extern aktualisieren\n"
    "            }\n"
    "        }\n"
    "        this.isValid = function() {\n"
    "            if (this.lastNode === undefined && this.lastNodeText === undefined && this.lastNodename === undefined)\n"
    "                return false;\n"
    "            else\n"
    "                return true;\n"
    "        }\n"
    "        this.setNodeAttribute = function(attr) {\n"
    "        }\n"
    "        this.getNodeText = function() {\n"
    "            if (this.lastNodeText)\n"
    "                return this.lastNodeText;\n"
    "            else\n"
    "                return '';\n"
    "        }\n"
    "        this.getNodeType = function() {\n"
    "            return this.lastNodeType;\n"
    "        }\n"
    "        this.getNodeName = function() {\n"
    "            return this.lastNodeName;\n"
    "        }\n"
    "        this.getDataset = function() {\n"
    "            return window[this.xpath.substring(0,this.xpath.indexOf(':'))];\n"
    "        }\n"
    "        this.getNodeAttribute = function(attr) {\n"
    "            if (this.lastNode)\n"
    "                return this.lastNode.getAttribute(attr);\n"
    "            else\n"
    "                return undefined;\n"
    "        }\n"
    "        this.selectNext = function() {\n"
    "            // Node aktualisieren in dem ich eins weiter wandere\n"
    "            if (this.lastNode)\n"
    "                this.lastNode = this.lastNode.nextSibling;\n"
    "            else\n"
    "                this.lastNode = null;\n"
    "            if (this.lastNode != null)\n"
    "            {\n"
    "                this.lastNodeText = this.lastNode.firstChild.nodeValue;\n"
    "                this.lastNodeName = this.lastNode.nodeName;\n"
    "                this.lastNodeType = this.lastNode.nodeType;\n"
    "\n"
    "                // Auch XPath aktualisieren:\n"
    "                this.xpath = this.datasetName + ':' + this.getElementsXPath(this.lastNode);\n"
    "                //alert(this.datasetName + ':' + this.getElementsXPath(this.lastNode) + '\\n'+ this.xpath);\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                // this.lastNodeText = ''; // <-- auskommentiert\n"
    "                // this.lastNodeName = ''; // bricht sonst Beispiel 12 bei <datapointer>\n"
    "            }\n"
    "            return this.lastNode != null;\n"
    "        }\n"
    "        this.getNodeCount = function() {\n"
    "            return this.lastQueryChildrenCounter;\n"
    "        }\n"
    "        this.getNodeOffset = function() {\n"
    "            if (this.lastQueryNumberOfNodesPointingTo == 0)\n"
    "                return undefined;\n"
    "            else\n"
    "                return this.lastQueryNumberOfNodesPointingTo;\n"
    "        }\n"
    "        this.getXPathIndex = function() {\n"
    "            return this.lastQueryNumberOfNodesPointingTo;\n"
    "        }\n"
    "        // Return a new datapointer that points to the same node, has a null xpath and a false rerunxpath attribute\n"
    "        this.dupePointer = function() {\n"
    "            var dupe = new lz.datapointer(this.xpath,false);\n"
    "            dupe.lastNode = this.lastNode;\n"
    "            dupe.lastNodeText = this.lastNodeText;\n"
    "            dupe.lastNodeName = this.lastNodeName;\n"
    "            dupe.lastNodeType = this.lastNodeType;\n"
    "            dupe.xpath = null;\n"
    "            return dupe;\n"
    "        }\n"
    "        this.serialize = function() {\n"
    "            if (this.xml && this.xml.xml) { // IE 6 - IE 8\n"
    "                return this.xml.xml;\n"
    "            } else { // W3C (Mozilla Firefox, Safari) or IE 9 (standard mode)\n"
    "                return (new XMLSerializer()).serializeToString(this.xml);\n"
    "            }\n"
    "        }\n"
    "        this.selectChild = function() {\n"
    "            // Node aktualisieren in dem ich eins tiefer wandere\n"
    "            if (this.lastNode)\n"
    "                this.lastNode = this.lastNode.firstChild;\n"
    "            else\n"
    "                this.lastNode = null;\n"
    "            if (this.lastNode != null)\n"
    "            {\n"
    "                this.lastNodeText = this.lastNode.firstChild.nodeValue;\n"
    "                this.lastNodeName = this.lastNode.nodeName;\n"
    "                this.lastNodeType = this.lastNode.nodeType;\n"
    "\n"
    "                // Auch XPath aktualisieren:\n"
    "                this.xpath = this.xpath + '/' + this.lastNodeName + '[1]';\n"
    "            }\n"
    "            return this.lastNode != null;\n"
    "        }\n"
    "        this.deleteNode = function() {\n"
    "            if (this.lastNode)\n"
    "            {\n"
    "                // Zwischenspeichern\n"
    "                var toDelete = this.lastNode;\n"
    "                // Auf Grundlage der zu löschenden Node eins vor\n"
    "                // selectNext() aktualisiert gleichzeitig auch die internen Variablen\n"
    "                var result = this.selectNext();\n"
    "                // Jetzt kann ich die Node löschen\n"
    "                toDelete.parentNode.removeChild(toDelete);\n"
    "\n"
    "                // selectNext() aktualisiert gleichzeitig auch die internen Variablen\n"
    "                if (result)\n"
    "                    return this.lastNode;\n"
    "                else\n"
    "                    return null;\n"
    "            }\n"
    "            return undefined;\n"
    "        }\n"
    "        this.addNodeFromPointer = function(pointer) {\n"
    "            if (this.lastNode === undefined) // Dringend ToDo\n"
    "                return; //throw new TypeError('function datapointer.addNodeFromPointer - this.lastNode should not be undefined. Can not add Pointer to an undefined datapointer.');\n"
    "            if (pointer === undefined)\n"
    "                throw new TypeError('function datapointer.addNodeFromPointer - pointer should not be undefined. Can not add an undefined Pointer.');\n"
    "\n"
    "            // alert(pointer.serialize());\n"
    "            if (pointer && pointer.lastNode) {\n"
    "\n"
    "                var newNode = pointer.lastNode.cloneNode(true);\n"
    "                // alert((new XMLSerializer()).serializeToString(newNode));\n"
    "\n"
    "                this.lastNode.appendChild(newNode);\n"
    "\n"
    "                return newNode;\n"
    "            }\n"
    "            return undefined;\n"
    "        }\n"
    "        this.p = {\n"
    "            appendChild : function() {}\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.view = function(scope,attributes) {\n"
    "        return createObjectFromScript('view',scope,attributes);\n"
    "    }\n"
    "    this.button = function(scope,attributes) {\n"
    "        return createObjectFromScript('button',scope,attributes);\n"
    "    }\n"
    "    this.text = function(scope,attributes) {\n"
    "        return createObjectFromScript('text',scope,attributes);\n"
    "    }\n"
    "\n"
    "    // Warum auch immer, hängt gemäß OL formatToString direkt im prototype...\n"
    "    this.text.prototype.formatToString = function() { return sprintf.apply(null, arguments); }\n"
    "}\n"
    "var lz = new lz_MetaClass();\n"
    "// lz.Focus is the single instance of the class lz.FocusService\n"
    "lz.Focus = new lz.FocusService();\n"
    "// lz.Cursor is the single instance of the class lz.CursorService\n"
    "lz.Cursor = new lz.CursorService();\n"
    "// lz.Timer is the single instance of the class lz.TimerService\n"
    "lz.Timer = new lz.TimerService();\n"
    "// lz.Audio is the single instance of the class lz.AudioService.\n"
    "lz.Audio = new lz.AudioService();\n"
    "// lz.Browser is the single instance of the class lz.BrowserService.\n"
    "lz.Browser = new lz.BrowserService();\n"
    "// lz.History is the single instance of the class lz.HistoryService.\n"
    "lz.History = new lz.HistoryService();\n"
    "\n"
    "// Viele Objekte können auch mit vorangestellten Lz aufgerufen werden\n"
    "LzBrowser = lz.Browser;\n"
    "LzEvent = lz.event;\n"
    "LzFormatter = lz.Formatter;\n"
    "LzView = lz.view;\n"
    "LzText = lz.text;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// LzDelegate scheint es zu ermöglichen eine Methode an einen scope zu binden...\n"
    "// ...und dann über register auf ein event zu horchen.\n"
    "/////////////////////////////////////////////////////////\n"
    //"LzDelegate = function(scope,method) { var fn = window[method]; return fn.bind(scope); }\n"
    // Beispiel 2.3 in Chapter 27 klappt nur so:
    "LzDelegate = function(scope,method) {\n"
    "    var fn = scope[method];\n"
    "    var boundFn = fn.bind(scope)\n"
    "\n"
    "    // Durch das binden geht die Funktion register sonst verloren\n"
    "    // Deswegen erst nach dem binden anfügen\n"
    "    boundFn.register = function(v,ev) {\n"
    "        $(v).on(ev, this);\n"
    "    }\n"
    "\n"
    "    return boundFn;\n"
    "}\n"
    "\n"
    "\n"
    "document.exitpage = {}; // <-- Taucht in general.js in 'setid' auf\n"
    "document.exitpage.request = {}; // <-- Taucht in general.js in 'setid' auf\n"
    "\n"
    "function LzContextMenu() { }\n"
    "\n"
    "\n"
    "\n"
    "\n"
    //"// var canvas = new Object();\n"
    //"// statt dessen besser:\n"
    //"function canvasKlasse() {\n}\nvar canvas = new canvasKlasse();\n"
    "var SonstigeAusgaben = null; //function() {}; //ToDo <-- id von BDSinputgrid, welches noch nicht ausgewertet wird, deswegen muss ich die Var noch manuell bekannt machen\n"
    "\n"
    "var LzDataElement = {} // ToDo;\n"
    "LzDataElement.stringToLzData = function() {};\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Opposite of jQuerys param() - um Cookies auf ein Objekt zu mappen\n"
    "/////////////////////////////////////////////////////////\n"
    "function stringToObject(query) {\n"
    "    if (query == '') return {}; // Leeres Objekt zurückliefern, nicht null, sonst Absturz bei IE bei lokalen Seiten, da dort kein Cookie vorhanden.\n"
    "    var hash = {};\n"
    "    var vars = query.split('&');\n"
    "    for (var i = 0; i < vars.length; i++) {\n"
    "        var pair = vars[i].split('=');\n"
    "        var k = decodeURIComponent(pair[0]);\n"
    "        var v = decodeURIComponent(pair[1]);\n"
    "        // If it is the first entry with this name\n"
    "        if (typeof hash[k] === 'undefined') {\n"
    "            if (k.substr(k.length-2) != '[]')  // not end with []. cannot use negative index as IE doesn't understand it\n"
    "                hash[k] = v;\n"
    "            else\n"
    "                hash[k] = [v];\n"
    "            // If subsequent entry with this name and not array\n"
    "        } else if (typeof hash[k] === 'string') {\n"
    "            hash[k] = v;  // replace it\n"
    "            // If subsequent entry with this name and is array\n"
    "        } else {\n"
    "            hash[k].push(v);\n"
    "        }\n"
    "    }\n"
    "    return hash;\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Simulation der Flash-Cookies über Browser-Cookies\n"
    "/////////////////////////////////////////////////////////\n"
    "// So heißt das Flash-Cookie-Zugriffs-Objekt\n"
    "var SharedObject = {}\n"
    "// Liefert einen Cookie-Context zurück, in welchem die tatsächlichen Cookies stecken\n"
    "// Meist gibt es nur einen Context je Applikation, muss aber nicht.\n"
    "SharedObject.getLocal = function(name, path) {\n"
    "    var SharedObjectInstance = function() {\n"
    "        /* In dem Data-Objekt stecken die Werte */\n"
    "        this.data = {}\n"
    "        /* Das Cookie tatsächlich im Browser speichern */\n"
    "        this.flush = function() {\n"
    "            // Das Objekt als String serialisieren\n"
    "            var serializedObject = jQuery.param(this.data)\n"
    "\n"
    "            var expires = new Date();\n"
    "            expires.setTime(expires.getTime() + 1000*60*60*24*365*2); // 2 years\n"
    "            document.cookie = serializedObject + ';expires=' + expires.toUTCString();\n"
    "            \n"
    "        }\n"
    "    };\n"
    "\n"
    "\n"
    "    if (name === undefined && path === undefined)\n"
    "        throw new TypeError('function SharedObject.getLocal - I need a context');\n"
    "    if (path === undefined)\n"
    "        path = '';\n"
    "    // '__cookie__' davor, um nicht ausversehen, auf irgendeine globale Variable zu testen\n"
    "    var context = '__cookie__'+name+path;\n"
    "\n"
    "    // Wenn es die instanz noch nicht gibt, dann anlegen\n"
    "    if (!window[context])\n"
    "    {\n"
    "        var cookiedaten = document.cookie;\n"
    "        // Cookie-Einträge sind wohl durch ';' getrennt, für 'stringToObject müssen es jedoch '&' sein\n"
    "        cookiedaten = cookiedaten.replace(/;/,'&');\n"
    "        window[context] = new SharedObjectInstance();\n"
    "        // Cookie auslesen und auf das Objekt mappen\n"
    "        \n"
    "        window[context].data = stringToObject(cookiedaten);\n"
    "    }\n"
    "\n"
    "    // context zurückgeben\n"
    "    return window[context];\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Debug-Objekt, welches unter Umständen angesprochen wird\n"
    "/////////////////////////////////////////////////////////\n"
    "Debug = {};\n"
    "Debug.debug = function(s,v) {\n"
    "    // Damit Example 5 von lz.Formatter kompiliert (jedoch ohne zu klappen):\n"
    "    s = s.replace(' %w',' %s');\n"
    "    s = s.replace(' %#w',' %s');\n"
    //"    s = s.replace('%s',v);\n"
    //"    s = s.replace('%w',v);\n"
    "    s = s + '<br />'\n"
    "    if ($('#debugInnerWindow').length)\n"
    "        $('#debugInnerWindow').append(sprintf(s, v))\n"
    "    //alert(s)\n"
    "};\n"
    "Debug.write = function(s1,v) {\n"
    "    if (v === undefined)\n"
    "        v = '';\n"
    "\n"
    "    var s = s1 + ' ' + v;\n"
    "    if ($('#debugInnerWindow').length)\n"
    "        $('#debugInnerWindow').append(s + '<br />')\n"
    "    else\n"
    "        console.log(s)\n"
    "    //alert(s)\n"
    "};\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Zentriere Anzeige beim öffnen der Seite             //\n"
    "/////////////////////////////////////////////////////////\n"
    "$(function()\n"
    "{\n"
    "    adjustOffsetOnBrowserResize();\n"
    "});\n"
    "\n"
    "function adjustOffsetOnBrowserResize()\n"
    "{\n"
    "    if ($('#element1').width() == '1000')\n" // ToDo - Als Option anbieten ob Fullscrenn
    "    {\n"
    "        // var widthDesErstenKindes = parseInt($('div:first').children(':first').css('width'));\n"
    "        var unsereWidth = parseInt($('div:first').css('width'));\n"
    "        var left;\n"
    "        if ((($(window).width())-unsereWidth)/2 > 0)\n"
    "            left = (($(window).width())-unsereWidth)/2;\n"
    "        else\n"
    "            left = 0;\n"
    "        $('div:first').css('left', left +'px');\n"
    "    }\n"
    "}\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Zentriere Anzeige beim resizen der Seite            //\n"
    "// + aktualisiere Canvas                               //\n"
    "/////////////////////////////////////////////////////////\n"
    "$(window).resize(function()\n"
    "{\n"
    "    if (canvas) // falls DOM schon initialisiert\n"
    "      canvas.myHeight = $(window).height();\n"
    "\n"
    "    adjustOffsetOnBrowserResize();\n"
    "});\n"
    "\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// Ersetzt das intern verwendete parent                 //\n"
    "//////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'getTheParent', {\n"
    "enumerable: false, // Darf nicht auf 'true' gesetzt werden! Sonst bricht jQuery!\n"
    "configurable: true,\n"
    "writable: false,\n"
    "value: function(immediate) {\n"
    //"value: function(reference) {\n"
    //"    if ($(this).get(0).nodeName === undefined && (typeof reference === 'undefined'))\n"
    //"        throw \"getTheParent() von 'DOMWindow' aus aufgerufen und kein Argument übergeben. Dies ist Unsinn: DOMWindow hat keinen parent + Argument, von dem einer ermittelt werden könnte, ist nicht vorhanden.\";\n"
    //"\n"
    //"    if ($(this).get(0).nodeName === undefined) /*sprich: this=DOMWindow*/\n"
    //"    {\n"
    //"        var p = $(reference).parent();\n"
    //"        if ($(reference).is('input') || $(reference).is('select'))\n"
    //"        {\n"
    //"            // input's und select's haben ein umgebendes id-loses div. Das müssen wir überspringen.\n"
    //"            p = p.parent();\n"
    //"        }\n"
    //"        if ($(p).hasClass('div_rudPanel') || $(p).hasClass('div_windowContent'))\n"
    //"        {\n"
    //"            // Das Rud-Element/Window-Element hat ein Zwischen-Element, da muss ich dann eine Ebene höher springen.\n"
    //"            p = p.parent();\n"
    //"        }\n"
    //"        return p.get(0);\n"
    //"    }\n"
    //"    else\n"
    //"    {\n"
    "    if(typeof(immediate) === 'undefined')\n"
    "        immediate = false;\n"
    "\n"
    "    // Wenn wir immediate sind, dann verzichten wir auf die Doppelsprünge!\n"
    "    // Vergleiche mit Beispiel 2 von <window>, dort der <button> z. B.\n"
    "\n"
    "    var p = $(this).parent();\n"
    "    if (!immediate && ($(this).is('input') || $(this).is('select')))\n"
    "    {\n"
    "        // input's und select's haben ein umgebendes id-loses div. Das müssen wir überspringen.\n"
    "        p = p.parent();\n"
    "    }\n"
    "    if (!immediate && ($(p).hasClass('div_rudPanel') || $(p).hasClass('div_windowContent')))\n"
    "    {\n"
    "        // Das Rud-Element/Window-Element hat ein Zwischen-Element, da muss ich dann eine Ebene höher springen.\n"
    "        p = p.parent();\n"
    "    }\n"
    "\n"
    "    return p.get(0);\n"
    //"    }\n"
    "}\n"
    "});\n"
    "\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// Eigene setAttribute-Methode für ALLE Objekte (JS+DOM)//\n"
    "//////////////////////////////////////////////////////////\n"
    "// Diese Funktion werde ich gleich 3 mal prototypen müssen um setAttribute in allen Browsern zu überschreiben\n"
    "// Neu: Leider bricht setAttribute jQuery.attr(), ein Zurückbehalten auf das originale setAttribute hat wirklich nicht geklapopt \n"
    "// Deswegen arbeite ich nun mit setAttribute_ und replacement dieser Funktionen im OL-Code \n"
    "var setAttributeFunc = function (attributeName, value) {\n"
    "    function setWidthAndHeightAndBackgroundImage(me, imgpath) {\n"
    "            // Get programmatically 'width' and 'height' of the image\n"
    "            var img = new Image();\n"
    "            img.src = imgpath;\n"
    "            // Nur wenn noch keine explizite Breite gesetzt wurde, dann Element so Breit machen, wie das Bild ist\n"
    "            if ($(me).get(0).style.width == '')\n"
    "                $(me).width(img.width);\n"
    "            // Nur wenn noch keine explizite Höhe gesetzt wurde, dann Element so hoch machen, wie das Bild ist\n"
    "            if ($(me).get(0).style.height == '')\n"
    "                $(me).height(img.height);\n"
    "\n"
    "            $(me).css('background-image','url('+imgpath+')');\n"
    "    }\n"
    "\n"
    "    function preload(arrayOfImages) {\n"
    "        $(arrayOfImages).each(function(){\n"
    "            $('<img/>')[0].src = this;\n"
    "            // Alternatively you could use:\n"
    "            // (new Image()).src = this;\n"
    "        });\n"
    "    }\n"
    "\n"
    "    if (attributeName == undefined || attributeName == '')\n"
    "        throw 'Error1 calling setAttribute, no argument attributeName given (this = '+this+').';\n"
    "    if (value == undefined)\n"
    "        throw 'Error2 calling setAttribute, no argument value given or undefined (attributeName = \"'+attributeName+'\" and this = '+this+').';\n"
    "\n"
    // Kann auch im Skript aufgetaucht sein und dort geändert worden sein, z. B. Beispiel 28.16
    // Hier richtig setzen, nicht unten reagieren, damit der getriggerte Handler der richtige ist.
    "    if (attributeName === 'myWidth') \n"
    "        attributeName = 'width';\n"
    "    if (attributeName === 'myHeight') \n"
    "        attributeName = 'height';\n"
    "\n"
    "\n"
    "\n"
    "\n"
    //"    var me = globalMe;\n"
    "    var me = this;\n"
    //"    if (this.nodeName == 'DIV' || this.nodeName == 'INPUT' || this.nodeName == 'SELECT')\n"
    //"      me = this; // Wir wurden aus einem Kontext heraus aufgerufen x.setAttribute() - Und nicht aus DOMWindow\n"
    "\n"
    "    if (attributeName == 'text')\n"
    "    {\n"
    "      if ($(me).children().length > 0 && $(me).children().get(0).nodeName == 'INPUT')\n"
    "          $(me).children().attr('value',value);\n"
    "      else if ($(me).get(0).nodeName == 'INPUT')\n"
    "          $(me).attr('value',value);\n"
    "      else\n"
    "          $(me).html(value);\n"
    "    }\n"
    "    else if (attributeName == 'font')\n"
    "    {\n"
    "        // ToDo\n"
    "    }\n"
    "    else if (attributeName == 'bgcolor')\n"
    "    {\n"
    "        if (typeof value === 'number')\n"
    "        {\n"
    "            value = value.toString(16);\n"
    "            while (value.length < 6) value = '0' + value;\n"
    "            value = '#' + value;\n"
    "        }\n"
    "        if (typeof value === 'string' && value.startsWith('0x'))\n"
    "        {\n"
    "            value = '#' + value.substr(2);\n"
    "        }\n"
    "        if (typeof value === 'string' && !value.startsWith('#') && value.length > 6)\n"
    "        {\n"
    "            value = '#' + Number(value).toString(16);\n"
    "            while (value.length > 6)\n"
    "                value = value.substr(1);\n"
    "            value = '#' + value;\n"
    "        }\n"
    "        $(me).css('background-color',value);\n"
    "    }\n"
    "    else if (attributeName == 'x')\n"
    "    {\n"
    "        // jQuery doesn't like plain strings containing a number\n"
    "        if (typeof value === 'string' && !value.endsWith('px') && !value.endsWith('%'))\n"
    "            value = value + 'px';\n"
    "\n"
    "        $(me).css('left',value);\n"
    "    }\n"
    "    else if (attributeName == 'y')\n"
    "    {\n"
    "        // jQuery doesn't like plain strings containing a number\n"
    "        if (typeof value === 'string' && !value.endsWith('px') && !value.endsWith('%'))\n"
    "            value = value + 'px';\n"
    "\n"
    "        $(me).css('top',value);\n"
    "    }\n"
    "    else if (attributeName == 'width')\n"
    "    {\n"
    "        // jQuery doesn't like plain strings containing a number\n"
    "        if (typeof value === 'string' && !value.endsWith('px') && !value.endsWith('%'))\n"
    "            value = value + 'px';\n"
    "\n"
    "        $(me).css('width',value);\n"
    //"        // Zusätzlich den setter setzen, falls die Variable gewatcht wird!\n"
    //"        $(me).get(0).myWidth = value;\n"
    "    }\n"
    "    else if (attributeName == 'height')\n"
    "    {\n"
    "        // jQuery doesn't like plain strings containing a number\n"
    "        if (typeof value === 'string' && !value.endsWith('px') && !value.endsWith('%'))\n"
    "            value = value + 'px';\n"
    "\n"
    "        $(me).css('height',value);\n"
    //"        // Zusätzlich den setter setzen, falls die Variable gewatcht wird!\n"
    //"        $(me).get(0).myHeight = value;\n"
    "    }\n"
    "    else if (attributeName == 'clickable')\n"
    "    {\n"
    "        if (value == 'true')\n"
    "        {\n"
    "            // Pointer-Events zulassen\n"
    "            $(me).css('pointer-events','auto');\n"
    "        }\n"
    "        else\n"
    "            alert('So far unsupported value for clickable. value: '+value);\n"
    "    }\n"
    "    else if (attributeName == 'focustrap')\n"
    "    {\n"
    "        // ToDo When 'true' dann wird der Focus-Bereich z. B. auf ein bestimmtes Fenster beschränkt\n"
    "    }\n"
    "    else if (attributeName == 'doesenter')\n"
    "    {\n"
    "        // if set to true, the component manager will call this component with doEnterDown\n"
    "        // and doEnterUp when the enter key goes up or down if it is focussed\n"
    "    }\n"
    "    else if (attributeName === 'initstage' && value === 'defer')\n"
    "    {\n"
    "      //$(me).hide() // ToDo: Bricht Anzeige Kinder;\n"
    "    }\n"
    "    else if (attributeName == 'align')\n"
    "    {\n"
    "        if (value === 'center')\n"
    "            this.align = value; // hmmm, Zugriff auf die Original-JS-Propertys erstmal \n"
    "        else if (value === 'right')\n"
    "            $(me).css('left',$(me).parent().width()-$(me).width());\n"
    "        else\n"
    "            alert('So far unsupported value for align. value: '+value);\n"
    "    }\n"
    "    else if (attributeName == 'opacity')\n"
    "    {\n"
    "        $(me).css('opacity',value);\n"
    "    }\n"
    "    else if (attributeName == 'visible')\n"
    "    {\n"
    "        if (value == true || value == 'true')\n"
    "            $(me).show();\n"
    "        else if (value == false || value == 'false')\n"
    "            $(me).hide();\n"
    "        else\n"
    "            alert('So far unsupported value for visible. value: '+value);\n"
    "    }\n"
    "    else if (attributeName == 'frame')\n"
    "    {\n"
    "        // frames sind 1-basiert\n"
    // Sonst klappt Beispiel 8.8 nicht
    "        value--;\n"
    "\n"
    "        if ($.isArray(me.resource))\n"
    "          $(me).css('background-image','url('+me.resource[value]+')');\n"
    "        else\n"
    "          throw 'setAttribute_ - Error trying to set frame. (value = '+value+', me.resource = '+me.resource+', me.id = '+me.id+').';\n"
    "    }\n"
    "    else if (attributeName == 'background-image')\n"
    "    {\n"
    "        $(me).css('background-image','url('+value+')');\n"
    "    }\n"
    "    else if (attributeName == 'stretches')\n"
    "    {\n"
    "        // Get programmatically 'width' and 'height' of the image\n"
    "        var imgpath = $(me).css('background-image');\n"
    "        if (imgpath.startsWith('url(\"')) /* Firefox... */\n"
    "            imgpath = imgpath.substring(5,imgpath.length-2);\n"
    "        if (imgpath.startsWith('url('))\n"
    "            imgpath = imgpath.substring(4,imgpath.length-1);\n"
    "        var img = new Image();\n"
    "        img.src = imgpath;\n"
    "\n"
    "        if (value == 'both')\n"
    "            $(me).css('background-size','100% 100%');\n"
    "        else if (value == 'width')\n"
    "            $(me).css('background-size','100% '+img.height+'px');\n"
    "        else if (value == 'height')\n"
    "            $(me).css('background-size',img.width+'px 100%');\n"
    "        else if (value == 'none')\n"
    "            $(me).css('background-size','auto');\n"
    "        else\n"
    "            alert('unsupported value for stretches. value: '+value);\n"
    "    }\n"
    "    else if (attributeName == 'enabled' && $(me).is('input'))\n"
    "    {\n"
    "        $(me).get(0).disabled = !value;\n"
    "\n"
    "      // Auch die Textfarbe des zugehörigen Textes anpassen\n"
    "      if ($(me).attr('type') === 'checkbox' && $(me).next().is('span') && $(me).next().css('color') == 'rgb(0, 0, 0)' && value == false)\n"
    "          $(me).next().css('color','darkgrey');\n"
    "      if ($(me).attr('type') === 'checkbox' && $(me).next().is('span') && $(me).next().css('color') == 'rgb(169, 169, 169)' && value == true)\n"
    "          $(me).next().css('color','black');\n"
    "    }\n"
    "    else if (attributeName == 'resource')\n"
    "    {\n"
    "        // In jedem Falle speichern. Var kann auch ausgelesen werden\n"
    "        me.resource = value;\n"
    "\n"
    "        // Die res kann sowohl als String, als auch als JS-Var übergeben werden. Beides wird erkannt\n"
    "        if ($.isArray(window[value]) || $.isArray(value))\n"
    "        {\n"
    "            var arr = [];\n"
    "            if ($.isArray(window[value]))\n"
    "                arr = window[value];\n"
    "            else\n"
    "                arr = value;\n"
    "            // Damit es nicht flackert bei mouseover und Klick:\n"
    "            preload(arr);\n"
    "\n"
    "            // Falls ein setAttribute_('frame','#'); hinterher kommt:\n"
    "            me.resource = arr;\n"
    "\n"
    "            var imgpath0 = arr[0];\n"
    "            var imgpath1 = arr[1];\n"
    "            var imgpath2 = arr[2];\n"
    "\n"
    "            setWidthAndHeightAndBackgroundImage(me,imgpath0)\n"
    "\n"
    // touchstart = mousedown
    // touchend = mouseup
    // (touchmove = mousemove)
    "            if (imgpath1 != undefined && imgpath2 != undefined)\n"
    "            {\n"
    "                // hover löst regelmäßig auch aus, wenn man kurz antoucht. Aber kann man wohl so lassen\n"
    "                $(me).hover(function() { $(me).css('background-image','url('+imgpath1+')') }, function() { $(me).css('background-image','url('+imgpath0+')') });\n"
    "                if ('ontouchstart' in document.documentElement)\n"
    "                {\n"
    "                    $(me).on('touchstart',function() { $(me).css('background-image','url('+imgpath2+')') });\n"
    "                    $(me).on('touchend',function() { $(me).css('background-image','url('+imgpath0+')') });\n"
    "                }\n"
    "                else\n"
    "                {\n"
    "                    $(me).on('mousedown',function() { $(me).css('background-image','url('+imgpath2+')') });\n"
    "                    $(me).on('mouseup',function() { $(me).css('background-image','url('+imgpath0+')') });\n"
    "                }\n"
    "            }\n"

    "        }\n"
    "        else\n"
    "        {\n"
    "            if (typeof value === 'string' && value.contains('.'))\n"
    "              setWidthAndHeightAndBackgroundImage(me,value);\n"
    "            else if (typeof value === 'string' && value != '')\n"
    "              setWidthAndHeightAndBackgroundImage(me,window[value]);\n"
    "            else\n"
    "              throw 'setAttribute_ - Error trying to set reource. (value = '+value+', me.id = '+me.id+').';\n"
    "        }\n"
    "    }\n"
    "    else if ($(me).hasClass('select_standard') && attributeName == 'editable') // Nur vom Element 'basecombobox' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // Not supported so far. The items of the select-box are never editable\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'thickness' || attributeName == 'sharpness')) // Nur vom Element 'text' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // Flash-Only Attributes, that will be ignored\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'resize')) // Nur vom Element 'text' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // In jedem Falle speichern. Es wird von addText()/setText() berücksichtigt.\n"
    "        me.resize = value;\n"
    "\n"
    "        if (value === false)\n"
    "        {\n"
    "            // Setting the width with myself, because resize=false, so I won't resize accidently\n"
    "            $(me).width($(me).width());\n"
    "        \n"
    "        }\n"
    "        if (value === true)\n"
    "        {\n"
    "            $(me).css('height','auto');\n"
    "        \n"
    "        }\n"
    "    }\n"
    "    else if ($(me).hasClass('iframe_standard') && attributeName == 'src') // Nur vom Element 'html' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // src-Attribut des iframe setzen\n"
    "        $(me).html('<iframe style=\"width:inherit;height:inherit;\" src=\"'+value+'\"></iframe>');\n"
    "    }\n"
    "    else if ($(me).hasClass('div_window') && attributeName == 'title') // Nur vom Element 'window' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        $(me).children('.div_windowTitle').html(value);\n"
    "    }\n"
    "    else if ($(me).hasClass('div_window') && attributeName == 'resizable') // Nur vom Element 'window' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        if (value == 'true')\n"
    "        {\n"
    "            $(me).resizable();\n"
    "\n"
    "            $(me).on('resize', function(event,ui) {\n"
    "                $('#'+this.id+'_content').get(0).setAttribute_('width',ui.size.width /* -10 */);\n"
    "                $('#'+this.id+'_content').get(0).setAttribute_('height',ui.size.height-20);\n"
    "                $(this).triggerHandler('onwidth',ui.size.width);\n"
    "                $(this).triggerHandler('onheight',ui.size.height);\n"
    "            });\n"
    "\n"
    "            $(me).on('resizestop', function(event,ui) {\n"
    "                $('#'+this.id+'_content').get(0).setAttribute_('width',ui.size.width /* -10 */);\n"
    "                $('#'+this.id+'_content').get(0).setAttribute_('height',ui.size.height-20);\n"
    "                $(this).triggerHandler('onwidth',ui.size.width);\n"
    "                $(this).triggerHandler('onheight',ui.size.height);\n"
    "            });\n"
    "        }\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "      // Wenn es vorher nicht matcht, dann einfach die Property setzen, dann ist es eine selbst definierte Variable\n"
    "      // Aber erstmal noch sammeln der Vars, die gesetzt werden sollen. Später lockern\n"
    "      // Vorher aber Test ob die Property auch vorher definiert wurde! Sonst läuft wohl etwas schief\n"
    "      if (attributeName === 'zusammenveranlagung' ||\n"
    "          attributeName === 'titlewidth' ||\n"
    "          attributeName === 'spacing' ||\n"
    "          attributeName === 'controlwidth' ||\n"
    "          attributeName === 'inset_y' ||\n"
    "          attributeName === 'focused' ||\n"
    "          attributeName === 'isopen' ||\n"
    "          attributeName === 'parentnumber' ||\n"
    "          attributeName === 'index' ||\n"
    "          attributeName === 'avalue')\n"
    "      {\n"
    "         if (this[attributeName] !== undefined)\n"
    "             this[attributeName] = value;\n"
    "         else\n"
    "             alert('Trying to set a property that never was declared!');\n"
    "      }\n"
    "      else\n"
    "      {\n"
    "          alert('Aufruf von setAttribute, der noch ausgewertet werden muss.\\n\\nattributeName: ' + attributeName + '\\n\\nvalue: '+ value);\n"
    "      }\n"
    "    }\n"
    "\n"
    "    // In jedem Fall: triggern! Das sieht OL so vor\n"
    "    // Kein bubblen, sondern Point-2-Point-Logik in OL, deswegen triggerHandler\n"
    "    // der getzte Wert (value) wird als Extra-Parameter mit gesendet\n"
    "    $(me).triggerHandler('on'+attributeName,value);\n"
    "}\n"
    "\n"
    "// Object.prototype ist verboten und bricht jQuery und z.B. JS .split()! Deswegen über defineProperty\n"
    "// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Object/defineProperty\n"
    "// Für alle JS-Objekte (insbesondere window => direkter Aufruf von setAttribute => Dann\n"
    "// auch Zusammenspiel mit globalMe (s.u))\n"
    "Object.defineProperty(Object.prototype, 'setAttribute_', {\n"
    "    enumerable: false, // Darf nicht auf 'true' gesetzt werden! Sonst bricht jQuery!\n"
    "    configurable: true,\n"
    "    writable: false,\n"
    "    value: setAttributeFunc\n"
    "});\n"
    "\n"
    "// Für alle DOM-Objekte\n"
    "// Ohne enumerabe und configurable, sonst beschwert sich Safari\n"
    "// bricht leider jQuery.... deswegen auskommentiert. HTMLDivElement (s. u.) muss reichen.\n"
    "// Object.defineProperty(Element.prototype, 'setAttribute', {\n"
    "// value: setAttributeFunc\n"
    "// } );\n"
    "\n"
    "// Sonderbehandlung für Firefox:\n"
    "// https://developer.mozilla.org/en/JavaScript-DOM_Prototypes_in_Mozilla\n"
    "// Node klappt nicht...\n"
    "// Element klappt nicht...\n"
    "// HTMLElement klappt auch nicht...\n"
    "// Aber HTMLDivElement... wtf Firefox??\n"
    "// HTMLDivElement.prototype.setAttribute = setAttributeFunc; // <- Nicht mehr nötig seit setAttribute_\n"
    "// HTMLInputElement.prototype.setAttribute = setAttributeFunc; // <- Nicht mehr nötig seit setAttribute_\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// nur für DOM-Elemente machen die getter/setter Sinn  //\n"
    "// Zusätzlich verlässt sich createObjectFromScript auf diesen Test in den Gettern\n"
    "/////////////////////////////////////////////////////////\n"
    "function isDOM(o) {\n"
    "    return o.nodeName ? true : false;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <div> (OL: <node>)                     //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// destroy() - nachimplementiert                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "var destroyFunction = function () {\n"
    "    $(this).remove;\n"
    "    $(this).triggerHandler('ondestroy');\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.destroy = destroyFunction;\n"
    "HTMLInputElement.prototype.destroy = destroyFunction;\n"
    "HTMLSelectElement.prototype.destroy = destroyFunction;\n"
    "HTMLButtonElement.prototype.destroy = destroyFunction;\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// applyConstraintMethod() - nachimplementiert         //\n"
    "/////////////////////////////////////////////////////////\n"
    "var applyConstraintMethodFunction = function (constraintMethod,dependencies) {\n"
    "    if (constraintMethod === undefined)\n"
    "        throw new Error('applyConstraintMethod() - First argument should not be undefined');\n"
    "    if (dependencies === undefined)\n"
    "        throw new Error('applyConstraintMethod() - Second argument should not be undefined');\n"
    "    if (typeof constraintMethod !== 'string')\n"
    "        throw new Error('applyConstraintMethod() - First argument should be a string');\n"
    "    if (typeof dependencies !== 'object' || !$.isArray(dependencies))\n"
    "        throw new Error('applyConstraintMethod() - Second argument should be an array');\n"
    "    if (dependencies.length.isOdd())\n"
    "        throw new Error('applyConstraintMethod() - Array length of Second argument should be an even number');\n"
    "\n"
    "    var tempDel = new LzDelegate(this, constraintMethod);\n"
    "\n"
    "    for (var i=0;i<dependencies.length;i++)\n"
    "    {\n"
    "        if (i.isEven())\n"
    "        {\n"
    "            tempDel.register(dependencies[i], 'on'+dependencies[i+1]);\n"
    "        }\n"
    "    }\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.applyConstraintMethod = applyConstraintMethodFunction;\n"
    "HTMLInputElement.prototype.applyConstraintMethod = applyConstraintMethodFunction;\n"
    "HTMLSelectElement.prototype.applyConstraintMethod = applyConstraintMethodFunction;\n"
    "HTMLButtonElement.prototype.applyConstraintMethod = applyConstraintMethodFunction;\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <div> (OL: <view>)                     //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// sendToBack() - nachimplementiert                    //\n"
    "/////////////////////////////////////////////////////////\n"
    "var sendToBackFunction = function (oThis) {\n"
    "    $(this).css('z-index','-1');\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.sendToBack = sendToBackFunction;\n"
    "HTMLInputElement.prototype.sendToBack = sendToBackFunction;\n"
    "HTMLSelectElement.prototype.sendToBack = sendToBackFunction;\n"
    "HTMLButtonElement.prototype.sendToBack = sendToBackFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// bringToFront() - nachimplementiert                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "var bringToFrontFunction = function (oThis) {\n"
    "    $(this).css('zIndex',\n"
    "        Math.max.apply(null, $.map($('div:first').find('*'), function(e,i) { return e.style.zIndex; }))+1);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.bringToFront = bringToFrontFunction;\n"
    "HTMLInputElement.prototype.bringToFront = bringToFrontFunction;\n"
    "HTMLSelectElement.prototype.bringToFront = bringToFrontFunction;\n"
    "HTMLButtonElement.prototype.bringToFront = bringToFrontFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <div class=\"div_text\"> (OL: <text>)    //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Nur für class='div_text' sind diese Methoden gültig //\n"
    "/////////////////////////////////////////////////////////\n"
    "function warnOnWrongClass(me) {\n"
    "    if (!$(me).hasClass('div_text'))\n"
    "    {\n"
    "        alert('Wieso meinst du mich aufrufen zu können? Du bist doch gar kein \\'div_text\\'. Ernsthafte Frage!');\n"
    "        return true;\n"
    "    }\n"
    "    return false;\n"
    "}\n"
    "\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// addFormat() - nachimplementiert                      //\n"
    "//////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.addFormat = function() {\n"
    "    warnOnWrongClass(this);\n"
    "    $(this).append(sprintf.apply(null, arguments));\n"
    "    $(this).triggerHandler('ontext',sprintf.apply(null, arguments));\n"
    "}\n"
    "\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// addText() - nachimplementiert                        //\n"
    "//////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.addText = function(s) {\n"
    "    warnOnWrongClass(this);\n"
    "\n"
    "    if (s === undefined)\n"
    "        throw new Error('addText() - argument should not be undefined');\n"
    "    s = String(s); // Damit s.replace keinen Error wirft bei übergebenen numbers\n"
    "\n"
    "    s = s.replace(/\\n/,'<br />');\n"
    "    $(this).append(s);\n"
    "    $(this).triggerHandler('ontext',s);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// clearText() - nachimplementiert                     //\n"
    "/////////////////////////////////////////////////////////\n"
    "var clearTextFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    this.setAttribute_('text', '');\n"
    "}\n"
    "\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.clearText = clearTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// getText() - nachimplementiert - deprecated!         //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getTextFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    return $(this).html();\n"
    "}\n"
    "\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.getText = getTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// getTextHeight() - nachimplementiert                 //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getTextHeightFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    return $(this).outerHeight();\n"
    "}\n"
    "\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.getTextHeight = getTextHeightFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// getTextWidth() - nachimplementiert                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getTextWidthFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    return $(this).outerWidth();\n"
    "}\n"
    "\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.getTextWidth = getTextWidthFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// setText() - nachimplementiert - deprecated!         //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setTextFunction = function (s) {\n"
    "    warnOnWrongClass(this);\n"
    "\n"
    "    if (s === undefined)\n"
    "        throw new Error('setText() - argument should not be undefined');\n"
    "    s = String(s); // Damit s.replace keinen Error wirft bei übergebenen numbers\n"
    "\n"
    "    s = s.replace(/\\n/,'<br />');\n"
    "    this.setAttribute_('text', s);\n"
    "}\n"
    "\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.setText = setTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// format() - nachimplementiert                        //\n"
    "/////////////////////////////////////////////////////////\n"
    "var formatFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    $(this).html(sprintf.apply(null, arguments));\n"
    // "    alert(sprintf.apply(this, arguments));\n"
    "}\n"
    "\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.format = formatFunction;\n"
    "\n"
    "// Ziemlich seltsame Geschichte, aber formatToString hängt iwie auch bei <text> mit drin\n"
    "HTMLDivElement.prototype.formatToString = LzFormatter.prototype.formatToString;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <input type=\"text\"> (OL: <edittext>)   //\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////COMPLETE////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// getText() / getvalue() - nachimplementiert          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getTextFunction = function () {\n"
    "    return $(this).val();\n"
    "}\n"
    "\n"
    "// Nur für Input! Da es die Methode nur bei <input> gibt\n"
    "HTMLInputElement.prototype.getText = getTextFunction;\n"
    "// Gleiche Methode kann auch über getValue() angesprochen werden\n"
    "HTMLInputElement.prototype.getValue = getTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// clearText() - nachimplementiert                     //\n"
    "/////////////////////////////////////////////////////////\n"
    "var clearTextFunction = function () {\n"
    "    $(this).val('');\n"
    "}\n"
    "\n"
    "// Nur für Input! Da es die Methode nur bei <input> gibt\n"
    "HTMLInputElement.prototype.clearText = clearTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// setSelection() - nachimplementiert                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setSelectionFunction = function (start, end) {\n"
    "    $(this).prop('selectionStart',start);\n"
    "    $(this).prop('selectionEnd',end);\n"
    "    this.focus();\n"
    "}\n"
    "\n"
    "// Nur für Input! Da es die Methode nur bei <input> gibt\n"
    "HTMLInputElement.prototype.setSelection = setSelectionFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// updateText() - nachimplementiert                    //\n"
    "/////////////////////////////////////////////////////////\n"
    "var updateTextFunction = function () {\n"
    "    this.text = $(this).val();\n"
    "}\n"
    "\n"
    "// Nur für Input! Da es die Methode nur bei <input> gibt\n"
    "HTMLInputElement.prototype.updateText = updateTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <input type=\"checkbox\"> (OL: <checkbox>)//\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// cb ist der undokumentierte Zugriff auf das eigentliche Checkbox-Feld\n"
    "// Zugriff darauf wird derzeit nicht unterstützt\n"
    "HTMLInputElement.prototype.cb = { setAttribute_ : function(){} }\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <select> (OL: <basecombobox>)          //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "HTMLSelectElement.prototype.isopen = false;\n"
    "\n"
    "// cblist ist der undokumentierte Zugriff auf die <option>-Elemente der Liste\n"
    "// bzw. auf das Element da drum herum. Also auf uns selber?\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter for 'cblist'                                 //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLSelectElement.prototype, 'cblist', {\n"
    "    get : function(){ return this; /* $(this).find('select').get(0); */ },\n"
    "    /* READ-ONLY set : , */\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <select> (OL: <list>)                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////COMPLETE////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// addItem() - nachimplementiert                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "var addItemFunction = function (text, val) {\n"
    // Braucht man wohl gar nicht: (Option berücksichtigt wohl intern, wenn 2. Argument undefined
    //"    if (val === undefined) val = '';\n"
    "    $(this).append( new Option(text, val) );\n"
    "}\n"
    "\n"
    "// Nur für Select! Da es die Methode nur bei <select> gibt\n"
    "HTMLSelectElement.prototype.addItem = addItemFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// ensureItemInView() - nachimplementiert              //\n"
    "/////////////////////////////////////////////////////////\n"
    "var ensureItemInViewFunction = function (item) {\n"
    "    // Ungetestet. Evtl. ist item auch direkt das Element, dann Anzahl der vorherigen Geschwister ermitteln\n"
    "    return $(this).scrollTop(item*15);\n"
    "}\n"
    "\n"
    "// Nur für Select! Da es die Methode nur bei <select> gibt\n"
    "HTMLSelectElement.prototype.ensureItemInView = ensureItemInViewFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// select() - nachimplementiert                        //\n"
    "/////////////////////////////////////////////////////////\n"
    "var selectFunction = function (view) {\n"
    "    // Ungetestet:\n"
    "    $(view).attr('selected','selected');\n"
    "    this.ensureItemInViewFunction(view);\n"
    "}\n"
    "\n"
    "// Nur für Select! Da es die Methode nur bei <select> gibt\n"
    "HTMLSelectElement.prototype.select = selectFunction;\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter for 'mask' (setter only to trigger an event) //\n"
    "// mask seems to be the next clipped parent.           //\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "\n"
    "var findNextMaskedElement = function(e) {\n"
    "    return $(e).parents().filter(function() {\n"
    "        return $(this).css('clip').startsWith('rect');\n"
    "    });\n"
    "}\n"
    "// in '_mask' speichern wir einen eventuell gesetzten Wert...\n"
    "Object.defineProperty(Object.prototype, '_mask', {\n"
    "    enumerable: false,\n"
    "    configurable: false,\n"
    "    writable: true, /* setting to false would be ignored by webkit... why? */\n"
    "    value: undefined\n"
    "});\n"
    "// ... aber der Getter gibt stets den korrekt berechneten Wert zurück...\n"
    "// ... und der Setter triggert im wesentlichen nur 'onmask'. Ein übergebener Wert \n"
    "// wird trotzdem mal gespeichert. Aber er sollte nie über 'mask' accessible sein.\n"
    "Object.defineProperty(Object.prototype, 'mask', {\n"
    "    get : function(){ return findNextMaskedElement(this).get(0); },\n"
    "    set : function(newValue){ this._mask = 2; $(this).triggerHandler('onmask',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter for 'subviews'                               //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'subviews', {\n"
    "    get : function(){ return $(this).find('*').get(); },\n"
    "    /* READ-ONLY set : , */\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter for 'name'                                   //\n"
    "// initialize-only (READ-ONLY AFTER INIT)              //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'name', {\n"
    "    get : function(){ return $(this).data('name'); },\n"
    "    /* READ-ONLY set : , */\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'parent'                          //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'parent', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return this.getTheParent(); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'immediateparent'                 //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'immediateparent', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return this.getTheParent(true); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'y'                               //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'y', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('top')); },\n"
    "    set: function(newValue){ $(this).css('top', newValue); $(this).triggerHandler('ony', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'x'                               //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'x', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('left')); },\n"
    "    set: function(newValue){ $(this).css('left', newValue); $(this).triggerHandler('onx', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'bgcolor'                         //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'bgcolor', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('background-color')); },\n"
    "    set: function(newValue){ $(this).css('background-color', newValue); $(this).triggerHandler('onbgcolor', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'opacity'                         //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "//// Nicht Object prototypen. Sonst wird auch das 'style'-Objekt prototgetypet und damit\n"
    "//// dort die opacity-Property kaputt gemacht und damit bricht jQuery.\n"
    "//// Statt dessen an HTMLElement prototypen.\n"
    "//// Im Prinzip können dann alle Propertys hier im 'HTMLElement' definiert werden.\n"
    "//// Aber auch nicht 100 % perfekt, da dann ein DOM-Element extended wird. Es ist immer\n"
    "//// besser reine JS-Objekte zu extenden.\n"
    "Object.defineProperty(HTMLElement.prototype, 'opacity', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).css('opacity'); },\n"
    "    set: function(newValue){ this.setAttribute_('opacity', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'myHeight'                        //\n"
    "// ('height' is replaced internally, else recursion)   //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'myHeight', {\n"
    //"    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('height'));  },\n"
    // Gemäß Beispiel 7.4 sind es die outer-Werte... wtf... ob es was bricht?
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).outerHeight();  },\n"
    "    set : function(newValue){ if (isDOM(this)) $(this).css('height',newValue); $(this).triggerHandler('onheight', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'myWidth'                         //\n"
    "// ('width' is replaced internally, else recursion)    //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'myWidth', {\n"
    
    //"    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('width'));  },\n"
    // Gemäß Beispiel 7.4 ist es outerWidth... wtf... ob es was bricht?
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).outerWidth();  },\n"
    "    set : function(newValue){ if (isDOM(this)) $(this).css('width',newValue); $(this).triggerHandler('onwidth', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    // es gibt ein natives JS-align, was sich wohl korrekt zur OL-Logik verhält
    // http://jsfiddle.net/Pv8YQ/ Deswegen nicht nötig.
    //"/////////////////////////////////////////////////////////\n"
    //"// Setter for 'align'                                  //\n"
    //"// WRITE                                               //\n"
    //"/////////////////////////////////////////////////////////\n"
    //"Object.defineProperty(Object.prototype, 'align', {\n"
    //"    get : function(){ /* Keine direkte CSS-Eigenschaft, wenn dann Variable _align einführen */ },\n"
    //"    set: function(newValue){\n"
    //"        if (newValue !== 'left' || newValue !== 'center' || newValue !== 'right')\n"
    //"            throw new Error('Unsupported value for align.');\n"
    //"\n"
    //"        if (newValue === 'left')\n"
    //"            /* Nothing */;\n"
    //"        if (newValue === 'center')\n"
    //"            $(this).css('left',toIntFloor((parseInt($(this).parent().css('width'))-parseInt($(this).outerWidth()))/2));\n"
    //"        if (newValue === 'right')\n"
    //"            $(this).css('left',toIntFloor((parseInt($(this).parent().width())-$(this).outerWidth())));\n"
    //"    },\n"
    //"    enumerable : false,\n"
    //"    configurable : true\n"
    //"});\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'textalign'                       //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(Object.prototype, 'textalign', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).css('text-align'); },\n"
    "    set: function(newValue){\n"
    "        if (newValue !== 'left' && newValue !== 'center' && newValue !== 'right')\n"
    "            throw new Error('Unsupported value for textalign.');\n"
    "\n"
    "        $(this).css('text-align', newValue);\n"
    "        $(this).triggerHandler('textalign', newValue);\n"
    "    },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um height/width von Div's anzupassen //\n"
    "// adjustHeightAndWidth()                              //\n"
    "/////////////////////////////////////////////////////////\n"
    // Code-Logik:
    // Bei (positionAbsolute == YES),
    // wenn entweder der x- oder der y-Wert (eines Kindes) gesetzt wurde,
    // dann muss ich die Größe des umgebenden Elements erweitern,
    // aber nur wenn im aktuellen View keine height angegeben wurde,
    // dann setz als height die des (höchsten Kindes + top-wert).
    // Jedoch wird nie das umgebende canvas verändert und bei rudElement bleibt es bei auto, damit es scrollt
    "// Falls ein Kind eine x, y, width oder height-Angabe hat: Wir müssen dann die Höhe des Eltern-Elements anpassen, da absolute-Elemente\n"
    "// nicht im Fluss auftauchen, aber das umgebende Element trotzdem mindestens so hoch sein muss, dass es dieses mit umfasst.\n"
    "// Wir überschreiben jedoch keinen explizit vorher gesetzten Wert,\n"
    "// deswegen test auf '' (nur mit JS möglich, nicht mit jQuery)\n"
    // position().top klappt nicht, weil das Elemente versteckt sein kann,
    // aber mit css('top') klappt es (gleiches gilt für position().left).
    // '0'+ als Schutz gegen 'auto', so, dass parseInt() auf jeden Fall ne Nummer findet.
    "var adjustHeightAndWidth = function (el) {\n"
    "    if ($(el).is('input')) // Dann Sprung, weil inputs aus mehreren Elementen bestehen\n"
    "        el = $(el).parent().get(0);\n"
    "\n"
    "    var sumXYHW = 0;\n"
    "    $(el).children().map(function ()\n"
    "    {\n"
    "        var n = this.nodeName.toLowerCase();\n"
    "        if (n === 'a' || n === 'b' || n === 'i' || n === 'p' || n === 'u' || n === 'br' || n === 'font' || n === 'img')\n"
    "            return;\n"
    "        sumXYHW += parseInt('0'+$(this).css('top'));\n"
    "        sumXYHW += parseInt('0'+$(this).css('left'));\n"
    "        sumXYHW += $(this).height();\n"
    "        sumXYHW += $(this).width();\n"
    "    });\n"
    "    if (sumXYHW > 0 && $(el).children().length > 0 && $(el).get(0).style.height == '')\n"
    "    {\n"
    "        var heights = $(el).children().map(function () { return $(this).outerHeight(true)+$(this).position().top; }).get();\n"
    "        if (!($(el).hasClass('div_rudElement')) && !($(el).hasClass('canvas_standard')))\n"
    "        {\n"
    "            if (($(el).hasClass('div_window')))\n"
    "            {\n"
    "                el.setAttribute_('height',getMaxOfArray(heights)+10);\n"
    "                $('#'+el.id+'_content').get(0).setAttribute_('height',getMaxOfArray(heights)-10)\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                // Umgekehrt gilt aber auch:\n"
    "                // Wenn bei windowContent das Window keine Höhe hat, dann dieses mitsetzen\n"
    "                if ($(el).hasClass('div_windowContent') && $(el).parent().get('0').style.height == '')\n"
    "                    $(el).parent().get(0).setAttribute_('height',getMaxOfArray(heights)+20);\n"
    "                el.setAttribute_('height',getMaxOfArray(heights));\n"
    "            }\n"
    "        }\n"
    "    }\n"
    "    // Analog muss die Breite gesetzt werden\n"
    "    if (sumXYHW > 0 && $(el).children().length > 0 && $(el).get(0).style.width == '')\n"
    "    {\n"
    "        var widths = $(el).children().map(function () { return $(this).outerWidth(true)+$(this).position().left; }).get();\n"
    "\n"
    "        // Bei einem Window entscheidet der content mit über das breiteste Element!\n"
    "        if ($('#'+el.id+'_content').length > 0)\n"
    "            widths = widths.concat($('#'+el.id+'_content').children().map(function () { return $(this).outerWidth(true)+$(this).position().left; }).get());\n"
    "\n"
    "        if (!($(el).hasClass('canvas_standard')))\n"
    "            el.setAttribute_('width',getMaxOfArray(widths))\n"
    "    }\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+el.id+'_repl'+c).length)\n"
    "    {\n"
    "        adjustHeightAndWidth($('#'+el.id+'_repl'+c).get(0));\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um width von Div's anzupassen        //\n"
    "// adjustWidthOfEnclosingDivWithWidestChildOnSimpleLayout()\n"
    "/////////////////////////////////////////////////////////\n"
    "// Eventuell nachfolgende Simplelayouts müssen entsprechend der Breite des vorherigen umgebenden Divs aufrücken.\n"
    "// Deswegen wird hier explizit die Breite gesetzt (ermittelt anhand des breitesten Kindes).\n"
    "// Eventuelle Kinder wurden vorher gesetzt.\n"
    "// Aber nur wenn Breite NICHT explizit vorher gesetzt wurde - dieser Test ist nur mit JS möglich, nicht mit jQuery.\n"
    "var adjustWidthOfEnclosingDivWithWidestChildOnSimpleLayout = function (el) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '')\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content').get(0);\n"
    "\n"
    "    var widths = $(el).children().map(function () { return $(this).outerWidth(); }).get();\n"
    "    if (el.style.width == '') {\n"
    "        el.setAttribute_('width',getMaxOfArray(widths));\n"
    "    }\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+el.id+'_repl'+c).length)\n"
    "    {\n"
    "        adjustWidthOfEnclosingDivWithWidestChildOnSimpleLayout($('#'+el.id+'_repl'+c).get(0));\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um height von Div's anzupassen       //\n"
    "// adjustHeightOfEnclosingDivWithHeighestChildOnSimpleLayout()\n"
    "/////////////////////////////////////////////////////////\n"
    "// Eventuell nachfolgende Simplelayouts müssen entsprechend der Höhe des vorherigen umgebenden Divs aufrücken.\n"
    "// Deswegen wird hier explizit die Höhe gesetzt (ermittelt anhand des höchsten Kindes).\n"
    "// Eventuelle Kinder wurden vorher gesetzt.\n"
    "// Aber nur wenn Höhe NICHT explizit vorher gesetzt wurde - dieser Test ist nur mit JS möglich, nicht mit jQuery.\n"
    "// (Jedoch bei rudElement MUSS es auto bleiben)\n"
    "var adjustHeightOfEnclosingDivWithHeighestChildOnSimpleLayout = function (el) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '')\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content').get(0);\n"
    "\n"
    "    var heights = $(el).children().map(function () { return $(this).outerHeight(); }).get();\n"
    "    if (el.style.height == '') {\n"
    "        el.setAttribute_('height',getMaxOfArray(heights));\n"
    "    }\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+el.id+'_repl'+c).length)\n"
    "    {\n"
    "        adjustHeightOfEnclosingDivWithHeighestChildOnSimpleLayout($('#'+el.id+'_repl'+c).get(0));\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um height von Div's anzupassen (SA Y)//\n"
    "// adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY()\n"
    "/////////////////////////////////////////////////////////\n"
    "// Y-Simplelayout: Deswegen die Höhe aller beinhaltenden Elemente erster Ebene ermitteln und dem umgebenden div die Summe als\n"
    "// Höhe mitgeben (aber nur wenn es NICHT explizit vorher gesetzt wurde - dieser Test ist nur mit JS möglich, nicht mit jQuery)\n"
    "// (Jedoch bei rudElement MUSS es auto bleiben)\n"
    "var adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY = function (el,spacing) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '')\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content').get(0);\n"
    "\n"
    "    var sumH = 0;\n"
    "    $(el).children().each(function() {\n"
    "        sumH += $(this).outerHeight(true);\n"
    "    });\n"
    // Muss natürlich auch den y-spacing-Abstand zwischen den Elementen mit berücksichtigen
    // und auf die Höhe aufaddieren.
    // Keine Ahnung, aber wenn ich es auskommentiere, stimmt es mit dem Original eher überein.
    "    sumH += ($(el).children().length-1) * spacing;\n"
    "    if (!($(el).hasClass('div_rudElement')))\n"
    "        if (el.style.height == '')\n"
    "            el.setAttribute_('height',sumH);\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+el.id+'_repl'+c).length)\n"
    "    {\n"
    "        adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY($('#'+el.id+'_repl'+c).get(0),spacing);\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um Width von Div's anzupassen (SA X) //\n"
    "// adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX()\n"
    "/////////////////////////////////////////////////////////\n"
    "// X-Simplelayout: Deswegen die Breite aller beinhaltenden Elemente erster Ebene ermitteln und dem umgebenden div die Summe als\n"
    "// Breite mitgeben (aber nur wenn es NICHT explizit vorher gesetzt wurde - dieser Test ist nur mit JS möglich, nicht mit jQuery)\n"
    "var adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX = function (el,spacing) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '')\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content').get(0);\n"
    "\n"
    "    var sumW = 0;\n"
    "    $(el).children().each(function() {\n"
    "        sumW += $(this).outerWidth(true);\n"
    "    });\n"
    // Muss natürlich auch den x-spacing-Abstand zwischen den Elementen mit berücksichtigen
    // und auf die Breite aufaddieren.
    "    sumW += ($(el).children().length-1) * spacing;\n"
    // Keine Einschränkung mehr auf position:relative
    // [s appendString:@"  if ($('#"];
    // [s appendString:self.zuletztGesetzteID];
    // [s appendString:@"').css('position') == 'relative'"];
    // [s appendString:@")\n"];
    "    if (el.style.width == '')\n"
    "        el.setAttribute_('width',sumW);\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+el.id+'_repl'+c).length)\n"
    "    {\n"
    "        adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX($('#'+el.id+'_repl'+c).get(0),spacing);\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein SimpleLayout Y zu setzen      //\n"
    "// setSimpleLayoutYIn()                                //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setSimpleLayoutYIn = function (el,spacing) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '')\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content').get(0);\n"
    "\n"
    "    // Es soll wirklich erst bei 1 losgehen (Das erste Kind sitzt schon richtig)\n"
    "    for (var i = 1; i < $(el).children().length; i++)\n"
    "    {\n"
    "        var kind = $(el).children().eq(i);\n"
    "\n"
    "        if (@@positionAbsoluteReplaceMe@@)\n"
    "        {\n"
    "            var topValue = kind.prev().get(0).offsetTop + kind.prev().outerHeight() + spacing;\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            var topValue = i * spacing;\n"
    "            if (kind.css('position') === 'relative')\n"
    "            {\n"
    "                // Wenn wir hinten nicht runter gefallen sind\n"
    "                if ($(el).children().eq(0).position().left != kind.position().left)\n"
    "                {\n"
    "                    // topValue = i * spacing + kind.prev().outerHeight()/* + kind.prev().position().top*/;\n"
    "                    // Nur so klappt es bei Beispiel <basebutton>:\n"
    "                    topValue = spacing + kind.prev().outerHeight() + kind.prev().position().top;\n"
    "                    // var leftValue = kind.prev().position().left-kind.prev().outerWidth();\n"
    "                    // leftValue = leftValue * i;\n"
    "                    // nur so klappt es bei Bsp. 27.1 (Constraints in tags):\n"
    "                    var width = 0;\n"
    "                    kind.prevAll().each(function() { width += $(this).outerWidth(); });\n"
    "                    var leftValue = width * -1;\n"
    "                    kind.get(0).setAttribute_('x',leftValue+'px');\n"
    "                }\n"
    "            }\n"
    "        }\n"
    "        kind.get(0).setAttribute_('y',topValue+'px');\n"
    "\n"
    "        // Falls es geklonte Geschwister gibt:\n"
    "        var c = 2;\n"
    "        while ($('#'+el.id+'_repl'+c).length)\n"
    "        {\n"
    "            setSimpleLayoutYIn($('#'+el.id+'_repl'+c).get(0),spacing);\n"
    "            c++;\n"
    "        }\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein SimpleLayout X zu setzen      //\n"
    "// setSimpleLayoutXIn()                                //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setSimpleLayoutXIn = function (el,spacing) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '')\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content').get(0);\n"
    "\n"
    "    // Es soll wirklich erst bei 1 losgehen (Das erste Kind sitzt schon richtig)\n"
    "    for (var i = 1; i < $(el).children().length; i++)\n"
    "    {\n"
    "        var kind = $(el).children().eq(i);\n"
    "        if (@@positionAbsoluteReplaceMe@@) {\n"
    "            var leftValue = kind.prev().get(0).offsetLeft + kind.prev().outerWidth() + spacing;\n"
    "        }\n"
    "        else {\n"
    "            var leftValue = spacing * i;\n"
    "        }\n"
    "        kind.get(0).setAttribute_('x',leftValue+'px');\n"
    "\n"
    "        // Falls es geklonte Geschwister gibt:\n"
    "        var c = 2;\n"
    "        while ($('#'+el.id+'_repl'+c).length)\n"
    "        {\n"
    "            setSimpleLayoutXIn($('#'+el.id+'_repl'+c).get(0),spacing);\n"
    "            c++;\n"
    "        }\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein StableBorderLayout Y zu setzen//\n"
    "// setStableBorderLayoutYIn()                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setStableBorderLayoutYIn = function (el) {\n"
    "    if ($(el).children().length == 1)\n"
    "        jQuery.noop(); /* no operation */\n"
    "\n"
    "    if ($(el).children().length == 2) {\n"
    "        $(el).children().last().get(0).setAttribute_('y',$(el).children().first().css('height'));\n"
    "        $(el).children().last().get(0).setAttribute_('height','0');\n"
    "    }\n"
    "\n"
    "    if ($(el).children().length > 2) {\n"
    // @"    $(el).children().eq(2).css('top',$(el).height()-$(el).children().eq(2).height()+'px');\n"
    // So funktioniert es besser:
    // Er will die Y und Y- Werte auslesen. Wenn ich in position:relative bin, klappt
    // das aber nicht, weil er ja automatisch nach rechts rutscht oder runter rutscht
    // deswegen muss ich, auch bei 'relative', hier alle Kinder 'absolute' machen.
    "        if (!@@positionAbsoluteReplaceMe@@)\n"
    "            $(el).children().each(function() { $(this).css('position','absolute'); });\n"
    "\n"
    "        $(el).children().eq(1).get(0).setAttribute_('y',$(el).children().first().css('height'));\n"
    "        $(el).children().eq(1).get(0).setAttribute_('height',$(el).height()-$(el).children().first().height()-$(el).children().eq(2).height());\n"
    "        $(el).children().eq(2).get(0).setAttribute_('y',$(el).children().eq(0).height()+$(el).children().eq(1).height()+'px');\n"
    "        // Noch die Height vom umgebenden anpassen, damit es so hoch ist, wie auch der Inhalt hoch ist\n"
    "        $(el).get(0).setAttribute_('height',$(el).children().eq(2).position().top+$(el).children().eq(2).height());\n"
    "  }\n"
    "}"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein StableBorderLayout X zu setzen//\n"
    "// setStableBorderLayoutXIn()                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setStableBorderLayoutXIn = function (el) {\n"
    "    if ($(el).children().length == 1)\n"
    "        jQuery.noop(); /* no operation */\n"
    "\n"
    "    if ($(el).children().length == 2) {\n"
    "        $(el).children().last().get(0).setAttribute_('x',$(el).children().first().css('width'));\n"
    "        $(el).children().last().get(0).setAttribute_('width','0');\n"
    "    }\n"
    "\n"
    "    if ($(el).children().length > 2) {\n"
    //[o appendFormat:@"    alert($('#%@').children().length);\n",idUmgebendesElement];

    //[o appendFormat:@"    $('#%@').children().eq(2).css('left','auto'); // sonst nimmt er 'right' nicht an.\n",idUmgebendesElement];
    //[o appendFormat:@"    $('#%@').children().eq(2).css('right','0');\n",idUmgebendesElement];
    // Habe Angst, dass er mir so irgendwas zerhaut, weil ich left auf 'auto' setze, aber andere Stellen sich
    // darauf verlassen, dass in 'left' ein numerischer Wert ist. Deswegen lieber so:
    "    if (!@@positionAbsoluteReplaceMe@@)\n"
    "        $(el).children().each(function() { $(this).css('position','absolute'); });\n"
    "\n"
    // So funktioniert es besser?
    // "  $(el).children().eq(2).css('left',$(el).children().eq(0).width()+$(el).children().eq(1).width()+'px');\n"
    "    $(el).children().eq(1).get(0).setAttribute_('x',$(el).children().first().css('width'));\n"
    "    $(el).children().eq(1).get(0).setAttribute_('width',$(el).width()-$(el).children().first().width()-$(el).children().eq(2).width());\n"
    "    $(el).children().eq(2).get(0).setAttribute_('x',$(el).width()-$(el).children().eq(2).width()+'px');\n"
    "    // Noch die Height vom umgebenden anpassen, damit es so hoch ist, wie auch der Inhalt hoch ist\n"
    "    $(el).get(0).setAttribute_('height',getHeighestHeightOfChilds(el));\n"
    "  }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um einen relativ gesetzten Datapath auszuwerten\n"
    "// setRelativeDataPathIn()                             //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setRelativeDataPathIn = function (el,path,pointer,attr) {\n"
    "    if ($(el).parent().data('IAmAReplicator') || $(el).data('IAmAReplicator'))\n"
    "    {\n"
    "        // Der xpath kann im eigenen Element oder im parent-Element stecken\n"
    "        var XPath = undefined;\n"
    "        if ($(el).parent().data('XPath'))\n"
    "            XPath = $(el).parent().data('XPath');\n"
    "        if ($(el).data('XPath'))\n"
    "            XPath = $(el).data('XPath');\n"
    "\n"
    "        var zusammengesetzterXPath = XPath + '[1]/' + path;\n"
    "        el.setAttribute_(attr,pointer.xpathQuery(zusammengesetzterXPath));\n"
    "\n"
    "        // Und alle geklonten Geschwister berücksichtigen\n"
    "        var c = 2;\n"
    "        while ($('#'+el.id+'_repl'+c).length)\n"
    "        {\n"
    "            zusammengesetzterXPath = XPath + '['+c+']/' + path;\n"
    //"            $('#'+el.id+'_repl'+c).setAttribute_(attr,pointer.xpathQuery(zusammengesetzterXPath));\n"
    "            window[el.id+'_repl'+c].setAttribute_(attr,pointer.xpathQuery(zusammengesetzterXPath));\n"
    "            c++;\n"
    "        }\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        el.setAttribute_(attr,pointer.xpathQuery(path));\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um das size-Attribut von select-Boxen zu setzen\n"
    "// setSizeOfSelectBoxIn()                             //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setSizeOfSelectBoxIn = function (el) {\n"
    "    if ($(el).data('shownitems') != -1)\n"
    "    {\n"
    "        $(el).attr('size', $(el).data('shownitems'));\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        // Falls eine Height gesetz wurde, muss ich gucken wie oft ein Eintrag da reinpasst und dann das Size-Attribut setzen, sonst starke Verzerrrungen (z. B. im Firefox)\n"
    "        if (el.style.height != '') // Über jQuery height auslesen von <select>-Elementen klappt bei Webkit nicht\n"
    "        {\n"
    "            $(el).attr('size', parseInt(mylist.style.height) % 15);\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            // Ansonsten wird das Attribut 'size' der <select>-Box entsprechend der Anzahl der options gesetzt\n"
    //"            $(el).attr('size', items);\n"
    // Das klappt nicht bei geklonten Elementen. Deswegen direkt die Options-Elemente zählen:
    "            $(el).attr('size',$(el).children('option').length);\n"
    "        }\n"
    "    }\n"
    "\n"
    "    // Bei dem Wert 2 oder 3 braucht Webkit leider etwas Nachhilfe\n"
    "    if ($(el).attr('size') == '2' || $(el).attr('size') == '3')\n"
    "    {\n"
    //[self.jQueryOutput appendFormat:@"  var sumH = 0;\n  $('#%@').children().each(function() { sumH += $(this).outerHeight(true); });\n  $('#%@').height(sumH);\n",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1],[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1],self.baselistitemCounter];
    // Neuer Code:
    // Beispiel von <list> klappt nur so (unter Webkit):
    "        $(el).height(Number($(el).attr('size'))*15);\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "\n";



    if (positionAbsolute == YES)
    {
        js = [js stringByReplacingOccurrencesOfString:@"@@positionAbsoluteReplaceMe@@" withString:@"true"];
    }
    else
    {
        js = [js stringByReplacingOccurrencesOfString:@"@@positionAbsoluteReplaceMe@@" withString:@"false"];
    }

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
    "//////////////////////////////////////////////////////////////////////////////////////////\n"
    "// Beinhaltet alle von OpenLaszlo mittels <class> definierte Klassen. Es werden korrespondierende //\n"
    "// 'Constructor Functions' angelegt, welche später von jQuery verarbeitet werden. Sobald          //\n"
    "// der Converter auf die Klasse dann stößt, legt er ein hier definiertes Objekt per new() an.     //\n"
    "//////////////////////////////////////////////////////////////////////////////////////////\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "// Globales Objekt, in dem alle Klassen stecken              //\n"
    "// Damit es keine Name-Conflicts gibt, z. B. bei SharedObject//\n"
    "///////////////////////////////////////////////////////////////\n"
    "var oo = {};\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "// Placeholder-ID, that ist replaced in all objects          //\n"
    "///////////////////////////////////////////////////////////////\n"
    "var placeholderID = '@@@P-L,A#TZHALTER@@@';\n"
    "///////////////////////////////////////////////////////////////\n"
    "// replace placeholder-id with real id                       //\n"
    "///////////////////////////////////////////////////////////////\n"
    "function replaceID(inString,to,to2)\n"
    "{\n"
    "  if (inString === undefined || inString === '')\n"
    "    return '';\n"
    "\n"
    "  // Wenn in einem s der Platzhalter mit und ohne angehängter Nummer auftaucht,\n"
    "  // dann nacheinander ersetzen. Ein Platzhalter ohne Nummer darf nicht den Objektnamen\n"
    "  // angehängt bekommen. Deswegen in so einem Fall Rückgriff auf 'to2'.\n"
    "  if (to2)\n"
    "  {\n"
    "    var from = new RegExp(placeholderID+'_', 'g');\n"
    "    inString = inString.replace(from, to+'_');\n"
    "\n"
    "    var from = new RegExp(placeholderID, 'g');\n"
    "    return inString.replace(from, to2);\n"
    "  }\n"
    "\n"
    "  var from = new RegExp(placeholderID, 'g');\n"
    "  return inString.replace(from, to);\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "// Mit dieser Funktion werden alle Objekte ausgewertet       //\n"
    "///////////////////////////////////////////////////////////////\n"
    "// Aus obj ziehen wir den ganzen Inhalt raus, wie das Objekt aussehen muss\n"
    "// und id wird dem entsprechend mit allen Attributen und Methoden erweitert.\n"
    "function interpretObject(obj,id)\n"
    "{\n"
    "  // Neu Durchlauf 1: Alle selbst definierten Attribute werden direkt an das Element gebunden\n"
    "  // Dies muss als allererstes passieren, da in Unterklassen definierte Methoden oder Attrbute bereits darauf zugreifen können\n"
    "  // Muss deswegen auch rückwärts ausgewertet werden\n"
    "  var currentObj = obj; // Zwischenspeichern\n"
    "  var rueckwaertsArray = [];\n"
    "  while (obj.inherit !== undefined)\n"
    "  {\n"
    "    rueckwaertsArray.push(obj);\n"
    "    obj = obj.inherit;\n"
    "  }\n"
    "  obj = currentObj; // Wieder unser Original-Objekt setzen\n"
    "  rueckwaertsArray.reverse();\n"
    "\n"
    "  for (var i = 0;i<rueckwaertsArray.length;i++)\n"
    "  {\n"
    "    var obj = rueckwaertsArray[i];\n"
    "    if (obj.selfDefinedAttributes)\n"
    "    {\n"
    "      Object.keys(obj.selfDefinedAttributes).forEach(function(key)\n"
    "      {\n"
    "        // Bitte nichts überschreiben, was ich gerade erst beim instanzieren der Klasse gesetzt haben\n"
    "        if (id[key] === undefined)\n"
    "        {\n"
    "          var value = obj.selfDefinedAttributes[key]\n"
    "\n"
    "          if (typeof value === 'string' && value.startsWith('@§.BERECHNETERWERT.§@'))\n"
    "          {\n"
    "            value = value.substr(21);\n"
    "            value = replaceID(value,''+$(id).attr('id'));\n"
    "\n"
    "            var evalString = 'id[key] = ' + value + ';'\n"
    "            //alert(evalString);\n"
    "            eval(evalString);\n"
    "          }\n"
    "          else\n"
    "          {\n"
    "            id[key] = value;\n"
    "          }\n"
    "        }\n"
    "      });\n"
    "    }\n"
    "  }\n"
    "\n"
    "\n"
    "\n"
    "  // Durchlauf 2\n"
    "  // Alle Attribute von Vorfahren werden geerbt. Dazu solange nach Vorfahren suchen, bis 'view' kommt\n"
    "  // und die Attribute übernehmen (bei gleichen gelten die hierachiemäßig allernächsten).\n"
    "  // Außerdem den HTML-Content von Vorfahren einfügen und individuelle ID vergeben.\n"
    "  var currentObj = obj; // Zwischenspeichern\n"
    "  while (obj.inherit !== undefined)\n"
    "  {\n"
    "    // Doppelte Einträge von Attributen entfernen\n"
    "    obj.inherit = deleteAttributesPreviousDeclared(currentObj.attributeNames,obj.inherit);\n"
    "\n"
    "    // attributeNames übernehmen\n"
    "    if (obj.inherit.attributeNames.length > 0)\n"
    "      currentObj.attributeNames = currentObj.attributeNames.concat(obj.inherit.attributeNames);\n"
    "\n"
    "    // attributeValues übernehmen\n"
    "    if (obj.inherit.attributeValues.length > 0)\n"
    "      currentObj.attributeValues = currentObj.attributeValues.concat(obj.inherit.attributeValues);\n"
    "\n"
    "\n"
    "    // Dann den HTML-Content des Vorfahren einfügen\n"
    "    // Prepend! Da es der OpenLaszlo-Logik entspricht, tiefer verschachtelte Vorfahren immer davor zu setzen\n"
    "    // Vorher aber die ID ersetzen\n"
    "    // Irgendwas stimmt in der Logik noch nicht... Nach meinem Verständnis erben alle Klassen von view\n"
    "    // So steht es auch in der Doku. Deswegen ist um alle Klassen eine View <div class='div-standard'> herumgebaut, an welche dann immer prepended wird.\n"
    "    // Dies geht aber nicht auf z. B. bei extends='text', dann nämlich muss die äußerste view ein\n"
    "    // <div class='div_text'> sein. (obwohl 'text' ja eigentlich auch nochmal von view erbt...)\n"
    "    // Dies äußerst sich darin, dass z. B. ein onclick-Handler auf höchster Ebene der Klasse mit 'this' auch\n"
    "    // Methoden von <text> aufrufen kann (2. Beispiel von <text> in OL-Doku)\n"
    "    // Derzeitige Lösung: Bei Text nicht appenden, sondern ersetzen...\n"
    "    // (und die Attribute, Methoden, Events und CSS übernehmen)\n"
    "    if (obj.inherit.name === 'text' || obj.inherit.name === 'inputtext' || obj.inherit.name === 'basewindow' || obj.inherit.name === 'button' || obj.inherit.name === 'basecombobox')\n"
    "    {\n"
    "        // Attribute sichern\n"
    "        var gesicherteAttribute = {};\n"
    "        Object.keys(obj.selfDefinedAttributes).forEach(function(key)\n"
    "        {\n"
    "            gesicherteAttribute[key] = id[key];\n"
    "        });\n"
    "\n"
    "        // Alle auf vorherigen Vererbungs-Ebenen hinzugefügten Methoden sichern\n"
    "        var gesicherteMethoden = {};\n"
    "        for(var prop in id) {\n"
    "            if (id.hasOwnProperty(prop) && typeof id[prop] === 'function') {\n"
    //"                alert(id[prop]);\n"
    //"                alert(prop);\n"
    "                gesicherteMethoden[prop] = id[prop];\n"
    "            }\n"
    "        }\n"
    "\n"
    "        // Events sichern\n"
    //"        var gesicherteEvents = $(id).data('events'); // Will break on jQuery 1.8\n"
    "        var gesicherteEvents = $._data(id,'events'); // Will work on jQuery 1.8\n"
    "\n"
    "\n"
    "        // Da wir ersetzen, bekommt dieses Element den Universal-id-Namen\n"
    "        obj.inherit.contentHTML = replaceID(obj.inherit.contentHTML,''+$(id).attr('id'));\n"
    "        var theSavedCSSFromRemovedElement = $(id).replaceWith(obj.inherit.contentHTML).attr('style');\n"
    "        // Interne ID dieser Funktion neu setzen\n"
    "        id = document.getElementById(id.id);\n"
    "        // Und externen Elementnamen neu setzen\n"
    "        window[id.id] = id; // Falls es irgendwo als parent gesetzt wurde, puh... überlegen, wie ich da dran käme\n"
    "        // Und das gerettete CSS wieder einsetzen\n"
    "        $(id).attr('style',$(id).attr('style') + theSavedCSSFromRemovedElement);\n"
    "\n"
    "        // Und die zuvor gesicherten events wieder einsetzen\n"
    "        if (gesicherteEvents) // Schutz gegen undefined, sonst Absturz bei undefined\n"
    "        {\n"
    "            $.each(gesicherteEvents, function() {\n"
    "                $.each(this, function() {\n"
    "                    $(id).on(this.type, this.handler);\n"
    "                });\n"
    "            });\n"
    "        }\n"
    "\n"
    "        // Und die Original-Propertys wieder herstellen mit Default-Werten (Wie käme ich an die Nicht-Default-Werte ... ?)\n"
    "        // Jupp. Gelöst! In dem ich alle selbst gesetzten Attribute vorher sichere und nun setze\n"
    "        Object.keys(obj.selfDefinedAttributes).forEach(function(key)\n"
    "        {\n"
    //"            id[key] = obj.selfDefinedAttributes[key];\n"
    "            id[key] = gesicherteAttribute[key];\n"
    "        });\n"
    "\n"
    "        // Und die Methoden wieder herstellen\n"
    "        Object.keys(gesicherteMethoden).forEach(function(key)\n"
    "        {\n"
    "            id[key] = gesicherteMethoden[key];\n"
    "        });\n"
    "\n"
    "        // Dann den kompletten JS-Code ausführen\n"
    "        executeJSCodeOfThisObject(obj.inherit, id, $(id).attr('id'));\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "      if (obj.inherit.contentHTML.length > 0)\n"
    "      {\n"
    "        // Damit es die IDs nicht doppelt gibt, hänge ich 'inherit.name' dran.\n"
    "        obj.inherit.contentHTML = replaceID(obj.inherit.contentHTML,''+$(id).attr('id')+'_'+obj.inherit.name);\n"
    //"        obj.inherit.contentHTML = replaceID(obj.inherit.contentHTML,''+$(id).attr('id'));\n"
    "        $(id).prepend(obj.inherit.contentHTML);\n"
    "      }\n"
    "\n"
    "      // Dann den kompletten JS-Code ausführen\n"
    "      executeJSCodeOfThisObject(obj.inherit, id, $(id).attr('id')+'_'+obj.inherit.name, $(id).attr('id'));\n"
    "    }\n"
    "\n"
    "    // Objekt der nächsten Vererbungs-Stufe holen\n"
    "    obj = obj.inherit;\n"
    "  }\n"
    "  obj = currentObj; // Wieder unser Original-Objekt setzen\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "  // Alle per style gegebenen Attribute muss ich ermitteln und später damit vergleichen\n"
    "  // Denn die per style direkt im Element übergebenen Attribute haben Vorrang vor denen\n"
    "  // der Klasse. Ich kann noch nicht hier, sondern erst später vergleichen, weil z.B.\n"
    "  // bgcolor erst noch durch background-color ersetzt werden muss usw.\n"
    "  var css = $(id).attr('style');\n"
    "  if(css !== undefined)\n"
    "  {\n"
    "    var attrArr = [];\n"
    "    css = css.split(';');\n"
    "    for (var i in css)\n"
    "    {\n"
    "      var l = css[i].split(':');\n"
    "      var attr = $.trim(l[0]);\n"
    "      if (attr != '')\n"
    "        attrArr.push(attr);\n"
    "    }\n"
    "  }\n"
    "\n"
    "\n"
    "  // Erst die Attribute auswerten\n"
    "  var an = obj.attributeNames;\n"
    "  var av = obj.attributeValues;\n"
    "\n"
    "  // height und width müssen immer als erstes ausgewertet werden\n"
    "  // z. B. 'layout' verlässt sich darauf, dass 'width' vorher gesetzt wurden\n"
    "  var posHeightInArray = $.inArray('height', an);\n"
    "  if (posHeightInArray != -1)\n"
    "  {\n"
    "    an.move(posHeightInArray,0);\n"
    "    av.move(posHeightInArray,0);\n"
    "  }\n"
    "  var posWidthInArray = $.inArray('width', an);\n"
    "  if (posWidthInArray != -1)\n"
    "  {\n"
    "    an.move(posWidthInArray,0);\n"
    "    av.move(posWidthInArray,0);\n"
    "  }\n"
    "\n"
    "  for (i = 0;i<an.length;i++)\n"
    "  {\n"
    //"    alert(an[i]);\n"
    //"    alert(av[i]);\n"
    "    var cssAttributes = ['bgcolor','x','y','width','height'];\n"
    "    var jsAttributes = ['onclick','ondblclick','onmouseover','onmouseout','onmouseup','onmousedown','onfocus','onblur','onkeyup','onkeydown','focusable','layout','text'];\n"
    "    if (jQuery.inArray(an[i],cssAttributes) != -1)\n"
    "    {\n"
    "        if (an[i] === 'bgcolor')\n"
    "          an[i] = 'background-color';\n"
    "        if (an[i] === 'x')\n"
    "          an[i] = 'left';\n"
    "        if (an[i] === 'y')\n"
    "          an[i] = 'top';\n"
    "\n"
    "        if (av[i].startsWith('$')) // = Constraint value\n"
    "        {\n"
    "            av[i] = av[i].substring(2,av[i].length-1);\n"
    "\n"
    //"            av[i] = av[i].replace('immediateparent','getTheParent(true)');\n"
    //"\n"
    //"            av[i] = av[i].replace('parent','getTheParent()');\n"
    //"\n"
    // --> Neu gelöst über getter, deswegen muss ich nicht mehr ersetzen.
    "            av[i] = av[i].replace('.width','.myWidth');\n"
    "\n"
    "            av[i] = av[i].replace('.height','.myHeight');\n"
    "\n"
    "            // sich selbst ausführende Funktion mit bind, um Scope korrekt zu setzen\n"
    "            var result = (function() { with (id) { return eval(av[i]); } }).bind(id)();\n"
    "            av[i] = result;\n"
    "        }\n"
    "\n"
    "        if (jQuery.inArray(an[i],attrArr) == -1)\n"
    "          $(id).css(an[i],av[i]);\n"
    "    }\n"
    "    else if (jQuery.inArray(an[i],jsAttributes) != -1)\n"
    "    {\n"
    "      if (an[i].startsWith('on'))\n"
    "      {\n"
    "        // Dann ist es JS-Code, Anpassungen vornehmen.\n"
    "        av[i] = av[i].replace('setAttribute','setAttribute_');\n"
    "        av[i] = av[i].replace('.width','.myWidth');\n"
    "        av[i] = av[i].replace('.height','.myHeight');\n"
    "\n"
    "        // 'on' entfernen\n"
    "        an[i] = an[i].substr(2);\n"
    "\n"
    "        if ($(id).hasClass('noPointerEvents'))\n"
    "          $(id).removeClass('noPointerEvents');\n"
    "        // Auch noch von der umgebenden view (Container der Klasse) die pointerEvents entfernen\n"
    "        if ($(id).parent().hasClass('noPointerEvents'))\n"
    "          $(id).parent().removeClass('noPointerEvents');\n"
    "\n"
    //"        // Array-Variable in diesen Scope holen, damit ich sie in die Funktion einfügen kann\n"
    //"        var executeInOnFunction = av[i];\n"
    //"\n"
    //"        $(id).on(an[i], function()\n"
    //"        {\n"
    //"          with (this)\n"
    //"          {\n"
    //"            eval(executeInOnFunction);\n"
    //"          }\n"
    //"        });\n"
    // Der alte Code war Quatsch, hat immer nur die zuletzt gesetzte Methode ausgeführt
    "          // Neuer Code: Ich muss den KOMPLETTEN on-Befehl per eval setzen,\n"
    "          // damit die Variable direkt verwertet wird.\n"
    "          eval('$(id).on(an[i], function() { with (this) { '+av[i]+'; } });');\n"
    "      }\n"
    "      else if (an[i] === 'focusable' && av[i] === 'false')\n"
    "      {\n"
    "        $(id).on('focus.blurnamespace', function() { this.blur(); });\n"
    "      }\n"
    "      else if (an[i] === 'focusable' && av[i] === 'true')\n"
    "      {\n"
    "        // Einen eventuell vorher gesetzten focus-Handler, der blur() handlet, entfernen\n"
    "        $(id).off('focus.blurnamespace');\n"
    "      }\n"
    "      else if (an[i] === 'layout' && !av[i].contains('class') &&  av[i].replace(/\\s/g,'').contains('axis:x'))\n"
    "      {\n"
    "        var spacing = parseInt(av[i].betterParseInt());\n"
    "        for (var j = 1; j < $(id).children().length; j++) {\n"
    "          var kind = $(id).children().eq(j);\n"
    "          var leftValue = kind.prev().get(0).offsetLeft + kind.prev().outerWidth() + spacing;\n"
    "          kind.css('left',leftValue+'px');\n"
    "        }\n"
    "      }\n"
    "      else if (an[i] === 'layout' && !av[i].contains('class') &&  av[i].replace(/\\s/g,'').contains('axis:y'))\n"
    "      {\n"
    "        var spacing = parseInt(av[i].betterParseInt());\n"
    "        for (var j = 1; j < $(id).children().length; j++) {\n"
    "          var kind = $(id).children().eq(j);\n"
    "          if ($(kind).css('position') === 'absolute')\n"
    "            var topValue = kind.prev().get(0).offsetTop + kind.prev().outerHeight() + spacing;\n"
    "          else\n"
    "            var topValue = spacing;\n"
    "          kind.css('top',topValue+'px');\n"
    "        }\n"
    "      }\n"
    "      else if (an[i] === 'text')\n"
    "      {\n"
    //"        $(id).children().html(av[i]);\n"
    "        // JEDE Klasse hat das Attribut 'text', weil es den Text zwischen öffnendem und schließendem Tag darstellt\n"
    "        // Deswegen nur dann setzen, wenn auch Text zwischen den Tags war. Sonst werden eventuell andere Tags überschrieben\n"
    "        if (av[i] != '')\n"
    "            id.setAttribute_(an[i],av[i]);\n"
    "      }\n"
    "      else { alert('Hoppala, \"'+an[i]+'\" (value='+av[i]+') muss noch von interpretObject() als jsAttribute ausgewertet werden.'); }\n"
    "    }\n"
    "    else if (an[i] === 'textBetweenTags_')\n"
    "    {\n"
    "        // Damit passiert erstmal nichts. Aber falls die Klasse ein Attribut text definiert hat, wird der Wert zugeordnet\n"
    "        // Klassen die <text> oder <inputtext> extenden haben dieses Attribut von haus aus und IMMER Zugriff auf Text der zwischen Tags übergeben wurde (Example 28.9 und Example 28.10)\n"
    "        if (id.text !== undefined)\n"
    "            id.text = av[i];\n"
    "    }\n"
    "    else { id.setAttribute_(an[i],av[i]); /* alert('Whoops, \"'+an[i]+'\" (value='+av[i]+') muss noch von interpretObject() ausgewertet werden.'); */ }\n"
    "  }\n"
    // "  $(id).css('background-color','black').css('width','200').css('height','5');\n"
    // "  $(id).attr('style',obj.style);\n"
    "\n"
    "  // Replace-IDs von contentHTML ersetzen\n"
    "  var s = replaceID(obj.contentHTML,$(id).attr('id'));\n"
    "  // Dann den HTML-Content hinzufügen\n"
    //"  // $(id).html(s);\n"
    //"  $(id).append(s);\n"
    "  // http://www.openlaszlo.org/lps4.9/docs/developers/introductory-classes.html#introductory-classes.placement\n"
    "  // 2.5 Placement -> By default, instances which appear inside a class are made children of the top level instance of the class.\n"
    "  var kinderVorDemAppenden = $(id).children(); // die existierenden Kinder sichern\n"
    "\n"
    "\n"
    "  // ********* Ich muss jedoch auch MICH selber an die richtige Stelle vom inherit setzen *********\n"
    "  // ********* Wenn der ein defaultplacement hat, muss ich da rein schlüpfen *********\n"
    "  if (obj.inherit && obj.inherit.defaultplacement && obj.inherit.defaultplacement !== '')\n"
    "  {\n"
    "    // Da der 'name' als inherit gesetzt wurde, spreche ich es darüber an\n"
    "    if ($(id[obj.inherit.defaultplacement]).length == 0)\n"
    "      alert('Kann nicht auf defaultplacement zugreifen. Das sollte nicht passieren.');\n"
    "\n"
    "    $(id[obj.inherit.defaultplacement]).prepend(s);\n"
    "  }\n"
    "  else\n"
    "  {\n"
    "    $(id).prepend(s); // dann den neuen Code anfügen\n"
    "  }\n"
    "\n"
    "\n"
    //"  // Wenn es Ein Text-Attribut gibt und eine Klasse mit class='div_text' vorliegt, und auch text übergeben wurde,\n"
    //"  // dann wird der textBetweenTags in das Element, welches 'div_text' als Klasse hat, eingefügt.\n"
    //"  // Example 28.10. Defining new text classes\n"
    //"  if (id.text !== undefined && $(s).hasClass('div_text') && jQuery.inArray('textBetweenTags_',an) != -1 && av[jQuery.inArray('textBetweenTags_',an)] !== '')\n"
    //"    $('#'+$(s).attr('id')).html(av[jQuery.inArray('textBetweenTags_',an)]);\n"
    //"\n"
    //"\n"
    "  // ********* Hier setze ich bereits vor ab in dem div existierende Kinder an die richtige Stelle *********\n"
    "  // ********* Damit 'defaultplacement' gesetzt werden kann *********\n"
    "  // ********* Die Variable, auf die defaultplacement verweist, wird hier bekannt gemacht *********\n"
    "      // Replace-IDs von contentJS ersetzen\n"
    "      var s = replaceID(obj.contentJS,$(id).attr('id'));\n"
    "      evalCode(s);\n"
    "\n"
    "  if (obj.defaultplacement !== '') // dann die vorher existierenden Kinder korrekt positionieren\n"
    "    $(kinderVorDemAppenden).appendTo($(window[obj.defaultplacement]));\n"
    "\n"
    "  // JS erst jetzt ausführen, sonst stimmen bestimmte width/height's nicht, weil ja etwas verschoben wurde\n"
    "  // Dann den kompletten JS-Code ausführen\n"
    "  // ToDo -> Eigentlich ohne das, was eben schon ausgeführt wurde.\n"
    "  executeJSCodeOfThisObject(obj, id, $(id).attr('id'));\n"
    "\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "// executes the complete JS-Code of the given Object         //\n"
    "///////////////////////////////////////////////////////////////\n"
    "// @arg r = replacement-String\n"
    "// @arg r2 = Ersatz-replacement-String. - Erklärung bei replaceID()\n"
    "function executeJSCodeOfThisObject(obj, id, r, r2)\n"
    "{\n"
    "  // Replace-IDs von contentLeadingJSHead ersetzen\n"
    "  var s = replaceID(obj.contentLeadingJSHead, r, r2);\n"
    "  // Dann den LeadingJSHead-Content hinzufügen/auswerten\n"
    "  if (s.length > 0)\n"
    "    evalCode(s);\n"
    "\n"
    "  // Replace-IDs von contentJSHead ersetzen\n"
    "  var s = replaceID(obj.contentJSHead, r, r2);\n"
    "  // Dann den JSHead-Content hinzufügen/auswerten\n"
    "  if (s.length > 0)\n"
    "    evalCode(s);\n"
    "\n"
    "  // Replace-IDs von contentJS ersetzen\n"
    "  var s = replaceID(obj.contentJS, r, r2);\n"
    "  // Dann den JS-Content hinzufügen/auswerten\n"
    "  if (s.length > 0)\n"
    "    evalCode(s);\n"
    "\n"
    "  // Replace-IDs von contentLeadingJQuery ersetzen\n"
    "  var s = replaceID(obj.contentLeadingJQuery, r, r2);\n"
    "  // Dann den LeadingJQuery-Content hinzufügen/auswerten\n"
    "  // evalCode benötigt Referenz auf id, damit es Methoden direkt adden kann\n"
    "  if (s.length > 0)\n"
    "    evalCode(s,id);\n"
    "\n"
    "  // Replace-IDs von den Computed Values ersetzen\n"
    "  var s = replaceID(obj.contentJSComputedValues, r, r2);\n"
    "  // Dann den ComputedValues-Content hinzufügen/auswerten\n"
    "  if (s.length > 0)\n"
    "    evalCode(s);\n"
    "\n"
    "  // Replace-IDs von den Constraint Values ersetzen\n"
    "  var s = replaceID(obj.contentJSConstraintValues, r, r2);\n"
    "  // Dann den ConstraintValues-Content hinzufügen/auswerten\n"
    "  if (s.length > 0)\n"
    "    evalCode(s);\n"
    "\n"
    "  // Replace-IDs von contentJQuery ersetzen\n"
    "  var s = replaceID(obj.contentJQuery, r, r2);\n"
    "  // Dann den jQuery-Content hinzufügen/auswerten\n"
    "  if (s.length > 0)\n"
    "    evalCode(s);\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  executes code from string                                //\n"
    "///////////////////////////////////////////////////////////////\n"
    "function evalCode(code,element)\n"
    "{\n"
    "    if (code.length == 0)\n"
    "        return;\n"
    "    // Möglichkeit 1: als eval, aber eval is evil (angeblich)\n"
    "    // Nur so klappt derzeit das Auswerten von Methoden, weil nur so der Scope erhalten bleibt\n"
    "    eval(code);\n"
    "\n"
    "    // Möglichkeit 2: Als Funktion\n"
    "    // var F=new Function (code);\n"
    "    // F();\n"
    "\n"
    "    // Möglichkeit 3: per jQuery den Code an das Ende von body anfügen\n"
    "    // var script = '<script type=\"text/javascript\"> $(window).load(function() { ' + code + ' }); </script>';\n"
    "    // $('body').append(script);\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  Löscht doppelte Attribute (ältere werden überschrieben)  //\n"
    "///////////////////////////////////////////////////////////////\n"
    "function deleteAttributesPreviousDeclared(bestand,neu)\n"
    "{\n"
    "    var an = neu.attributeNames;\n"
    "    var av = neu.attributeValues;\n"
    "\n"
    "    for (i = 0;i<an.length;i++)\n"
    "    {\n"
    "        if (jQuery.inArray(an[i],bestand) != -1)\n"
    "        {\n"
    "            an.splice(i,1);\n"
    "            av.splice(i,1);\n"
    "        }\n"
    "    }\n"
    "\n"
    "    return neu;\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = view (native class)                              //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.view = function() {\n"
    "  this.name = 'view';\n"
    "  this.inherit = undefined;\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.contentHTML = '';\n"
    //"  this.contentHTML = '<div id=\"@!JS,PLZ!REPLACE!ME!@\" class=\"div_standard\" />';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = text (native class)                              //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.text = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'text';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  // Text kann entweder als Attribut übergeben werden, oder als Text zwischen den Tags\n"
    "  // Deswegen kein direktes einfügen in contentHTML, sondern als Attribut auswerten lassen\n"
    "  this.attributeNames = [\"text\"];\n"
    "  this.attributeValues = [textBetweenTags];\n"
    "\n"
    "  this.defaultplacement = '';\n"
    "\n"
    "  this.contentHTML = '<div id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_text\" />';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = inputtext (native class)                         //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.inputtext = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'inputtext';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  // Text kann entweder als Attribut übergeben werden, oder als Text zwischen den Tags\n"
    "  // Deswegen kein direktes einfügen in contentHTML, sondern als Attribut auswerten lassen\n"
    "  this.attributeNames = [\"text\"];\n"
    "  this.attributeValues = [textBetweenTags];\n"
    "\n"
    "  this.defaultplacement = '';\n"
    "\n"
    "  this.contentHTML = '<div id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_text\" />';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = basewindow (native class)                        //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.basewindow = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'basewindow';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.attributeNames = [\"text\"];\n"
    "  this.attributeValues = [textBetweenTags];\n"
    "\n"
    "  this.defaultplacement = '_content';\n"
    "\n"
    "  this.contentHTML = '' +\n"
    "  '<div id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_window ui-corner-all\">\\n' +\n"
    "  '  <div id=\"@@@P-L,A#TZHALTER@@@_title\" class=\"div_text div_windowTitle\"></div>\\n' +\n"
    "  '  <div id=\"@@@P-L,A#TZHALTER@@@_content\" class=\"div_windowContent\">\\n' +\n"
    "  '  </div>\\n' +\n"
    "  '</div>\\n' +\n"
    "  '';\n"
    "\n"
    "  this.contentJS = \"\" +\n"
    "  \"  _content = document.getElementById('@@@P-L,A#TZHALTER@@@_content');\\n\" +\n"
    "  \"  document.getElementById('@@@P-L,A#TZHALTER@@@_content').getTheParent()._content = _content;\\n\" +\n"
    "  \"  $(@@@P-L,A#TZHALTER@@@_content).data('name','_content');\\n\" +\n"
    "  \"\";\n"
    "\n"
    "  this.contentJQuery = \"\" +\n"
    "  \"  $('#@@@P-L,A#TZHALTER@@@').draggable();\\n\" +\n"
    "  \"  $('#@@@P-L,A#TZHALTER@@@').on('drag', function(event,ui) {    $(this).triggerHandler('ony',ui.position.top);    $(this).triggerHandler('onx',ui.position.left);  });\\n\" +\n"
    "  \"  $('#@@@P-L,A#TZHALTER@@@').on('dragstop', function(event,ui) {    $(this).triggerHandler('ony',ui.position.top);    $(this).triggerHandler('onx',ui.position.left);  });\\n\" +\n"
    "  \"\";\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    // window ist ein JS-Objekt... alle extends='window' werden nach basewindow umgeleitet
    //"///////////////////////////////////////////////////////////////\n"
    //"//  class = window (native class)                            //\n"
    //"///////////////////////////////////////////////////////////////\n"
    //"var window = function(textBetweenTags) {\n"
    //"  if(typeof(textBetweenTags) === 'undefined')\n"
    //"    textBetweenTags = '';\n"
    //"\n"
    //"  this.name = 'window';\n"
    //"  this.inherit = new basewindow(textBetweenTags);\n"
    //"\n"
    //"  this.defaultplacement = '';\n"
    //"}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = button (native class)                            //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.button = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'button';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.attributeNames = [\"text\"];\n"
    "  this.attributeValues = [textBetweenTags];\n"
    "\n"
    "  this.defaultplacement = '';\n"
    "\n"
    "  this.contentHTML = '<button type=\"button\" id=\"@@@P-L,A#TZHALTER@@@\" class=\"input_standard\" style=\"\">'+textBetweenTags+'</button>';\n"
    "\n"
    "  this.contentLeadingJSHead = '';\n"
    "\n"
    "  this.contentJSHead = '';\n"
    "\n"
    "  this.contentJS = '';\n"
    "\n"
    "  this.contentLeadingJQuery = ''\n"
    "\n"
    "  this.contentJQuery = '';\n"
    "\n"
    "  this.test1 = function () { // Intern definierte Methode\n"
    "    return 'I am ' + this.name;\n"
    "  };\n"
    "};\n"
    "oo.button.prototype.test2 = function() {}; // extern definierte Methode\n"
    "oo.button.prototype.test3 = 2; // extern definierte Variable\n"
    "oo.button.test4 = function() {}; // extern definierte Methode an einzelnes Objekt\n"
    "oo.button.test5 = 2; // extern definierte Variable an einzelnes Objekt\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = basebutton (native class)                        //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.basebutton = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'basebutton';\n"
    "  this.inherit = new oo.basecomponent();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.defaultplacement = '';\n"
    "\n"
    "  this.contentHTML = '';\n"
    "\n"
    "  this.contentLeadingJSHead = '';\n"
    "\n"
    "  this.contentJSHead = '';\n"
    "\n"
    "  this.contentJS = '';\n"
    "\n"
    "  this.contentLeadingJQuery = ''\n"
    "\n"
    "  this.contentJQuery = '';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = baselistitem (native class)                      //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.baselistitem = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'baselistitem';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.selfDefinedAttributes = { selected:false }\n"
    "\n"
    "  this.contentHTML = '<option id=\"@@@P-L,A#TZHALTER@@@\">'+textBetweenTags+'</option>';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = textlistitem (native class)                      //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.textlistitem = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'textlistitem';\n"
    "  this.inherit = new oo.listitem();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.contentHTML = '';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = listitem (native class)                          //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.listitem = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'listitem';\n"
    "  this.inherit = new oo.baselistitem();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.contentHTML = '';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = basecombobox (native class)                      //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.basecombobox = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'basecombobox';\n"
    "  this.inherit = new oo.baseformitem();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.selfDefinedAttributes = { editable:true }\n"
    "\n"
    "  this.contentHTML = '<select id=\"@@@P-L,A#TZHALTER@@@\" class=\"select_standard\"></select>';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = baseformitem (native class)                      //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.baseformitem = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'baseformitem';\n"
    "  this.inherit = new oo.basevaluecomponent();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.selfDefinedAttributes = { changed:false, ignoreform:false, rollbackvalue:null, submit:this.inherit.inherit.selfDefinedAttributes.enabled, submitname:'', value:null }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = basevaluecomponent (native class)                //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.basevaluecomponent = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'basevaluecomponent';\n"
    "  this.inherit = new oo.basecomponent();\n"
    "\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  this.selfDefinedAttributes = { type:'none', value:null }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "};\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = basecomponent (native class)                     //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.basecomponent = function(textBetweenTags) {\n"
    "  if(typeof(textBetweenTags) === 'undefined')\n"
    "    textBetweenTags = '';\n"
    "\n"
    "  this.name = 'basecomponent';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    //"  // Ob dann das hier raus kann? Dafür unten die selfdefinedAttributes ja\n"
    //"  //  -> Es MUSS sogar raus, sonst wird es doppelt ausgewertet\n
    //"  this.attributeNames = ['doesenter','enabled','hasdefault','isdefault','style','styleable','text'];\n"
    //"  this.attributeValues = [false,true,false,false,null,true,''];\n"
    "  this.attributeNames = [];\n"
    "  this.attributeValues = [];\n"
    "\n"
    "  // ich muss mehr mit den selfDefinedAttributes arbeiten!\n"
    "  this.selfDefinedAttributes = { doesenter:false, enabled:true, hasdefault:false, isdefault:false, style: null, styleable: true, text: '' }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "};\n"
    "\n";

    js = [js stringByReplacingOccurrencesOfString:@"@@@P-L,A#TZHALTER@@@" withString:ID_REPLACE_STRING];


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

    if ([errorString hasSuffix:@"68"])
    {
        NSLog(@"Z. B. '/ />' am Elementende oder Ampersand (&) im Attribut (NSXMLParserNAMERequiredError) ");
    }

    if ([errorString hasSuffix:@"38"])
    {
        NSLog(@"Kleiner-Zeichen (<) in Attribut (NSXMLParserLessThanSymbolInAttributeError) ");
    }

    if ([errorString hasSuffix:@"5"])
    {
        NSLog(@"XML-Dokument unvollständig geladen bzw Datei nicht vorhanden bzw kein vollständiges XML-Tag enthalten bzw. malformed XML (z. B. kein umschließendes Tag um alles).");
    }

    if ([errorString hasSuffix:@"4"])
    {
        NSLog(@"Keine XML-Daten im Dokument vorhanden! (NSXMLParserEmptyDocumentError).");
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
