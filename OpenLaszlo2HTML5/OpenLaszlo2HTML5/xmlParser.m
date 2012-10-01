//
//  xmlParser.m
//  OpenLaszlo2Canvas
//
//
//
// iwie gibt es noch ein Problem mit den pointer-events (globalhelp verdeckt Foren-Button)
//
//
// 'name' Attribute werden global gemacht. Dies ist aber nicht immer korrekt.
// Ich kann die Zeile die 'name'-Attribute global macht, wohl rausnehmen!
// -> Aber Vorsicht!! Wenn die View auf erster Ebene ist, muss das name-Attribut weiterhin global bleiben!
// http://www.openlaszlo.org/lps4.2/docs/developers/program-development.html Dort 2.2.3
//
//
//
// Eher unwichtig:
// - width/height muss nicht mehr initial auf 'auto' gesetzt werden, seitdem der ganze JS-Code
// in '$(window).load(function()' steckt,
//
//- Eigene Klassen müssen als allererstes und nicht als letztes gecheckt werden (Bsp. 15.14 und 15.15)
// (erst nachdem ich alle ToDos und alle noch nicht selbst ausgewerteten Klassen entfernt habe)
//
//
//
//
// Als Optionen mit anbieten
// - skip build-in-splash-Tag
// - keep comments
// - auswahl ob $swf8 usw. true oder false
// - Schalter für 'Writing Log-File to File-System' (search the 'x' string)
// - Anzahl ausgewertete Elemente anzeigen (self.elementeZaehler)
// - trigger 'oninit' for all elements 'non-blocking' (May increase display time of elements - not suitable in all situations
//   e. g. oninit creates new elements)
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







BOOL ownSplashscreen = NO;


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

@property (strong, nonatomic) NSMutableString *jsInitstageDeferOutput;
@property (strong, nonatomic) NSMutableString *jsToUseLaterOutput;

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

// Für das Element Replicator (wird erst beim schließen angelegt, deswegen Attribut retten)
@property (strong, nonatomic) NSString *nodesAttrOfReplicator;
@property (strong, nonatomic) NSString *collectTheNextIDForReplicator;

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

// "class" muss auch das extends-attribut in den rekursiven Aufruf <evaluateclass> rüberretten,
// damit ich dort darauf reagieren kann (z. B. bei <drawview> der Fall.
@property (strong, nonatomic) NSString *lastUsedExtendsAttributeOfClass;

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

// Gefundene <include>-Tags, die bereits inkludiert wurden (Denn jedes darf nur einmal inkludiert werden,
// auch wenn es mehrmals aufgerufen wird - z. B. bei 'certdatepicker' der Fall im GFlender-Code)
@property (strong, nonatomic) NSMutableArray *allIncludedIncludes;



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
@property (nonatomic) BOOL initStageDefer;
// 'reference'-Variable in einem Handler muss an das korrekte Element gebunden werden
@property (nonatomic) BOOL referenceAttributeInHandler;
@property (nonatomic) BOOL handlerofDrawview;
// 'method'-Variable in einem Handler
@property (strong, nonatomic) NSString *methodAttributeInHandler;

// wenn wir in einem 'state' sind, muss ich oft anders reagieren und zeige Sachen nur an, wenn der 'state' 'applied' ist
@property (strong, nonatomic) NSString *lastUsedNameAttributeOfState;


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

@synthesize jsInitstageDeferOutput = _jsInitstageDeferOutput, jsToUseLaterOutput = _jsToUseLaterOutput;

@synthesize errorParsing = _errorParsing, verschachtelungstiefe = _verschachtelungstiefe, rollUpDownVerschachtelungstiefe = _rollUpDownVerschachtelungstiefe;

@synthesize baselistitemCounter = _baselistitemCounter, idZaehler = _idZaehler, elementeZaehler = _elementeZaehler, element_merker = _element_merker;

@synthesize simplelayout_y = _simplelayout_y, simplelayout_y_spacing = _simplelayout_y_spacing;
@synthesize firstElementOfSimpleLayout_y = _firstElementOfSimpleLayout_y, simplelayout_y_tiefe = _simplelayout_y_tiefe;

@synthesize simplelayout_x = _simplelayout_x, simplelayout_x_spacing = _simplelayout_x_spacing;
@synthesize firstElementOfSimpleLayout_x = _firstElementOfSimpleLayout_x, simplelayout_x_tiefe = _simplelayout_x_tiefe;

@synthesize zuletztGesetzteID = _zuletztGesetzteID;

@synthesize last_resource_name_for_frametag = _last_resource_name_for_frametag, collectedFrameResources = _collectedFrameResources;

@synthesize datasetItemsCounter = _datasetItemsCounter, rollupDownElementeCounter = _rollupDownElementeCounter;

@synthesize animDuration = _animDuration, nodesAttrOfReplicator = _nodesAttrOfReplicator, collectTheNextIDForReplicator = _collectTheNextIDForReplicator, lastUsedTabSheetContainerID = _lastUsedTabSheetContainerID, rememberedID4closingSelfDefinedClass = _rememberedID4closingSelfDefinedClass, defaultplacement = _defaultplacement, lastUsedNameAttributeOfMethod = _lastUsedNameAttributeOfMethod, lastUsedNameAttributeOfClass = _lastUsedNameAttributeOfClass, lastUsedExtendsAttributeOfClass =_lastUsedExtendsAttributeOfClass, lastUsedNameAttributeOfFont = _lastUsedNameAttributeOfFont, lastUsedNameAttributeOfDataPointer = _lastUsedNameAttributeOfDataPointer;

@synthesize allJSGlobalVars = _allJSGlobalVars, allImgPaths = _allImgPaths;

@synthesize allFoundClasses = _allFoundClasses, allIncludedIncludes = _allIncludedIncludes;

@synthesize attributeCount = _attributeCount;

@synthesize issueWithRecursiveFileNotFound = _issueWithRecursiveFileNotFound;

@synthesize weAreInTheTagSwitchAndNotInTheFirstWhen = _weAreInTheTagSwitchAndNotInTheFirstWhen;
@synthesize weAreCollectingTextAndThereMayBeHTMLTags = _weAreCollectingTextAndThereMayBeHTMLTags;
@synthesize weAreInDatasetAndNeedToCollectTheFollowingTags = _weAreInDatasetAndNeedToCollectTheFollowingTags;
@synthesize weAreInRollUpDownWithoutSurroundingRUDContainer = _weAreInRollUpDownWithoutSurroundingRUDContainer;
@synthesize weAreCollectingTheCompleteContentInClass = _weAreCollectingTheCompleteContentInClass;
@synthesize weAreSkippingTheCompleteContentInThisElement = _weAreSkippingTheCompleteContentInThisElement;

@synthesize ignoreAddingIDsBecauseWeAreInClass = _ignoreAddingIDsBecauseWeAreInClass, onInitInHandler = _onInitInHandler, initStageDefer = _initStageDefer, referenceAttributeInHandler = _referenceAttributeInHandler, methodAttributeInHandler = _methodAttributeInHandler, handlerofDrawview = _handlerofDrawview, lastUsedNameAttributeOfState = _lastUsedNameAttributeOfState;




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

        self.jsInitstageDeferOutput = [[NSMutableString alloc] initWithString:@""];
        self.jsToUseLaterOutput = [[NSMutableString alloc] initWithString:@""];

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

        self.last_resource_name_for_frametag = @"";
        self.collectedFrameResources = [[NSMutableArray alloc] init];

        self.animDuration = @"slow";
        self.nodesAttrOfReplicator = nil;
        self.collectTheNextIDForReplicator = @"";
        self.lastUsedTabSheetContainerID = @"";
        self.rememberedID4closingSelfDefinedClass = [[NSMutableArray alloc] init];
        self.defaultplacement = @"";
        self.lastUsedDataset = @"";
        self.lastUsedNameAttributeOfMethod = @"";
        self.lastUsedNameAttributeOfClass = @"";
        self.lastUsedExtendsAttributeOfClass = @"";
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
        self.initStageDefer = NO;
        self.referenceAttributeInHandler = NO;
        self.handlerofDrawview = NO;
        self.methodAttributeInHandler = @"";
        self.lastUsedNameAttributeOfState = @"";

        self.allJSGlobalVars = [[NSMutableDictionary alloc] initWithCapacity:200];
        self.allFoundClasses = [[NSMutableDictionary alloc] initWithCapacity:200];

        self.allIncludedIncludes = [[NSMutableArray alloc] init];

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
        NSArray *r = [NSArray arrayWithObjects:[self.output copy],[self.jsOutput copy],[self.jsOLClassesOutput copy],[self.jQueryOutput0 copy],[self.jQueryOutput copy],[self.jsHeadOutput copy],[self.jsHead2Output copy],[self.cssOutput copy],[self.externalJSFilesOutput copy],[self.allJSGlobalVars copy],[self.allFoundClasses copy],[[NSNumber numberWithInteger:self.idZaehler] copy],[self.defaultplacement copy],[self.jsComputedValuesOutput copy],[self.jsConstraintValuesOutput copy],[self.jsInitstageDeferOutput copy],[self.jsToUseLaterOutput copy],[self.allImgPaths copy],[self.allIncludedIncludes copy], nil];
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




-(NSMutableArray *) getTheDependingVarsOfTheConstraint:(NSString*)s in:(NSString*)currentElem
{
    NSError *error = NULL;


    NSMutableArray *vars = [[NSMutableArray alloc] init];

    s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
    // s = [self removeOccurrencesofBracketsIn:s]; -> Auskommentiert, sonst wachsen JS-Wörter und Variablennamen zusammen


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



    // Now get all var-names, that are left
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

            // Falls ganz vorne jetzt getTheParent() steht, dann muss ich unser aktuelles Element
            // davorsetzen. Weil jetzt nochmal extra mit 'with () {}' zu arbeiten ist wohl nicht nötig
            // da wir ja auf Ebene der einzelnen Variable sind und individuell reagieren können.
            if ([varName hasPrefix:@"getTheParent("])
                varName = [NSString stringWithFormat:@"%@.%@",currentElem,varName];

            // Gefundene reservierte JS-Wörter muss ich an dieser Stelle fallen lassen. Dies sind keine Var-Namen

            // Objektnamen
            if ([varName isEqualToString:@"Boolean"]) continue;
            if ([varName isEqualToString:@"Date"]) continue;
            if ([varName isEqualToString:@"Number"]) continue;
            if ([varName isEqualToString:@"String"]) continue;
            if ([varName isEqualToString:@"Array"]) continue;

            // Funktionsnamen
            if ([varName isEqualToString:@"eval"]) continue;
            if ([varName isEqualToString:@"isNaN"]) continue;
            if ([varName isEqualToString:@"parseFloat"]) continue;
            if ([varName isEqualToString:@"parseInt"]) continue;

            // reservierte Wörter
            if ([varName isEqualToString:@"break"]) continue;
            if ([varName isEqualToString:@"case"]) continue;
            if ([varName isEqualToString:@"catch"]) continue;
            if ([varName isEqualToString:@"continue"]) continue;
            if ([varName isEqualToString:@"default"]) continue;
            if ([varName isEqualToString:@"delete"]) continue;
            if ([varName isEqualToString:@"do"]) continue;
            if ([varName isEqualToString:@"else"]) continue;
            if ([varName isEqualToString:@"false"]) continue;
            if ([varName isEqualToString:@"finally"]) continue;
            if ([varName isEqualToString:@"for"]) continue;
            if ([varName isEqualToString:@"function"]) continue;
            if ([varName isEqualToString:@"if"]) continue;
            if ([varName isEqualToString:@"in"]) continue;
            if ([varName isEqualToString:@"instanceof"]) continue;
            if ([varName isEqualToString:@"new"]) continue;
            if ([varName isEqualToString:@"null"]) continue;
            if ([varName isEqualToString:@"return"]) continue;
            if ([varName isEqualToString:@"switch"]) continue;
            if ([varName isEqualToString:@"throw"]) continue;
            if ([varName isEqualToString:@"true"]) continue;
            if ([varName isEqualToString:@"try"]) continue;
            if ([varName isEqualToString:@"typeof"]) continue;
            if ([varName isEqualToString:@"var"]) continue;
            if ([varName isEqualToString:@"void"]) continue;
            if ([varName isEqualToString:@"while"]) continue;


            // Falls mehrmals auf den gleichen Wert getestet wird (z. B. if (x == 2 || x == 3)
            // brauche (und sollte) ich natürlich auf das 'x' nur einmal horchen.
            if (![vars containsObject:varName])
                [vars addObject:varName];
        }
    }

    return vars;
}




// Alle Aufrufe hier drin leitern weiter zu setAttribute_()
// setAttribute_() wird zur absolutern PRIORITY-Function. Über die läuft alles!
- (void) setTheValue:(NSString *)s ofAttribute:(NSString*)attr
{
    NSLog([NSString stringWithFormat:@"Setting the attribute %@ with the value %@ by jQuery + we watch it, if necessary!",attr,s]);

    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

    [o appendFormat:@"\n  // Setting the Attribute '%@' of '%@' with the value '%@'\n",attr,self.zuletztGesetzteID,s];



    // Example 19.2 - Er sollte die Styles auch so richtig setzen.
    if ([s hasPrefix:@"$style{"])
    {
        return;
    }



    BOOL weNeedQuotes = YES;
    // Das bedeutet wird müssen es noch vor dem DOM ausführen
    if ([s hasPrefix:@"$immediately{"])
    {
        s = [s substringFromIndex:12];


        // Alle Variablen ermitteln, die die zu setzende Variable beeinflussen können...
        NSMutableArray *vars = [self getTheDependingVarsOfTheConstraint:s in:self.zuletztGesetzteID];


        // ...s computable machen...
        s = [NSString stringWithFormat:@"$%@",s];
        s = [self makeTheComputedValueComputable:s];


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

        // Somit ist kein $ mehr davor und er geht automatisch unten richtig rein und setzt die prop ohne constraint
        weNeedQuotes = NO;
    }

    if ([s hasPrefix:@"$once{"])
    {
        s = [s substringFromIndex:5];

        // ...s computable machen...
        s = [NSString stringWithFormat:@"$%@",s];
        s = [self makeTheComputedValueComputable:s];

        // Somit ist kein $ mehr davor und er geht automatisch unten richtig rein und setzt die prop ohne constraint
        weNeedQuotes = NO;
    }

    if ([s hasPrefix:@"$always{"])
    {
        s = [s substringFromIndex:7];

        // Damit er unten richtig reingeht
        s = [NSString stringWithFormat:@"$%@",s];
    }



    BOOL constraintValue = NO;

    if ([s hasPrefix:@"$path{"])
    {
        // Ein relativer Pfad zum vorher gesetzen XPath Ich nehme Bezug zum letzten lastDP_ und dem dort gesetzten Pfad.
        s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
        // Die Variable 'lastDP_' ist bekannt, da die Ausgabe hier in 'jsComputedValuesOutput' erfolgt.
        // Genau da (und kurz vorher) erfolgt auch das setzen von lastDP_
        [o appendFormat:@"  setRelativeDataPathIn(%@,%@,lastDP_,'%@');\n",self.zuletztGesetzteID,s,attr];
    }
    else if ([s hasPrefix:@"$"]) // = 'sure' constraint Value
    {
        constraintValue = YES;


        // Alle Variablen ermitteln, die die zu setzende Variable beeinflussen können...
        NSMutableArray *vars = [self getTheDependingVarsOfTheConstraint:s in:self.zuletztGesetzteID];



        NSString *e = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
        e = [self modifySomeExpressionsInJSCode:e];
        // Escape ' in e
        e = [e stringByReplacingOccurrencesOfString:@"'" withString:@"\\\'"];




        // Wenn wir in einer Klasse sind und state extenden, dann müssen wir einen Doppelsprung
        // bei parent machen. Weil ich den 'state' überspringen muss.
        if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"] && [e hasPrefix:@"getTheParent()."])
        {
            if ([self.lastUsedExtendsAttributeOfClass isEqualToString:@"state"] || [self.lastUsedExtendsAttributeOfClass isEqualToString:@"dragstate"])
            {
                e = [NSString stringWithFormat:@"getTheParent().%@",e];
            }
        }




        [o appendFormat:@"  setInitialConstraintValue(%@,'%@','%@');\n",self.zuletztGesetzteID,attr,e];

        [o appendFormat:@"  // Der zu setzende Wert ist abhängig von %ld woanders gesetzten Variable(n)\n",[vars count]];            
        for (id __strong object in vars)
        {
            // Wenn wir in einer Klasse sind und state extenden, dann müssen wir einen Doppelsprung
            // bei parent machen. Weil ich den 'state' überspringen muss.
            if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"] && [e hasPrefix:@"getTheParent()."])
            {
                if ([self.lastUsedExtendsAttributeOfClass isEqualToString:@"state"] || [self.lastUsedExtendsAttributeOfClass isEqualToString:@"dragstate"])
                {
                    object = [self inString:object searchFor:@"getTheParent()" andReplaceWith:@"getTheParent().getTheParent()" ignoringTextInQuotes:YES];
                }
            }



            [o appendFormat:@"  setConstraint(%@,'%@',\"return (function() { with (%@) { %@.setAttribute_('%@',%@); } }).bind(%@)();\");\n",self.zuletztGesetzteID,object,self.zuletztGesetzteID,self.zuletztGesetzteID,attr,e,self.zuletztGesetzteID];
        }
    }
    else // Übrig bleibt eine ganz normale prop, die gesetzt wird (keine Constraint oder irgendwas)
    {
        if (isJSExpression(s))
            weNeedQuotes = NO;

        if (weNeedQuotes)
            [o appendFormat:@"  %@.setAttribute_('%@','%@');\n",self.zuletztGesetzteID,attr,s];
        else
            [o appendFormat:@"  %@.setAttribute_('%@',%@);\n",self.zuletztGesetzteID,attr,s];
    }



    // 'align' / 'valign' muss darauf warten, dass die Breite / Höhe der Eltern korrekt gesetzt wurde.
    // Kann deswegen erst ganz am Ende ausgewertet werden
    if ([attr isEqualToString:@"align"] || [attr isEqualToString:@"valign"])
    {
        [self.jQueryOutput appendString:o];
    }
    else if (constraintValue)
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
    // Egal welcher String da drin steht, hauptsache nicht canvas
    // Für canvas muss ich bei bestimmten Attributen anders vorgehen
    // insbesondere font-size wird dann global deklariert usw.
    return [self addCSSAttributes:attributeDict toElement:@"xyz"];
}




- (NSMutableString*) addCSSAttributes:(NSDictionary*) attributeDict toElement:(NSString*) elemName
{
    // Alle Styles in einem eigenen String sammeln, könnte nochmal nützlich werden
    NSMutableString *style = [[NSMutableString alloc] initWithString:@""];


    if ([attributeDict valueForKey:@"textalign"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"textalign"] ofAttribute:@"textalign"];
    }

    if ([attributeDict valueForKey:@"textindent"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"textindent"] ofAttribute:@"textindent"];
    }

    if ([attributeDict valueForKey:@"letterspacing"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"letterspacing"] ofAttribute:@"letterspacing"];
    }

    if ([attributeDict valueForKey:@"textdecoration"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"textdecoration"] ofAttribute:@"textdecoration"];
    }

    if ([attributeDict valueForKey:@"multiline"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"multiline"] ofAttribute:@"multiline"];
    }

    if ([attributeDict valueForKey:@"selectable"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"selectable"] ofAttribute:@"selectable"];
    }

    if ([attributeDict valueForKey:@"bgcolor"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"bgcolor"] ofAttribute:@"bgcolor"];
    }

    if ([attributeDict valueForKey:@"rotation"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"rotation"] ofAttribute:@"rotation"];
    }

    if ([attributeDict valueForKey:@"style"]) // Von Basecomponent, aber immer auswerten, damit kein Konflikt mit css-style
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"style"] ofAttribute:@"style"];
    }

    if ([attributeDict valueForKey:@"text_x"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"text_x"] ofAttribute:@"text_x"];
    }

    if ([attributeDict valueForKey:@"text_y"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"text_y"] ofAttribute:@"text_y"];
    }

    if ([attributeDict valueForKey:@"text_padding_x"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"text_padding_x"] ofAttribute:@"text_padding_x"];
    }

    if ([attributeDict valueForKey:@"text_padding_y"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"text_padding_y"] ofAttribute:@"text_padding_y"];
    }

    if ([attributeDict valueForKey:@"fontstyle"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"fontstyle"] ofAttribute:@"fontstyle"];
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

        if ([[attributeDict valueForKey:@"fgcolor"] hasPrefix:@"$"] || [[attributeDict valueForKey:@"fgcolor"] hasPrefix:@"0x"])
        {
            [self setTheValue:[attributeDict valueForKey:@"fgcolor"] ofAttribute:@"fgcolor"];
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
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"valign"] ofAttribute:@"valign"];
    }

    // speichern, falls height schon gesetzt wurde (für Attribut resource)
    BOOL heightGesetzt = NO;
    if ([attributeDict valueForKey:@"height"])
    {
        self.attributeCount++;

        NSLog(@"Setting the attribute 'height' as CSS 'height'.");

        NSString *s = [attributeDict valueForKey:@"height"];

        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:s ofAttribute:@"height"];
        }
        else
        {
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


        if ([s hasPrefix:@"$"])
        {
            [self setTheValue:[attributeDict valueForKey:@"width"] ofAttribute:@"width"];
        }
        else
        {
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
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"align"] ofAttribute:@"align"];
    }

    if ([attributeDict valueForKey:@"clip"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"clip"] ofAttribute:@"clip"];
    }


    if ([attributeDict valueForKey:@"stretches"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"stretches"] ofAttribute:@"stretches"];
    }


    // Damit kann der Ladezeitpunkt von Elementen beeinflusst werden
    // Letzen Endes spielt nur initstage=defer eine Rolle, weil es dann GAR NICHT
    // geladen wird, sondern erst später nach Aufruf von 'completeInstantiation'
    if ([attributeDict valueForKey:@"initstage"])
    {
        self.attributeCount++;

        if ([[attributeDict valueForKey:@"initstage"] isEqual:@"immediate"] ||
            [[attributeDict valueForKey:@"initstage"] isEqual:@"early"] ||
            [[attributeDict valueForKey:@"initstage"] isEqual:@"normal"] ||
            [[attributeDict valueForKey:@"initstage"] isEqual:@"late"])
        {
            NSLog(@"Skipping the attribute 'initstage'.");
        }

        if ([[attributeDict valueForKey:@"initstage"] isEqual:@"defer"])
        {
            [self setTheValue:[attributeDict valueForKey:@"initstage"] ofAttribute:@"initstage"];
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
            // Es ist bei einer lokalen Datei lediglich  ein Hinweis darauf, dass es erst ab run-time geladen werden darf.
            src = [src substringFromIndex:5];
        }



        self.attributeCount++;
        NSString *s = @"";


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
        // ... to think about.
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

            // 2. Bedingung: Damit er dann wenigstens '' setzt, sonst Absturz
            if ([src rangeOfString:@"."].location != NSNotFound || src.length == 0)
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
                [self.jsOutput appendFormat:@"  %@.setAttribute_('frame', %ld);\n",self.zuletztGesetzteID,index+1];
            }




// Dieser Code ist nicht mehr nötig, aber würde auch nichts schaden mit ausgeführt zu werden.
// Es gibt irgendwie noch Probs mit dem Code. Er lädt css-Bilder nicht korrekt beim startup... -> War ein preload-Problem
 
            // Wenn ein Punkt enthalten ist, ist es wohl eine Datei
            if ([src rangeOfString:@"."].location != NSNotFound ||
            // ... Keine Ahnung wo diese Res herkommenen sollen.
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

                // Schutz gegen Leerzeichen im Pfad
                //s = [s stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
                // auskommentiert, weil sonst in 'class calculator (from calculator.lzx)' die Pfade doppelt escaped werden

                NSURL *pathToImg = [NSURL URLWithString:s relativeToURL:path];

                // [NSString stringWithFormat:@"%@%@",path,s];
                NSLog([NSString stringWithFormat:@"Path to Image: %@",pathToImg]);
                NSImage *image = [[NSImage alloc] initByReferencingURL:pathToImg];
                NSSize dimensions = [image size];
                int w = (int)dimensions.width;
                int h = (int)dimensions.height;
                NSLog([NSString stringWithFormat:@"Resolving width of image from original file: %d (setting as CSS-width)",w]);
                NSLog([NSString stringWithFormat:@"Resolving height of Image from original file: %d (setting as CSS-height)",h]);
                if (!widthGesetzt)
                    [style appendFormat:@"width:%dpx;",w];
                if (!heightGesetzt)
                    [style appendFormat:@"height:%dpx;",h];

                // Als Schutz gegen Leerzeichen im Pfad Hochkommata drum herum
                [style appendFormat:@"background-image:url('%@');",s];
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


    [self adjustHeightAndWidthOfElement:self.zuletztGesetzteID];

    return style;
}



- (void) adjustHeightAndWidthOfElement:(NSString*) elemName
{
    if (positionAbsolute == YES)
    {
        // Aus Sicht des umgebenden Divs gelöst.

        NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

        // Bei Windows muss auch der content vergrößert werden
        if ([elemName isEqualToString:@"window"])
        {
            [s appendString:@"\n  // Höhe/Breite des umgebenden Elements u. U. vergrößern\n"];
            [s appendFormat:@"  adjustHeightAndWidth(%@_content_);\n",elemName];
        }

        [s appendString:@"\n  // Höhe/Breite des umgebenden Elements u. U. vergrößern\n"];
        [s appendFormat:@"  adjustHeightAndWidth(%@);\n",elemName];


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
}



// titlewidth hier extra setzen, außerhalb addCSS, titlewidth bezieht sich  immer auf den Text VOR
// einem input-Feld und nicht auf das input-Feld selber.
// @deprecated (sobald alle Klassen ausgewertet werden)
- (NSMutableString*) addTitlewidth:(NSDictionary*) attributeDict
{
    NSMutableString *titlewidth = [[NSMutableString alloc] initWithString:@""];

    if ([attributeDict valueForKey:@"titlewidth"])
    {
        self.attributeCount++;
        NSLog(@"Setting the attribute 'titlewidth' as width for the leading text of the input-field.");

        [titlewidth appendFormat:@"width:%@px;",[attributeDict valueForKey:@"titlewidth"]];
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

    s = [self escapeCDATAChars:[NSString stringWithString:s]];

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


        [self.jsOutput appendString:@"  // All 'name'-attributes can be referenced by its parent Element...\n"];
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
            // Wenn wir in einem 'state' sind, müssen wir nen Extrasprung machen.
            // Aber nur für das DIREKT im 'state' liegende Element
            if (self.lastUsedNameAttributeOfState.length > 0)
            {
                [self.jsOutput appendFormat:@"  ($(document.getElementById('%@').getTheParent()).data('olel') == 'state') ? document.getElementById('%@').getTheParent().getTheParent().%@ = %@ : document.getElementById('%@').getTheParent().%@ = %@;\n",self.zuletztGesetzteID, self.zuletztGesetzteID, name, name, self.zuletztGesetzteID, name, name];
            }
            else
            {
                [self.jsOutput appendFormat:@"  document.getElementById('%@').getTheParent().%@ = %@;\n",self.zuletztGesetzteID, name, name];
            }
        }

        //[self.jsOutput appendString:@"  // ...save 'name'-attribute internally, so it can be retrieved by the getter.\n"];
        //[self.jsOutput appendFormat:@"  $(%@).data('name','%@');\n",self.zuletztGesetzteID, name];
        // -> Nicht mehr nötig, weil ich 'name' als HTML5-Annotation setze und somit automatisch in jQuerys data() erscheint

        //[self.jsOutput appendString:@"  // ...and all 'name'-attributes can be referenced by canvas.*\n"];
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
            NSLog([NSString stringWithFormat:@"%ld mal hat ein RegExp gematcht und hat %@ ausgetauscht.",numberOfMatches,f]);
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

    s = [NSString stringWithFormat:@"(function() { with (%@) { return %@; } }).bind(%@)()",self.zuletztGesetzteID,s,self.zuletztGesetzteID];

    return s;
}



- (NSString*) makeTheComputedValueComputable:(NSString*)s withAndBindEquals:(NSString*)scope
{
    s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
    s = [self modifySomeExpressionsInJSCode:s];

    s = [NSString stringWithFormat:@"(function() { with (%@) { return %@; } }).bind(%@)()",scope,s,scope];

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



    // Bevor ich die parents ersetze muss ich das native 'parentNode', welches im Code vorkommen kann, retten
    s = [self inString:s searchFor:@"parentNode" andReplaceWith:@"@@@_prentNode_@@@" ignoringTextInQuotes:YES];
    // und 'parentnumber'...
    s = [self inString:s searchFor:@"parentn" andReplaceWith:@"@@@_prentn_@@@" ignoringTextInQuotes:YES];

    s = [self inString:s searchFor:@"immediateparent" andReplaceWith:@"getTheParent(true)" ignoringTextInQuotes:YES];
    // --> Neu als getter gelöst / Ganz neu: Bricht leider jQuery UI...

    s = [self inString:s searchFor:@"parent" andReplaceWith:@"getTheParent()" ignoringTextInQuotes:YES];
    // --> Neu als getter gelöst / Ganz neu: Bricht leider jQuery UI...


    // Und das native 'parentNode' wieder herstellen.
    s = [self inString:s searchFor:@"@@@_prentNode_@@@" andReplaceWith:@"parentNode" ignoringTextInQuotes:YES];
    // und 'parentnumber'...
    s = [self inString:s searchFor:@"@@@_prentn_@@@" andReplaceWith:@"parentn" ignoringTextInQuotes:YES];



    // dataset ist eine interne Property von ECMAScript 5. Keine Property darf so heißen.
    // Mit '.' davor, sonst würde er auch Variablen wie  z. B. 'complexdataset' modifizieren
    s = [self inString:s searchFor:@".dataset" andReplaceWith:@".myDataset" ignoringTextInQuotes:YES];


    // Ich kann die andere Beudeutung von 'value' (insb. bei checkbox) in OL nicht in JS überschreiben
    s = [self inString:s searchFor:@".value" andReplaceWith:@".myValue" ignoringTextInQuotes:YES];

    // classroot taucht nur in Klassen auf und bezeichnet die Wurzel der Klasse
    if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
        s = [self inString:s searchFor:@"classroot" andReplaceWith:ID_REPLACE_STRING ignoringTextInQuotes:YES];


    // Diese Doppelpunkt-Syntax muss weg... omg... Wieso kann man sich nicht an ECMAScript-Standards halten?
    // Damit sollen wohl Variablen typisiert werden, dabei ist JS im Grunde typenlos... Hallo?
    s = [self inString:s searchFor:@":FileReference" andReplaceWith:@"" ignoringTextInQuotes:YES];
    s = [self inString:s searchFor:@":Array" andReplaceWith:@"" ignoringTextInQuotes:YES];

    // Was ist das? Eine Art cast-Anweisung? Da wäre ein Mega-RegExp fällig. Erstmal auskommentieren
    s = [self inString:s searchFor:@" cast " andReplaceWith:@"; // cast " ignoringTextInQuotes:YES];


    // super ist nicht erlaubt in JS (reserviert) und gibt es auch noch nicht.
    s = [self inString:s searchFor:@"super" andReplaceWith:@"super_" ignoringTextInQuotes:YES];


    // Remove leading and ending Whitespaces and NewlineCharacters
    s = [s stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return s;
}



- (NSString*) modifySomeCanvasExpressionsInJSCode:(NSString*)s
{
    // und Farbwerte Raus regExpen
    // DIESES DUMME OPENLASZLO hält sich an keine Standards.
    // Jetzt müssen auch noch Hex-Farb-werte in Strings mit Leading '#' gepackt werden
    // Wie ich RegExp liebe....
    NSError *error = NULL;
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"(0x([a-fA-F0-9]{6}))" options:NSRegularExpressionCaseInsensitive error:&error];
    
    NSUInteger numberOfMatches;
    do {
        numberOfMatches = [regexp numberOfMatchesInString:s options:0 range:NSMakeRange(0, [s length])];
        
        if (numberOfMatches > 0)
        {
            NSArray *matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];
            
            // Ein match nach dem anderen, weil sich sonst die range ja verschiebt
            NSRange matchRange = [[matches objectAtIndex:0] range];
            
            NSString *hexWert = [s substringWithRange:matchRange];
            
            NSString *replacement = [NSString stringWithFormat:@"'#%@'",[hexWert substringFromIndex:2]];
            
            s = [s stringByReplacingOccurrencesOfString:hexWert withString:replacement];
        }
    } while (numberOfMatches > 0);


    return s;
}




- (NSString *) somePropertysNeedToBeRenamed:(NSString*)s
{
    if ([s isEqualToString:@"dataset"])
        s = @"myDataset";

    if ([s isEqualToString:@"value"])
        s = @"myValue";

    return s;
}



- (NSString *) protectThisSingleQuotedJavaScriptString:(NSString*)s
{
    // ' und Newlines müssen escaped werden bei JS-Strings, die in ' stehen:
    s = [s stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"];
    s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

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


    if ([attributeDict valueForKey:@"visible"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"visible"] ofAttribute:@"visible"];
    }

    if ([attributeDict valueForKey:@"doesenter"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"doesenter"] ofAttribute:@"doesenter"];
    }

    if ([attributeDict valueForKey:@"enabled"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"enabled"] ofAttribute:@"enabled"];
    }

    //if ([attributeDict valueForKey:@"isdefault"])
    //{
    //    self.attributeCount++;
    //    [self setTheValue:[attributeDict valueForKey:@"isdefault"] ofAttribute:@"isdefault"];
    //}

    if ([attributeDict valueForKey:@"focusable"])
    {
        self.attributeCount++;
        [self setTheValue:[attributeDict valueForKey:@"focusable"] ofAttribute:@"focusable"];
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
            [o appendString:@"\n  // datapath-Attribut mit ':' im String (also ein absoluter XPath).\n"];
            [o appendFormat:@"  setAbsoluteDataPathIn(%@,%@);\n",idName,dp];
        }
        else
        {
            if (!kompiliereSpeziellFuerTaxango)
            {
                [o appendString:@"\n  // Ein relativer Pfad! Dann nehme ich Bezug zum letzten 'lastDP_' und dem dort gesetzten Pfad.\n"];
                [o appendFormat:@"  setRelativeDataPathIn(%@,%@,lastDP_,'text');\n",idName,dp];
            }
        }


        // Auf jeden Fall müssen absolute und relative Datapaths GLEICH ausgegeben werden,
        // weil relative sich ja auf die kurz vorher definierten absoluten beziehen.
        // Diese Analogie gilt wohl auch zum Element 'datapath'.
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
        NSLog(@"Setting the attribute 'clickable' as css 'pointer-events' and 'cursor:pointer'.");

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
    NSLog([NSString stringWithFormat:@"Setting the (attribute 'id' as) HTML-attribute 'id'. Id = '%@'.",self.zuletztGesetzteID]);


    // Erstmal auch dann setzen, wenn wir eine gegebene ID von OpenLaszlo haben, evtl. zu ändern
    self.idZaehler++;

    if ([attributeDict valueForKey:@"id"])
    {
        self.attributeCount++;
        self.zuletztGesetzteID = [attributeDict valueForKey:@"id"];
    }
    else
    {
        self.zuletztGesetzteID = [NSString stringWithFormat:@"element%ld",self.idZaehler];
    }


    // Wenn wir gerade rekursiv eine <class></class> auswerten, darf es keine fixen IDs geben
    // Es handelt sich ja um generelle Klassen. Deswegen hier mit einem Replace-String arbeiten,
    // welcher später beim auslesen der Klasse ersetzt werden muss.
    // (Es sei denn es wurde wirklich vom Benutzer explizit eine ID vergeben)
    if (self.ignoreAddingIDsBecauseWeAreInClass && ![attributeDict valueForKey:@"id"])
        self.zuletztGesetzteID = [NSString stringWithFormat:@"%@_%ld",ID_REPLACE_STRING,self.idZaehler];


    [self.output appendFormat:@" id=\"%@\"",self.zuletztGesetzteID];



    // Ebenfalls noch Elementnamen als HTML5-Annotation adden
    [self.output appendFormat:@" data-olel=\"%@\"",[self.enclosingElements lastObject]];

    // Ebenfalls noch placement als HTML5-Annotation adden
    if ([attributeDict valueForKey:@"placement"])
    {
        self.attributeCount++;
        [self.output appendFormat:@" data-placement=\"%@\"",[attributeDict valueForKey:@"placement"]];
    }

    // Ebenfalls noch ignoreplacement als HTML5-Annotation adden
    if ([attributeDict valueForKey:@"ignoreplacement"])
    {
        self.attributeCount++;
        [self.output appendFormat:@" data-ignoreplacement=\"%@\"",[attributeDict valueForKey:@"ignoreplacement"]];
    }

    // Ebenfalls noch 'name'-Attribut als HTML5-Annotation adden
    if ([attributeDict valueForKey:@"name"])
        [self.output appendFormat:@" data-name=\"%@\"",[attributeDict valueForKey:@"name"]];


    // Falls wir in einem Replicator sind, muss ich wissen welche ID geklont werden soll
    if ([self.collectTheNextIDForReplicator isEqualToString:@"$collectTheID_PLZ$"])
        self.collectTheNextIDForReplicator = self.zuletztGesetzteID;


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

        [self.jsOutput appendFormat:@"%ld", spacing_y];
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
            [self.jsOutput appendString:@"\n  // top-css-Eigenschaft nullen, da ein y-wert gesetzt wurde,\n  // obwohl wir in einem Simplelayout Y sind, welches top automatisch ausrichtet.\n"];
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
            [self.jsOutput appendFormat:@"%ld", spacing_y];
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
            [self.jsOutput appendFormat:@"%ld", spacing_y];
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

        [self.jsOutput appendFormat:@"%ld", spacing_x];
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
            [self.jsOutput appendString:@"\n  // left-css-Eigenschaft nullen, da ein x-wert gesetzt wurde,\n  // obwohl wir in einem Simplelayout X sind, welches left automatisch ausrichtet.\n"];
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
            [self.jsOutput appendFormat:@"%ld", spacing_x];

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
            [self.jsOutput appendFormat:@"%ld", spacing_x];
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

    // Schutz gegen Leerzeichen im Pfad
    relativePath = [relativePath stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

    NSURL *pathToFile = [NSURL URLWithString:relativePath relativeToURL:path];

    // Test ob wir die Datei schin mal vorher eingebunden haben
    if ([self.allIncludedIncludes containsObject:pathToFile])
    {
        NSLog(@"Aborting recursion, because this file already was included");
        return;
    }



    // Alles bereits eingebunde in Array speichern, damit ich ausversehen <includes> doppelt inkludiere
    [self.allIncludedIncludes addObject:pathToFile];

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

    // Die soweit erkannten Klassen müssen auch rekursiv aufgerufenen Dateien bekannt sein!
    [x.allFoundClasses addEntriesFromDictionary:self.allFoundClasses];

    // Die soweit inkludierten <includes> müssen auch rekursiv aufgerufenen Dateien bekannt sein!
    x.allIncludedIncludes = [[NSMutableArray alloc] initWithArray:self.allIncludedIncludes];

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

        [self.jsInitstageDeferOutput appendString:[result objectAtIndex:15]];
        [self.jsToUseLaterOutput appendString:[result objectAtIndex:16]];

        // Hier adden, weil ich NICHT die Werte aus diesem Array mit an die Rekursions-Stufe übergeben hatte
        [self.allImgPaths addObjectsFromArray:[result objectAtIndex:17]];

        // Hier wieder überschreiben, da ich ja die Werte mit übergeben hatte
        self.allIncludedIncludes = [[NSMutableArray alloc] initWithArray:[result objectAtIndex:18]];
    }

    NSLog(@"Leaving recursion");
}



// Muss rückwärts gesetzt werden, weil die Höhe der Kinder ja bereits bekannt sein muss!
-(void) korrigiereHoeheUndBreiteDesUmgebendenDivBeiSimpleLayoutX:(NSString*)spacing beiElement:(NSString*)elem
{
    NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

    [s appendString:@"\n  // Korrekturen wegen SA X:\n"];
    [s appendFormat:@"  adjustHeightOfEnclosingDivWithHeighestChildOnSimpleLayout(%@);\n",elem];


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
    [s appendFormat:@"  adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX(%@,%@);\n",elem,spacing];


    // An den Anfang des Strings setzen
    // Die Breite und die Höhe muss bekannt sein, bevor das Simplelayout als solches ausgeführt wird!
    // Andererseits muss es nach evtl. klonen (multiple datapaths) kommen, die in ComputeValues stecken.
    // Beispiel 11.3
    // Außerdem muss es vor adjustHeightAndWidth bekannt sein, damit hier diese Korrektur als erstes
    // ausgeführt wird (aufaddieren von children, im Gegensatz zu nur dem breitesten children).
    // Denn SA-Korrekturen haben immer Vorrang vor dem normalen adjustHeightAndWidth().
    [self.jsConstraintValuesOutput insertString:s atIndex:0];
}



// Muss rückwärts gesetzt werden, weil die Breite der Kinder ja bereits bekannt sein muss!
-(void) korrigiereBreiteUndHoeheDesUmgebendenDivBeiSimpleLayoutY:(NSString*)spacing beiElement:(NSString*)elem
{
    NSMutableString *s = [[NSMutableString alloc] initWithString:@""];

    [s appendString:@"\n  // Korrekturen wegen SA Y:\n"];
    [s appendFormat:@"  adjustWidthOfEnclosingDivWithWidestChildOnSimpleLayout(%@);\n",elem];


    // Auch noch die Höhe setzen! (Damit die Angaben im umgebenden Div stimmen). Da sich valign=middle auf
    // die Höhenangabe bezieht, muss diese mit jQueryOutput0 noch vor allen anderen Angaben gesetzt werden.
    [s appendFormat:@"  adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY(%@,%@);\n",elem,spacing];

    // An den Anfang des Strings setzen
    // Die Breite und Höhe muss bekannt sein, bevor das Simplelayout als solches ausgeführt wird!
    // Andererseits muss es nach evtl. klonen (multiple datapaths) kommen, die in ComputeValues stecken.
    // Beispiel 11.3
    // Außerdem muss es vor adjustHeightAndWidth() bekannt sein, damit hier diese Korrektur als erstes
    // ausgeführt wird (aufaddieren von children, im Gegensatz zu nur dem breitesten children).
    // Denn SA-Korrekturen haben immer Vorrang vor dem normalen adjustHeightAndWidth().
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
                [self.enclosingElementsIds addObject:[NSString stringWithFormat:@"%@_%ld",ID_REPLACE_STRING,self.idZaehler+1]];
            }
        }
        else
        {
            [self.enclosingElementsIds addObject:[NSString stringWithFormat:@"element%ld",self.idZaehler+1]];
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
            s = [NSString stringWithFormat:@"%@_content_",s];
        }
    }

    return s;
}



- (void) becauseOfSimpleLayoutXMoveTheChildrenOfElement:(NSString*)elem withSpacing:(NSString*)spacing andAttributes:(NSDictionary*)attributeDict
{
    /*******************/
    // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Größe
    // der beinhaltenden Elemente an.
    // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
    // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
    [self korrigiereHoeheUndBreiteDesUmgebendenDivBeiSimpleLayoutX:spacing beiElement:elem];
    /*******************/


    // Bricht Beispiel 27.6
    // elem = [self korrigiereElemBeiWindow:elem];

    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


    [o appendFormat:@"\n  // Setting a 'simplelayout' (axis:x) in '%@':\n",elem];

    if ([attributeDict valueForKey:@"inset"])
    {
        self.attributeCount++;
        NSLog(@"Using the attribute 'inset' as spacing for the first element.");

        NSString *inset = [attributeDict valueForKey:@"inset"];
        if ([inset hasPrefix:@"$"])
        {
            inset = [self makeTheComputedValueComputable:inset];
        }

        [o appendFormat:@"  setSimpleLayoutXIn(%@,%@,%@);\n",elem,spacing,inset];
    }
    else
    {
        [o appendFormat:@"  setSimpleLayoutXIn(%@,%@);\n",elem,spacing];
    }


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
    /*******************/
    // Das alle Geschwisterchen umgebende Div nimmt leider nicht die Größe
    // der beinhaltenden Elemente an.
    // Alle Tricks haben nichts geholfen, deswegen hier explizit setzen. 
    // Dies ist nötig, damit nachfolgende simplelayouts richtig aufrücken
    [self korrigiereBreiteUndHoeheDesUmgebendenDivBeiSimpleLayoutY:spacing beiElement:elem];
    /*******************/


    // Bricht Beispiel 27.6
    // elem = [self korrigiereElemBeiWindow:elem];

    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


    [o appendFormat:@"\n  // Setting a 'simplelayout' (axis:y) in '%@':\n",elem];

    if ([attributeDict valueForKey:@"inset"])
    {
        self.attributeCount++;
        NSLog(@"Using the attribute 'inset' as spacing for the first element.");

        NSString *inset = [attributeDict valueForKey:@"inset"];
        if ([inset hasPrefix:@"$"])
        {
            inset = [self makeTheComputedValueComputable:inset];
        }

        [o appendFormat:@"  setSimpleLayoutYIn(%@,%@,%@);\n",elem,spacing,inset];
    }
    else
    {
        [o appendFormat:@"  setSimpleLayoutYIn(%@,%@);\n",elem,spacing];
    }


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
    // Beispiel lz.DataNodeMixin: Wenn eine width (und/oder eine height?) gegeben ist, dann ist resize wohl false
    if ([attributeDict valueForKey:@"width"])    
        resize = @"false";
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
            // MUSS derzeit noch rein, sonst verschwindet Schriftzug "Deine Steuererklärung 2011"
            // Ich vermute, weil er sonst bestimmte Simplelayouts nicht richtig berechnen kann (To Check?)
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
    [self.jsHead2Output appendString:@"\n// Dataset wird als XML-Struktur angelegt und in einem JS-String gespeichert.\n"];
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

        if ([elementName isEqualToString:@"b"] ||
            [elementName isEqualToString:@"i"] ||
            [elementName isEqualToString:@"p"] ||
            [elementName isEqualToString:@"pre"] ||
            [elementName isEqualToString:@"u"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendFormat:@"<%@>",elementName];
            return;
        }

        if ([elementName isEqualToString:@"a"] || [elementName isEqualToString:@"img"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);
            [self.textInProgress appendFormat:@"<%@",elementName];
            for (id e in attributeDict)
            {
                // Alle Elemente in 'a' (href) oder 'img' (src usw...) einfach ausgeben
                [self.textInProgress appendFormat:@" %@=\"%@\"",e,[attributeDict valueForKey:e]];
            }
            [self.textInProgress appendString:@">"];
            return;
        }

        if ([elementName isEqualToString:@"font"])
        {
            NSLog([NSString stringWithFormat:@"\nSkipping the Element <%@>, because it's an HTML-Tag", elementName]);

            [self.textInProgress appendFormat:@"<span style=\"float:none;"];
            for (id e in attributeDict)
            {
                // Alle Elemente in 'font' (color usw...) als css ausgeben, da das <font>-tag deprecated ist
                // Bei size muss ich gesondert drauf reagieren. Da die HTML-Logik dahinter eine andere ist
                if ([e isEqualToString:@"size"])
                {
                    [self.textInProgress appendFormat:@"font-size:%@px;",[attributeDict valueForKey:e]];
                }
                else if ([e isEqualToString:@"face"])
                {
                    NSString *v = [attributeDict valueForKey:e];
                    // Falls die font Leerzeichen beinhaltet (z. B. 'Times New Roman', dann Hochkomma drum herum
                    if ([v rangeOfString:@" "].location != NSNotFound)
                        v = [NSString stringWithFormat:@"'%@'",v];

                    [self.textInProgress appendFormat:@"font-family:%@;",v];
                }
                else // 'color' insbesondere
                {
                    [self.textInProgress appendFormat:@"%@:%@;",e,[attributeDict valueForKey:e]];
                }
            }
            [self.textInProgress appendString:@"\">"];
            return;
        }
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


    if (self.weAreCollectingTheCompleteContentInClass)
    {
        // Wenn wir in <class> sind, sammeln wir alles (wird erst später rekursiv ausgewertet)


        // Erst eventuell gefundenen Text hinzufügen
        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Alle '&' und '<' müssen ersetzt werden, sonst meckert der XML-Parser
        s = [self escapeCDATAChars:[NSString stringWithString:s]];
        

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


    NSLog([NSString stringWithFormat:@"\nOpening Element: %@ (Neue Verschachtelungstiefe: %ld)", elementName,self.verschachtelungstiefe]);
    NSLog([NSString stringWithFormat:@"with these attributes: %@\n", attributeDict]);




    if ([elementName isEqualToString:@"window"] ||
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"videoview"] ||
        [elementName isEqualToString:@"radiogroup"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"vbox"] ||
        [elementName isEqualToString:@"state"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"multistatebutton"] ||
        [elementName isEqualToString:@"BDSeditXXX"] ||
        [elementName isEqualToString:@"BDStext"] ||
        [elementName isEqualToString:@"statictext"] ||
        [elementName isEqualToString:@"text"] ||
        [elementName isEqualToString:@"inputtext"] ||
        [elementName isEqualToString:@"button"] ||
        [elementName isEqualToString:@"rollUpDownContainer"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"tabslider"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"tabelement"] ||
        [elementName isEqualToString:@"baselist"] ||
        [elementName isEqualToString:@"list"] ||
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
        // Es kann darauf zugegriffen werden über das Eltern-Element,
        // um es z. B. zu locken oder unzulocken (Example 17.16)
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'name' as 'layout'.");

            NSString *elem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

            [self.jQueryOutput appendString:@"\n  // Layout-Object:\n"];
            [self.jQueryOutput appendFormat:@"  %@.%@ = new lz.layout();\n",elem,[attributeDict valueForKey:@"name"]];

            // Auch intern speichern
            [self.jQueryOutput appendFormat:@"  $(%@).data('layout_',%@.%@);\n",elem,elem,[attributeDict valueForKey:@"name"]];
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


            [self becauseOfSimpleLayoutXMoveTheChildrenOfElement:[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2] withSpacing:spacing andAttributes:attributeDict];
        }
    }






    if ([elementName isEqualToString:@"include"] || [elementName isEqualToString:@"import"])
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
        NSString *href = [attributeDict valueForKey:@"href"];

        if (![href hasSuffix:@".lzx"])
        {
            // Wegen Chapter 15, 3.1
            href = [NSString stringWithFormat:@"%@/library.lzx",href];
        }

        // Diese implizit inkludierten Files, können u. U. auch explizit gesetzt werden. Dann ignorieren.
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


        // Zusätzliche Attribute vom Import-Tag, die ignoriert werden
        if ([attributeDict valueForKey:@"stage"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"name"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"prefix"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"onerror"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"ontimeout"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"onload"])
            [self.jQueryOutput appendFormat:@"  (function() { %@; })();",[attributeDict valueForKey:@"onload"]]; // untested
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
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').css('left','%@px');",[attributeDict valueForKey:@"x"]];

            [self.jQueryOutput appendString:@"\n  // Dann auch Breite des Debug-Fenster anpassen (Elternbreite - Padding - Border - 1 * X\n"];
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').width($('#debugWindow').parent().width()-20-10-1*%@);\n",[attributeDict valueForKey:@"x"]];
        }

        if ([attributeDict valueForKey:@"y"])
        {
            self.attributeCount++;

            [self.jQueryOutput appendString:@"\n  // Debug-Fenster soll eine andere y-Position haben\n"];
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').css('top','%@px');\n",[attributeDict valueForKey:@"y"]];
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

        if ([attributeDict valueForKey:@"fontsize"])
        {
            self.attributeCount++;
            [self.jQueryOutput appendString:@"\n  // Debug-Fenster soll eine andere Schriftgröße haben\n"];
            [self.jQueryOutput appendFormat:@"  $('#debugWindow').setAttribute_('fontsize',%@);\n",[attributeDict valueForKey:@"fontsize"]];
        }
    }



    if ([elementName isEqualToString:@"stylesheet"])
    {
        element_bearbeitet = YES;

        // Text sammeln und beim schließen des Tags auslesen
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
        self.lastUsedDataset = name;






        // Alle nachfolgenden Tags in eine eigene Data-Struktur überführen
        // und diese Tags nicht auswerten lassen vom XML-Parser.
        // Aber wieder rückgängig machen in <items>, falls wir darauf stoßen und
        // das dataset also damit strukturiert ist (und nicht mit eigenen Begriffen)!
        // Muss (logischerweise) vor der Rekursion stehen, deswegen steht es hier oben
        self.weAreInDatasetAndNeedToCollectTheFollowingTags = YES;






        // Fals es per src in eigener externer Datei angegeben ist, müssen wir diese auslesen
        if ([attributeDict valueForKey:@"src"])
        {
            NSString *src = [attributeDict valueForKey:@"src"];

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

                // Trotzdem anlegen, damit das Programm nicht laufend abstürzt. - aber jQueryOutput0, weil Zugriff auf 'canvas' und/oder canvas.coDataserver nicht klappt
                [self.jQueryOutput0 appendString:@"\n  // Ein Dataset, welches per Request aus der Wolke gefüllt wird. Ich speichere den Link mal in 'src'.\n"];
                [self.jQueryOutput0 appendFormat:@"  %@ = new lz.dataset('%@'); // muss vom Typ dataset sein, damit er auf die Methode 'setQueryParam' z. B. zugreifen kann\n",self.lastUsedDataset, self.lastUsedDataset];

                if ([src hasPrefix:@"$"])
                {
                    // src = [self makeTheComputedValueComputable:src]; // <-- klappt nicht, weil dataset keine 'id' hat
                    src = [self removeOccurrencesOfDollarAndCurlyBracketsIn:src];
                    [self.jQueryOutput0 appendFormat:@"  %@.src = %@;\n",self.lastUsedDataset, src];
                }
                else
                {
                    [self.jQueryOutput0 appendFormat:@"  %@.src = '%@';\n",self.lastUsedDataset, src];
                }
            }
            else
            {
                if ([src hasPrefix:@"http://"])
                {
                    NSLog([NSString stringWithFormat:@"'src'-Attribute in dataset found! But it is starting with 'http://'. So I am loading the XML-File (%@) into a string.",src]);

                    [self.jsHead2Output appendString:@"\n// Externe XML-Datei wird als XML-Struktur ausgelesen und in einem JS-String gespeichert.\n"];
                    [self.jsHead2Output appendFormat:@"var %@ = new lz.dataset('%@');\n",self.lastUsedDataset,self.lastUsedDataset];
                    [self.jsHead2Output appendFormat:@"%@.rawdata = (new XMLSerializer()).serializeToString(getXMLDocumentFromFile('%@'));\n",self.lastUsedDataset,src];

                    // Alle 'äußeren' Datasets stecken auch in 'canvas' (aber 'canvas' ist erst nach DOM bekannt, deswegen jsOutput
                    [self.jsOutput appendString:@"  // datasets außerhalb von Klassen sind auch in canvas verankert\n"];
                    [self.jsOutput appendFormat:@"  canvas.%@ = %@;\n",self.lastUsedDataset,self.lastUsedDataset];
                }
                else
                {
                    NSLog([NSString stringWithFormat:@"'src'-Attribute in dataset found! So I am calling myself recursive with the file %@",src]);

                    [self legeDatasetAnUndInitMitOeffnendemTag];

                    [self callMyselfRecursive:src];

                    // Oh man, was ein Bug... Und natürlich noch das letzte schleßende 'dataset'-Tag anfügen,
                    // damit es keine parser-error beim Einlesen des XML-Strings gibt
                    [self.jsHead2Output appendFormat:@"%@.rawdata += '</%@>';\n",self.lastUsedDataset,self.lastUsedDataset];
                }
            }

            // Nach dem Verlassen der Rekursion müssen wir nicht länger ein Dataset auswerten
            self.weAreInDatasetAndNeedToCollectTheFollowingTags = NO;
        }
        else
        {
            [self legeDatasetAnUndInitMitOeffnendemTag];
        }
    }



    if ([elementName isEqualToString:@"replicator"])
    {
        element_bearbeitet = YES;

        // Früher hatte ich hier ein <div>, aber gemäß Code-Inspektion ohne DIV und würde auch Layouts brechen

        // Gemäß Tests: Immer nur das erste Element in einem <replicator> wird repliziert.
        // Deswegen brauche ich die nächste ID, die auftaucht. Und dieses Element (und alle Unterelemente) werden geklont


        NSString *nodes = @"";
        if ([attributeDict valueForKey:@"nodes"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'nodes' as argument for the replicator");

            nodes = [attributeDict valueForKey:@"nodes"];

            nodes = [self removeOccurrencesOfDollarAndCurlyBracketsIn:nodes];
        }

        self.nodesAttrOfReplicator = nodes;

        self.collectTheNextIDForReplicator = @"$collectTheID_PLZ$";
    }



    if ([elementName isEqualToString:@"datapointer"])
    {
        element_bearbeitet = YES;

        // Sammeln der Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


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
            [o appendString:@"\n  // Ein Datapointer (bewusst ohne var, damit global verfügbar)\n"];
            [o appendFormat:@"  %@ = new lz.datapointer(%@);\n",name,dp];
        }
        else
        {
            name = @"pointerWithoutName";

            [o appendString:@"\n  // Ein Datapointer ohne 'name'- oder 'id'-Attribut. Wohl nur um ein Handler daran zu binden oder so... hmmm\n"];
            [o appendFormat:@"  %@ = new lz.datapointer(%@);\n",name,dp];
        }

        // Falls gleich eine Methode kommt, die sich an diesen Pointer binden möchte
        self.lastUsedNameAttributeOfDataPointer = name;

        [self addJSCode:attributeDict withId:name];

        // Weil Methoden darauf zugreifen, deswegen muss der Datapointer vorher bekannt sein
        // Und damit Methoden sich daran binden können (Beispiel 11.4).
        [self.jQueryOutput0 appendString:o];
    }



    if ([elementName isEqualToString:@"datapath"])
    {
        element_bearbeitet = YES;

        NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        // Nicht zwingen nötig dieses Attribut... Aber was dann? ...
        if ([attributeDict valueForKey:@"xpath"])
            self.attributeCount++;


        NSString *dp;
        if ([attributeDict valueForKey:@"xpath"])
        {
            dp = [attributeDict valueForKey:@"xpath"];

            if ([dp hasPrefix:@"$"])
                dp = [self makeTheComputedValueComputable:dp];
            else
                dp = [NSString stringWithFormat:@"'%@'",dp];
        }
        else
        {
            dp = @""; // ... hmmm ...
        }



        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

        if ([dp rangeOfString:@":"].location != NSNotFound)
        {
            [o appendString:@"\n  // datapath-Attribut mit ':' im String (also ein absoluter XPath).\n"];
            [o appendFormat:@"  setAbsoluteDataPathIn(%@,%@);\n",idUmgebendesElement,dp];
        }
        else if (dp.length == 0)
        {
            ; // ...dann mache ich erstmal nichts.
        }
        else
        {

            [o appendString:@"\n  // Ein relativer Pfad! Dann nehme ich Bezug zum letzten 'lastDP_' und dem dort gesetzten Pfad.\n"];
            [o appendFormat:@"  setRelativeDataPathIn(%@,%@,lastDP_,'text');\n",idUmgebendesElement,dp];
        }

        // Auf jeden Fall müssen absolute und relative Datapaths GLEICH ausgegeben werden,
        // weil relative sich ja auf die kurz vorher definierten absoluten beziehen.
        // Diese Analogie gilt wohl auch zum Attribut 'datapath'.
        [self.jsComputedValuesOutput appendString:o];
    }



    if ([elementName isEqualToString:@"videoview"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<video"];

        [self addIdToElement:attributeDict];

        // width und height werden beim HTML5-video-tag gesondert parallel zu CSS und ohne px-Angabe gesetzt.
        if ([attributeDict valueForKey:@"width"])
        {
            [self.output appendFormat:@" width=\"%@\"",[attributeDict valueForKey:@"width"]];
        }
        if ([attributeDict valueForKey:@"height"])
        {
            [self.output appendFormat:@" height=\"%@\"",[attributeDict valueForKey:@"height"]];
        }

        if ([attributeDict valueForKey:@"autoplay"])
        {
            self.attributeCount++;

            [self.output appendString:@" autoplay=\"autoplay\""];
        }

        [self.output appendString:@" controls=\"controls\" class=\"div_standard noPointerEvents\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

        if ([attributeDict valueForKey:@"url"])
        {
            self.attributeCount++;

            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
            [self.output appendFormat:@"<source src=\"%@\" type=\"video/mp4\" />\n",[attributeDict valueForKey:@"url"]];
            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
            [self.output appendFormat:@"<source src=\"%@\" type=\"video/ogg\" />\n",[attributeDict valueForKey:@"url"]];
            [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
            [self.output appendString:@"Your browser does not support HTML5 (video-tag).\n"];
        }

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"</video>\n"];


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];


        if ([attributeDict valueForKey:@"type"])
            self.attributeCount++;
    }



    if ([elementName isEqualToString:@"resource"] || [elementName isEqualToString:@"audio"])
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

            // Die Res 'btn_weiter_up' hat bei GFlender hinten Leerzeichen in der src-Angabe. Dies scheint OL zu tolerien
            src = [src stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            // Aber den mit %20 escapeten String, sonst beschwert sich der HTML5-Validator
            src = [src stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];


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



    if ([elementName isEqualToString:@"attribute"])
    {
        element_bearbeitet = YES;


        if (![attributeDict valueForKey:@"name"])
            [self instableXML:@"ERROR: No attribute 'name' given in attribute-tag"];
        else
            self.attributeCount++;


        NSString* a = [attributeDict valueForKey:@"name"];

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
            if (isNumeric([attributeDict valueForKey:@"value"]) || [[attributeDict valueForKey:@"value"] isEqual:@"null"])
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
            // Wenn wir also weder value noch type haben, dann beides setzen
            if (![attributeDict valueForKey:@"type"])
            {
                // Gemäß Bsp. 29.27 muss es hier wohl 'null' sein
                value = @"null"; // 'null' sollte dann natürlich ohne Quotes sein...
                // ... deswegen type_ auf number setzen
                type_ = @"number";
            }
            else
            {
                // value = @""; // Quotes werden dann automatisch unten reingesetzt

                // Wenn bei einer 'expression', 'string', 'number' kein value gesetzt ist, ist es gemäß OL-Test immer undefined
                value = @"undefined";

                // Text vor Example 28.10:
                if ([a isEqualToString:@"text"] && ([type_ isEqualToString:@"text"] || [type_ isEqualToString:@"html"]))
                    value = @"textBetweenTags";
            }
        }



        NSString *elem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];

        // Ein 'state' bewirkt einen Extra-Sprung, da der 'state' selber nicht als Hierachieebene zählt
        if ([elemTyp isEqualToString:@"state"])
        {
            elem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-3];
        }

        if ([elemTyp isEqualToString:@"canvas"] || [elemTyp isEqualToString:@"library"])
        {
            elem = @"canvas";
        }


        // Hier drin sammle ich erstmal alle Ausgaben
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        if ([attributeDict valueForKey:@"setter"])
        {
            NSLog(@"Setting the attribute 'setter' as setter for the property of the object.");
            self.attributeCount++;

            NSString *setter = [attributeDict valueForKey:@"setter"];


            /*
            // Ich kann leider nicht NUR einen setter anlegen. Immer analog mit getter nur.
            // Denn getter mappe ich um, dann auf eine interne Variable die ich dafür anlege.
            // Direkt an das Objekt binden, das setter/getter-Paar. Nicht per Prototype (eh Compilerfehler dann)

            [o appendString:@"\n  // Ein setter... \n"];
            [o appendFormat:@"  /////////////////////////////////////////////////////////\n"];
            [o appendFormat:@"  // Getter/Setter for '%@'\n",a];
            [o appendFormat:@"  // READ/WRITE\n"];
            [o appendFormat:@"  /////////////////////////////////////////////////////////\n"];
            [o appendFormat:@"  Object.defineProperty(%@, '%@', {\n",elem,a];
            [o appendFormat:@"      get : function(){ return 99; },\n"];
            NSString *arg = [setter substringFromIndex:[setter rangeOfString:@"("].location+1];
            arg = [arg substringToIndex:[arg rangeOfString:@")"].location];
            [o appendFormat:@"      set: function(%@){ this.%@ },\n",arg,setter]; // this MUSS rein
            [o appendFormat:@"      enumerable : false,\n"];
            [o appendFormat:@"      configurable : true\n"];
            [o appendFormat:@"  });\n"];
             */

            // I can't work with REAL JS-setters, else infinite recursion, weil in der setter-Funktion dann Wert gesetzt wird
            // Ich könnte das rausparsen... aber statt dessen einfach eigenen setter erfinden und darauf testen in setAttribute_
            [o appendString:@"\n  // Define a 'setter'... I can't work with real JS-Setters here, else infinite recursion."];
            // Setter können als Methoden angegeben sein (dann taucht eine Klammer im string auf)
            // oder es kann eine direkte Anweisung vorhanden sein
            // (dann taucht eher keine Klammer im String auf)
            if ([setter rangeOfString:@"("].location != NSNotFound)
                setter = [setter substringToIndex:[setter rangeOfString:@"("].location];
            
            [o appendFormat:@"\n  %@.mySetterFor_%@_ = '%@'; \n",elem,a,setter];

            // Und event mitgeben. Gilt wohl eigentlich für alle Attribute, aber noch anders gelöst, da ich in
            // setAtribute_ immer DIREKT triggerHandler aufrufe.
            // Bei settern darf triggerHandler() jedoch nicht automatisch ausgelöst werden. Statt dessen wird es oft
            // in der setAttribute manuell ausgelöst. Mit diesem event schaffe ich die Möglichkeit dazu. S. Bsp. 29.27
            // Vermutlich gilt dies sogar generell für alle Attribute.
            NSString *enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];
            [o appendFormat:@"  // Gleichzeitig <event> für %@ setzen\n",enclosingElem];
            [o appendFormat:@"  %@.on%@ = new lz.event(null,%@,'on%@');\n",enclosingElem, a, enclosingElem, a];
        }


        if ([attributeDict valueForKey:@"when"])
        {
            // Sollte der Standard sein bei Atributen
            if ([[attributeDict valueForKey:@"when"] isEqualToString:@"once"])
            {
                NSLog(@"Skipping the attribute 'when'.");
                self.attributeCount++;
            }

            // Hmmm, dann packe ich mal ${} drum herum, damit er unten korrekt rein geht.
            // Aber das ist noch nicht die ganze Wahrheit. Er legt unten ja iwie keine Constraints an
            if ([[attributeDict valueForKey:@"when"] isEqualToString:@"always"])
            {
                NSLog(@"Using the attribute 'when' to create a constraint value.");
                self.attributeCount++;

                value = [NSString stringWithFormat:@"${%@}",value];
            }
        }



        NSLog([NSString stringWithFormat:@"Setting '%@' as object-attribute in JavaScript-object.",a]);

        BOOL weNeedQuotes = YES;
        if ([type_ isEqualTo:@"boolean"] || [type_ isEqualTo:@"number"]  || [type_ isEqualTo:@"expression"])
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
            // Wenn wir in einer Klasse sind, die von state erbt, ist das Eltern-Element nicht der state,
            // sondern das davon umgebende Element (quasi wie ein Extrasprung)
            if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"] && [self.lastUsedExtendsAttributeOfClass isEqualToString:@"state"])
            {
                value = [self makeTheComputedValueComputable:value withAndBindEquals:[NSString stringWithFormat:@"%@.getTheParent()",elem]];
            }
            else
            {
                value = [self makeTheComputedValueComputable:value withAndBindEquals:elem];
            }

            weNeedQuotes = NO;

            berechneterWert = YES;
        }



        // Wenn wir in einer Klasse sind, alle Attribute der Klasse intern mitspeichern
        // Denn sie müssen bei jedem instanzieren der Klasse mit ihren Startwerten
        // initialisiert werden (Überschreibungen durch Instanzvariablen sind möglich).
        if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
        {
            NSString *className = self.lastUsedNameAttributeOfClass;
            
            if (![self.allFoundClasses objectForKey:className])
                [self instableXML:@"Das geht so nicht. Wenn ich Attribute hinzufüge zu einer Klasse, muss ich vorher auf diese Klasse gestoßen sein!"];

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
                [o appendFormat:@"\n  // Ein per <attribute> gesetztes Attribut von '%@' (Objekttyp: %@)", self.lastUsedDataset, elemTyp];
                [o appendFormat:@"\n  %@.",self.lastUsedDataset];
            }
            else
            {
                [o appendFormat:@"\n  // Ein per <attribute> gesetztes Attribut von '%@' (Objekttyp: %@)", elem, elemTyp];
                [o appendFormat:@"\n  %@.",elem];
            }
            


            [o appendFormat:@"%@ = ",a];
            if (weNeedQuotes)
                [o appendString:@"\""];
            [o appendString:value];
            if (weNeedQuotes)
                [o appendString:@"\""];
            [o appendString:@";\n"];


            // Erstmal nur hier drin. Eventuell aber auch erst nach der geschweiften Klammer
            // Und erstmal nicht, wenn wir in canvas sind (globale Attribute)
            if (berechneterWert)
            {
                NSString *s = [attributeDict valueForKey:@"value"];


                // Alle Variablen ermitteln, die die zu setzende Variable beeinflussen können...
                NSMutableArray *vars = [self getTheDependingVarsOfTheConstraint:s in:elem];


                s = [self removeOccurrencesOfDollarAndCurlyBracketsIn:s];
                s = [self modifySomeExpressionsInJSCode:s];
                // Escape ' in s
                s = [s stringByReplacingOccurrencesOfString:@"'" withString:@"\\\'"];



                [o appendFormat:@"  setInitialConstraintValue(%@,'%@','%@');\n",elem,a,s];

                [o appendFormat:@"  // The constraint value depends on %ld other var(s)\n",[vars count]];            
                for (id object in vars)
                {
                    [o appendFormat:@"  setConstraint(%@,'%@',\"return (function() { with (%@) { %@.setAttribute_('%@',%@); } }).bind(%@)();\"",elem,object,elem,elem,a,s,elem];
                    if ([elemTyp isEqualToString:@"state"])
                    {
                        NSString *idOfState = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];
                        [o appendFormat:@",'.state_%@'",idOfState];
                    }
                    [o appendFormat:@");\n"];
                }
            }


            // War früher mal jsHeadOutput, aber die Elemente sind ja erst nach Instanzierung
            // bekannt, deswegen jQueryOutput0
            // (Damit es noch vor den Computed Values und Constraint Values bekannt ist)
            // Wenn wir ein Attribut von canvas haben, dann so früh wie möglich bekannt machen, da z. B. 'datasets'
            // auf diese Attribute schon zugreifen.
            if ([elemTyp isEqualToString:@"canvas"])
            {
                [self.jsOutput appendString:o];
            }
            else
            {
                if ([elemTyp isEqualToString:@"state"])
                {
                    NSString *idOfState = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

                    // Das erste Newline wieder entfernen...
                    o = [NSMutableString stringWithFormat:@"%@",[o substringFromIndex:1]];
                    // ... und 2 Spaces mehr einrücken.
                    o = [NSMutableString stringWithFormat:@"%@",[self inString:o searchFor:@"  " andReplaceWith:@"    " ignoringTextInQuotes:YES]];

                    NSString *verdoppeltesO = o;

                    o = [NSMutableString stringWithFormat:@"\n  // Einmal Attribut sofort setzen, wenn 'applied'...\n  if (%@.applied) {\n%@",idOfState,verdoppeltesO];
                    [o appendString:@"  }\n"];

                    [o appendString:@"  // ...und einmal bei Änderungen von 'applied' darauf reagieren\n"];
                    // Nochmal 2 Spaces mehr einrücken.
                    verdoppeltesO = [NSMutableString stringWithFormat:@"%@",[self inString:verdoppeltesO searchFor:@"    " andReplaceWith:@"      " ignoringTextInQuotes:YES]];
                    [o appendFormat:@"  $('#%@').on('onapplied',function(a,b) {\n    if (b) {\n%@",idOfState,verdoppeltesO];
                    [o appendFormat:@"    }\n    else {\n      // Von allen Elementen evtl. on's mit diesem namespace entfernen\n      $('.canvas_standard').first().find('*').andSelf().each(function() { $(this).off('.state_%@'); });\n    }\n  });\n",idOfState];


                    [self.jQueryOutput0 appendString:o];
                }
                else
                {
                    [self.jQueryOutput0 appendString:o];
                }
            }
        }





        // 'defaultplacement' wird, falls wir in einer Klasse sind, ausgelesen und gesetzt.
        // Das ist evtl. nicht mehr nötig, seitdem ich ALLE Attribute einer Klasse auslese
        // Aber wegen Zugriff auf obj.inherit.defaultplacement noch drin (Bei entfernen von defaultplacement, müsste man
        // auf das selfDefinedAttributes-Objekt zugreifen, und schauen ob da drin eine var 'defaultplacement' steckt)
        // hmm, ich schreibe jetzt nicht mehr vor der klasse, sondern erst am Anfang von interpretObject (bzw. teils/teils)
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

        // Die Res 'btn_weiter_up' hat bei GFlender hinten Leerzeichen in der src-Angabe. Dies scheint OL zu tolerien
        src = [src stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        // Aber den mit %20 escapeten String, sonst beschwert sich der HTML5-Validator
        src = [src stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

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
        [self.output appendFormat:@"<div id=\"%@_content_\" class=\"div_windowContent\">\n", self.zuletztGesetzteID];

        if ([attributeDict valueForKey:@"height"])
        {
            // Ich muss auch von windowContent die Height anpassen, falls diese gesetzt wurde.
            [self.jQueryOutput appendString:@"\n  // Wenn bei <window> die height gesetzt wurde: Auch vom div_windowContent die Height dann anpassen"];
            [self.jQueryOutput appendFormat:@"\n  $(%@_content_).height(%@-25);\n",self.zuletztGesetzteID, [attributeDict valueForKey:@"height"]];

            title = [attributeDict valueForKey:@"title"];
        }

        if ([attributeDict valueForKey:@"width"])
        {
            // Ich muss auch von windowContent die width anpassen, falls diese gesetzt wurde.
            [self.jQueryOutput appendString:@"\n  // Wenn bei <window> die width gesetzt wurde: Auch vom div_windowContent die width dann anpassen"];
            [self.jQueryOutput appendFormat:@"\n  $(%@_content_).width(%@);\n",self.zuletztGesetzteID, [attributeDict valueForKey:@"width"]];

            title = [attributeDict valueForKey:@"title"];
        }


        if ([attributeDict valueForKey:@"closeable"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'closeable' as closeable window.");
            
            [self.jQueryOutput appendFormat:@"\n  // Window is closeable\n"];
            [self.jQueryOutput appendFormat:@"  %@.setAttribute_('closeable',true);\n",self.zuletztGesetzteID];
        }

        if ([attributeDict valueForKey:@"resizable"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'resizable' as resizable window.");

            [self.jQueryOutput appendFormat:@"\n  // Window is resizable\n"];
            [self.jQueryOutput appendFormat:@"  %@.setAttribute_('resizable',true);\n",self.zuletztGesetzteID];
        }


        [self.jQueryOutput appendFormat:@"\n  // Window is draggable\n"];
        [self.jQueryOutput appendFormat:@"  %@.setAttribute_('allowdrag',true);\n",self.zuletztGesetzteID];


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




    // radiogroup hat ein eingebautes vorbelegtes layout, wenn es nicht überschrieben wird
    if ([elementName isEqualToString:@"radiogroup"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];

        [self.output appendString:@" class=\"div_standard noPointerEvents\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];


        if (![attributeDict valueForKey:@"layout"])
        {
            [self becauseOfSimpleLayoutYMoveTheChildrenOfElement:self.zuletztGesetzteID withSpacing:@"0" andAttributes:attributeDict];
        }

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];
    }




    if ([elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"vbox"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div"];


        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];


        if ([attributeDict valueForKey:@"placement"])
        {
            // Die zugehörige Klasse 'BDSTabSheetContainer' ist in BDSlib.lzx definiert
            // Solange ich BDSTabSheetContainer nicht auswerte, muss ich hier gesondert auf 'placment' reagieren
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
        if ([elementName isEqualToString:@"vbox"])
        {
            NSString *spacing = @"0";
            if ([attributeDict valueForKey:@"spacing"])
            {
                self.attributeCount++;
                spacing = [attributeDict valueForKey:@"spacing"];
            }

            [self becauseOfSimpleLayoutYMoveTheChildrenOfElement:theId withSpacing:spacing andAttributes:attributeDict];
        }
    }




    if ([elementName isEqualToString:@"drawview"])
    {
        element_bearbeitet = YES;

        NSString *canvasWidth = [attributeDict valueForKey:@"width"] ? [attributeDict valueForKey:@"width"] : @"300";
        NSString *canvasHeight = [attributeDict valueForKey:@"height"] ? [attributeDict valueForKey:@"height"] : @"150";

        // Bei constraint, trotzdem erstmal default-werte einsetzen
        // Die eigentliche constraint wird ja unten in 'addCSS' erkannt und dann mit berücksichtigt von setAttribute_()
        if ([canvasWidth hasPrefix:@"$"])
        {
            canvasWidth = @"300";
        }
        if ([canvasHeight hasPrefix:@"$"])
        {
            canvasHeight = @"150";
        }


        // Weil IN canvas gemäß OL noch Elemente liegen können, ein Extra div drum. Gemäß HTML5 geht das nämlich nicht.
        [self.output appendFormat:@"<div class=\"canvas_element noPointerEvents\" style=\"width:%@px;height:%@px;\">\n",canvasWidth,canvasHeight];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"<canvas"];

        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];


        // width und height werden bei HTML5-Canvas gesondert ohne CSS und ohne px-Angabe gesetzt. Warum auch immer
        // Ich lasse die width/height-Angabe parallel unten von CSS auswerten, denke das schadet nicht.
        [self.output appendFormat:@" width=\"%@\"",canvasWidth];
        [self.output appendFormat:@" height=\"%@\"",canvasHeight];



        [self.output appendString:@" class=\"div_standard noPointerEvents\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\"></canvas>\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }




    if ([elementName isEqualToString:@"button"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<button type=\"button\""];

        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];

        // Die font-size in der css-class anzugeben, klappt nicht... Weder unter Webkit noch FF
        // Wegen Beispiel 16.1 font-size von 11px.
        [self.output appendString:@" class=\"input_standard\" style=\"font-size:11px;"];
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


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];

        // Ein Button kann auch HTML-Tags als Beschriftungstext haben
        self.weAreCollectingTextAndThereMayBeHTMLTags = YES;
    }



    if ([elementName isEqualToString:@"vscrollbar"])
    {
        element_bearbeitet = YES;

        NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        // Recht spät setzen, damit es nach einem evtl. Clip ist
        [self.jQueryOutput appendFormat:@"\n  // <vscrollbar>:\n"];
        [self.jQueryOutput appendFormat:@"  $(%@).css('overflow-y','scroll');\n",idUmgebendesElement];
        [self.jQueryOutput appendFormat:@"  $(%@).css('pointer-events','auto');\n",idUmgebendesElement];
    }



    if ([elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"multistatebutton"])
    {
        element_bearbeitet = YES;

        [self.output appendString:@"<div"];

        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];

        [self.output appendString:@" class=\"div_standard\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];


        // ToDo: Wird derzeit nicht ausgewertet - ist zum ersten mal bei einem imgbutton aufgetaucht (nur da?)
        // Imgbutton ist ja auch self defind class....
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'text' for now.");
        }
        if ([attributeDict valueForKey:@"isdefault"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'isdefault' for now.");
        }




        /////////// 'nur'-Multistatebutton-Attribute - To Do //////////////
        if ([attributeDict valueForKey:@"maxstate"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"statelength"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"statenum"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"reference"]) // <- auch basebutton
            self.attributeCount++;

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }




    // ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand
    // der definierten Klasse erkannt werden.
    if ([elementName isEqualToString:@"BDStext"] || [elementName isEqualToString:@"statictext"])
    {
        element_bearbeitet = YES;


        [self.output appendString:@"<div"];

        [self addIdToElement:attributeDict];


        [self.output appendString:@" class=\"div_text noPointerEvents\" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];

        self.weAreCollectingTextAndThereMayBeHTMLTags = YES;
        NSLog(@"We won't include possible following HTML-Tags, because it is content of the text.");

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];

        [self evaluateTextOnlyAttributes:attributeDict];
    }


    // ToDo ToDo ToDo: Eigentlich sollte das hier selbständig hinzugefügt werden und anhand der definierten Klasse erkannt werden
    if ([elementName isEqualToString:@"BDSeditXXX"])
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

        [self.output appendString:@" class=\"input_standard\" style=\""];

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

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];

        [self.output appendString:@"<option"];

        [self addIdToElement:attributeDict];

        if ([attributeDict valueForKey:@"selected"] && [[attributeDict valueForKey:@"selected"] isEqualToString:@"true"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'selected' as 'selected=\"selected\".");

            [self.output appendString:@" selected=\"selected\""];
        }

        [self.output appendString:@" style=\""];




        // datapath-Attribut MUSS zuerst ausgewertet, falls sich Attribut 'text' auf den dort gesetzten Pfad bezieht
        // Andererseits muss Attribut "text_x" wegen Beispiel <textlistitem> vor "text" ausgewertet werden.
        // Mal schauen ob es was bricht, dass die beiden hier mitten drin. Falls ja, dann zurück.
        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",self.zuletztGesetzteID]];

        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' as text between opening and closing tag.");

            // [self.output appendString:[attributeDict valueForKey:@"text"]];
            // Kann nicht direkt gesetzt werden, falls constraint oder $path
            [self setTheValue:[attributeDict valueForKey:@"text"] ofAttribute:@"text"];
        }




        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">"];

        self.baselistitemCounter++;




        if ([attributeDict valueForKey:@"value"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'value' as jQuerys val().");


            NSString* v = [attributeDict valueForKey:@"value"];


            if ([v hasPrefix:@"$path{"])
            {
                // Ein relativer Pfad zum vorher gesetzen XPath Ich nehme Bezug zum letzten lastDP_ und dem dort gesetzten Pfad.
                v = [self removeOccurrencesOfDollarAndCurlyBracketsIn:v];
                // Die Variable 'lastDP_' ist bekannt, da die Ausgabe hier in 'jsComputedValuesOutput' erfolgt.
                // Genau da (und kurz vorher) erfolgt auch das setzen von lastDP_
                [self.jsComputedValuesOutput appendFormat:@"  setRelativeDataPathIn(%@,%@,lastDP_,'%@');\n",self.zuletztGesetzteID,v,@"value"];
            }
            else
            {
                // Muss jQueryOutput0 (nicht jQueryOutput) sein, weil z.B. Constraints den Wert auslesen wollen (Bsp. <combobox>)
                [self.jQueryOutput0 appendFormat:@"\n  // Setting the value of '%@'\n",self.zuletztGesetzteID];
                [self.jQueryOutput0 appendFormat:@"  $('#%@').val(%@);\n",self.zuletztGesetzteID,v];
            }
        }
    }



    if ([elementName isEqualToString:@"BDScombobox"] || // ToDo -  als Klasse auslesen
        [elementName isEqualToString:@"combobox"] ||
        [elementName isEqualToString:@"datacombobox"])
    {
        element_bearbeitet = YES;


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];


        // Umgebendes <div> für die komplette Combobox inklusive Text
        // WOW, dieses vorangehende <br /> als Lösung zu setzen, hat mich 3 Stunden Zeit gekostet...
        // Quatsch, jetzt nach der neuen Lösung.
        [self.output appendString:@"<div class=\"div_combobox\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];



        [self.output appendString:@"<span style=\""];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@"\">"];




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



        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];




        // Jetzt erst haben wir die ID und können diese nutzen für den jQuery-Code
        if (titelDynamischSetzen)
        {
            NSString *code = [attributeDict valueForKey:@"title"];

            code = [self makeTheComputedValueComputable:code];

            [o appendString:@"\n  // combobox-Text wird hier dynamisch gesetzt\n"];
            [o appendFormat:@"  $('#%@').prev().text(%@);\n",theId,code];
        }




        [self.output appendString:@" style=\""];



        // Im Prinzip nur wegen controlwidth
        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

 // ToDo - Auflösen, wenn BDSCheckbox als Klasse ausgewertet
if (![elementName isEqualToString:@"combobox"] && ![elementName isEqualToString:@"datacombobox"])
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


        [o appendFormat:@"\n  // Combobox-content über einen Datapointer auswerten\n"];
        if ([dataset hasPrefix:@"$"])
        {
            // Falls es ein Ausdruck ist, muss ich $,{,} entfernen
            // Ich lasse den Ausdruck dann von JS auswerten
            dataset = [self removeOccurrencesOfDollarAndCurlyBracketsIn:dataset];

            [o appendFormat:@"  var myDp_ = new lz.datapointer(%@+':/items/*[1]');\n",dataset];
        }
        else
        {
            [o appendFormat:@"  var myDp_ = new lz.datapointer('%@:/items/*[1]');\n",dataset];
        }
        [o appendFormat:@"  if (myDp_.isValid())\n"];
        [o appendFormat:@"  {\n"];
        [o appendFormat:@"      do\n"];
        [o appendFormat:@"      {\n"];
        [o appendFormat:@"          $('#%@').append( new Option(myDp_.getNodeText(), myDp_.getNodeAttribute('value') ? myDp_.getNodeAttribute('value') : '') );\n",theId];
        [o appendFormat:@"      }\n"];
        [o appendFormat:@"      while (myDp_.selectNext())\n"];
        [o appendFormat:@"  }\n"];


        // Vorauswahl setzen, falls eine gegeben ist
        if ([attributeDict valueForKey:@"initvalue"])
        {
            self.attributeCount++;

            if ([[attributeDict valueForKey:@"initvalue"] isEqual:@"false"])
            {
                // 'false' heißt wohl es gibt keinen Init-Wert
                // Aber wegen Kirchensteuer-Combobox muss ich trotzdem das erste Element anwählen (keine KiSt-Pflicht)

                [o appendString:@"  // Keine Vorauswahl für diese Combobox getroffen, deswegen erstes Element\n"];
                [o appendFormat:@"  $('#%@ option[value='+",self.zuletztGesetzteID];
                [o appendFormat:@"$('#%@').children('option :first').prop('value')",self.zuletztGesetzteID];
                [o appendString:@"+']').attr('selected',true);\n"];
                [o appendString:@"  // parallel myValue setzen, damit Constraint den defaultwert richtig auslesen kann\n"];
                [o appendFormat:@"  %@.myValue = $('#%@').children('option :first').prop('value');\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
            }
            else
            {
                NSLog(@"Using the attribute 'initvalue' to set a starting value for the combobox.");
                [o appendString:@"  // Vorauswahl für diese Combobox setzen\n"];
                [o appendFormat:@"  $(\"#%@ option[value=",self.zuletztGesetzteID];
                [o appendString:[attributeDict valueForKey:@"initvalue"]];
                [o appendString:@"]\").attr('selected',true);\n"];
                [o appendString:@"  // parallel myValue setzen, damit Constraint den defaultwert richtig auslesen kann\n"];
                [o appendFormat:@"  %@.myValue = $('#%@').children('option[value=%@]').prop('value');\n",self.zuletztGesetzteID,self.zuletztGesetzteID,[attributeDict valueForKey:@"initvalue"]];
            }

        }
        else
        {
            // Trotzdem eine Vorauswahl treffen (erstes Element), sonst testet constraint auf 'undefined'
            [o appendString:@"  // parallel myValue setzen, damit Constraint den defaultwert richtig auslesen kann\n"];
            [o appendFormat:@"  %@.myValue = $('#%@').children('option :first').prop('value');\n",self.zuletztGesetzteID,self.zuletztGesetzteID];
        }
}

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
        if ([attributeDict valueForKey:@"editable"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'editable'.");
        }
        // ToDo
        if ([attributeDict valueForKey:@"defaulttext"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"shownitems"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"searchable"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"itemdatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"textdatapath"])
            self.attributeCount++;
        // ToDo
        if ([attributeDict valueForKey:@"valuedatapath"])
            self.attributeCount++;


        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];


        // Es muss jQueryOutput0 sein, damit die constraints wissen, was der default-wert der combobox ist,
        // da sie darauf testen. Wenn ich den Inhalt der combobox erst danach setze ist es 'undefined'.
        [self.jQueryOutput0 appendString:o];
    }







    // ToDo: Puh, title ist ein selbst erfundenes Attribut von BDScheckbox!
    // Das gibt es nämlich gar nicht laut Doku und Test mit OL-Editor!
    if ([elementName isEqualToString:@"BDScheckbox"] ||
        [elementName isEqualToString:@"checkbox"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        // Bei onclick die this-Abfrage damit es keine unendlichkeits-Schleige gibt, falls man gleichzeitig auch auf
        // den Button oder das span innerhalb des divs kommt
        [self.output appendString:@"<div class=\"div_checkbox\" onclick=\"if (this == event.target) $(this).children(':first').trigger('click');\""];


        [self.output appendString:@" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        [self.output appendString:@"\">\n"];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<input class=\"input_checkbox\" type=\"checkbox\""];

        NSString *theId =[self addIdToElement:attributeDict];

        [self.output appendString:@"/>\n"];





        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<span class=\"div_text\" onclick=\"$(this).prev().trigger('click');\" style=\"top:2px;left:20px;"];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@"\">"];



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


        // Javascript aufrufen hier, für z. B. Visible-Eigenschaften usw.
        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }



    if ([elementName isEqualToString:@"radiobutton"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        [self.output appendString:@"<div class=\"div_checkbox\" onclick=\"if (!$(this).children(':first').is(':disabled')) $(this).children(':first').attr('checked',true);\">\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];


        [self.output appendString:@"<input class=\"input_checkbox\" type=\"radio\""];

        if ([attributeDict valueForKey:@"value"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'value' as 'value' for the radiobutton.");

            [self.output appendFormat:@" value=\"%@\"",[attributeDict valueForKey:@"value"]];
        }

        if ([attributeDict valueForKey:@"selected"] && [[attributeDict valueForKey:@"selected"] isEqualToString:@"true"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'selected' as 'checked=\"checked\".");

            [self.output appendString:@" checked=\"checked\""];
        }

        [self.output appendFormat:@" name=\"%@_radiogroup\"",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2]];

        NSString *theId =[self addIdToElement:attributeDict];


        [self.output appendString:@" style=\""];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\" />\n"];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<span class=\"div_text\">"];

        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Setting the attribute 'text' in <span>-tags after the checkbox.");

            [self.output appendString:[attributeDict valueForKey:@"text"]];
        }

        [self.output appendString:@"</span>\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }



    // ToDo: Bei BDSeditnumber nur Ziffern zulassen als Eingabe inkl. wohl '.' + ','
    if ([elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"])
    {
        element_bearbeitet = YES;

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        if ([attributeDict valueForKey:@"title"])
            [self.output appendString:@"<div class=\"div_textfield\">\n"];
        else
            [self.output appendString:@"<div class=\"div_textfield_ohne_vorangehenden_text\">\n"];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];





        [self.output appendString:@"<span style=\""];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@"\">"];



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
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];

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
        if ([attributeDict valueForKey:@"maxvalue"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'maxvalue'.");
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
        if ([attributeDict valueForKey:@"toobigErrorstring"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'toobigErrorstring'.");
        }
        if ([attributeDict valueForKey:@"toosmallErrorstring"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'toosmallErrorstring'.");
        }
        if ([attributeDict valueForKey:@"plausicheck"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'plausicheck'.");
        }
        if ([attributeDict valueForKey:@"plausiinfo"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'plausiinfo'.");
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




        [self.output appendString:@"<span style=\""];
        [self.output appendString:[self addTitlewidth:attributeDict]];
        [self.output appendString:@"\">"];



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
        [self.output appendString:@"</div>\n"];


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
        if ([attributeDict valueForKey:@"datedays"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'datedays'.");
        }
        if ([attributeDict valueForKey:@"allowfuturedate"]) // ToDo
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'allowfuturedate'.");
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
        [self.output appendString:@"<div class=\"div_slider\" style=\"height:20px;"];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];


        // type bleibt erstmal immer 'range', da 'color als 'type' noch nicht unterstützt wird von den Browsern
        [self.output appendFormat:@"<input type=\"range\""];

        NSString *theId =[self addIdToElement:attributeDict];


        NSString *type  = @"range";
        if ([attributeDict valueForKey:@"type"])
        {
            type = [attributeDict valueForKey:@"type"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'type' as 'type' of the slider.");

            [self.jsOutput appendString:@"\n  // Der 'type' vom Slider muss intern bekannt sein\n"];
            [self.jsOutput appendFormat:@"  $(%@).data('type_','%@');\n",self.zuletztGesetzteID,type];
        }


        NSString *value  = @"50";
        if ([attributeDict valueForKey:@"value"])
        {
            value = [attributeDict valueForKey:@"value"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'value' as 'value' of the slider.");
        }

        NSString *minvalue  = @"0";
        if ([attributeDict valueForKey:@"minvalue"])
        {
            minvalue = [attributeDict valueForKey:@"minvalue"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'minvalue' as 'minvalue' of the slider.");
        }

        // To Check
        if ([attributeDict valueForKey:@"keystep"])
        {
            self.attributeCount++;
        }


        NSString *maxvalue  = @"100";
        if ([attributeDict valueForKey:@"maxvalue"])
        {
            maxvalue = [attributeDict valueForKey:@"maxvalue"];

            self.attributeCount++;
            NSLog(@"Setting the attribute 'maxvalue' as 'maxvalue' of the slider.");

            // Ein Hex-Value wird von Webkit leider nicht erkannt, deswegen dezimal umrechnen
            if ([[attributeDict valueForKey:@"maxvalue"] hasPrefix:@"0x"])
            {
                NSScanner* pScanner = [NSScanner scannerWithString: maxvalue];

                unsigned int iValue;
                [pScanner scanHexInt: &iValue];

                maxvalue = [NSString stringWithFormat:@"%d",iValue];
            }
        }
        [self.output appendString:@" class=\"input_standard\""];


        if ([type isEqualToString:@"color"])
        {
            [self.output appendFormat:@" onchange=\"%@_output.value = this.presentValue();\"",self.zuletztGesetzteID];
        }
        else
        {
            [self.output appendFormat:@" onchange=\"%@_output.value=parseInt(this.value)\"",self.zuletztGesetzteID];
        }

        [self.output appendFormat:@" value=\"%@\" min=\"%@\" max=\"%@\" step=\"1\" />\n",value,minvalue,maxvalue];


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        // id ist Fallback für alte Browser
        [self.output appendFormat:@"<output name=\"%@_output\" id=\"%@_output\" for=\"%@\" style=\"position:absolute;left:150px;top:0px;\"></output>\n",self.zuletztGesetzteID,self.zuletztGesetzteID,self.zuletztGesetzteID];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];
        [self.output appendString:@"</div>\n"];

        [self addJSCode:attributeDict withId:[NSString stringWithFormat:@"%@",theId]];
    }



    if ([elementName isEqualToString:@"whitestyle"] ||
        [elementName isEqualToString:@"silverstyle"] ||
        [elementName isEqualToString:@"bluestyle"] ||
        [elementName isEqualToString:@"greenstyle"] ||
        [elementName isEqualToString:@"goldstyle"] ||
        [elementName isEqualToString:@"purplestyle"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;

            [self.jsOutput appendString:@"\n  // Ein 'style' bekommt einen neuen Namen zugewiesen\n"];
            [self.jsOutput appendFormat:@"  var %@ = %@;\n",[attributeDict valueForKey:@"name"],elementName];
        }
        if ([attributeDict valueForKey:@"isdefault"])
            self.attributeCount++;
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
        breiteVonRollUpDown = (breiteVonRollUpDown - (abstand*2*((int)self.rollUpDownVerschachtelungstiefe-2)));

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
            }

            callback = s;
        }


        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<!-- Die Flipleiste -->\n"];
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"<div style=\"position:relative; top:0px; left:0px; width:"];
        [self.output appendFormat:@"%dpx; height:%dpx; background-color:lightblue; line-height: %dpx; vertical-align:middle;\" class=\"ui-corner-top\" id=\"",breiteVonRollUpDown,heightOfFlipBar, heightOfFlipBar];
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



    if ([elementName isEqualToString:@"tabslider"])
    {
        element_bearbeitet = YES;

        // Hmmm, es klappt nur so: Ein Extra-Div drum herum, dass alle CSS-Angaben aufnimmt.
        // und dann per Option { fillSpace: true } das accordian aufrufen, damit er die Höhe korrekt setzt
        // Die ID bekommt aber das innere div. Äußeres div bleibt id-los.

        [self.output appendString:@"<div class=\"div_tabSlider\""];

        [self.output appendString:@" style=\""];
        [self.output appendString:[self addCSSAttributes:attributeDict]];
        [self.output appendString:@"\">\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        [self.output appendString:@"<div"];
        self.lastUsedTabSheetContainerID = [self addIdToElement:attributeDict];
        [self.output appendString:@">\n"];


        // Hier legen wir den tabslider per jQuery an
        [self.jQueryOutput appendString:@"\n  // Ein tabslider. Angelegt als jQuery UI accordion.\n"];

        [self.jQueryOutput appendFormat:@"  $('#%@').accordion({ fillSpace: true });\n",self.lastUsedTabSheetContainerID];

        [self.jQueryOutput appendString:@"  // Das von jQuery UI gesetzte CSS danach wieder zurück überschreiben.\n"];
        [self.jQueryOutput appendFormat:@"  $('.div_tabElement').css('overflow','hidden');\n"];
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
        int tabwidthForLink = tabwidth - 4*6;
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



    if ([elementName isEqualToString:@"tabelement"])
    {
        element_bearbeitet = YES;


        NSString *title = @"";
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'text' as heading for the tabsheet.");

            title = [attributeDict valueForKey:@"text"];
        }

        [self.output appendFormat:@"<h3 style=\"font-size:10px;\"><a href=\"#\">%@</a></h3>\n",title];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe];

        [self.output appendString:@"<div class=\"div_tabElement\""];

        [self addIdToElement:attributeDict];

        // + 2px, damit sich der Border nicht überschneidet.
        // Gleiche Angabe auch schon in der class, aber wird wohl von jQuery UI überschrieben
        // Auch weitere Angaben sind dafür da, um die jQuery UI-Angaben zu überschreiben
        [self.output appendFormat:@" style=\"%@top:2px;width:inherit;padding:0px;border-color:black;overflow:hidden;\">\n",[self addCSSAttributes:attributeDict]];



        if ([attributeDict valueForKey:@"selected"])
        {
            self.attributeCount++;

            if ([[attributeDict valueForKey:@"selected"] isEqualToString:@"true"])
            {
                // ToDo
                //[self.jQueryOutput appendString:@"\n  // Dieser Tab ist selected\n"];
                //[self.jQueryOutput appendFormat:@"  $('#%@').tabs('select', '#%@');\n",self.lastUsedTabSheetContainerID,geradeVergebeneID];
            }
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
        [self.output appendString:@" style=\"top:50px;width:inherit;height:inherit;"];

        [self.output appendString:[self addCSSAttributes:attributeDict]];

        [self.output appendString:@"\">\n"];


        // ToDo: Wird derzeit nicht ausgewertet
        if ([attributeDict valueForKey:@"info"])
        {
            self.attributeCount++;
            NSLog(@"Skipping the attribute 'info' for now.");
        }



        NSString *title = @"";
        if ([attributeDict valueForKey:@"text"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'text' as heading for the tabsheet.");

            title = [attributeDict valueForKey:@"text"];
        }

        // Das Attribut 'title' hat noch Vorrang und überschreibt u. U. 'text'
        //  solange wir BDStabsheetTaxango gesondert auswerten.
        if ([attributeDict valueForKey:@"title"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'title' as heading for the tabsheet.");

            title = [attributeDict valueForKey:@"title"];
        }


        [self.jQueryOutput appendString:@"\n  // Hinzufügen eines tabsheets in den tabsheetContainer\n"];
        [self.jQueryOutput appendFormat:@"  $('#%@').tabs('add', '#%@', '%@');\n",self.lastUsedTabSheetContainerID,geradeVergebeneID,title];


        if ([attributeDict valueForKey:@"selected"])
        {
            self.attributeCount++;

            if ([[attributeDict valueForKey:@"selected"] isEqualToString:@"true"])
            {
                [self.jQueryOutput appendString:@"\n  // Dieser Tab ist selected\n"];
                [self.jQueryOutput appendFormat:@"  $('#%@').tabs('select', '#%@');\n",self.lastUsedTabSheetContainerID,geradeVergebeneID];
            }
        }
    }



    if ([elementName isEqualToString:@"animatorgroup"])
    {
        element_bearbeitet = YES;

        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

        [o appendString:@"\n  // Eine Animator-Group mit gemeinsamen Attributen für gleich folgende Animationen...\n"];

        if ([attributeDict valueForKey:@"duration"])
        {
            self.attributeCount++;
            [o appendFormat:@"  animatorgroup_.duration = %@;\n",[attributeDict valueForKey:@"duration"]];
        }

        if ([attributeDict valueForKey:@"process"])
        {
            self.attributeCount++;
            [o appendFormat:@"  animatorgroup_.process = '%@';\n",[attributeDict valueForKey:@"process"]];
        }

        if ([attributeDict valueForKey:@"repeat"])
        {
            self.attributeCount++;
            [o appendFormat:@"  animatorgroup_.repeat = %@;\n",[attributeDict valueForKey:@"repeat"]];
        }

        if ([attributeDict valueForKey:@"start"])
        {
            self.attributeCount++;
            [o appendFormat:@"  animatorgroup_.start = %@;\n",[attributeDict valueForKey:@"start"]];
        }

        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            [o appendFormat:@"  animatorgroup_.name = '%@';\n",[attributeDict valueForKey:@"name"]];
        }


        // Muss jsOutput sein, weil da auch die 'animator's drin stecken
        // (Vorsicht: Bei evtl. Änderung auch schließendes Tag beachten)
        [self.jsOutput appendString:o];


        // Erst nach der Ausgabe:
        if ([attributeDict valueForKey:@"name"])
        {
            // Evtl. muss hier eine ähnliche Kaskade sein, wie bei "animator"? (dann auslagern nach 'verankereName...'
            NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];
            [self verankereNameAttribut:[attributeDict valueForKey:@"name"] inElement:idUmgebendesElement animatorgroup:YES];
        }
    }



    if ([elementName isEqualToString:@"animator"])
    {
        element_bearbeitet = YES;


        // Auch bei "state" muss ich derzeit noch nen Extra Sprung machen. Ob sich das ändert, wenn ich "state" auswerte?
        // Nein, es ändert sich nicht! Siehe http://www.openlaszlo.org/lps4.9/docs/developers/states.html 1) 2. Absatz, 2. Satz

        NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];
        // Wenn wir in einer 'animatorgroup' stecken, muss ich einmal extra springen
        if ([[self.enclosingElements objectAtIndex:[self.enclosingElements count]-2] isEqualToString:@"animatorgroup"] ||
            [[self.enclosingElements objectAtIndex:[self.enclosingElements count]-2] isEqualToString:@"state"])
        {
            idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-3];

            // falls 2 verschachtelte, nochmals korrigieren
            if ([[self.enclosingElements objectAtIndex:[self.enclosingElements count]-3] isEqualToString:@"animatorgroup"] ||[[self.enclosingElements objectAtIndex:[self.enclosingElements count]-3] isEqualToString:@"state"])
            {
                idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-4];

                // falls 3 verschachtelte, nochmals korrigieren
                if ([[self.enclosingElements objectAtIndex:[self.enclosingElements count]-4] isEqualToString:@"animatorgroup"] ||
                    [[self.enclosingElements objectAtIndex:[self.enclosingElements count]-4] isEqualToString:@"state"])
                {
                    idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-5];

                    // falls 4 verschachtelte, nochmals korrigieren
                    if ([[self.enclosingElements objectAtIndex:[self.enclosingElements count]-5] isEqualToString:@"animatorgroup"])
                    {
                        idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-6];
                    }
                    // tiefer gehen wir jetzt mal nicht...
                }
            }
        }










        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

        if (![attributeDict valueForKey:@"attribute"])
            [self instableXML:@"animator needs attribute to animate."];
        else
            self.attributeCount++;

        NSString *name = @"animatorWithoutName";
        if ([attributeDict valueForKey:@"name"])
        {
            self.attributeCount++;
            name = [attributeDict valueForKey:@"name"];
        }

        NSString *to = @"0";
        if ([attributeDict valueForKey:@"to"])
        {
            self.attributeCount++;
            to = [attributeDict valueForKey:@"to"];

            to = [self removeOccurrencesOfDollarAndCurlyBracketsIn:to];
        }

        NSString *duration = @"undefined";
        if ([attributeDict valueForKey:@"duration"])
        {
            self.attributeCount++;
            duration = [attributeDict valueForKey:@"duration"];

            duration = [self removeOccurrencesOfDollarAndCurlyBracketsIn:duration];
        }

        NSString *from = @"undefined";
        if ([attributeDict valueForKey:@"from"])
        {
            self.attributeCount++;
            from = [attributeDict valueForKey:@"from"];

            from = [self removeOccurrencesOfDollarAndCurlyBracketsIn:from];
        }

        NSString *target = @"undefined";
        if ([attributeDict valueForKey:@"target"])
        {
            self.attributeCount++;
            target = [attributeDict valueForKey:@"target"];

            target = [self removeOccurrencesOfDollarAndCurlyBracketsIn:target];
        }

        NSString *motion = @"swing";
        if ([attributeDict valueForKey:@"motion"])
        {
            self.attributeCount++;
            motion = [attributeDict valueForKey:@"motion"];

            motion = [self removeOccurrencesOfDollarAndCurlyBracketsIn:motion];
        }

        NSString *relative = @"false";
        if ([attributeDict valueForKey:@"relative"])
        {
            self.attributeCount++;
            relative = [attributeDict valueForKey:@"relative"];

            relative = [self removeOccurrencesOfDollarAndCurlyBracketsIn:relative];
        }

        NSString *start = @"undefined";
        if ([attributeDict valueForKey:@"start"])
        {
            self.attributeCount++;
            start = [attributeDict valueForKey:@"start"];

            start = [self removeOccurrencesOfDollarAndCurlyBracketsIn:start];
        }

        NSString *repeat = @"undefined";
        if ([attributeDict valueForKey:@"repeat"])
        {
            self.attributeCount++;
            repeat = [attributeDict valueForKey:@"repeat"];

            repeat = [self removeOccurrencesOfDollarAndCurlyBracketsIn:repeat];
        }

        [o appendString:@"\n  // Ein Animator\n"];
        [o appendFormat:@"  var %@ = new lz.animator(%@,'%@',%@,%@,%@,%@,'%@',%@,%@,%@,animatorgroup_);\n",name,idUmgebendesElement,[attributeDict valueForKey:@"attribute"],to,duration,from,target,motion,relative,start,repeat];

        // Auch in der umgebenden animatorgroup speichern (falls vorhanden), falls über diese doStart() aufgerufen wird
        if ([[self.enclosingElements objectAtIndex:[self.enclosingElements count]-2] isEqualToString:@"animatorgroup"])
            [o appendFormat:@"  animatorgroup_.animators.push(%@);\n",name];


        // Muss jsOutput sein, damit das 'name'-Attribut gleich am Anfang bekannt ist, weil Methoden darauf zugreifen
        [self.jsOutput appendString:o];


        // Erst nach der Ausgabe!:
        // nur falls 'name' überhaupt gesetzt wurde, deswegen nicht auf die var 'name' testen
        if ([attributeDict valueForKey:@"name"])
        {
            [self verankereNameAttribut:name inElement:idUmgebendesElement animatorgroup:NO];
        }
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

            // Manchmal muss ich wissen von wem die Klasse erbt, z.B. bei <drawview>
            self.lastUsedExtendsAttributeOfClass = [attributeDict valueForKey:@"extends"] ? [attributeDict valueForKey:@"extends"] : @"view";


            // Auserdem speichere ich die gefunden Klasse als JS-Objekt und schreibe es nach
            // collectedClasses.js
            // Die Attribute speichere ich einzeln ab und lese sie durch jQuery aus, sobald sie
            // instanziert wird.


            NSArray *keys_ = [attributeDict allKeys];
            NSMutableArray *keys = [[NSMutableArray alloc] initWithArray:keys_];


            [self.jsOLClassesOutput appendString:@"\n\n"];
            [self.jsOLClassesOutput appendString:@"///////////////////////////////////////////////////////////////\n"];
            [self.jsOLClassesOutput appendFormat:@"// class = %@ (from %@)",name,[self.pathToFile lastPathComponent]];

            for (int i=(42-((int)[name length]+(int)[[self.pathToFile lastPathComponent] length])); i > 0; i--)
            {
                [self.jsOLClassesOutput appendFormat:@" "];
            }

            [self.jsOLClassesOutput appendFormat:@"//\n"];
            [self.jsOLClassesOutput appendString:@"///////////////////////////////////////////////////////////////\n"];
            [self.jsOLClassesOutput appendFormat:@"oo.%@ = function(textBetweenTags) {\n",name];


            [self.jsOLClassesOutput appendFormat:@"  this.name = '%@';\n",name];

            // Das Attribut 'name' brauchen wir jetzt nicht mehr.
            int i = (int)[keys count]; // Test, ob es auch klappt
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
            // Denn manche Abfragen verlassen sich noch auf die Existenz eines Arrays.
            // if ([keys count] > 0)
            {
                // Alle Attributnamen als Array hinzufügen
                [self.jsOLClassesOutput appendString:@"  this.attributeNames = ["];

                int i = 0;
                for (NSString *key in keys)
                {
                    i++;

                    if (i > 1)
                        [self.jsOLClassesOutput appendString:@", "];

                    // Es gibt Attribute mit ' drin, deswegen hier "
                    [self.jsOLClassesOutput appendString:@"\""];
                    [self.jsOLClassesOutput appendString:key];
                    [self.jsOLClassesOutput appendString:@"\""];

                    // Die Attribute werden erst später ausgelesen, deswegen hier hochzählen
                    // Sie werden aktuell ja nicht weiter bearbeitet.
                    self.attributeCount++;
                }

                [self.jsOLClassesOutput appendString:@"];\n"];


                // Und alle Attributwerte als Array hinzufügen
                [self.jsOLClassesOutput appendString:@"  this.attributeValues = ["];

                i = 0;
                for (NSString *key in keys)
                {
                    i++;

                    if (i > 1)
                        [self.jsOLClassesOutput appendString:@", "];

                    // Es gibt Attribute mit ' drin, deswegen hier "
                    if (!isJSExpression([attributeDict valueForKey:key]))
                        [self.jsOLClassesOutput appendString:@"\""];
                    [self.jsOLClassesOutput appendString:[attributeDict valueForKey:key]];
                    if (!isJSExpression([attributeDict valueForKey:key]))
                        [self.jsOLClassesOutput appendString:@"\""];
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


    if ([elementName isEqualToString:@"state"])
    {
        element_bearbeitet = YES;

        // hmm, ich lege es mal als div an, damit ich für states ohne 'name' eine 'id' erzeugen kann
        // (und damit ich alle da drin steckenden views mit einem Schlag visible/invisible schalten kann)

        [self.output appendString:@"<div"];
        // id hinzufügen und gleichzeitg speichern
        NSString *theId = [self addIdToElement:attributeDict];

        [self convertNameAttributeToGlobalJSVar:attributeDict];

        [self.output appendString:@" class=\"div_standard\" >\n"];





        if ([attributeDict valueForKey:@"name"])
        {
            self.lastUsedNameAttributeOfState = [attributeDict valueForKey:@"name"];
        }
        else
        {
            self.lastUsedNameAttributeOfState = theId;
        }

        NSString *applied = @"false"; // Default-Wert
        if ([attributeDict valueForKey:@"applied"])
        {
            self.attributeCount++;

            applied = [attributeDict valueForKey:@"applied"];

            if ([applied hasPrefix:@"$"])
                applied = [self makeTheComputedValueComputable:applied];
        }
        // Muss ich dann so früh wie möglich bekannt geben, ob applied oder nicht, weil nachfolgende Handler usw. darauf achten
        // bzw. sogar es modifizieren (sonst beschwert sich setAttribute es sei noch undeclared)
        [self.jQueryOutput0 appendFormat:@"\n  // %@ repräsentiert einen 'state'...\n",self.zuletztGesetzteID];
        [self.jQueryOutput0 appendFormat:@"  %@.applied = %@;\n",self.zuletztGesetzteID,applied];
        [self.jQueryOutput0 appendString:@"  // ...und initial die Visibility setzen...\n"];
        [self.jQueryOutput0 appendFormat:@"  $('#%@').toggle(%@);\n",self.zuletztGesetzteID,applied];
        [self.jQueryOutput0 appendString:@"  // ...und auf 'onapplied' horchen und Visibility bei Änderung anpassen\n"];
        [self.jQueryOutput0 appendFormat:@"  $('#%@').on('onapplied', function(a,b) { $('#%@').toggle(b); } );\n",self.zuletztGesetzteID, self.zuletztGesetzteID];


        if ([attributeDict valueForKey:@"onremove"])
            self.attributeCount++;

        if ([attributeDict valueForKey:@"pooling"])
            self.attributeCount++;
    }



    // ToDo -  Ein state
    if ([elementName isEqualToString:@"dragstate"])
    {
        element_bearbeitet = YES;

        if ([attributeDict valueForKey:@"name"])
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

    if ([elementName isEqualToString:@"constantlayout"])
    {
        element_bearbeitet = YES;

        NSString *axis = @"y";
        if ([attributeDict valueForKey:@"axis"] && ([[attributeDict valueForKey:@"axis"] isEqualToString:@"x"] || [[attributeDict valueForKey:@"axis"] isEqualToString:@"y"]))
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'axis' of 'constantlayout' to determine the axis.");

            axis = [attributeDict valueForKey:@"axis"];
        }

        NSString *value = @"0";
        if ([attributeDict valueForKey:@"value"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'value' of 'constantlayout' to determine the spacing.");

            value = [attributeDict valueForKey:@"value"];
        }

        NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

        [o appendFormat:@"\n  // Setting a 'constantlayout' in '%@':\n",idUmgebendesElement];
        [o appendFormat:@"  %@.setAttribute_('layout','class:constantlayout;axis:%@;spacing:%@');\n",idUmgebendesElement,axis,value];

        [self.jQueryOutput appendString:o];
    }

    if ([elementName isEqualToString:@"wrappinglayout"])
    {
        element_bearbeitet = YES;

        NSString *axis = @"x"; // 'x' ist hier default!! Nicht y, wie bei anderen Layouts!
        if ([attributeDict valueForKey:@"axis"] && ([[attributeDict valueForKey:@"axis"] isEqualToString:@"x"] || [[attributeDict valueForKey:@"axis"] isEqualToString:@"y"]))
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'axis' of 'constantlayout' to determine the axis.");
            
            axis = [attributeDict valueForKey:@"axis"];
        }

        NSString *spacing = @"0";
        if ([attributeDict valueForKey:@"spacing"])
        {
            self.attributeCount++;
            NSLog(@"Using the attribute 'value' of 'constantlayout' to determine the spacing.");

            spacing = [attributeDict valueForKey:@"spacing"];
        }


        // ToDo
        if ([attributeDict valueForKey:@"yinset"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"xinset"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"xspacing"])
            self.attributeCount++;
        if ([attributeDict valueForKey:@"yspacing"])
            self.attributeCount++;



        NSString* idUmgebendesElement = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-2];

        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

        [o appendFormat:@"\n  // Setting a 'wrappinglayout' in '%@':\n",idUmgebendesElement];
        [o appendFormat:@"  %@.setAttribute_('layout','class:wrappinglayout;axis:%@;spacing:%@');\n",idUmgebendesElement,axis,spacing];

        [self.jQueryOutput appendString:o];
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


            [self.externalJSFilesOutput appendString:@"<script type=\"text/javascript\" src=\""];
            [self.externalJSFilesOutput appendString:[attributeDict valueForKey:@"src"]];
            [self.externalJSFilesOutput appendString:@"\"></script>\n"];
        }
        else
        {
            // JS-Code mit foundCharacters sammeln und beim schließen übernehmen
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



        [self.output appendString:@" class=\"div_text noPointerEvents\" style=\""];

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



                // Es gibt doch tatsächlich Argumente wo explizit der Typ dahinter steht, z. B. in fileUpload im Cancelhandler
                // Da JS typenlos, sinnlos und somit raus damit
                args = [args stringByReplacingOccurrencesOfString:@":IOErrorEvent" withString:@""];
                args = [args stringByReplacingOccurrencesOfString:@":HTTPStatusEvent" withString:@""];
                args = [args stringByReplacingOccurrencesOfString:@":SecurityErrorEvent" withString:@""];
                args = [args stringByReplacingOccurrencesOfString:@":ProgressEvent" withString:@""];
                args = [args stringByReplacingOccurrencesOfString:@":Event" withString:@""];



                // Überprüfen ob es default values gibt im Handler direkt (mit RegExp)...
                NSError *error = NULL;
                NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"([\\w]+)=([\\w']+)" options:NSRegularExpressionCaseInsensitive error:&error];

                NSUInteger numberOfMatches = [regexp numberOfMatchesInString:args options:0 range:NSMakeRange(0, [args length])];

                if (numberOfMatches > 0)
                {
                    NSMutableString *neueArgs = [[NSMutableString alloc] initWithString:@""];

                    // Es kann ja auch eine Mischung geben, von sowohl Argumenten mit
                    // Defaultwerten als auch solchen ohne. Deswegen hier erstmal ohne
                    // Defaultargumente setzen und dann gleich die alle mit.
                    neueArgs = [self holAlleArgumentDieKeineDefaultArgumenteSind:args];

                    NSLog([NSString stringWithFormat:@"There is/are %ld argument(s) with a default argument. I will regexp them.",numberOfMatches]);

                    NSArray *matches = [regexp matchesInString:args options:0 range:NSMakeRange(0, [args length])];

                    for (NSTextCheckingResult *match in matches)
                    {
                        // NSRange matchRange = [match range];
                        NSRange varNameRange = [match rangeAtIndex:1];
                        NSRange defaultValueRange = [match rangeAtIndex:2];

                        NSString *varName = [args substringWithRange:varNameRange];
                        NSLog([NSString stringWithFormat:@"Resulting variable name: %@",varName]);
                        NSString *defaultValue = [args substringWithRange:defaultValueRange];
                        NSLog([NSString stringWithFormat:@"Resulting default value: %@",defaultValue]);

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

        // Extra-Sprung bei 'when' / 'switch' für elem und elemTyp
        int z = 3;
        while ([elemTyp isEqualToString:@"when"] || [elemTyp isEqualToString:@"switch"])
        {
            elem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-z];
            elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-z];
            z++;
        }


        // http://www.openlaszlo.org/lps4.9/docs/reference/ <method> => s. Attribut 'name'
        // Deswegen bei canvas und library 'method' als Funktionen global verfügbar machen
        // UND an canvas binden.
        // Ansonsten 'method' als Methode an das umgebende Objekt koppeln.

        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        [o appendFormat:@"\n  // Ich binde eine Methode an das genannte Objekt (Objekttyp: %@)\n", elemTyp];


        NSString *benutzMich = @""; // Um nur einen s für dataset, datapointer und datapath zu haben
        BOOL wirBrauchenWith = NO;

        if ([elemTyp isEqualToString:@"canvas"] || [elemTyp isEqualToString:@"library"])
        {
            [o appendString:@"  "];
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
            // Und ebenso datapath's... ! (dann eine Ebene weiter zurück springen, um korrektes el zu erwischen)
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
            else if ([elemTyp isEqualToString:@"datapath"])
            {
                benutzMich = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-3];
                [o appendFormat:@"  %@.",benutzMich];
            }
            else
            {
                //if ([elemTyp isEqualToString:@"evaluateclass"]) // Weil ich dort rückwärts auswerte
                //    [o appendFormat:@"  if (%@.%@ == undefined)\n",elem,[attributeDict valueForKey:@"name"]];
                // Unsinn! Ich wärte vorwärts aus! Methoden sollen BEWUSST überschrieben werden


                //NSString *enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];
                // Da ich bei canvas alle handler an den context binde, muss ich, falls in handlern methoden aufgerufen
                // werden, diese auch direkt an den Context binden.
                // Dies gilt auch Falls wir eine Klasse auswerten, die von drawview erbt natürlich.
                //if ([enclosingElemTyp isEqualToString:@"drawview"] || ([enclosingElemTyp isEqualToString:@"evaluateclass"] && [self.lastUsedExtendsAttributeOfClass isEqualToString:@"drawview"]))
                //    [o appendFormat:@"  %@.getContext('2d').",elem];
                //else

                [o appendFormat:@"  %@.",elem];
            }
        }

        [o appendString:[attributeDict valueForKey:@"name"]];
        [o appendFormat:@" = function(%@)\n  {\n",args];
        if (wirBrauchenWith)
        {
            if ([elemTyp isEqualToString:@"dataset"] || [elemTyp isEqualToString:@"datapointer"] || [elemTyp isEqualToString:@"datapath"])
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
        NSString *enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];


        // Extra-Sprung bei 'when' / 'switch' für elem und elemTyp
        int z = 3;
        while ([enclosingElemTyp isEqualToString:@"when"] || [enclosingElemTyp isEqualToString:@"switch"])
        {
            enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-z];
            enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-z];
            z++;
        }


        // Beim Schließen des Tags dann auf den 'canvas' reagieren
        // Falls wir eine Klasse auswerten, die von drawview erbt, muss er natürlich auch richtig darauf reagieren.
        if ([enclosingElemTyp isEqualToString:@"drawview"] || ([enclosingElemTyp isEqualToString:@"evaluateclass"] && [self.lastUsedExtendsAttributeOfClass isEqualToString:@"drawview"]))
        {
            self.handlerofDrawview = YES;
        }




        // ToDo: Per 'jQuery' an 'datapointer' und 'dataset' gebundene Handler machen noch keinen Sinn,
        // da die jQuery-Length 0 ergibt.


        // Bei 'datapointer' brauche ich das name-Attribut
        if ([enclosingElemTyp isEqualToString:@"datapointer"])
        {
            enclosingElem = self.lastUsedNameAttributeOfDataPointer;
        }


        // Bei 'dataset' brauche ich das zuletzt benutzte dataset
        if ([enclosingElemTyp isEqualToString:@"dataset"])
        {
            enclosingElem = self.lastUsedDataset;
        }


        // Bei 'datapath' muss ich einen Extrasprung machen
        if ([enclosingElemTyp isEqualToString:@"datapath"])
        {
            enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-3];
        }



        // Wenn 'reference' gesetzt, dann Bezug nehmen und DARAN binden
        // Aber gleichzeitig muss das aktuelle this erhalten bleiben, deswegen mit bind() arbeiten
        if ([attributeDict valueForKey:@"reference"])
        {
            self.attributeCount++;

            self.referenceAttributeInHandler = YES;

            NSLog(@"Using the referenced element to bind the handler, not the enclosing Element.");

            enclosingElem = [attributeDict valueForKey:@"reference"];
        }




        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];




        [o appendString:@"\n  // pointer-events zulassen, da ein Handler an dieses Element gebunden ist."];
        [o appendFormat:@"\n  $('#%@').css('pointer-events','auto');\n",enclosingElem];

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

            [o appendFormat:@"\n  // onclick-Handler für %@\n",enclosingElem];

            // 'e', weil 'event' würde wohl das event-Objekt zugreifen. Auf dieses kann man so und so zugreifen.
            [o appendFormat:@"  $('#%@').click(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"ondblclick"])
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-dblclick-event.");

            [o appendFormat:@"\n  // ondblclick-Handler für %@\n",enclosingElem];

            // 'e', weil 'event' würde wohl das event-Objekt zugreifen. Auf dieses kann man so und so zugreifen.
            [o appendFormat:@"  $('#%@').dblclick(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onchanged"] ||
            [name isEqualToString:@"onvalue"] ||
            // [name isEqualToString:@"ondata"] || // Lieber als 'Custom'-Handler
            [name isEqualToString:@"onnewvalue"])
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-change-event.");

            [o appendFormat:@"\n  // change-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').change(function(e)\n  {\n    ",enclosingElem];


            // Extra Code, um den alten Value speichern zu können (s. als Erklärung auch
            // unten bei gegebenenem Attribut args)
            if ([name isEqualToString:@"onnewvalue"] ||
                [name isEqualToString:@"onvalue"])
            {
                [o appendString:@"var oldvalue = $(this).data('oldvalue') || '';\n"];
                [o appendString:@"    $(this).data('oldvalue', $(this).val());\n\n    "];
            }

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onerror"] ||
            [name isEqualToString:@"ontimeout"])
        {
            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-error-event.");

            [o appendFormat:@"\n  // error-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').error(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }


        if ( [name isEqualToString:@"oninitToDoDeleteMe"] || [name isEqualToString:@"onconstructToDoDeleteMe"])
        {
            self.attributeCount++;
            // NSLog(@"Binding the method in this handler to a jQuery-load-event.");
            // Nein, load-event gibt es nur bei window (also body und frameset)
            // alles was in init ist einfach direkt ausführen
            // Falls es doch mal das init eines windows (canvas) sein sollte, nicht schlimm,
            // denn wir führen schon von vorne herein den gesamten Code in
            // $(window).load(function() aus!
            // Hmm, seitdem ich alle handler in jQueryOutput0 ausgebe, sind die in der oninit-Methode benutzten Methoden
            // noch nicht alle bekannt. Deswegen neu: Ich lasse es als oninit-Handler und triggere dann 'oninit' später
            NSLog(@"NOT Binding the method in this handler. Direct execution of code.");

            [o appendFormat:@"\n  // oninit/onconstruct-Handler für %@ (wir führen den Code direkt aus)\n  // Aber korrekten Scope berücksichtigen! Deswegen in einer Funktion mit bind() ausführen\n  // Zusätzlich ist auch noch with (this) {} erforderlich.\n",enclosingElem];

            // [o appendFormat:@"  $('#%@').load(function()\n  {\n    ",self.zuletztGesetzteID];
            [o appendFormat:@"  var bindMeToCorrectScope = function () {\n    with (this) {\n        "];


            if ([attributeDict valueForKey:@"args"])
            {
                self.attributeCount++;

                [o appendFormat:@"var %@ = this;\n\n      ",[attributeDict valueForKey:@"args"]];
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

            [o appendFormat:@"\n  // focus-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').focus(function(e)\n  {\n    ",enclosingElem];

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

            [o appendFormat:@"\n  // select-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').select(function(e%@)\n  {\n    ",enclosingElem,args];

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

            [o appendFormat:@"\n  // blur-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').blur(function(e%@)\n  {\n    ",enclosingElem,args];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmousedown"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mousedown-event.");

            [o appendFormat:@"\n  // mousedown-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').mousedown(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmouseup"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mouseup-event.");

            [o appendFormat:@"\n  // mouseup-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').mouseup(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmouseover"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mouseover-event.");

            [o appendFormat:@"\n  // mouseover-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').mouseover(function(e)\n  {\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }

        if ([name isEqualToString:@"onmouseout"])
        {
            [self changeMouseCursorOnHoverOverElement:enclosingElem];

            self.attributeCount++;
            NSLog(@"Binding the method in this handler to a jQuery-mouseout-event.");

            [o appendFormat:@"\n  // mouseout-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').mouseout(function(e)\n  {\n    ",enclosingElem];

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

            [o appendFormat:@"\n  // keyup-Handler für %@\n",enclosingElem];

            // die Variable k wird von OpenLaszlo einfach so benutzt. Das muss der keycode sein.
            [o appendFormat:@"  $('#%@').keyup(function(e)\n  {\n    var k = e.keyCode;\n    var key = e.keyCode;\n\n    ",enclosingElem];

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

            [o appendFormat:@"\n  // keydown-Handler für %@\n",enclosingElem];

            [o appendFormat:@"  $('#%@').keydown(function(e)\n  {\n    var k = e.keyCode;\n    var key = e.keyCode;\n\n    ",enclosingElem];

            alsBuildInEventBearbeitet = YES;

            // Okay, jetzt Text sammeln und beim schließen einfügen
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
            [o appendFormat:@"\n  // 'custom'-Handler für %@\n",enclosingElem];
            [o appendFormat:@"  $('#%@').on('%@',function(e%@)\n  {\n    ",enclosingElem,name,args];

            // Okay, jetzt Text sammeln und beim schließen einfügen
        }


        // Falls ich es ändere: Analog auch beim schließenden Tag ändern!
        // jQueryOutput0! Damit die Handler bekannt sind, bevor diese getriggert werden! (Bsp. 30.3)
        // Problem: Ladezeit verdoppelt sich... weil er dann viel mehr triggern kann... Erst iwie das triggern optimieren
        [self.jQueryOutput appendString:o];


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



        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];
        [o appendFormat:@"\n  // Klasse '%@' wurde instanziert in '%@'",elementName,self.zuletztGesetzteID];


// Die Defaultwerte werden nicht länger vor der Klasse gesetzt, sondern erst in interpretObject
/*
        // Okay, außerdem muss ich alle Variablen der Klasse setzen mit ihren Defaultwerten
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

                // Der Test auf null und undefined bricht bei Strings, die WIRKLICH diese Werte enthalten,
                // aber das nehme ich in Kauf.
                if (isNumeric(value) || isJSArray(value) || [value isEqualToString:@"null"] || [value isEqualToString:@"undefined"])
                    weNeedQuotes = NO;

                // Wegen Beispiel 28.10 => Klassen können auf den Text zwischen den Tags zugreifen, wenn das Attribut text heißt
                // Dann nicht hier ausgeben der Var
                if ([key isEqualToString:@"text"] && [value isEqualToString:@"textBetweenTags"])
                    continue;

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
            [o appendString:@"\n  // Keine Klassen-Attribute vorhanden, die gesetzt werden müssen"];
        }
*/

        // Erst alle Build-in-Attribute raushauen...
        NSMutableDictionary *d = [[NSMutableDictionary alloc] initWithDictionary:attributeDict];
        // CSS
        [d removeObjectForKey:@"id"];
        [d removeObjectForKey:@"name"];
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
        [d removeObjectForKey:@"text_x"];
        [d removeObjectForKey:@"text_y"];
        [d removeObjectForKey:@"text_padding_x"];
        [d removeObjectForKey:@"text_padding_y"];

        // von 'text':
        [d removeObjectForKey:@"text"];
        [d removeObjectForKey:@"textalign"];
        [d removeObjectForKey:@"textindent"];
        [d removeObjectForKey:@"letterspacing"];
        [d removeObjectForKey:@"textdecoration"];
        [d removeObjectForKey:@"multiline"];

        // JS
        [d removeObjectForKey:@"visible"];
        [d removeObjectForKey:@"enabled"];
        [d removeObjectForKey:@"focusable"];
        [d removeObjectForKey:@"layout"];
        [d removeObjectForKey:@"oninit"];
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
        [d removeObjectForKey:@"placement"]; // Neu hinzugefügt
        [d removeObjectForKey:@"ignoreplacement"];

        /* [d removeObjectForKey:@"value"]; Auskommentieren, bricht sonst Beispiel <basecombobox> */


        // Really Build-In-Values??
        [d removeObjectForKey:@"boxheight"];
        [d removeObjectForKey:@"controlwidth"];
        [d removeObjectForKey:@"title"];





        NSMutableString *instanceVars = [[NSMutableString alloc] initWithString:@""];

        // ...dann die übrig gebliebenen Attribute (die von der Instanz selbst definierten) setzen
        if ([d count] > 0)
        {
            // [o appendString:@"\n  // Setzen der Instanz-Variablen, für die nicht die Defaultwerte der Klasse gelten (interpretObject() setzt nur bei hier 'undefined' Werten)"];

            // '__strong', damit ich object modifizieren kann
            for (NSString __strong *key in d)
            {
                self.attributeCount++;

                NSString *s = [d valueForKey:key];

                BOOL weNeedQuotes = YES;

                if (isJSExpression(s))
                    weNeedQuotes = NO;

                // Eventuell sogar in isJSExpression() auslagern?
                if ([s hasPrefix:@"'"] && [s hasSuffix:@"'"])
                    weNeedQuotes = NO;

                if ([s hasPrefix:@"$"])
                {
                    s = [self makeTheComputedValueComputable:s];
                    weNeedQuotes = NO;
                }

                key = [self somePropertysNeedToBeRenamed:key];

                if (weNeedQuotes)
                {
                    // [o appendFormat:@"\n  %@.%@ = '%@';",self.zuletztGesetzteID,key,s];
                    s = [self protectThisSingleQuotedJavaScriptString:s];
                    [instanceVars appendFormat:@"%@ : '%@', ",key,s];
                }
                else
                {
                    // [o appendFormat:@"\n  %@.%@ = %@;",self.zuletztGesetzteID,key,s];
                    [instanceVars appendFormat:@"%@ : %@, ",key,s];
                }
            }

            // Letztes Komma wieder raus und Leerzeichen ran:
            instanceVars = [[NSMutableString alloc] initWithFormat:@"%@ ",[instanceVars substringToIndex:instanceVars.length-2]];

            // [o appendString:@"\n"];
        }


        // Es können ja verschachtelte Klassen auftreten, deswegen muss ich die IDs
        // hier draufpushen, und später wegholen.
        [self.rememberedID4closingSelfDefinedClass addObject:self.zuletztGesetzteID];


        // Okay, jQuery-Code mache ich beim schließen, weil ich erst den eventuellen Text der
        // zwischen den Tags steht, aufsammeln kann, und dann als Parameter übergebe.

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
        [o appendFormat:@"\n  // Instanzvariablen holen, id holen, Instanz erzeugen, Objekt auswerten"];
        [o appendFormat:@"\n  var iv = { %@};",instanceVars];
        [o appendFormat:@"\n  var id = document.getElementById('%@');",idUmgebendesElement];
        [o appendFormat:@"\n  var obj = new oo.%@('');",elementName];

        // [o appendFormat:@"\n  if (jQuery.inArray('defer',obj.attributeValues) == -1)"]; // try 1 --> Ohne Erfolg...
        // [o appendFormat:@"\n  if ($(id).is(':visible'))"]; // try 2 --> Ohne Erfolg, bricht viewlose Elemente (swfso z. B.)

        [o appendString:@"\n  interpretObject(obj,id,iv);\n"];

        if ([elementName isEqualToString:@"deferview"])
        {
            self.initStageDefer = YES;
        }


        // in jQueryOutput0! Damit a) keine weiteren Elemente überschrieben werden,
        // weil anhand der gesetzten css wird erkannt, welche überschrieben werden dürfen
        // und welche nicht.
        // b) damit Simplelayout hiernach NICHT EINMAL ausgeführt werden kann
        // War früher jQueryOutput.
        // analog auch beim beenden beachten. (Falls es hier geändert wird, dort mitändern!)
        if (self.initStageDefer)
        {
            [self.jsInitstageDeferOutput appendString:o];
        }
        else
        {
            [self.jQueryOutput0 appendString:o];
        }


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

        NSLog([NSString stringWithFormat:@"Es wurden %d von %ld Attributen berücksichtigt.",self.attributeCount,[attributeDict count]]);

        if (self.attributeCount != [attributeDict count])
        {
            [self instableXML:[NSString stringWithFormat:@"\nERROR: Nicht alle Attribute verwertet."]];
        }
    }
    /////////////////////////////////////////////////
    // Abfragen ob wir alles erfasst haben (Debug) //
    /////////////////////////////////////////////////
}


-(void) verankereNameAttribut:(NSString*)name inElement:(NSString*)inElem animatorgroup:(BOOL)ag
{
    NSMutableString *o = [[NSMutableString alloc] initWithString:@""];

    // Das umgebende Element kann den Animator über das 'name'-Attribut ansprechen!
    [o appendString:@"  // All 'animators' can be referenced by its 'name'-attribute...\n"];
    NSString *elemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-2];
    if ([elemTyp isEqualToString:@"evaluateclass"])
    {
        [o appendFormat:@"  %@.%@ = %@;\n",ID_REPLACE_STRING, name, name];
    }
    else
    {
        if (ag)
            [o appendFormat:@"  document.getElementById('%@').%@ = %@;\n",inElem, name, @"animatorgroup_"];
        else
            [o appendFormat:@"  document.getElementById('%@').%@ = %@;\n",inElem, name, name];
    }
    [o appendString:@"  // ...save 'name'-attribute internally, so it can be retrieved by the getter.\n"];
    [o appendFormat:@"  $(%@).data('name','%@');\n",inElem, name];

    [self.jsOutput appendString:o];
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

        NSUInteger n1 = [self.pathToFile_basedir length];

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

        NSUInteger n1 = [self.pathToFile_basedir length];

        NSUInteger n2 = [[[self.pathToFile URLByDeletingLastPathComponent] absoluteString] length];

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
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"\\w+[=][\\w']+" options:NSRegularExpressionCaseInsensitive error:&error];


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
    while ( [args length] > 0 && [args hasSuffix:@","])
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



BOOL isJSBoolean(NSString *s)
{
    if ([s isEqualToString:@"true"] || [s isEqualToString:@"false"])
        return YES;

    return NO;
}


BOOL isJSExpression(NSString *s)
{
    // Bricht bei JS-Strings, die tatsächlich diese Werte enthalten, aber nehme ich in Kauf.
    if (isNumeric(s) || isJSArray(s) || isJSBoolean(s) || [s isEqualToString:@"undefined"] || [s isEqualToString:@"null"])
        return YES;

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
            // Example 28.16.:
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
                s = [self protectThisSingleQuotedJavaScriptString:s];

                // Dann IN den Output hinein injecten
                // [self.jQueryOutput insertString:s atIndex:[self.jQueryOutput length]-34];
                if (self.initStageDefer)
                {
                    [self.jsInitstageDeferOutput insertString:s atIndex:[self.jsInitstageDeferOutput length]-34];
                }
                else
                {
                    [self.jQueryOutput0 insertString:s atIndex:[self.jQueryOutput0 length]-34];
                }
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


    NSLog([NSString stringWithFormat:@"Closing Element: %@ (Neue Verschachtelungstiefe: %ld)\n", elementName,self.verschachtelungstiefe]);


    if (self.weAreCollectingTextAndThereMayBeHTMLTags)
    {
        if ([elementName isEqualToString:@"br"])
        {
            element_geschlossen = YES;

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"a"] ||
            [elementName isEqualToString:@"b"] ||
            [elementName isEqualToString:@"i"] ||
            [elementName isEqualToString:@"img"] ||
            [elementName isEqualToString:@"p"] ||
            [elementName isEqualToString:@"pre"] ||
            [elementName isEqualToString:@"u"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendFormat:@"</%@>",elementName];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }

        if ([elementName isEqualToString:@"font"])
        {
            element_geschlossen = YES;

            [self.textInProgress appendString:@"</span>"];

            // Für den Fall raus! Sonst überschreibt er weAreCollectingTextAndThereMayBeHTMLTags
            if (self.weAreInDatasetAndNeedToCollectTheFollowingTags)
                return;
        }
    }



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
        // Falsch!! <library> ist nicht neutral! Es beeinflusst ob Methoden global sind oder nicht!
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

        // <drawview> bzw. die da drin befindlichen handler müssen wissen von wem sie erben.
        x.lastUsedExtendsAttributeOfClass = self.lastUsedExtendsAttributeOfClass;

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



        NSString *rekursiveRueckgabeJsInitstageDeferOutput = [result objectAtIndex:15];
        if (![rekursiveRueckgabeJsInitstageDeferOutput isEqualToString:@""])
            NSLog(@"String 15 aus der Rekursion wird unser JS-Initstage-Defer-content für JS-Objekt");

        NSString *rekursiveRueckgabeJsToUseLaterOutput = [result objectAtIndex:16];
        if (![rekursiveRueckgabeJsToUseLaterOutput isEqualToString:@""])
            NSLog(@"String 16 aus der Rekursion wird unser To-Use-Later-content für JS-Objekt");



        [self.allImgPaths addObjectsFromArray:[result objectAtIndex:17]];

        // Nur Erinnerung, dass es index 18 gibt. Es können in einer Klasse wohl keine includes auftauchen
        // self.allIncludedIncludes = [[NSMutableArray alloc] initWithArray:[result objectAtIndex:18]];



        // Falls im HTML-Code Text mit ' auftaucht, müssen wir das escapen.
        rekursiveRueckgabeOutput = [rekursiveRueckgabeOutput stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
        rekursiveRueckgabeJsComputedValuesOutput = [rekursiveRueckgabeJsComputedValuesOutput stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
        rekursiveRueckgabeJsConstraintValuesOutput = [rekursiveRueckgabeJsConstraintValuesOutput stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
        rekursiveRueckgabeJsInitstageDeferOutput = [rekursiveRueckgabeJsInitstageDeferOutput stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
        rekursiveRueckgabeJsToUseLaterOutput = [rekursiveRueckgabeJsToUseLaterOutput stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];


        // In manchen JS/jQuery tauchen " auf, die müssen escaped werden
        rekursiveRueckgabeJQueryOutput = [rekursiveRueckgabeJQueryOutput stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        rekursiveRueckgabeJsHead2Output = [rekursiveRueckgabeJsHead2Output stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        rekursiveRueckgabeJsConstraintValuesOutput = [rekursiveRueckgabeJsConstraintValuesOutput stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        rekursiveRueckgabeJsInitstageDeferOutput = [rekursiveRueckgabeJsInitstageDeferOutput stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        rekursiveRueckgabeJsToUseLaterOutput = [rekursiveRueckgabeJsToUseLaterOutput stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];



        // In manchen JS/jQuery tauchen \n auf, die müssen zu <br /> werden
        rekursiveRueckgabeJQueryOutput = [rekursiveRueckgabeJQueryOutput stringByReplacingOccurrencesOfString:@"\\n" withString:@"<br />"];
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"\\n" withString:@"<br />"];


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
        // Am Ende innerhalb der JS-String-Zeile muss ein \\n stehen,
        // damit Kommentare nur für eine Zeile gelten.
        rekursiveRueckgabeOutput = [rekursiveRueckgabeOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n' + \n  '"];
        rekursiveRueckgabeJQueryOutput = [rekursiveRueckgabeJQueryOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJQueryOutput0 = [rekursiveRueckgabeJQueryOutput0 stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsHead2Output = [rekursiveRueckgabeJsHead2Output stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsOutput = [rekursiveRueckgabeJsOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsHeadOutput = [rekursiveRueckgabeJsHeadOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsComputedValuesOutput = [rekursiveRueckgabeJsComputedValuesOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsConstraintValuesOutput = [rekursiveRueckgabeJsConstraintValuesOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsInitstageDeferOutput = [rekursiveRueckgabeJsInitstageDeferOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];
        rekursiveRueckgabeJsToUseLaterOutput = [rekursiveRueckgabeJsToUseLaterOutput stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n\" + \n  \""];



        [self.jsOLClassesOutput appendFormat:@"  this.selfDefinedAttributes = {"];

        NSArray *keys = [self.allFoundClasses objectForKey:self.lastUsedNameAttributeOfClass];
        if ([keys count] > 0)
        {
            for (NSString *key in keys)
            {
                NSString *value = [keys valueForKey:key];


                BOOL weNeedQuotes = YES;


                if (isJSExpression(value))
                    weNeedQuotes = NO;


                // Wegen Beispiel 28.10 => Klassen können auf den Text zwischen den Tags zugreifen, wenn das Attribut text heißt
                if ([key isEqualToString:@"text"] && [value isEqualToString:@"textBetweenTags"])
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
                    // ' und Newlines escapen bei JS-Strings:
                    value = [self protectThisSingleQuotedJavaScriptString:value];

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


        // defaultplacement immer mit speichern, damit es besser ausgelesen werden kann, falls gesetzt.
        // self.defaultplacement = [self protectThisSingleQuotedJavaScriptString:self.defaultplacement];
        // [self.jsOLClassesOutput appendFormat:@"  this.defaultplacement = '%@';\n\n",self.defaultplacement];
        // Neu: Wird nicht mehr hier ausgegeben. Steckt als ganz normale Variable in selfDefinedAttributes
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




        // In manchen propertys von duration in Klassen erfolgt der Zugriff auf classroot...
        // Deswegen schalte ich es hier davor.
        [self.jsOLClassesOutput appendFormat:@"  this.contentJS = \"var classroot = %@;\\n\" +\n  \"",ID_REPLACE_STRING];
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
        [self.jsOLClassesOutput appendString:@"\";\n\n"];

        [self.jsOLClassesOutput appendString:@"  this.contentJSToUseLater = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsToUseLaterOutput];
        [self.jsOLClassesOutput appendString:@"\";\n\n"];

        [self.jsOLClassesOutput appendString:@"  this.contentJSInitstageDefer = \""];
        [self.jsOLClassesOutput appendString:rekursiveRueckgabeJsInitstageDeferOutput];
        [self.jsOLClassesOutput appendString:@"\";\n"];



        [self.jsOLClassesOutput appendString:@"};\n"];

        
        [self.jsOLClassesOutput appendString:@"// Jede Klasse kann auch per Skript erzeugt werden\n"];
        [self.jsOLClassesOutput appendFormat:@"lz_MetaClass.prototype.%@ = function(scope,attributes) { return createObjectFromScript('%@',scope,attributes); };\n",self.lastUsedNameAttributeOfClass,self.lastUsedNameAttributeOfClass];

        // marker - eventuell kann das wieder entfernt werden
        self.textInProgress = nil;
    }

    if ([elementName isEqualToString:@"class"] ||
        [elementName isEqualToString:@"dlginfo"] ||
        [elementName isEqualToString:@"dlgwarning"] ||
        [elementName isEqualToString:@"dlgyesno"] ||
        [elementName isEqualToString:@"nicepopup"] ||
        [elementName isEqualToString:@"nicemodaldialog"] ||
        [elementName isEqualToString:@"nicedialog"])
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
        s = [self escapeCDATAChars:[NSString stringWithString:s]];

        [self.collectedContentOfClass appendString:s];
        [self.collectedContentOfClass appendFormat:@"</%@>",elementName];


        return;
    }

    if ([elementName isEqualToString:@"BDSinputgrid"])
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
        [elementName isEqualToString:@"vbox"] ||
        [elementName isEqualToString:@"state"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"rollUpDownContainer"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"tabslider"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"tabelement"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"multistatebutton"] ||
        [elementName isEqualToString:@"baselist"] ||
        [elementName isEqualToString:@"list"])
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





    if ([elementName isEqualToString:@"resource"] || [elementName isEqualToString:@"audio"])
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
        self.last_resource_name_for_frametag = @"";
    }


    // Bei diesen Elementen muss beim schließen nichts unternommen werden
    if ([elementName isEqualToString:@"simplelayout"] ||
        [elementName isEqualToString:@"whitestyle"] ||
        [elementName isEqualToString:@"silverstyle"] ||
        [elementName isEqualToString:@"bluestyle"] ||
        [elementName isEqualToString:@"greenstyle"] ||
        [elementName isEqualToString:@"goldstyle"] ||
        [elementName isEqualToString:@"purplestyle"] ||
        [elementName isEqualToString:@"BDSeditXXX"] ||
        [elementName isEqualToString:@"BDSeditdate"] ||
        [elementName isEqualToString:@"dragstate"] ||
        [elementName isEqualToString:@"frame"] ||
        [elementName isEqualToString:@"font"] ||
        [elementName isEqualToString:@"face"] ||
        [elementName isEqualToString:@"library"] ||
        [elementName isEqualToString:@"html"] ||
        [elementName isEqualToString:@"vscrollbar"] ||
        [elementName isEqualToString:@"include"] ||
        [elementName isEqualToString:@"import"] ||
        [elementName isEqualToString:@"datapointer"] ||
        [elementName isEqualToString:@"datapath"] ||
        [elementName isEqualToString:@"attribute"] ||
        [elementName isEqualToString:@"animator"] ||
        [elementName isEqualToString:@"stableborderlayout"] ||
        [elementName isEqualToString:@"constantlayout"] ||
        [elementName isEqualToString:@"wrappinglayout"] ||
        [elementName isEqualToString:@"BDStabsheetselected"] ||
        [elementName isEqualToString:@"ftdynamicgrid"] ||
        [elementName isEqualToString:@"debug"] ||
        [elementName isEqualToString:@"event"] ||
        [elementName isEqualToString:@"slider"] ||
        [elementName isEqualToString:@"videoview"] ||
        [elementName isEqualToString:@"evaluateclass"])
    {
        element_geschlossen = YES;
    }



    if ([elementName isEqualToString:@"state"])
    {
        element_geschlossen = YES;

        [self.output appendString:@"</div>\n"];

        self.lastUsedNameAttributeOfState = @"";
    }



    // Nur schließen des Div's
    if ([elementName isEqualToString:@"canvas"] || 
        [elementName isEqualToString:@"view"] ||
        [elementName isEqualToString:@"drawview"] ||
        [elementName isEqualToString:@"radiogroup"] ||
        [elementName isEqualToString:@"hbox"] ||
        [elementName isEqualToString:@"vbox"] ||
        [elementName isEqualToString:@"splash"] ||
        [elementName isEqualToString:@"basebutton"] ||
        [elementName isEqualToString:@"imgbutton"] ||
        [elementName isEqualToString:@"multistatebutton"] ||
        [elementName isEqualToString:@"BDStabsheetcontainer"] ||
        [elementName isEqualToString:@"BDStabsheetTaxango"] ||
        [elementName isEqualToString:@"tabelement"])
    {
        element_geschlossen = YES;

        [self.output appendString:@"</div>\n"];
    }



    // Doppel-Div hier erforderlich
    if ([elementName isEqualToString:@"tabslider"])
    {
        element_geschlossen = YES;

        [self.output appendString:@"</div>\n"];
        [self.output appendString:@"</div>\n"];
    }



    if ([elementName isEqualToString:@"animatorgroup"])
    {
        element_geschlossen = YES;

        [self.jsOutput appendString:@"\n  // Animatorgroup leeren, damit nachfolgende Animationen diese Attribute nicht als die ihrigen auffassen\n"];
        [self.jsOutput appendString:@"  animatorgroup_ = { animators : [], doStart : function() { for (var i = 0;i<this.animators.length;i++) { this.animators[i].doStart(); } } };\n"];
    }



    if ([elementName isEqualToString:@"BDScombobox"] ||
        [elementName isEqualToString:@"combobox"] ||
        [elementName isEqualToString:@"datacombobox"])
    {
        element_geschlossen = YES;

        // Select auch wieder schließen
        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+3];
        [self.output appendString:@"</select>\n"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+2];
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



    // Schließen von replicator
    if ([elementName isEqualToString:@"replicator"])
    {
        element_geschlossen = YES;



        // Sammeln der JS-Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        NSString *theID = self.collectTheNextIDForReplicator;

        [o appendString:@"\n  // Ein Replicator\n"];
        // [o appendFormat:@"  var %@_replicator = new lz.replicator(%@,%@);\n",theID,theID,self.nodesAttrOfReplicator];
        // Ein speichern des Replikators global scheint nicht nötig
        [o appendFormat:@"  new lz.replicator(%@,%@);\n",theID,self.nodesAttrOfReplicator];


        [self.jQueryOutput0 appendString:o];

        self.nodesAttrOfReplicator = nil;
        self.collectTheNextIDForReplicator = @"";
    }



    // Schließen von passthrough
    if ([elementName isEqualToString:@"passthrough"])
    {
        element_geschlossen = YES;

        // Ich muss in dem Fall den gesammelten Text leeren, da ich diesen nicht verwerte
        self.textInProgress = nil;
    }




    if ([elementName isEqualToString:@"stylesheet"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];


        // Oh man, OL, ich muss massiv in die Stylesheet-Angaben eingreifen
        // bgcolor ist noch das leichteste...
        s = [self inString:s searchFor:@"bgcolor" andReplaceWith:@"background-color" ignoringTextInQuotes:YES];


        // ...'[name=' ersetzen mit '[data-name=', weil es das 'name'-Attribut so nicht gibt in HTML5...
        // (Parallel dazu das 'name'-Attribut stets als data-name setzen)
        s = [self inString:s searchFor:@"[name=" andReplaceWith:@"[data-name=" ignoringTextInQuotes:YES];


        // ...ich muss aber auch alle Zahlenangaben bei (height|width usw...) um px ergänzen...
        // (auch unten ergänzen bei Erweiterungen)
        NSError *error = NULL;
        // Geklammert, damit nachfolgendes optionales Leerzeichen sich auf alle Oder-Inhalte bezieht
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"(height|width)\\s*:\\s*\\d+()\\s*;" options:NSRegularExpressionCaseInsensitive error:&error];

        NSArray *matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];

        while ([matches count] > 0)
        {
            NSTextCheckingResult *match = [matches lastObject];
            NSRange r = [match rangeAtIndex:2];
            NSUInteger pos = r.location;
            s = [NSString stringWithFormat:@"%@px%@",[s substringToIndex:pos],[s substringFromIndex:pos]];

            // weil es sich intern nun verschoben hat im s, am Ende der Schleife die pos neu ermitteln
            matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];
        }


        /************************************************************************************/


        // ...der Attribut-Selektor kann bei OL auch Unter-Attribute vom Attribut 'styles' umfassen
        // Was für ein großer Quatsch ist das denn?
        // Ich ändere den '='-Operator in den '*='-Operator (contains-Operator) und mappe alle
        // css-Angaben auf 'styles' um (trifft die Logik nicht ganz genau, aber für mehr keine Zeit).
        regexp = [NSRegularExpression regularExpressionWithPattern:@"\\[(height|width)=\"\\d+\"\\]" options:NSRegularExpressionCaseInsensitive error:&error];

        matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];

        while ([matches count] > 0)
        {
            NSTextCheckingResult *match = [matches lastObject];

            NSString *attributSelektor = [s substringWithRange:[match rangeAtIndex:0]];

            // Anfang und Ende des Unter-Attributs von Style ermitteln und durch 'style' ersetzen
            NSUInteger posOeffnendeEckigeKlammer = [attributSelektor rangeOfString:@"["].location;
            NSUInteger posGleichheitsZeichen = [attributSelektor rangeOfString:@"="].location;
            posOeffnendeEckigeKlammer++;
            attributSelektor = [NSString stringWithFormat:@"%@style*%@",[attributSelektor substringToIndex:posOeffnendeEckigeKlammer],[attributSelektor substringFromIndex:posGleichheitsZeichen]];

            // Dann den alten attributSelektor komplett ersetzen.
            s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:attributSelektor];

            // weil es sich intern nun verschoben hat im s, am Ende der Schleife die pos neu ermitteln
            matches = [regexp matchesInString:s options:0 range:NSMakeRange(0, [s length])];
        }



        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        if ([s length] > 0)
        {
            [self.cssOutput appendString:[NSString stringWithFormat:@"    %@",s]];
        }
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
            [self setTheValue:s ofAttribute:@"text"];


        self.weAreCollectingTextAndThereMayBeHTMLTags = NO;
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



    // Schließen von Elementen, in denen u. U. Text gesammelt wurde
    if ([elementName isEqualToString:@"edittext"] ||
        [elementName isEqualToString:@"BDSedittext"] ||
        [elementName isEqualToString:@"BDSeditnumber"] ||
        [elementName isEqualToString:@"BDScheckbox"] ||
        [elementName isEqualToString:@"checkbox"] ||
        [elementName isEqualToString:@"radiobutton"])
    {
        element_geschlossen = YES;

        NSString *s = [self holDenGesammeltenTextUndLeereIhn];

        // Hinzufügen von gesammelten Text, falls er zwischen den tags gesetzt wurde
        if (s.length > 0)
            [self setTheValue:s ofAttribute:@"text"];

        [self rueckeMitLeerzeichenEin:self.verschachtelungstiefe+1];
        [self.output appendString:@"</div>\n"];
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

            // Überprüfen ob es default values gibt
            NSError *error = NULL;
            NSRegularExpression *regexp2 = [NSRegularExpression regularExpressionWithPattern:@"([\\w]+)=([\\w']+)" options:NSRegularExpressionCaseInsensitive error:&error];

            NSUInteger numberOfMatches = [regexp2 numberOfMatchesInString:args options:0 range:NSMakeRange(0, [args length])];
            if (numberOfMatches > 0)
            {
                NSMutableString *neueArgs = [[NSMutableString alloc] initWithString:@""];
                // Es kann ja auch eine Mischung geben, von sowohl Argumenten mit
                // Defaultwerten als auch solchen ohne. Deswegen hier erstmal ohne
                // Defaultargumente setzen und dann gleich die alle mit.
                neueArgs = [self holAlleArgumentDieKeineDefaultArgumenteSind:args];
                NSLog([NSString stringWithFormat:@"There is/are %ld argument(s) with a default argument. I will regexp them.",numberOfMatches]);

                NSArray *matches = [regexp2 matchesInString:args options:0 range:NSMakeRange(0, [args length])];

                for (NSTextCheckingResult *match in matches)
                {
                    // NSRange matchRange = [match range];
                    NSRange varNameRange = [match rangeAtIndex:1];
                    NSRange defaultValueRange = [match rangeAtIndex:2];

                    NSString *varName = [args substringWithRange:varNameRange];
                    NSLog([NSString stringWithFormat:@"Resulting variable name: %@",varName]);
                    NSString *defaultValue = [args substringWithRange:defaultValueRange];
                    NSLog([NSString stringWithFormat:@"Resulting default value: %@",defaultValue]);

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
                NSUInteger posOeffnendeKlammer = [funktionskopf rangeOfString:@"("].location;
                funktionskopf = [funktionskopf substringToIndex:posOeffnendeKlammer];
                funktionskopf = [NSString stringWithFormat:@"%@(%@) {",funktionskopf,neueArgs];

                // ... dann den alten Funktionskopf komplett ersetzen. Dazu auf das alte regexp von oben  zugreifen
                s = [regexp stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, [s length]) withTemplate:funktionskopf];


                // Jetzt muss ich 'nur noch' die defaultwerte injecten
                // Dazu kurz mit einem NSMutableString arbeiten. Und wir greifen auf den 'match'
                // und dessen Länge vo ganz oben zu um die genaue Stelle zu ermitteln.
                NSUInteger n_entfernteZeichen = [match rangeAtIndex:0].length - funktionskopf.length;

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
        if ([s length] > 0)
        {
            [self.jQueryOutput0 appendString:@"\n  /***** ausgewertetes <script>-Tag - Anfang *****/\n"];
            [self.jQueryOutput0 appendFormat:@"  %@",s];
            [self.jQueryOutput0 appendString:@"\n  /***** ausgewertetes <script>-Tag - Ende *****/\n"];
        }
    }






    if ([elementName isEqualToString:@"handler"])
    {
        element_geschlossen = YES;


        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        if ([self.methodAttributeInHandler length] > 0)
        {
            [o appendString:@"if (this == e.target) {\n      "];

            [o appendFormat:@"this.%@();\n    }\n",self.methodAttributeInHandler];

            [o appendString:@"  });\n"];
        }
        else
        {
            NSString* enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1];
            NSString *enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-1];

            // Extra-Sprung bei 'when' / 'switch' für elem und elemTyp
            int z = 2;
            while ([enclosingElemTyp isEqualToString:@"when"] || [enclosingElemTyp isEqualToString:@"switch"])
            {
                enclosingElem = [self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-z];
                enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-z];
                z++;
            }



            NSString *s = [self holDenGesammeltenTextUndLeereIhn];

            NSLog([NSString stringWithFormat:@"Original code defined in handler: \n**********\n%@\n**********",s]);

            s = [self indentTheCode:s];

            s = [self modifySomeExpressionsInJSCode:s];



            if (self.handlerofDrawview)
            {
                // Dann an den context binden des 'canvas', nicht an das canvas selber! (Damit es bei oninit klappt)
                // enclosingElem = [NSString stringWithFormat:@"%@.getContext('2d')",enclosingElem];
                // Neu: Ich mappe alles direkt in das HTMLCanvasElement. Erklärung siehe dort.

                s = [self modifySomeCanvasExpressionsInJSCode:s];
            }



            // OL benutzt 'classroot' als Variable für den Zugriff auf das erste in einer Klasse
            // definierte Element. Deswegen, falls wir eine Klasse auswerten, einfach diese Var setzen
            if ([[self.enclosingElements objectAtIndex:0] isEqualToString:@"evaluateclass"])
                [o appendFormat:@"var classroot = %@;\n    ",ID_REPLACE_STRING];

            if (self.onInitInHandler)
            {
                [o appendString:s];
                [o appendFormat:@"\n    }\n  }\n  bindMeToCorrectScope.bind(%@)();\n",enclosingElem];
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
                    [o appendString:@"  // Wegen 'reference'-Attribut falsches this. Dieses korrigieren mit selbst ausführender Funktion und bind()\n"];                
                    [o appendString:@"      (function() {\n"];
                }
                else
                {
                    [o appendString:@"if (this == e.target) {\n"];
                }


                [o appendString:@"      with (this) {\n        "];

                [o appendString:s];

                [o appendString:@"\n      }\n"];


                if (self.referenceAttributeInHandler)
                {
                    [o appendFormat:@"    }).bind(%@)();\n",enclosingElem];
                }
                else
                {
                    [o appendString:@"    }\n"];
                }

                [o appendString:@"  });\n"];
            }
        }


        if (self.handlerofDrawview)
        {
            // oft ist es an 'oncontext' gebunden. Deswegen dies einfach hinterher triggern.
            [o appendFormat:@"  $(%@).triggerHandler('oncontext');\n",[self.enclosingElementsIds objectAtIndex:[self.enclosingElementsIds count]-1]];
        }



        // Falls ich es ändere: Analog auch beim öffnenden Tag ändern!
        // jQueryOutput0! Damit die Handler bekannt sind, bevor diese getriggert werden! (Bsp. 30.3)
        // Problem: Ladezeit verdoppelt sich... weil er dann viel mehr triggern kann... Erst iwie das triggern optimieren
        [self.jQueryOutput appendString:o];



        // Erkennungszeichen für oninit in jedem Fall zurücksetzen
        self.onInitInHandler = NO;
        // Erkennungszeichen für 'reference'-Attribut auf jeden Fall zurücksetzen
        self.referenceAttributeInHandler = NO;
        // Erkennungszeichen für 'drawview'-Handler auf jeden Fall zurücksetzen
        self.handlerofDrawview = NO;
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
        //s = [s stringByReplacingOccurrencesOfString:@"\\n" withString:@"\\\\n"];
        // Puh, das war ein collectedClasses-Problem. Strings müssen untouched bleiben hier.


        // Damit er in jeder Code-Zeile korrekt einrückt
        s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\n   "];


        // Bei Methoden in 'drawview' muss ich nochmal extra was machen.
        NSString *enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-1];
        if ([enclosingElemTyp isEqualToString:@"drawview"] || ([enclosingElemTyp isEqualToString:@"evaluateclass"] && [self.lastUsedExtendsAttributeOfClass isEqualToString:@"drawview"]))
        {
            s = [self modifySomeCanvasExpressionsInJSCode:s];
        }


        NSLog([NSString stringWithFormat:@"Modified code changed to in method: \n**********\n%@\n**********",s]);


        // Hier drin sammle ich erstmal die Ausgabe
        NSMutableString *o = [[NSMutableString alloc] initWithString:@""];


        [o appendString:@"   "];
        [o appendString:s];


        // Falls wir in canvas/library sind, dann muss es nicht nur global verfügbar sein,
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

        if ([self.lastUsedNameAttributeOfMethod isEqualToString:@"init"])
        {
            // in der init-Methode werden u. U. computedValues-Werte überschrieben,
            // deswegen die init-Methode erst danach ausführen
            [self.jsComputedValuesOutput appendString:@"\n  // Oben definierte init-Methode wird erst hier ausgeführt\n"];
            [self.jsComputedValuesOutput appendFormat:@"  %@.init();\n",[self.enclosingElementsIds lastObject]];
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


 /* MARKER -60 / -31 vom defer-Test */
        // Wenn wir einen String gefunden haben, dann IN den existierenden Output injecten:
        if ([s length] > 0)
        {
            // Da ich den string mit ' umschlossen habe, muss ich eventuelle ' im String escapen
            s = [self protectThisSingleQuotedJavaScriptString:s];


            if (self.initStageDefer)
            {
                [self.jsInitstageDeferOutput insertString:s atIndex:[self.jsInitstageDeferOutput length]-34];
            }
            else
            {
                [self.jQueryOutput0 insertString:s atIndex:[self.jQueryOutput0 length]-34];
            }
        }


        NSString *enclosingElemTyp = [self.enclosingElements objectAtIndex:[self.enclosingElements count]-1];
        if ([enclosingElemTyp isEqualToString:@"deferview"])
        {
            self.initStageDefer = NO;
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


    if (debugmode)
    {
        if (!element_geschlossen)
            [self instableXML:[NSString stringWithFormat:@"ERROR: Nicht erfasstes schließendes Element: '%@'", elementName]];
    }
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

    // Müsste ich machen gemäß Bsp. 21.5, aber bricht einfach zu viel
    /*
    NSString *former_ms = [self escapeCDATAChars:[NSString stringWithString:self.textInProgress]];
    self.textInProgress = [NSMutableString stringWithString:former_ms];
     */
}


- (NSString*)escapeCDATAChars:(NSString *)s
{
    // Das &-ersetzen muss natürlich als erstes kommen, weil ich danach ja wieder
    // welche einfüge (durch die Entitys).
    s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];

    return s;
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
    // Gleichzeitig Fallback auf Google Chrome Frame, sofern installiert.
    [pre appendString:@"<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\" />\n"];

    // Die Meta-Angaben sind nicht HTML5-Konform! Aber zum testen um sicherzustellen, dass wir nichts aus dem Cache laden.
    [pre appendString:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n<meta http-equiv=\"pragma\" content=\"no-cache\" />\n<meta http-equiv=\"cache-control\" content=\"no-cache\" />\n<meta http-equiv=\"expires\" content=\"0\" />\n"];

    // Viewport für mobile Devices anpassen...
    // ...width=device-width funktioniert nicht im Portrait-Modus.
    // initial-scale baut links und rechts einen kleinen Abstand ein. Wollen wir das?
    // Er springt dann etwas immer wegen adjustOffsetOnBrowserResize - To Check
    [pre appendString:@"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n"];
    //      [pre appendString:@"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.024\" />\n"]; // => Dann perfekte Breite, aber Grafiken wirken etwas verwaschen.To Do@End
    //[pre appendString:@"<meta name=\"viewport\" content=\"\" />\n"];

    // Icon für Bookmark bei iOS:
    // [pre appendString:@"<link rel=\"apple-touch-icon\" href=\"/mobile-img/icon.png\" />\n"];
    // Start-Bild, während die Anwendung startet:
    // [pre appendString:@"<link rel=\"apple-touch-startup-image\" href=\"/mobile-img/icon.png\" />\n"];





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
        [pre appendString:@"\n</style>\n"];
    }

    [pre appendString:@"\n<script type=\"text/javascript\">\n"];

    // Muss auch ausgegeben werde! Auf die resourcen wird per JS unter Umständen zugegriffen
    [pre appendString:self.jsHeadOutput];

    // erstmal nur die mit resource gesammelten globalen vars ausgeben
    // (+ globale Funktionen + globales JS)
    [pre appendString:self.jsHead2Output];
    [pre appendString:@"\n</script>\n\n</head>\n\n<body>\n"];



    // Splashscreen vorschalten
    if (ownSplashscreen)
    {
        if ([[[self.pathToFile lastPathComponent] stringByDeletingPathExtension] isEqualToString:@"Taxango"])
        {
            [pre appendString:@"<span id=\"splashscreen_\" style=\"position:absolute;top:0px;left:0px;background-color:white;width:100%;height:100%;z-index:10000;background-image:url(resources/logo.png);font-size:80px;text-align:center;\">LOADING...</span>\n\n"];
        }
        else
        {
            [pre appendString:@"<span id=\"splashscreen_\" style=\"position:absolute;top:0px;left:0px;background-color:white;width:100%;height:100%;z-index:10000;font-size:80px;text-align:center;\">LOADING...</span>\n\n"];
        }
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
        // Auch mp3-files
        if (![object hasSuffix:@".swf"] && ![object hasSuffix:@".mp3"])
        {
            [self.output appendFormat:@"<img class=\"img_preload\" alt=\"preload\" src=\"%@\" />\n",object];
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


    // So lange ich den TabSheetContainer nicht auswerte, muss ich diese Methoden nachimplementieren...
    [self.output appendString:@"  if (window['tabsMain']) tabsMain.selecttab = function(index) { $(this).tabs('select', index ) }\n"];
    [self.output appendString:@"  if (window['tabsMain']) tabsMain.next = function() { $(this).tabs('select', $(this).tabs('option', 'selected')+1) }\n"];


    [self.output appendString:@"  if (window['rudStpfl']) rudStpfl.rolldown = function() {} // ToDo\n"];
    [self.output appendString:@"  if (window['rudWeitereInfos']) rudWeitereInfos.isvalid = true; // ToDo\n"];
    [self.output appendString:@"  if (!window['globalcalendar']) globalcalendar = {}; // ToDo\n"];
    [self.output appendString:@"  globalcalendar.setCurrentdate = function() { return new Date(); };\n"];
    [self.output appendString:@"  globalcalendar.close = function() {  };\n\n"];

    [self.output appendString:@"  var dlgsave = new dlg();"];
    [self.output appendString:@"  var dlgwaitonline = new dlg();"];
    [self.output appendString:@"  // ShowError = function(x) { /* alert(x); */ };\n"];
    [self.output appendString:@"  function dlg()\n  {\n    // Extern definiert\n    this.open = open;\n    // Intern definiert (beides möglich)\n"];
    [self.output appendString:@"     this.completeInstantiation = function completeInstantiation() { };\n  }\n"];
    [self.output appendString:@"  function open()\n  {\n    alert('Willst du wirklich deine Ehefrau löschen? Usw...');\n  }\n"];
    [self.output appendString:@"  var dlgFamilienstandSingle = new dlg();\n\n"];

    // Seitdem ich die initstage=defer-Klassen nach ganz unten verschoben habe, taucht das hier auf,
    // Er erwartet glaube ich die Variable _inner in einem 'BDSReplicator'
    [self.output appendString:@"  if (window.element139) element139._inner = element139;\n"];
    [self.output appendString:@"  if (window.element139) element139._scrollview = element139;\n"];
    [self.output appendString:@"  if (window.element139) element139._innerscroll = element139;\n"];
    [self.output appendString:@"  if (window.element139) element139.measureHeight = function() {};\n\n"];


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

    // Remove Splashscreen(s)
    [self.output appendString:@"\n  $('#splashtag_').remove(); // The Build-In-SplashTag\n"];
    if (ownSplashscreen)
        [self.output appendString:@"\n  $('#splashscreen_').remove();\n"];



    if (![self.jsToUseLaterOutput isEqualToString:@""])
    {
        [self.output appendString:@"\n\n  /*******************************************************************/\n"];
        [self.output appendString:@"  /***************************** Grenze ******************************/\n"];
        [self.output appendString:@"  /********************* ToUseLater ist hier nach ********************/\n"];
        [self.output appendString:@"  /*******************************************************************/\n"];

        [self.output appendString:self.jsToUseLaterOutput];
    }



    if (![self.jsInitstageDeferOutput isEqualToString:@""])
    {
        [self.output appendString:@"\n\n  /*******************************************************************/\n"];
        [self.output appendString:@"  /***************************** Grenze ******************************/\n"];
        [self.output appendString:@"  /******************* Initstage Defer ist hier nach *****************/\n"];
        [self.output appendString:@"  /*******************************************************************/\n"];

        [self.output appendString:@"  $('#tabsMain').one('mouseenter', function(event) {\n"];

        // ... und 2 Spaces mehr einrücken.
        self.jsInitstageDeferOutput = [NSMutableString stringWithFormat:@"%@",[self inString:self.jsInitstageDeferOutput searchFor:@"  " andReplaceWith:@"    " ignoringTextInQuotes:YES]];

        [self.output appendString:self.jsInitstageDeferOutput];
        [self.output appendString:@"  });\n"];
    }



    [self.output appendString:@"\n  // To Speed up Loading I will trigger 'oninit' after everything is displayed (not suitable in every situation)\n"];
    [self.output appendString:@"  // setTimeout()-function with 1 ms delay (setTimeout() is non-blocking, and though shows the Layout immediately)\n"];
    // 0 oder 1 als ms-Angabe klappt nicht 100 %, dann zeigt er manchmal doch nicht das Layout an.
    // Vermutlich checkt er intern nicht jede ms, und deswegen kann es u. U. passieren,
    // dass er direkt weiter den Code ausführt, ka.
    [self.output appendString:@"  window.setTimeout(function() { triggerOnInitForAllElements() }, 20);\n"];


    [self.output appendString:@"\n});\n</script>\n\n"];



    // Und nur noch die schließenden Tags
    [self.output appendString:@"</body>\n</html>"];

    // Path zum speichern ermitteln
    // Download-Verzeichnis war es mal, aber Problem ist, dass dann die Ressourcen fehlen...
    // NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    // NSString *dlDirectory = [paths objectAtIndex:0];
    // NSString * path = [[NSString alloc] initWithString:dlDirectory];
    //... deswegen ab jetzt immer im gleichen Verzeichnis wie das OpenLaszlo-input-File
    // Die Dateien dürfen dann nur nicht zufälligerweise genau so heißen wie welche im Verzeichnis
    // (To Do bei Public Release)
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
    ".greenstyleClass\n"
    "{\n"
    "    background: #899c89;\n"
    "    background: -moz-linear-gradient(top, #c9e6c9, #899c89);\n"
    "    background: -webkit-linear-gradient(top, #c9e6c9, #899c89);\n"
    "    background: -ms-linear-gradient(top, #c9e6c9, #899c89);\n"
    "    background: -o-linear-gradient(top, #c9e6c9, #899c89);\n"
    "}\n"
    "\n"
    ".greenstyleClass:hover\n"
    "{\n"
    "    background: #89ad89;\n"
    "    background: -moz-linear-gradient(top, #d9f8d9, #89ad89);\n"
    "    background: -webkit-linear-gradient(top, #d9f8d9, #89ad89);\n"
    "    background: -ms-linear-gradient(top, #d9f8d9, #89ad89);\n"
    "    background: -o-linear-gradient(top, #d9f8d9, #89ad89);\n"
    "}\n"
    "\n"
    ".greenstyleClass:active\n"
    "{\n"
    "    background: #a6bfa6;\n"
    "    background: -moz-linear-gradient(top, #505c50, #a6bfa6);\n"
    "    background: -webkit-linear-gradient(top, #505c50, #a6bfa6);\n"
    "    background: -ms-linear-gradient(top, #505c50, #a6bfa6);\n"
    "    background: -o-linear-gradient(top, #505c50, #a6bfa6);\n"
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
    "div, button /* Alle Elemente auf die Simplelayout stoßen kann. */\n"
    "{           /* Damit SA nie auf 'auto' stößt, sondern bei $(el).css('top') immer einen numerischen Wert zurück bekommt (über parseInt()). */\n"
	"    top:0;  /* Ich muss mit css('top') arbeiten, da position().top bei versteckten Elementen bricht. */\n"
	"    left:0;\n"
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
    "    z-index:1; /* Damit Example 26.6 klappt + damit sendBehind()/sendInFrontOf() spätestens hier auf einen numerischen Wert treffen */\n"
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
	"    height:auto; /* Damit es einen Startwert gibt. */\n"
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
    "\n"
    ".canvas_element\n"
    "{\n"
	"    height:auto;\n"
	"    width:auto;\n"
    "\n"
	"    position:relative;\n"
	"    top:0px;\n"
	"    left:0px;\n"
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
    "/* TabSlider */\n"
    ".div_tabSlider\n"
    "{\n"
    "    height:auto;\n"
    "    width:auto;\n"
    "    position:relative;\n"
    "    top:0px;\n"
    "    left:0px;\n"
    "\n"
    "    border-style:solid; /* Bei Bedarf auskommentieren */\n"
    "    border-width:1px; /* Bei Bedarf auskommentieren */\n"
    "}\n"
    "\n"
    "/* TabElement */\n"
    ".div_tabElement\n"
    "{\n"
    "    height:auto;\n"
    "    width:auto;\n"
    "    position:relative;\n"
    "    top:2px;\n"
    "    left:0px;\n"
    "    border-width:0; /* Um den von jQuery UI gesetzten Rand zu überschreiben */\n"
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
    "    height:auto;\n" // War mal 'inherit', aber 'auto' erscheint mir logischer.
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
    "    padding:1px 2px;\n" // padding:4px;
    "\n"
    "    cursor:pointer;\n"
    "    pointer-events: auto;\n"
    "}\n"
    "\n"
    "/* Standard-checkbox (die checkbox selber) */\n"
    "/* Standard-radiobutton (der button selber) */\n"
    ".input_checkbox\n"
    "{\n"
    //"    position:relative;\n" <-- Auskommentiert, verschiebt sonst den Text der checkbox AUF die checkbox
    //"\n"                           Und die checkbox kann wohl 'static' bleiben.
    "    margin-right:5px;\n"
    "    vertical-align:top; /* Damit checkbox mit nebenstehendem Text auf einer Höhe */\n"
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
    "/* edittext */\n"
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
    //"var black = 'black';\n"
    //"var green = 'green';\n"
    //"var silver = 'silver';\n"
    //"var lime = 'lime';\n"
    //"var gray = 'gray';\n"
    //"var olive = 'olive';\n"
    //"var white = 'white';\n"
    //"var yellow = 'yellow';\n"
    //"var maroon = 'maroon';\n"
    //"var navy = 'navy';\n"
    //"var red = 'red';\n"
    //"var blue = 'blue';\n"
    //"var purple = 'purple';\n"
    //"var teal = 'teal';\n"
    //"var fuchsia = 'fuchsia';\n"
    //"var aqua = 'aqua';\n"
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
    //"/////////////////////////////////////////////////////////\n"
    //"// watch/unwatch-Skript um auf Änderungen von Variablen reagieren zu können\n"
    //"/////////////////////////////////////////////////////////\n"
    //"/*\n"
    //"* object.watch polyfill\n"
    //"*\n"
    //"* 2012-04-03\n"
    //"*\n"
    //"* By Eli Grey, http://eligrey.com\n"
    //"* Public Domain.\n"
    //"* NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.\n"
    //"*/\n"
    //"\n"
    //"// object.watch\n"
    //"if (!Object.prototype.watch) {\n"
    //"    Object.defineProperty(Object.prototype, 'watch', {\n"
    //"        enumerable: false,\n"
    //"        configurable: true,\n"
    //"        writable: false,\n"
    //"        value: function (prop, handler) {\n"
    //"            var oldval = this[prop], newval = oldval,\n"
    //"            getter = function () {\n"
    //"                return newval;\n"
    //"            },\n"
    //"            setter = function (val) {\n"
    //"                oldval = newval;\n"
    //"                return newval = handler.call(this, prop, oldval, val);\n"
    //"            };\n"
    //"            if (delete this[prop]) { // can't watch constants\n"
    //"                Object.defineProperty(this, prop, {\n"
    //"                get: getter,\n"
    //"                set: setter,\n"
    //"                enumerable: true,\n"
    //"                configurable: true\n"
    //"                });\n"
    //"            }\n"
    //"        }\n"
    //"    });\n"
    //"}\n"
    //"\n"
    //"// object.unwatch\n"
    //"if (!Object.prototype.unwatch) {\n"
    //"    Object.defineProperty(Object.prototype, 'unwatch', {\n"
    //"        enumerable: false,\n"
    //"        configurable: true,\n"
    //"        writable: false,\n"
    //"        value: function (prop) {\n"
    //"            var val = this[prop];\n"
    //"            delete this[prop]; // remove accessors\n"
    //"            this[prop] = val;\n"
    //"        }\n"
    //"    });\n"
    //"}"
    //"\n"
    //"\n"
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
    "\n"

    /*
    "    // Hilfsfunktion, um jederzeit die Mauskoordinaten einlesen zu können\n"
    "    window.mouseXPos = -1000;\n"
    "    window.mouseYPos = -1000;\n"
    "    $(document).ready(function(){\n"
    "        $(document).mousemove(function(e){\n"
    "            window.mouseXPos = e.pageX;\n"
    "            window.mouseYPos = e.pageY;\n"
    "            $(canvas).triggerHandler('change'); // Etwas geschummelt, aber damit die Examples in Kapitel 32 klappen\n"
    "        });\n"
    "    });\n"
     */

    // Variante mit Delay (um Resourcen zu schonen):
    //function getMousePosition(timeoutMilliSeconds) {
    //    // "one" attaches the handler to the event and removes it after it has executed once 
    //    $(document).one("mousemove", function (event) {
    //        window.mouseXPos = event.pageX;
    //        window.mouseYPos = event.pageY;
    //        // set a timeout so the handler will be attached again after a little while
    //        setTimeout(function() { getMousePosition(timeoutMilliSeconds) }, timeoutMilliseconds);
    //    });
    //}
    //
    //// start storing the mouse position every 100 milliseconds
    //getMousePosition(100);
    "    canvas.getMouse = function(axis) {\n"
    "        if (typeof axis !== 'string' || (axis !== 'x' && axis !== 'y'))\n"
    "            throw new Error('canvas.getMouse() - No axis or wrong axis.');\n"
    "\n"
    "        if (axis === 'x') return window.mouseXPos;\n"
    "        if (axis === 'y') return window.mouseYPos;\n"
    "    }\n"
    "\n"
    "\n"
    "    canvas.setDefaultContextMenu = function(contextmenu) {};\n"
    "\n"
    "\n"
    "    // Anhand dieser Variable kann im Skript abgefragt werden, ob wir im Debugmode sind\n"
    "    // ohne 'var', damit global. \n"
    "    $debug = false;\n"
    "    $swf8 = false;\n"
    "\n"
    "    flash = { net : { FileReference : function() { this.addListener = function() {} } } }\n"
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
    "        // this.checked = $(this).is(':checked'); // Unnötig, wird in setAttribute_() gesetzt\n"
    "        // und bei jeder Änderung\n"
    "        $(this).on('change',function() {\n"
    "            this.value = $(this).is(':checked');\n"
    "            // this.checked = $(this).is(':checked'); // Unnötig, wird in setAttribute_() gesetzt\n"
    "\n"
    "            $(this).triggerHandler('onchecked',$(this).is(':checked')); // <-- darauf lauschen die constraints bei Checkboxen!\n"
    "        });\n"
    "\n"
    "        // Den Mousecursor ändern vom benachbarten span\n"
    "        $(this).next().css('cursor','pointer');\n"
    "    });\n"
    "\n"
    "    // Davon unabhängig: Triggern, damit da dran hängende Constraints die Änderung mitbekommen\n"
    "    // Dies gilt sogar für jedes input (und select)!\n"
    "    $('input,select').each( function() {\n"
    "        $(this).on('change',function() {\n"
    "            this.myValue = $(this).val(); // <-- aktualisieren, weil die Constraints myValue auslesen, nicht Value\n"
    "            $(this).triggerHandler('onvalue',$(this).val());\n"
    "            $(this).triggerHandler('onmyValue',$(this).val());\n"
    "        });\n"
    "    });\n"
    "\n"
    "    // Auch bei radio-buttons den Cursor stets anpassen vom benachbarten Text\n"
    "    $('input[type=radio]').each( function() {\n"
    "        // Den Mousecursor ändern vom benachbarten span\n"
    "        $(this).next().css('cursor','pointer');\n"
    "    });\n"
    "\n"
    "\n"
    "    // ohne 'var', damit global\n"
    "    whitestyle = 'whitestyleClass';\n"
    "    silverstyle = 'silverstyleClass';\n"
    "    bluestyle = 'bluestyleClass';\n"
    "    greenstyle = 'greenstyleClass';\n"
    "    goldstyle = 'goldstyleClass';\n"
    "    purplestyle = 'purplestyleClass';\n"
    "\n"
    "    // Hier schreiben 'animatorgroup's ihre Attribute rein. Als globales Objekt, welches immer erst beim schließen\n"
    "    // einer Grupper geleert wird (und NICHT beim öffnen neu initialisiert). Weil bei verschachtelten\n"
    "    // 'animatorgroups's die inneren, die Attribute der äußeren 'erben'.\n"
    "    animatorgroup_ = { animators : [], doStart : function() { for (var i = 0;i<this.animators.length;i++) { this.animators[i].doStart(); } } };\n"
    "\n"
    "    // Der zuletzt angesprochene absolute Datapath für relative Datapaths (bewusst ohne var, damit global)\n"
    "    lastDP_ = undefined;\n"
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
    "// Testet Numbers oder Strings, ob sie Nummern sind    //\n"
    "/////////////////////////////////////////////////////////\n"
    "function isNumber(o)\n"
    "{\n"
    "    return ! isNaN (o-0);\n"
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
    "// wird aufgerufen, nachdem alles geladen wurde        //\n"
    "/////////////////////////////////////////////////////////\n"
    "function triggerOnInitForAllElements() {\n"
    "    $('body').find('*').each( function() {\n"
    "        $(this).triggerHandler('onconstruct');\n"
    "        $(this).triggerHandler('oninit');\n"
    "    });\n"
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
    //"/////////////////////////////////////////////////////////\n"
    //"// datasetItem-Klasse für in OL deklarierte datasets (bzw. ein Objekt-Konstruktor dafür)\n"
    //"/////////////////////////////////////////////////////////\n"
    //"function datasetItem(value, info, afa, check, content)\n"
    //"{\n"
    //"    // Die Propertys des Objekts\n"
    //"    this.value = value;\n"
    //"    this.content = content;\n"
    //"    // Manche items haben auch noch ein info-Attribut\n"
    //"    this.info = info;\n"
    //"    // Manche items haben auch noch ein afa-Attribut\n"
    //"    this.afa = afa;\n"
    //"    // Manche items haben auch noch ein check-Attribut\n"
    //"    this.check = check;\n"
    //"}\n"
    //"\n"
    //"\n"
    //"/////////////////////////////////////////////////////////\n"
    //"// toggleVisibility (wird benötigt um Visibility sowohl jetzt, als auch später,\n"
    //"// abhängig von einer Bedingung zu setzen)\n"
    //"/////////////////////////////////////////////////////////\n"
    //"function toggleVisibility(id, idAbhaengig, bedingungAlsString)\n"
    //"{\n"
    //"  // Bei checkboxen bezieht sich die Abfrage nach 'value' darauf, ob es 'checked' ist oder nicht\n"
    //"  // Und nicht auf das value-Attribut als solches... warum auch immer.\n"
    //"  // http://www.openlaszlo.org/lps4.9/docs/reference/lz.checkbox.html (Dortiges Beispiel)\n"
    //"  if ($(idAbhaengig).is('input') && $(idAbhaengig).attr('type') === 'checkbox' && bedingungAlsString === 'value')\n"
    //"      bedingungAlsString = 'checked';\n"
    //"\n"
    //"\n"
    //"\n"
    //"  // 'value' wird intern von OpenLaszlo benutzt! Indem ich auch in JS 'value' in der Zeile\n"
    //"  // vorher setze und danach den string auswerte, der 'value' in der Bedingung enthält,\n"
    //"  // muss ich das von OpenLaszlo benutzte 'value' nicht intern parsen (nice Trick, I Think)\n"
    //"  // => eval(bedingungAlsString) kennt dann die Var value und kann korrekt auswerten\n"
    //"  // Das gleiche gilt für 'text', was wohl jQueryhtml() entspricht, da text auch dynamisch mit html() gesetzt wird.\n"
    //"  // Das gleiche gilt für 'visible'.\n"
    //"  if (idAbhaengig == \"__PARENT__\")\n"
    //"  {\n"
    //"      var value = $(idAbhaengig).parent().val();\n"
    //"      // Die nachfolgenden beiden Zeilen helfen mir jetzt bei parent().parent(), oder können sie weg?\n"
    //"      var parent = $(idAbhaengig).parent().parent();\n"
    //"      parent.value = $(idAbhaengig).parent().parent().val();\n"
    //"\n"
    //"      var text = $(idAbhaengig).parent().html();\n"
    //"      var visible = $(idAbhaengig).parent().is(':visible')\n"
    //"  }\n"
    //"  else\n"
    //"  {\n"
    //"      var value = $(idAbhaengig).val();\n"
    //"      // Die nachfolgenden beiden Zeilen helfen mir jetzt bei parent().parent(), oder können sie weg?\n"
    //"      var parent = $(idAbhaengig).parent();\n"
    //"      parent.value = $(idAbhaengig).parent().val();\n"
    //"\n"
    //"      var text = $(idAbhaengig).html();\n"
    //"      var visible = $(idAbhaengig).is(':visible')\n"
    //"  }\n"
    //"\n"
    //"\n"
    //"  console.log('Bedingung: '+bedingungAlsString)\n"
    //"\n"
    //"  if (bedingungAlsString === 'checked')\n"
    //"    var bedingung = $(idAbhaengig).is(':checked');\n"
    //"  else\n"
    //"    var bedingung = eval(bedingungAlsString);\n"
    //"\n"
    //"  // Wenn wir ein input sind, vor uns ist ein span und um uns herum ist ein div\n"
    //"  // dann müssen wir das umgebende div togglen, weil dies das komplette input-Feld umfasst\n"
    //"  if (($(id).is('input') && $(id).prev().is('span') && $(id).parent().is('div')) ||\n"
    //"      ($(id).is('select') && $(id).prev().is('span') && $(id).parent().is('div')))\n"
    //"    $(id).parent().toggle(bedingung);\n"
    //"  else\n"
    //"    $(id).toggle(bedingung);\n"
    //"}\n"
    //"\n"
    //"\n"
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
    //"  // Zusatz-Code -  Das hier muss noch zu ECHTEM generierten Code werden // To Do\n"
    //"  $(globalhelp_6).height(globalhelp._inner.height+35-35);\n"
    //"  $(globalhelp_10).css('top',globalhelp._inner.height+50-50+15);\n"
    //"  // Damit der eine blöde Effekt weggeht Hintergrundbild mit sich selbst aktualisieren\n"
    //"  $(globalhelp_7).css('background-image',$(globalhelp_7).css('background-image'))\n"
    //"  $(globalhelp_8).css('background-image',$(globalhelp_8).css('background-image'))\n"
    //"  $(globalhelp_9).css('background-image',$(globalhelp_9).css('background-image'))\n"
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
    "\n"
    "        // Objekt sofort global bekannt machen\n"
    "        window[id] = document.getElementById(id);\n"
    "    }\n"
    "    else if (name === 'button') {\n"
    "        jQuery('<button/>', {\n"
    "            id: id,\n"
    "            class: 'input_standard',\n"
    "        }).appendTo(scope);\n"
    "\n"
    "        // Objekt sofort global bekannt machen\n"
    "        window[id] = document.getElementById(id);\n"
    "    }\n"
    "    else if (name === 'text') {\n"
    "        jQuery('<div/>', {\n"
    "            id: id,\n"
    "            class: 'div_text noPointerEvents',\n"
    //"            text: 'Go to Google!'\n"
    "        }).appendTo(scope);\n"
    "\n"
    "        // Objekt sofort global bekannt machen\n"
    "        window[id] = document.getElementById(id);\n"
    "    }\n"
    "    else if (typeof oo[name] === 'function') {\n"
    "        jQuery('<div/>', {\n"
    "            id: id,\n"
    "            class: 'div_standard noPointerEvents',\n"
    "        }).appendTo(scope);\n"
    "\n"
    "        // Objekt sofort global bekannt machen\n"
    "        window[id] = document.getElementById(id);\n"
    "\n"
    "        var obj = new oo[name]('');\n"
    "        var el = document.getElementById(id);\n"
    "        interpretObject(obj,el,{});\n"
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
    "            // Damit 'remove()' die Referenz entfernen kann, name-Attribut unbedingt intern mitspeichern\n"
    "            $(elem).data('name',attributes.name);\n"
    "\n"
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
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "    objectFromScriptCounter++;\n"
    "\n"
    "    // Damit sich z. B. Simplelayouts aktualiseren können (s. Bsp. 17.2)\n"
    "    $('#'+id).parent().triggerHandler('onaddsubview');\n"
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
    "    // Doku says: Inside Animators, the 'this' keyword refers to the animator, and 'parent' refers to the view or node it is nested in. To Check?\n"
    "    this.animator = function(el,prop,to,duration,from,target,motion,isRelative,start,repeat,moreArgs) {\n"
    "        this.el = el; // Element to animate\n"
    "\n"
    "        this.prop = prop;\n"
    "        this.to = to;\n"
    "        this.duration = duration;\n"
    "        this.from = from;\n"
    "        this.target = target;\n"
    "        this.motion = motion;\n"
    "        this.isRelative = (isRelative!==undefined) ? isRelative : false;\n"
    "        this.start = (start!==undefined) ? start : ((moreArgs.start!==undefined) ? moreArgs.start : true);\n"
    "        this.repeat = repeat;\n"
    "\n"
    "        // Nutze ich, um die von 'animatorgroup' gesetzten Attribute zu speichern/weiterzugeben\n"
    "        // ich muss jedoch ne copy machen! Da nachfolgende Animatoren die Einstellungen sonst ändern können\n"
    "        // Der Einfacheit halber für die Copy benutze ich jQuerys extend()\n"
    "        this.moreArgs = jQuery.extend({},moreArgs);\n"
    "\n"
    "        this.doStart = function() {\n"
    "            if (this.from !== undefined)\n"
    "                el.setAttribute_(this.prop,this.from);\n"
    "\n"
    "            this.el.animate(this.prop,this.to,this.duration,this.isRelative,this.moreArgs,this.motion);\n"
    "        }\n"
    "\n"
    "       this.stop = function() { /* ToDo, seems to stop the animation */ }\n"
    "\n"
    "        if (this.start)\n"
    "            this.doStart();\n"
    "    }\n"
    "\n"
    "\n"
    "    this.layout = function() {\n"
    "        this.locked = false;\n"
    "\n"
    "        this.lock = function() {\n"
    "            this.locked = true;\n"
    "        }\n"
    "        this.unlock = function() {\n"
    "            this.locked = false;\n"
    "        }\n"
    "        this.update = function() {\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
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
    "        this.setCursorGlobal = function(cursor) {\n"
    "            if (cursor === 'waitcursor')\n"
    "                cursor = 'wait';\n"
    "            $('body').css('cursor', cursor);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.XMLHttpRequest = function() {\n"
    "        return new XMLHttpRequest();\n"
    "    }\n"
    "\n"
    "\n"
    "    this.TimerService = function() {\n"
    "        this.addTimer = function(handler, millisecs) {\n"
    "            window.setTimeout(function() { handler(); }, millisecs);\n"
    "        }\n"
    "        this.resetTimer = function(handler, millisecs) {\n"
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
    "        this.isAAActive = function() {\n"
    "            return false;\n"
    "        }\n"
    "        this.loadJS = function(code,target) {\n"
    "            eval(code);\n"
    "        }\n"
    "        this.loadURL = function(url,target) {\n"
    "            window.open(url, target);\n"
    "        }\n"
    "        this.setClipboard = function(s) {\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.contextmenu = function() {\n"
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
    "    this.replicator = function(el,nodes) {\n"
    "        this.setData = function(v,n) {\n"
    "            v.get(0).data = n;\n"
    "        }\n"
    "\n"
    "        this.insertNode = function(idx,n) {\n"
    "            // Nochmals Klon klonen, um ID auszutauschen usw.\n"
    "            var clone = this.elementToCopy.clone(true);\n"
    "\n"
    "            // Id austauschen\n"
    "            clone.find('*').andSelf().each( function() {\n"
    "                $(this).attr('id',$(this).attr('id')+'_repl'+(n+1))\n"
    "                // Die neu geschaffene id noch global bekannt machen\n"
    "                window[$(this).attr('id')] = this;\n"
    "            } );\n"
    "\n"
    "            if (this.lastClone === undefined)\n"
    "            {\n"
    "                // Dann an das erste Element anfügen...\n"
    "                idx.after(clone);\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                // ...später an den jeweils letzten Klon.\n"
    "                this.lastClone.after(clone);\n"
    "            }\n"
    "            this.lastClone = clone;\n"
    "\n"
    "            return clone;\n"
    "        }\n"
    "\n"
    "        var firstChild = $(el);\n"
    "        this.elementToCopy = firstChild.clone(true);\n"
    "        this.lastClone = undefined;\n"
    "\n"
    "        // The data attribute of the replicated (cloned) view is set by the setData method with data from the nodes array when the clone is bound\n"
    "        for (var i = 0;i < nodes.length;i++)\n"
    "        {\n"
    "            // Die erste Node besteht schon, dort nur setData() aufrufen\n"
    "            if (i != 0)\n"
    "                var insertedNode = this.insertNode(firstChild,i);\n"
    "            // Beim ersten mal in das bestehende erste Elemente 'data' setzen, ansonsten in das neu kreierte\n"
    "            if (i == 0)\n"
    "                this.setData(firstChild,nodes[i]);\n"
    "            else\n"
    "                this.setData(insertedNode,nodes[i]);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "\n"
    "    this.DataElementMixin = function() {\n"
    "        // attributes = Build-in\n"
    "        // nodeName = Build-in\n"
    "\n"
    "        // appendChild() = Build-in\n"
    "        this.getAttr = function(name) {\n"
    "            return this.getAttribute(name);\n"
    "        }\n"
    "        // getElementsByTagName() = Build-in\n"
    "        this.getFirstChild = function() {\n"
    "            return this.firstChild;\n"
    "        }\n"
    "        this.getLastChild = function() {\n"
    "            var l = this.nextSibling;\n"
    "            while (l.nextSibling)\n"
    "                l = l.nextSibling;\n"
    "            return l;\n"
    "        }\n"
    "        this.handleDocumentChange = function(what, who, type, cobj) {\n"
    "            $(this).triggerHandler('onDocumentChange');\n"
    "        }\n"
    "        this.hasAttr = function(a) {\n"
    "            return this.hasAttribute(a);\n"
    "        }\n"
    "        // hasChildNodes() = Build-in\n"
    "        // insertbefore() = Build-in\n"
    "        this.removeAttr = function(a) {\n"
    "            return this.removeAttribute(a);\n"
    "        }\n"
    "        // removeChild() = Build-in\n"
    "        // replaceChild() = Build-in\n"
    "        this.setAttr = function(n,v) {\n"
    "            this.setAttribute(n,v);\n"
    "        }\n"
    "        this.setAttrs = function(o) { /* Deprecated */\n"
    "            Object.keys(o).forEach(function(key)\n"
    "            {\n"
    "                this.setAttr(key,o[key]);\n"
    "            });\n"
    "        }\n"
    "        this.setChildNodes = function(a) { /* Deprecated */\n"
    "            for (var i = 0;i < a.length;i++)\n"
    "            {\n"
    "                this.appendChild(a[i]);\n"
    "            }\n"
    "        }\n"
    "        this.setNodeName = function(name) { /* Deprecated */\n"
    "            this.setAttribute('nodeName',name);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.DataNodeMixin = function() {\n"
    "        // childNodes = Build-in\n"
    "        // nodeType = Build-in\n"
    "        this.ownerDocument = $(this).parents('document').get(0); // Untested\n"
    "        // parentNode = Build-in\n"
    "        this.sel = false;\n"
    "\n"
    "        this.childOf = function(el,allowself) {  // Ungetestet\n"
    "            if (allowself)\n"
    "                return $(el).find(this).andSelf().length > 0\n"
    "            else\n"
    "                return $(el).find(this).length > 0\n"
    "        }\n"
    "        // cloneNode = Build-in\n"
    "        this.getNextSibling = function() {\n"
    "            return this.nextSibling;\n"
    "        }\n"
    "        this.getOffset = function() {\n"
    "            return 'To Do';\n"
    "        }\n"
    "        this.getParent = function() {\n"
    "            return this.parentNode;\n"
    "        }\n"
    "        this.getPreviousSibling = function() {\n"
    "            return this.previousSibling;\n"
    "        }\n"
    "        this.getUserData = function(s) {\n"
    "            return $(this).data(s);\n"
    "        }\n"
    "        this.serialize = function() {\n"
    "            if (this && this.xml) { // IE 6 - IE 8\n"
    "                return this.xml;\n"
    "            } else { // W3C (Mozilla Firefox, Safari) or IE 9 (standard mode)\n"
    "                return (new XMLSerializer()).serializeToString(this);\n"
    "            }\n"
    "        }\n"
    "        this.setOwnerDocument = function(doc) {\n"
    "            this.setAttribute_('ownerDocument',doc);\n"
    "        }\n"
    "        this.setUserData = function(key,data,handler) {\n"
    "            $(this).data(key,data);\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    this.DataElement = function(name,attr,children) {\n"
    "        if (typeof name !== 'string')\n"
    "            throw new TypeError('Constructor function this.DataElement - first argument must be a string.');\n"
    "        if (attr && typeof attr !== 'object')\n"
    "            throw new TypeError('Constructor function this.DataElement - second argument must be a object dictionary.');\n"
    "\n"
    "        this.makeNodeList = function(count,name) {\n"
    "        }\n"
    "        this.stringToLzData = function(s,trim,nsprefix) {\n"
    "        }\n"
    "        this.valueToElement = function(o) {\n"
    "        }\n"
    "\n"
    "        var el = document.createElement(name);\n"
    "        // Firefox fügt immer das 'xmlns'-Attribut hinzu. Um das zu verhindern mit createElementNS ohne NS arbeiten\n"
    "        if (document.createElementNS)\n"
    "            el = document.createElementNS('',name);\n"
    "\n"
    "        if (attr)\n"
    "        {\n"
    "            for(var prop in attr) {\n"
    "                if (attr.hasOwnProperty(prop)) {\n"
    "                    el.setAttribute(prop,attr[prop]);\n"
    "                }\n"
    "            }\n"
    "        }\n"
    "        if (children)\n"
    "        {\n"
    "            for (var i = 0; i < children.length; i++) {\n"
    "                el.appendChild(children[i]);\n"
    "            }\n"
    "        }\n"
    "\n"
    "\n"
    "        // lz.DataElementMixin reinmixen\n"
    "        var mix = new lz.DataElementMixin();\n"
    "        for(var prop in mix) {\n"
    "            el[prop] = mix[prop];\n"
    "        }\n"
    "\n"
    "        // lz.DataNodeMixin reinmixen\n"
    "        var mix = new lz.DataNodeMixin();\n"
    "        for(var prop in mix) {\n"
    "            el[prop] = mix[prop];\n"
    "        }\n"
    "\n"
    "\n"
    "\n"
    "        return el;\n"
    "    }\n"
    "\n"
    "\n"
    "    this.DataText = function(s) {\n"
    "        if (typeof s !== 'string')\n"
    "            throw new TypeError('Constructor function this.DataText - first argument must be a string.');\n"
    "\n"
    "        this.LzDataText = function(text) {\n"
    "            return document.createTextNode(text); // Untested\n"
    "        }\n"
    "        this.setData = function(newdata) {\n"
    "            this.setAttribute_('data',newdata);\n"
    "        }\n"
    "\n"
    "        var el = document.createTextNode(s);\n"
    "\n"
    "        // lz.DataNodeMixin reinmixen\n"
    "        var mix = new lz.DataNodeMixin();\n"
    "        for(var prop in mix) {\n"
    "            el[prop] = mix[prop];\n"
    "        }\n"
    "\n"
    "        return el;\n"
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
    // Wegen Bsp. 37.2 'escapeTextFunction' drum herum
    "            return escapeTextFunction(this.rawdata);\n"
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
    "\n"
    "            // '/text()' kann/muss entfernt werden. Es würde auch mit klappen, nur beim counter nicht.\n"
    "            if (xpath.endsWith('/text()'))\n"
    "                xpath = xpath.substr(0,xpath.length-7);\n"
    "\n"
    "            // '/name()' muss entfernt werden. Er will dann den Tagnamen als Result haben (dieser wird dann in 'xpathQuery' zurückgeliefert)\n"
    "            if (xpath.endsWith('/name()'))\n"
    "                xpath = xpath.substr(0,xpath.length-7);\n"
    "\n"
    "\n"
    "            // Gets all nodes: var xpath = '/' + this.datasetName + '//*';\n"
    "\n"
    "            var node = undefined;\n"
    "            var nodeValue = undefined;\n"
    "            var nodeName = undefined;\n"
    "            var nodeType = undefined;\n"
    "            var p = undefined;\n"
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
    "            this.p = node; // Hoffe das stimmt so grob, dass p immer die letzte node ist\n"
    "            this.lastQueryChildrenCounter = childrenCounter;\n"
    "            this.lastQueryNumberOfNodesPointingTo = numberOfNodesPointingTo;\n"
    "\n"
    "            // Weil es kann undefined zurückliefern, oder boolescher Wert\n"
    "            if (this.lastNode === undefined) return undefined;\n"
    "            return (this.lastNode !== undefined);\n"
    "        }\n"
    "\n"
    "\n"
    "        // Normalweise wird beim anlegen alles initialisiert anhand des Arguments xpath\n"
    "        // Es gibt jedoch eine Stelle im GFlender-Code (CalcUmzugskostenpauschale)\n"
    "        // wo Quatsch übergeben wird als Argument. Das muss ich abfangen.\n"
    "        // **private** (iwie privat machen)\n"
    "        this.init = function(xpath) {\n"
    "            this.xpath = xpath;\n"
    "\n"
    "            this.datasetName = xpath.substring(0,xpath.indexOf(':'));\n"
    "\n"
    "            this.dataset = window[this.datasetName];\n"
    "\n"
    "            // Standardfall:\n"
    "            if (this.dataset && this.dataset.rawdata)\n"
    "            {\n"
    "                this.xml = getXMLDocumentFromString(this.dataset.rawdata);\n"
    "            }\n"
    "            // Wolkenfall:\n"
    "            else if (this.dataset && this.dataset.src)\n"
    "            {\n"
    "                // this.xml = getXMLDocumentFromFile(this.dataset.src);\n"
    "                // Will break due to cross-domain policy in testing environment\n"
    "                this.xml = getXMLDocumentFromString('<error><crossdomainpolicy></crossdomainpolicy></error>'); // Damit auf jeden Fall ein [Object Document] zurückkommt\n"
    "            }\n"
    "            else\n"
    "            {\n"
    //"                this.xml = getXMLDocumentFromString(''); // Damit auf jeden Fall ein [Object Document] zurückkommt\n"
    // Wirft im FF den Fehler 'Kein Element gefunden', deswegen packe ich nen xml rein:
    "                this.xml = getXMLDocumentFromString('<error><noxmlfound></noxmlfound></error>'); // Damit auf jeden Fall ein [Object Document] zurückkommt\n"
    "            }\n"
    "        }\n"
    "\n"
    "\n"
    //"        if (typeof xpath !== 'string' && typeof xpath !== 'object')\n"
    //"            throw new TypeError('Constructor function datapointer - first argument is no string.');\n"
    //"        if (xpath === '')\n"
    //"            throw new TypeError('Constructor function datapointer - first argument should not be empty.');\n"
    //"\n"
    "        this.rerunxpath = rerun; // Noch ziemlich oft 'undefined', aber das ist Absicht\n"
    "\n"
    "        this.lastNode = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.lastNodeText = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.lastNodeName = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.lastNodeType = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "        this.p = undefined; // Ergebnis wird von setXPath hier reingeschrieben\n"
    "\n"
    //"        // Wenn dieses blöde Objekt kommt, dann keine Initialisierung\n"
    //"        // Das 'object' (DOMWindow), welches GFlender einmal übergibt, muss ich aussparen\n"
    //"        if (typeof xpath !== 'object')\n"
    // Neu: Gemäß Bsp. lz.DataNodeMixin kann ein datapointer auch leer initialisiert werden. Deswegen oben die Errors raus
    // Und init nur dann durchführen, wenn ein nicht leerer String übergeben
    "        if (typeof xpath === 'string' && xpath !== '')\n"
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
    "            var lastP = this.p;\n"
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
    "            // Wenn Request mit 'name()' endet, will er immer den Tagnamen haben\n"
    "            if (query.endsWith('/name()'))\n"
    "                returnValue = this.lastNodeName;\n"
    "            // Wenn Request mit 'text()' endet, will er auf jeden Fall einen String haben, und sei es ein leerer\n"
    "            if (query.endsWith('/text()'))\n"
    "                returnValue = this.lastNodeText ? this.lastNodeText : '';\n"
    "\n"
    "            // alte 'pointer' wiederherstellen\n"
    "            this.lastNode = lastNode;\n"
    "            this.lastNodeText = lastNodeText;\n"
    "            this.lastNodeName = lastNodeName;\n"
    "            this.lastNodeType = lastNodeType;\n"
    "            this.p = lastP;\n"
    "\n"
    "            return returnValue;\n"
    "        }\n"
    "        this.setNodeText = function(text) {\n"
    "            // Lieber ohne jQuery, da kein HTML-Dokument, sondern eine Node\n"
    "            if (this.lastNode && typeof text == 'string')\n"
    "            {\n"
    "                this.lastNodeText = text; // Intern aktualisieren\n"
    "                this.lastNode.childNodes[0].nodeValue = text; // Extern aktualisieren\n"
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
    "            // Damit Beispiel lz.DataNodeMixin funzt, hier mit p arbeiten, falls p gesetzt\n"
    "            // p wird gesondert gesetzt in this.setPointer(). Ansonsten ist es eh immer this.lastNode.\n"
    "            // Irgendwas stimmt noch nicht ganz (evtl. gelöst jetzt wegen Zugriff auf 'firstChild' bei lastNodeText und einem hinzugefügten return false und Ergänzung von this.lastNode\n"
    "            if (this.p)\n"
    "            {\n"
    "                if (this.p.nextSibling != null)\n"
    "                {\n"
    "                    this.p = this.p.nextSibling;\n"
    "\n"
    "                    this.lastNode = this.p;\n"
    "                    // this.lastNodeText = this.p.nodeValue; <-- Ich denke das ist falsch, statt dessen:\n"
    "                    this.lastNodeText = this.p.firstChild.nodeValue;\n"
    "                    this.lastNodeName = this.p.nodeName;\n"
    "                    this.lastNodeType = this.p.nodeType;\n"
    "                    this.xpath = this.datasetName + ':' + this.getElementsXPath(this.lastNode);\n"
    "\n"
    "                    return true;\n"
    "                }\n"
    "                return false;\n"
    "            }\n"
    "\n"
    "\n"
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
    "            dupe.p = this.p;\n"
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
    "        this.setPointer = function(p) {\n"
    "            // init ohne Dataset in diesem Fall!\n"
    "            // Sollte evtl. dann auch eine eigene Init-Methode werden\n"
    "\n"
    "            // Gets all Nodes starting on root element, fehlender Leading '/' wird ergänzt\n"
    "            this.xpath = '/*';\n"
    "\n"
    "            // Kein dataset\n"
    "            this.datasetName = '';\n"
    "            this.dataset = '';\n"
    "\n"
    "            this.xml = getXMLDocumentFromString(p.serialize());\n"
    "\n"
    "            this.setXPath(this.xpath);\n"
    "\n"
    "            // In dem Fall p direkt übernehmen, sonst gehen zu viele Informationen verloren (z. B. parentNode)\n"
    "            this.p = p;\n"
    "        }\n"
    // Doesn't work with Example lz.DataNodeMixin
    //"        // Ich hatte 'p' die ganze Zeit schon. p ist wohl nichts anderes als this.lastNode!\n"
    //"        Object.defineProperty(this, 'p', {\n"
    //"            get : function(){ return this.lastNode; },\n"
    //"            set : function(newValue){ this.lastNode = newValue; $(this).triggerHandler('onp', newValue); },\n"
    //"            enumerable : false,\n"
    //"            configurable : true\n"
    //"        });\n"
    "    }\n"
    "\n"
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
    "\n"
    "\n"
    "\n"
    "    // Mit unregisterAll können alle zuvor gesetzten Delegates entfernt werden. Dazu hier drin sammeln.\n"
    "    this.allRegisteredDelegates = [];\n"
    "\n"
    "    /////////////////////////////////////////////////////////\n"
    "    // Delegate scheint es zu ermöglichen eine Methode an einen scope zu binden...\n"
    "    // ...und dann über register auf ein event zu horchen.\n"
    "    /////////////////////////////////////////////////////////\n"
    //    "LzDelegate = function(scope,method) { var fn = window[method]; return fn.bind(scope); }\n"
    //     Beispiel 2.3 in Chapter 27 klappt nur so:
    "    this.Delegate = function(scope,method) {\n"
    "        var fn = scope[method];\n"
    "        if (fn === undefined)\n"
    "            throw new TypeError('function lz.Delegate - The given method was not found in the given scope. Method not yet defined?');\n"
    "        var boundFn = fn.bind(scope)\n"
    "\n"
    "        // Durch das binden geht die Funktion register sonst verloren\n"
    "        // Deswegen erst nach dem binden anfügen\n"
    "        boundFn.register = function(v,ev) {\n"
    "            // Das Element intern sichern, damit ich in 'unregisterAll()' darauf zugreifen kann\n"
    "            lz.allRegisteredDelegates.push(v);\n"
    "\n"
    "            // 'onclick' klappt nicht, falls übergeben, es muss das 'on' davor entfernt werden (dies steckt implizit im Funktionsnamen)\n"
    "            // Aber 'oninit' ist kein JS-event-Handler!\n"
    "            if (ev.startsWith('on') && ev != 'oninit')\n"
    "                ev = ev.substr(2);\n"
    "            $(v).on(ev+'.DelegateRegister', this);\n"
    "        }\n"
    "\n"
    "        boundFn.unregisterAll = function() {\n"
    "            for (var i=0;i<lz.allRegisteredDelegates.length;i++)\n"
    "                $(lz.allRegisteredDelegates[i]).off('.DelegateRegister');\n"
    "            lz.allRegisteredDelegates = [];\n"
    "        }\n"
    "\n"
    "        return boundFn;\n"
    "    }\n"
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
    "var LzBrowser = lz.Browser;\n"
    "var LzEvent = lz.event;\n"
    "var LzFormatter = lz.Formatter;\n"
    "var LzView = lz.view;\n"
    "var LzText = lz.text;\n"
    "var LzDatapointer = lz.datapointer;\n"
    "var LzDataElement = lz.DataElement;\n"
    "var LzDataText = lz.DataText;\n"
    "var LzDelegate = lz.Delegate;\n"
    "var LzContextMenu = lz.contextmenu;\n"
    "\n"
    "// deprecated\n"
    "lz.DataNode = lz.DataElement;\n"
    "var LzDataNode = lz.DataElement;\n"
    "\n"
    "\n"
    "\n"
    "document.exitpage = {}; // <-- Taucht in general.js in 'setid' auf\n"
    "document.exitpage.request = {}; // <-- Taucht in general.js in 'setid' auf\n"
    "\n"
    "HTMLDivElement.prototype.doroll = function() {}; // ToDo <-- Seitdem ich rollUpDownContainerReplicator auswerte, taucht es auf\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "var SonstigeAusgaben = null; // ToDo <-- id von BDSinputgrid, welches noch nicht ausgewertet wird, deswegen muss ich die Var noch manuell bekannt machen\n"
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
    "        cookiedaten = cookiedaten.replace(/;/g,'&');\n"
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
    "Debug.debug = function(s,v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19) {\n"
    "    // Damit Example 5 von lz.Formatter kompiliert (jedoch ohne zu klappen):\n"
    "    s = s.replace(/%w/g,'%s');\n"
    "    s = s.replace(/%#w/g,'%s');\n"
    "    s = s + '<br />';\n"
    "    if ($('#debugInnerWindow').length)\n"
    "        $('#debugInnerWindow').append(sprintf(s,v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15,v16,v17,v18,v19));\n"
    "    //alert(s);\n"
    "};\n"
    "Debug.format = Debug.debug; // I don't c the difference between this 2 methods\n"
    "Debug.write = function(s1,v) {\n"
    "    if (v === undefined)\n"
    "        v = '';\n"
    "\n"
    "    var s = s1 + ' ' + v;\n"
    "    if ($('#debugInnerWindow').length)\n"
    "        $('#debugInnerWindow').append(s + '<br />');\n"
    "    else\n"
    "        console.log(s);\n"
    "    //alert(s);\n"
    "};\n"
    "Debug.explainStyleBindings = function(t) {\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Zentriere Anzeige beim öffnen der Seite             //\n"
    "/////////////////////////////////////////////////////////\n"
    "$(function()\n"
    "{\n"
    "    /////////////////////////////////////////////////////////\n"
    "    // Zentriere Anzeige beim resizen der Seite            //\n"
    "    // + aktualisiere Canvas                               //\n"
    "    /////////////////////////////////////////////////////////\n"
    "    $(window).resize(function()\n"
    "    {\n"
    "          // Erst, wenn DOM schon initialisiert! Deswegen hier drin\n"
    "          canvas.height = $(window).height();\n"
    "\n"
    "        adjustOffsetOnBrowserResize();\n"
    "    });\n"
    "\n"
    "\n"
    "    adjustOffsetOnBrowserResize();\n"
    "});\n"
    "\n"
    "function adjustOffsetOnBrowserResize()\n"
    "{\n"
    "    if ($('#element1').width() == '1000')\n"
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
    "    if (!immediate && $(this).data('olel') == 'drawview')\n"
    "    {\n"
    "        // Das canvas-Element hat ein (zwei?) Zwischen-Element(e), da muss ich dann eine Ebene höher springen.\n"
    "        p = p.parent().parent();\n"
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
    "var setAttributeFunc = function (attributeName, value, ifchanged, triggerMe) {\n"
    "    // So können setter setAttribute_ aufrufen, ohne das getriggert wird\n"
    "    if (triggerMe === undefined) triggerMe = true;\n"
    "\n"
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
    "            $(me).css('background-image','url(\\''+imgpath+'\\')');\n"
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
    "    function adjustColorValue(value) {\n"
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
    "        if (typeof value === 'string' && !value.startsWith('#') && isNumber(value) && value.length > 6)\n"
    "        {\n"
    "            value = '#' + Number(value).toString(16);\n"
    "            while (value.length > 6)\n"
    "                value = value.substr(1);\n"
    "            value = '#' + value;\n"
    "        }\n"
    "        if (typeof value === 'string' && !value.startsWith('#') && isNumber(value) && value.length <= 6) // Bsp. 1 <combobox>\n"
    "        {\n"
    "            value = Number(value).toString(16);\n"
    "            while (value.length < 6)\n"
    "                value = '0' + value;\n"
    "            value = '#' + value;\n"
    "        }\n"
    "        return value;\n"
    "    }\n"
    "\n"
    "    if (attributeName === undefined || attributeName === '')\n"
    "        throw 'Error1 calling setAttribute, no argument attributeName given (this = '+this+').';\n"
    "    if (value === undefined) // Wirklich Triple-= erforderlich, damit er 'null' passieren lässt bei 'text' und 'mask'\n"
    "        throw 'Error2 calling setAttribute, no argument value given or undefined (attributeName = \"'+attributeName+'\" and this = '+this+').';\n"
    "\n"
    "\n"
    "\n"
    "\n"
    //"    var me = globalMe;\n"
    "    var me = this;\n"
    //"    if (this.nodeName == 'DIV' || this.nodeName == 'INPUT' || this.nodeName == 'SELECT')\n"
    //"      me = this; // Wir wurden aus einem Kontext heraus aufgerufen x.setAttribute() - Und nicht aus DOMWindow\n"
    "\n"
    "\n"
    "    // Attribute können u. U. auch einen eigenen Setter gesetzt haben, dann diesen aufrufen\n"
    //"    alert(Object.getOwnPropertyDescriptor(Object.getPrototypeOf(me),attributeName));\n"
    //"    if (Object.getOwnPropertyDescriptor(me,attributeName) && Object.getOwnPropertyDescriptor(me,attributeName).set)\n"
    "    if (me['mySetterFor_'+attributeName+'_'])\n"
    "    {\n"
    "        var fnName = me['mySetterFor_'+attributeName+'_'];\n"
    "        var fn = me[fnName];\n"
    //"        alert(fn);\n"
    "        var boundFn = fn.bind(me)\n"
    //"        alert(boundFn);\n"
    "        boundFn(value);\n"
    "\n"
    "        // Dann raus, damit er nicht triggert (s. Chapter 29, 6.5)\n"
    "        return;\n"
    "    }\n"
    "\n"
    "\n"
    "    if (attributeName == 'text')\n"
    "    {\n"
    "        if (value === null) value = 'null'; // Damit er 'null' textuell ausgibt.\n"
    "\n"
    "        if ($(me).children().length > 0 && $(me).children(':first').is('input'))\n"
    "        {\n"
    "            $(me).children(':first').attr('value',value);\n"
    "        }\n"
    "        else if ($(me).is('input') && ($(me).attr('type') === 'checkbox' || $(me).attr('type') === 'radio'))\n"
    "        {\n"
    "            $(me).parent().children('span').html(value);\n"
    "        }\n"
    "        else if ($(me).is('input'))\n"
    "        {\n"
    "            $(me).attr('value',value);\n"
    "        }\n"
    "        else\n"
    "        {\n"
    //"            $(me).html(value);\n"
    // Wegen Bsp. 37.2 wohl eher text()
    // ne, muss html() bleiben, damit keine <br>'s auftauchen auf der Taxango-Startseite.
    "            $(me).html(value);\n"
    "\n"
    "            // Wegen Example 16.1, bei Buttons width mit outerwidth setzen\n"
    "            if ($(me).is('button'))\n"
    "                $(me).width($(me).outerWidth()/* -22 */);\n"
    "\n"
    "            if (me.resize)\n"
    "            {\n"
    "                // hmmmm, wo kam das her? Wegen Bsp. 21.14 muss ich hier genau nix machen\n"
    "                // Wegen Bsp. 29.17 muss ich hier sehr wohl was machen!.\n"
    "                // ne, bei Bsp 29.17 betrifft es eher das allgemeine resizen von Elementen, nicht speziell text\n"
    "                //$(me).parent().height($(me).height()+4); // + 4 for the padding of div_text\n"
    "                //$(me).parent().width($(me).width()+4); // + 4 for the padding of div_text\n"
    "                // Die Lösung ist: Ich muss triggern!\n"
    "                // Weil sich bei einem neuen Text meist die Breite/Höhe ändert, triggern!\n"
    "                $(me).triggerHandler('onwidth',me.width);\n"
    "                $(me).triggerHandler('onheight',me.height);\n"
    "            }\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName == 'value')\n"
    "    {\n"
    "        if ($(me).is('input') && $(me).attr('type') === 'checkbox')\n"
    "        {\n"
    "            $(me).prop('checked',value);\n"
    "        }\n"
    "        else if ($(me).is('option'))\n"
    "        {\n"
    "            $(me).val(value);\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            alert('So far unsupported value for value in setAttribute_()');\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName == 'font')\n"
    "    {\n"
    "        $(me).css('font-family',value+',Verdana,sans-serif');\n"
    "        // Die Eigenschaft font-family überträgt sich auf alle Kinder und Enkel\n"
    "        $(me).find('.div_text').css('font-family',value+',Verdana,sans-serif')\n"
    "    }\n"
    "    else if (attributeName == 'fontsize')\n"
    "    {\n"
    "        $(me).css('font-size',value+'px');\n"
    "        // Die Eigenschaft font-size überträgt sich auf alle Kinder und Enkel\n"
    "        $(me).find('.div_text').css('font-size',value+'px')\n"
    "    }\n"
    "    else if (attributeName == 'fontstyle')\n"
    "    {\n"
    "        if (value === 'plain')\n"
    "        {\n"
    "            $(me).css('font-style','normal');\n"
    "            $(me).find('.div_text').css('font-style','normal')\n"
    "            $(me).css('font-weight','normal');\n"
    "            $(me).find('.div_text').css('font-weight','normal')\n"
    "        }\n"
    "        // contains() und nicht ===, weil mit der Angabe 'bolditalic' auch beides auf einmal gelten kann\n"
    "        if (value.contains('bold'))\n"
    "        {\n"
    "            $(me).css('font-weight','bold');\n"
    "            $(me).find('.div_text').css('font-weight','bold')\n"
    "        }\n"
    "        if (value.contains('italic'))\n"
    "        {\n"
    "            $(me).css('font-style','italic');\n"
    "            $(me).find('.div_text').css('font-style','italic')\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName == 'bgcolor')\n"
    "    {\n"
    "        value = adjustColorValue(value);\n"
    "        $(me).css('background-color',value);\n"
    "    }\n"
    "    else if (attributeName == 'fgcolor')\n"
    "    {\n"
    "        value = adjustColorValue(value);\n"
    "        $(me).css('color',value);\n"
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
    "\n"
    "        $(me).data('widthOnlySetByHelperFn',false);\n"
    "\n"
    "        if ($(me).is('canvas'))\n"
    "        {\n"
    "            // Attribut 'width' noch mitsetzen\n"
    "            $(me).attr('width',value);\n"
    "            // 'canvas' hat ein umgebendes Div. Dort 'width' parallel mitsetzen\n"
    "            $(me).parent().css('width',value);\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName == 'height')\n"
    "    {\n"
    "        // jQuery doesn't like plain strings containing a number\n"
    "        if (typeof value === 'string' && !value.endsWith('px') && !value.endsWith('%'))\n"
    "            value = value + 'px';\n"
    "\n"
    "        $(me).css('height',value);\n"
    "\n"
    "        $(me).data('heightOnlySetByHelperFn',false);\n"
    "\n"
    "        if ($(me).is('canvas'))\n"
    "        {\n"
    "            // Attribut 'height' noch mitsetzen\n"
    "            $(me).attr('height',value);\n"
    "            // 'canvas' hat ein umgebendes Div. Dort 'height' parallel mitsetzen\n"
    "            $(me).parent().css('height',value);\n"
    "        }\n"
    "    }\n"

    "    else if (attributeName === 'layout')\n"
    "    {\n"
    "        // Alle 'whitespaces' entfernen (welche erlaubt sind), aber zum testen auf den Inhalt von 'value' nerven\n"
    "        value = value.replace(/\\s/g,'');\n"
    "        var spacing = parseInt(value.betterParseInt());\n"
    "        if (isNaN(spacing))\n"
    "            spacing = 0;\n"
    "\n"
    "        if (!value.contains('class') || value.contains('class:simplelayout'))\n"
    "        {\n"
    "            // Y ist bei Simplelayout der Default-Wert, deswegen auf 'x' testen, ansonsten 'else'-Zweig\n"
    "            if (value.contains('axis:x'))\n"
    "            {\n"
    "                setSimpleLayoutXIn(me,spacing);\n"
    "            }\n"
    "            else // if (value.contains('axis:y'))\n"
    "            {\n"
    "                setSimpleLayoutYIn(me,spacing);\n"
    "            }\n"
    "        }\n"
    "        else if (value.contains('class:constantlayout'))\n"
    "        {\n"
    "            if (value.contains('axis:x'))\n"
    "            {\n"
    "                $(me).children().each(function() { $(this).setAttribute_('x',spacing+'px'); });\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                $(me).children().each(function() { $(this).setAttribute_('y',spacing+'px'); });\n"
    "            }\n"
    "        }\n"
    "        else if (value.contains('class:wrappinglayout'))\n"
    "        {\n"
    "            if (value.contains('axis:y'))\n"
    "            {\n"
    "                var x = 0; // (0 scheint richtig), alt: parseInt($(me).css('left'));\n"
    "\n"
    "                $(me).children().each(function() {\n"
    "                    if ($(this).prev().length > 0) // Das erste Kind sitzt schon richtig\n"
    "                    {\n"
    "                        var y = $(this).prev().outerHeight()+parseInt($(this).prev().css('top'))+spacing;\n"
    "                        // Check ob wir noch reinpassen, sonst x anpassen für nächste Spalte\n"
    "                        if (y+$(this).outerHeight() > $(me).height())\n"
    "                        {\n"
    "                            y = 0;\n"
    "                            x += $(this).outerWidth() + spacing;\n"
    "\n"
    "                            // Auch das umgebende div vergrößern, falls nicht fix\n"
    "                            if (me.style.width == '' || $(me).data('widthOnlySetByHelperFn'))\n"
    "                            {\n"
    "                                $(me).width($(me).width()+$(this).width()+spacing);\n"
    "                                $(me).data('widthOnlySetByHelperFn',true);\n"
    "                            }\n"
    "                        }\n"
    "\n"
    "                        $(this).setAttribute_('x',x+'px');\n"
    "                        $(this).setAttribute_('y',y+'px');\n"
    "                    }\n"
    "                });\n"
    "            }\n"
    "            else // axis: x (= default bei wrappinglayout)\n"
    "            {\n"
    "                var y = 0; // (0 scheint richtig), alt: parseInt($(me).css('top'));\n"
    "\n"
    "                $(me).children().each(function() {\n"
    "                    if ($(this).prev().length > 0) // Das erste Kind sitzt schon richtig\n"
    "                    {\n"
    // Es muss wirklich outerWidth hier usw. sein, wegen Bsp. 30.1
    "                        var x = $(this).prev().outerWidth()+parseInt($(this).prev().css('left'))+spacing;\n"
    "                        // Check ob wir noch reinpassen, sonst y anpassen für nächste Zeile\n"
    "                        if (x+$(this).outerWidth() > $(me).width())\n"
    "                        {\n"
    "                            y += $(this).outerHeight() + spacing;\n"
    "                            x = 0;\n"
    "\n"
    "                            // Auch das umgebende div vergrößern, falls nicht fix\n"
    "                            if (me.style.height == '' || $(me).data('heightOnlySetByHelperFn'))\n"
    "                            {\n"
    "                                $(me).height($(me).height()+$(this).height()+spacing);\n"
    "                                $(me).data('heightOnlySetByHelperFn',true);\n"
    "                            }\n"
    "                        }\n"
    "\n"
    "                        $(this).setAttribute_('x',x+'px');\n"
    "                        $(this).setAttribute_('y',y+'px');\n"
    "                    }\n"
    "                });\n"
    "            }\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            alert('Ein Layout, welches noch ausgwertet werden muss.');\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName === 'defaultplacement')\n"
    "    {\n"
    //"        $(me).data('defaultplacement_',value);\n"
    "        me.defaultplacement = value;\n"
    "    }\n"
    "    else if (attributeName === 'clip' && value === false)\n"
    "    {\n"
    "        // clip='false', just in case, set overflow back to default.\n"
    "        $(me).css('overflow','visible');\n"
    "    }\n"
    "    else if (attributeName === 'clip' && value === true)\n"
    "    {\n"
    "        // clip='true', so clipping to width and height\n"
    //  $(me).css('clip','rect(0px, '+$(me).width()+'px, '+$(me).height(+'px, 0px)');\n"
    //  clip macht zu oft Ärger. Passt sich nicht an, wenn sich Höhe oder Breite ändert. Erstmal
    //  ganz rausgenommem, weil es auch sehr gut nur mit der overflow-Angabe klappt. Falls clip doch
    //  irgendwo unbedingt erforderlich ist, wäre eine Alternative width und height zu watchen.
    "        $(me).css('overflow','hidden');\n"
    "    }\n"
    "    else if (attributeName === 'rotation')\n"
    "    {\n"
    "        var v = 'rotate('+value+'deg)';\n"
    "        var w = '0% 0% 0';\n"
    "\n"
    "        $(me).css('-moz-transform',v); // FF\n"
    "        $(me).css('-webkit-transform',v); // Safari, Chrome\n"
    "        $(me).css('-o-transform',v); // Opera\n"
    "        $(me).css('-ms-transform',v); // IE\n"
    "        $(me).css('transform',v); // W3C\n"
    "        $(me).css('-moz-transform-origin',w); // FF\n"
    "        $(me).css('-webkit-transform-origin',w); // Safari, Chrome\n"
    "        $(me).css('-o-transform-origin',w); // Opera\n"
    "        $(me).css('-ms-transform-origin',w); // IE\n"
    "        $(me).css('transform-origin',w); // W3C\n"
    "    }\n"
    "    else if (attributeName === 'clickable')\n"
    "    {\n"
    "        if (value === true)\n"
    "        {\n"
    "            // Pointer-Events zulassen\n"
    "            $(me).css('pointer-events','auto');\n"
    "            // Maus-Cursor anpassen\n"
    "            $(me).css('cursor','pointer');\n"
    "        }\n"
    "        else if (value === false)\n"
    "        {\n"
    "            // Pointer-Events verhindern\n"
    "            $(me).css('pointer-events','none');\n"
    "            // Maus-Cursor zurück auf default\n"
    "            $(me).css('cursor','auto');\n"
    "        }\n"
    "        else\n"
    "            alert('So far unsupported value for clickable. value: '+value);\n"
    "    }\n"
    "    else if (attributeName === 'focusable' && value === false)\n"
    "    {\n"
    "        $(me).on('focus.blurnamespace', function() { this.blur(); });\n"
    "    }\n"
    "    else if (attributeName === 'focusable' && value === true)\n"
    "    {\n"
    "        // Einen eventuell vorher gesetzten focus-Handler, der blur() handlet, entfernen\n"
    "        $(me).off('focus.blurnamespace');\n"
    "    }\n"
    "    else if (attributeName === 'focustrap')\n"
    "    {\n"
    "        // To Do When 'true' dann wird der Focus-Bereich z. B. auf ein bestimmtes Fenster beschränkt\n"
    "    }\n"
    "    else if (attributeName === 'mask')\n"
    "    {\n"
    "        $(me).data('mask_',value); // noch ka warum man den explizit setzen kann\n"
    "    }\n"
    "    else if (attributeName === 'doesenter')\n"
    "    {\n"
    "        // If set to true, the component manager will call this component with doEnterDown\n"
    "        // and doEnterUp when the enter key goes up or down if it is focussed\n"
    "        $(me).data('doesenter_',value);\n"
    "    }\n"
    "    else if (attributeName === 'styleable')\n"
    "    {\n"
    "        me.styleable = value; // Ruft den dazu gehörigen Setter auf (der speichert dann den value)\n"
    "    }\n"
    "    else if (attributeName === 'style')\n"
    "    {\n"
    //"        if (me.styleable)\n"
    //"        {\n"
    //"            if ($(me).attr('style'))\n"
    //"            {\n"
    //"                // Dann 'style' ergänzen\n"
    //"\n"
    //"                // Sollte eigentlich nicht passieren, aber zur absoluten Sicherheit:\n"
    //"                if (!$(me).attr('style').endsWith(';'))\n"
    //"                    value = ';' + value;\n"
    //"\n"
    //"                $(me).attr('style',$(me).attr('style')+value);\n"
    //"            }\n"
    //"            else\n"
    //"            {\n"
    //"                // Dann 'style' neu setzen\n"
    //"                $(me).attr('style',value);\n"
    //"            }\n"
    //"        }\n"
    "        $(me).find('input, button').andSelf().filter('input, button').each(function() { if (this.styleable) $(this).addClass(value); });\n"
    "        $(me).prev('h3').each(function() { if (this.styleable) $(this).addClass(value); }); // <-- Um auch den Header von TabPanels zu erwischen\n"
    "    }\n"
    "    else if (attributeName === 'styleclass')\n"
    "    {\n"
    "        $(me).addClass(value);\n"
    "    }\n"
    "    else if (attributeName === 'initstage')\n"
    "    {\n"
    "        if (value === 'defer')\n"
    "            //$(me).hide() // ToDo: Bricht Anzeige Kinder;\n"
    "\n"
    "        if (value === 'immediate' || value === 'early' || value === 'normal' || value === 'late')\n"
    "            jQuery.noop(); /* no operation */\n"
    "\n"
    "        $(me).data('initstage_',value);\n"
    "    }\n"
    "    else if (attributeName === 'align')\n"
    "    {\n"
    "        if (value === 'center')\n"
    "        {\n"
    "            // this.align = value; // hmmm, Zugriff auf die Original-JS-Propertys erstmal\n"
    "            // Richte das Element entsprechend mittig (horizontale Achse) aus\n"
    "            $(me).css('left',toIntFloor((parseInt($(me).parent().css('width'))-parseInt($(me).outerWidth()))/2));\n"
    "        }\n"
    "        else if (value === 'right')\n"
    "        {\n"
    "            $(me).css('left',$(me).parent().width()-$(me).outerWidth());\n"
    "        }\n"
    "        else if (value === 'left')\n"
    "        {\n"
    "            $(me).css('left', 0); // Default-Value\n"
    "        }\n"
    "        else\n"
    "            alert('So far unsupported value for align. value: '+value);\n"
    "    }\n"
    "    else if (attributeName === 'valign')\n"
    "    {\n"
    "        if (value === 'middle')\n"
    "        {\n"
    "            // http://phrogz.net/css/vertical-align/index.html\n"
    "            // Setting the attribute 'valign:middle' by computing difference of height of surrounding element and inner element. And setting the half of it as CSS top.\n"
    "            // Dies beides klappt nicht wirklich...\n"
    "            // 1) position:absolute; top:50%; margin-top:-12px;\n"
    "            // 2) line-height:4em;\n"
    "            $(me).css('top',toIntFloor((parseInt($(me).parent().css('height'))-parseInt($(me).outerHeight()))/2));\n"
    "        }\n"
    "        else if (value === 'bottom')\n"
    "        {\n"
    "            // Bottom heißt es soll am untern Ende des umgebenden divs aufsetzen\n"
    "            $(me).css('top',toInt((parseInt($(me).parent().css('height'))-parseInt($(me).outerHeight()))));\n"
    "        }\n"
    "        else if (value === 'top')\n"
    "        {\n"
    "            // Nichts zu tun, der Ausgangswert\n"
    "            $(me).css('vertical-align','top');\n"
    "        }\n"
    "        else\n"
    "            alert('So far unsupported value for valign. value: '+value);\n"
    "    }\n"
    "    else if (attributeName == 'opacity')\n"
    "    {\n"
    "        $(me).css('opacity',value);\n"
    "    }\n"
    "    else if (attributeName == 'visible')\n"
    "    {\n"
    "        // Muss intern mitgespeichert werden, um es auslesen zu können bei SA\n"
    "        $(me).data('visible_',value);\n"
    "\n"
    "        // Sprung bei 'input' und 'select', und 'me' neu belegen, damit er am Ende auch das richtige Element triggert\n"
    "        if (isMultiEl(me))\n"
    "            me = $(me).parent().get(0);\n"
    "\n"
    "        if (value == true || value == 'true')\n"
    "        {\n"
    "            $(me).show();\n"
    "        }\n"
    "        else if (value == false || value == 'false')\n"
    "        {\n"
    "            $(me).hide();\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            alert('Unsupported value for visible. value: '+value);\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName == 'frame')\n"
    "    {\n"
    "        // frames sind 1-basiert\n"
    // Sonst klappt Beispiel 8.8 nicht
    "        value--;\n"
    "\n"
    "        if ($.isArray(me.resource))\n"
    "          $(me).css('background-image','url('+me.resource[value]+')');\n"
    //"        else\n"
    //"          throw 'setAttribute_ - Error trying to set frame. (value = '+value+', me.resource = '+me.resource+', me.id = '+me.id+').';\n"
    "    }\n"
    "    else if (attributeName == 'background-image')\n"
    "    {\n"
    "       alert('Wer ruft mich denn auf? Seltsam.'); $(me).css('background-image','url('+value+')');\n"
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
    "    else if (attributeName == 'isdefault')\n"
    "    {\n"
    "       // Give me focus; To Do\n"
    "    }\n"
    "    else if (attributeName == 'enabled' && ($(me).is('input') || $(me).is('select')))\n"
    "    {\n"
    "        $(me).get(0).disabled = !value;\n"
    "\n"
    "        // Auch die Textfarbe des zugehörigen Textes anpassen\n"
    "        if (($(me).attr('type') === 'checkbox' || $(me).attr('type') === 'radio') && $(me).next().is('span') && $(me).next().css('color') == 'rgb(0, 0, 0)' && value == false)\n"
    "        {\n"
    "            $(me).next().css('color','darkgrey');\n"
    "            $(me).next().css('cursor','default');\n"
    "            $(me).css('cursor','default');\n"
    "            $(me).parent().css('cursor','default');\n"
    "        }\n"
    "        if (($(me).attr('type') === 'checkbox' || $(me).attr('type') === 'radio') && $(me).next().is('span') && $(me).next().css('color') == 'rgb(169, 169, 169)' && value == true)\n"
    "        {\n"
    "            $(me).next().css('color','black');\n"
    "            $(me).next().css('cursor','pointer');\n"
    "            $(me).css('cursor','pointer');\n"
    "            $(me).parent().css('cursor','pointer');\n"
    "        }\n"
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
    "                $(me).hover(function() { $(me).css('background-image','url(\\''+imgpath1+'\\')') }, function() { $(me).css('background-image','url(\\''+imgpath0+'\\')') });\n"
    "                if ('ontouchstart' in document.documentElement)\n"
    "                {\n"
    "                    $(me).on('touchstart',function() { $(me).css('background-image','url(\\''+imgpath2+'\\')') });\n"
    "                    $(me).on('touchend',function() { $(me).css('background-image','url(\\''+imgpath0+'\\')') });\n"
    "                }\n"
    "                else\n"
    "                {\n"
    "                    $(me).on('mousedown',function() { $(me).css('background-image','url(\\''+imgpath2+'\\')') });\n"
    "                    $(me).on('mouseup',function() { $(me).css('background-image','url(\\''+imgpath0+'\\')') });\n"
    "                }\n"
    "            }\n"

    "        }\n"
    "        else\n"
    "        {\n"
    "            if (typeof value === 'string' && value.contains('.'))\n"
    "                setWidthAndHeightAndBackgroundImage(me,value);\n"
    "            else if (typeof value === 'string' && value != '')\n"
    "                setWidthAndHeightAndBackgroundImage(me,window[value]);\n"
    //"            else\n"
    //"                throw 'setAttribute_ - Error trying to set resource. (value = '+value+', me.id = '+me.id+').';\n"
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
    "    else if ($(me).hasClass('div_text') && (attributeName == 'resize')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        // In jedem Falle speichern. Es wird von addText()/setText() berücksichtigt.\n"
    "        me.resize = value;\n"
    "\n"
    "        if (value === false)\n"
    "        {\n"
    "            // Setting the width with myself, because resize=false, so I won't resize accidently\n"
    "            $(me).width($(me).width());\n"
    "\n"
    "        }\n"
    "        if (value === true)\n"
    "        {\n"
    "            $(me).css('height','auto');\n"
    "\n"
    "        }\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'multiline')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        if (value === false)\n"
    "        {\n"
    "            // False ist wohl der in '.div_text' definierte CSS-Wert 'white-space:nowrap;'\n"
    "            // Nur bei true muss ich es abändern auf 'white-space:normal;'\n"
    "        }\n"
    "        if (value === true)\n"
    "        {\n"
    "            $(me).css('white-space','normal');\n"
    "        }\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'selectable')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        if (value === false)\n"
    "        {\n"
    "            // False ist wohl der in '.div_text' definierte CSS-Wert 'user-select:none;'\n"
    "            // Nur bei true muss ich es abändern auf 'user-select:text;'\n"
    "        }\n"
    "        if (value === true)\n"
    "        {\n"
    "            $(me).css('-webkit-user-select','text');\n"
    "            $(me).css('-khtml-user-select','text'); /* Safari */\n"
    "            $(me).css('-moz-user-select','text');\n"
    "            $(me).css('-o-user-select','text');\n"
    "            $(me).css('user-select','text');\n"
    "\n"
    "            $(me).css('pointer-events','auto');\n"
    "        }\n"
    "    }\n"
    "    else if ( /* $(me).hasClass('div_text') && --bricht sonst zu viel-- */ (attributeName == 'textalign')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        $(me).css('text-align',value);\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'textindent')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        $(me).css('text-indent',value+'px');\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'letterspacing')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        $(me).css('letter-spacing',value+'px');\n"
    "    }\n"
    "    else if ($(me).hasClass('div_text') && (attributeName == 'textdecoration')) // Nur vom Element 'text' von Haus aus gesetzt\n"
    "    {\n"
    "        $(me).css('text-decoration',value);\n"
    "    }\n"
    "    else if ($(me).hasClass('iframe_standard') && attributeName == 'src') // Nur vom Element 'html' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // src-Attribut des iframe setzen\n"
    "        $(me).html('<iframe style=\"width:inherit;height:inherit;\" src=\"'+value+'\"></iframe>');\n"
    "    }\n"
    "    else if ($(me).is('option') && attributeName == 'text_x') // Nur vom Element 'textlistitem' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // Direktes setzen des margin-left klappt zumindestens bei Webkit nicht... Deswegen Leerzeichen einfügen\n"
    "        var anzahl_leerzeichen = parseInt(value / 5); // Für 5 Pixel ein Leerzeichen\n"
    "        for (var i = 0;i < anzahl_leerzeichen;i++)\n"
    "        {\n"
    "            $(me).html('&nbsp;'+$(me).html());\n"
    "        }\n"
    "    }\n"
    "    else if ($(me).is('option') && attributeName == 'text_y') // Nur vom Element 'textlistitem' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        // not supported so far. Man könnte den margin nach oben und unten setzen der <option>. Unterstützt aber nur FF\n"
    "    }\n"
    "    else if ($(me).hasClass('div_window') && attributeName == 'title') // Nur vom Element 'window' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        $(me).children('.div_windowTitle').html(value);\n"
    "    }\n"
    "    else if ($(me).hasClass('div_window') && attributeName == 'resizable') // Nur vom Element 'window' von Haus aus gesetztes Attribut\n"
    "    {\n"
    "        if (value == true)\n"
    "        {\n"
    "            $(me).resizable();\n"
    "\n"
    "            $(me).on('resize', function(event,ui) {\n"
    "                $('#'+this.id+'_content_').get(0).setAttribute_('width',ui.size.width /* -10 */);\n"
    "                $('#'+this.id+'_content_').get(0).setAttribute_('height',ui.size.height-20);\n"
    "                $(this).triggerHandler('onwidth',ui.size.width);\n"
    "                $(this).triggerHandler('onheight',ui.size.height);\n"
    "            });\n"
    "\n"
    "            $(me).on('resizestop', function(event,ui) {\n"
    "                $('#'+this.id+'_content_').get(0).setAttribute_('width',ui.size.width /* -10 */);\n"
    "                $('#'+this.id+'_content_').get(0).setAttribute_('height',ui.size.height-20);\n"
    "                $(this).triggerHandler('onwidth',ui.size.width);\n"
    "                $(this).triggerHandler('onheight',ui.size.height);\n"
    "            });\n"
    "        }\n"
    "    }\n"
    "    else if ($(me).hasClass('div_window') && attributeName == 'allowdrag') // Nur Element 'window'\n"
    "    {\n"
    "        if (value == true)\n"
    "        {\n"
    "            $(me).draggable();\n"
    "            $(me).on('drag', function(event,ui) {\n"
    "                $(this).triggerHandler('ony',ui.position.top);\n"
    "                $(this).triggerHandler('onx',ui.position.left);\n"
    "            });\n"
    "            $(me).on('dragstop', function(event,ui) {\n"
    "                $(this).triggerHandler('ony',ui.position.top);\n"
    "                $(this).triggerHandler('onx',ui.position.left);\n"
    "            });\n"
    "        }\n"
    "    }\n"
    "    else if ($(me).hasClass('div_window') && attributeName == 'closeable') // Nur Element 'window'\n"
    "    {\n"
    "        // To Do\n"
    "    }\n"
    "    else if (attributeName === 'index')\n"
    "    {\n"
    "        // Noch ka, wird von GFlender benutzt, in der Klasse baserollUpDownContainer. Wo das Attribut herkommt: unklar!\n"
    "        // Ich reiche es erstmal einfach durch:\n"
    "        me.index = value;\n"
    "    }\n"
    "    else if (attributeName === 'spacing' && ($(me).data('olel') == 'vbox' || $(me).data('olel') == 'hbox')) // <vbox>/<hbox>\n"
    "    {\n"
    "        $(me).data('spacing_',value);\n"
    "\n"
    "        if ($(me).data('olel') == 'vbox')\n"
    "        {\n"
    "            adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY(me,value);\n"
    "            setSimpleLayoutYIn(me,value);\n"
    "        }\n"
    "        if ($(me).data('olel') == 'hbox')\n"
    "        {\n"
    "            adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX(me,value);\n"
    "            setSimpleLayoutXIn(me,value);\n"
    "        }\n"
    "    }\n"
    "    else if (attributeName === 'inset' && ($(me).data('olel') == 'vbox' || $(me).data('olel') == 'hbox')) // <vbox>/<hbox>\n"
    "    {\n"
    "        $(me).data('inset_',value);\n"
    "        // inset noch unimplementiert\n"
    "\n"
    "        if ($(me).data('olel') == 'vbox')\n"
    "        {\n"
    "            adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY(me,me.spacing);\n"
    "            setSimpleLayoutYIn(me,me.spacing);\n"
    "        }\n"
    "        if ($(me).data('olel') == 'hbox')\n"
    "        {\n"
    "            adjustWidthOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutX(me,me.spacing);\n"
    "            setSimpleLayoutXIn(me,me.spacing);\n"
    "        }\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        // Wenn es vorher nicht matcht, dann einfach die Property setzen, dann ist es eine selbst definierte Variable\n"
    "        // Aber erstmal noch sammeln der Vars, die gesetzt werden sollen. Später lockern\n"
    "        // Vorher aber Test ob die Property auch vorher definiert wurde! Sonst läuft wohl etwas schief\n"
    "        if (attributeName === 'zusammenveranlagung' ||\n"
    "            attributeName === 'titlewidth' ||\n"
    "            attributeName === 'controlwidth' ||\n"
    "            attributeName === 'inset_y' ||\n"
    "            attributeName === 'focused' ||\n"
    "            attributeName === 'day' ||\n"
    "            attributeName === 'userchecked' ||\n"
    "            attributeName === 'spacing' ||\n"
    "            attributeName === 'isopen' ||\n"
    "            attributeName === 'start' ||\n"
    "            attributeName === 'ende' ||\n"
    "            attributeName === 'checked' || // Von BDSCheckbox\n"
    "            attributeName === 'parentnumber' ||\n"
    "            attributeName === 'season' ||\n"
    "            attributeName === 'animduration' ||\n"
    "            attributeName === 'pooling' ||\n"
    "            attributeName === 'size' ||\n"
    "            attributeName === 'text_x' ||\n"
    "            attributeName === 'label' ||\n"
    "            attributeName === 'countApplies' ||\n"
    "            attributeName === 'mouseIsDown' ||\n"
    "            attributeName === 'applied' ||\n"
    "            attributeName === 'digitcolor' ||\n"
    "            attributeName === 'bezpartnerdbig' ||\n"
    "            attributeName === 'bezpartnerdsmall' ||\n"
    "            attributeName === 'bezpartnermsmall' ||\n"
    "            attributeName === 'bezpartnermbig' ||\n"
    "            attributeName === 'bezpartnerpr' ||\n"
    "            attributeName === 'bezpartnerpronom_nominativ_gross' ||\n"
    "            attributeName === 'avalue')\n"
    "        {\n"
    "            if (me[attributeName] !== undefined)\n"
    "                me[attributeName] = value;\n"
    "            else\n"
    "                alert('Trying to set a property that never was declared! - Propertyname: '+attributeName);\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            alert('Aufruf von setAttribute_, der noch ausgewertet werden muss.\\n\\nattributeName: ' + attributeName + '\\n\\nvalue: ' + value + '\\n\\nolel:' + $(me).data('olel'));\n"
    "        }\n"
    "    }\n"
    "\n"
    "    // In jedem Fall: triggern! Das sieht OL so vor\n"
    "    // Kein bubblen, sondern Point-2-Point-Logik in OL, deswegen triggerHandler\n"
    "    // der getzte Wert (value) wird als Extra-Parameter mit gesendet\n"
    "    if (triggerMe)\n"
    "        $(me).triggerHandler('on'+attributeName,value);\n"
    "\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+me.id+'_repl'+c).length)\n"
    "    {\n"
    "        // Gemäß Bsp. 'lz.ReplicationManager' ist das hier falsch... (Deswegen testweise mal hier rausgenommen)\n"
    "        //$('#'+me.id+'_repl'+c).get(0).setAttribute_(attributeName,value);\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "// Object.prototype ist verboten und bricht jQuery und z.B. JS .split()! Deswegen über defineProperty\n"
    "// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Object/defineProperty\n"
    "Object.defineProperty(Object.prototype, 'setAttribute_', {\n"
    "    enumerable: false, // Darf nicht auf 'true' gesetzt werden! Sonst bricht jQuery!\n"
    "    configurable: true,\n"
    "    writable: false,\n"
    "    value: setAttributeFunc\n"
    "});\n"
    "\n"
    // Funktioniert nicht, bricht irgendwas in jQuery -> Evtl. jetzt nicht mehr, weil Umstieg auf HTMLElement.prototype?!
    //"// Wegen Chapter 15 5.\n"
    //"Object.defineProperty(HTMLElement.prototype, 'unload', {\n"
    //"    enumerable: false, // Darf nicht auf 'true' gesetzt werden! Sonst bricht jQuery!\n"
    //"    configurable: true,\n"
    //"    writable: false,\n"
    //"    value: function() {}\n"
    //"});\n"
    //"\n"
    //"\n"
    //"// Für alle DOM-Objekte\n"
    //"// Ohne enumerabe und configurable, sonst beschwert sich Safari\n"
    //"// bricht leider jQuery.... deswegen auskommentiert. HTMLDivElement (s. u.) muss reichen.\n"
    //"// Object.defineProperty(Element.prototype, 'setAttribute', {\n"
    //"// value: setAttributeFunc\n"
    //"// } );\n"
    //"\n"
    //"// Sonderbehandlung für Firefox:\n"
    //"// https://developer.mozilla.org/en/JavaScript-DOM_Prototypes_in_Mozilla\n"
    //"// Node klappt nicht...\n"
    //"// Element klappt nicht...\n"
    //"// HTMLElement klappt auch nicht...\n"
    //"// Aber HTMLDivElement... wtf Firefox??\n"
    //"// HTMLDivElement.prototype.setAttribute = setAttributeFunc; // <- Nicht mehr nötig seit setAttribute_\n"
    //"// HTMLInputElement.prototype.setAttribute = setAttributeFunc; // <- Nicht mehr nötig seit setAttribute_\n"
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
    "// Attribute/Methoden von <div> (OL: <node>)           //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// id = Build-in\n"
    "// name = Build-in\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// addSubview()                                        //\n"
    "/////////////////////////////////////////////////////////\n"
    "var addSubviewFunction = function (node) {\n"
    "    $(this).append(node);\n"
    "\n"
    "    $(this).triggerHandler('onaddsubview');\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.addSubview = addSubviewFunction;\n"
    "HTMLInputElement.prototype.addSubview = addSubviewFunction;\n"
    "HTMLSelectElement.prototype.addSubview = addSubviewFunction;\n"
    "HTMLButtonElement.prototype.addSubview = addSubviewFunction;\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// destroy() - nachimplementiert                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "var destroyFunction = function () {\n"
    "    $(this).triggerHandler('ondestroy');\n"
    "\n"
    "    // Referenz auf dieses Element im parent nullen - Wegen Bsp. 33.10\n"
    "    this.getTheParent()[$(this).data('name')] = null;\n"
    "\n"
    "    $(this).remove();\n"
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
    "// init() - nachimplementiert                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var initFunction = function () {\n"
    "    $(this).triggerHandler('oninit');\n"
    "    this.inited = true;\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.init = initFunction;\n"
    "HTMLInputElement.prototype.init = initFunction;\n"
    "HTMLSelectElement.prototype.init = initFunction;\n"
    "HTMLButtonElement.prototype.init = initFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// inited - nachimplementiert\n"
    "/////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.inited = false;\n"
    "HTMLInputElement.prototype.inited = false;\n"
    "HTMLSelectElement.prototype.inited = false;\n"
    "HTMLButtonElement.prototype.inited = false;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// isinited - undokumentiert - aber in Example 29.27 taucht es auf\n"
    "/////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.isinited = true;\n"
    "HTMLInputElement.prototype.isinited = true;\n"
    "HTMLSelectElement.prototype.isinited = true;\n"
    "HTMLButtonElement.prototype.isinited = true;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// animate() - nachimplementiert                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "var animateFunction = function (prop,to,duration,isRelative,moreArgs,motion) {\n"
    "    // Animationen mit gemischten process-Angaben (sequential,simultaneous) klappen noch nicht...\n"
    "\n"
    "    if (prop === undefined)\n"
    "        throw new Error('animate() - First argument should not be undefined');\n"
    "    if (prop !== 'x' && prop !== 'y' && prop !== 'width' && prop !== 'height' && prop !== 'rotation' && prop !== 'alpha' && prop !== 'spacing' && prop !== 'opacity')\n"
    "        throw new Error('animate() - First argument must contain one of the following values: x, y, width, height, rotation, opacity or alpha (or spacing on vbox/hbox)');\n"
    "    var originalProp = prop; // damit triggerHandler() onx/ony triggert\n"
    "    if (prop === 'x') prop = 'left';\n"
    "    if (prop === 'y') prop = 'top';\n"
    "\n"
    "    if (to === undefined)\n"
    "        throw new Error('animate() - Second argument (to) should not be undefined');\n"
    "\n"
    "    if (duration === 0)\n"
    "    {\n"
    "        this.setAttribute_(prop,to);\n"
    "        return;\n"
    "    }\n"
    "\n"
    "    if (isRelative === undefined)\n"
    "        isRelative = false;\n"
    "\n"
    "    // Neben 'swing' wird derziet nur 'linear' von jQuery unterstützt (mehr über jQuery Plugins möglich)\n"
    "    if (motion != 'linear')\n"
    "        motion = 'swing';\n"
    "\n"
    "    if (isRelative)\n"
    "        to = '+=' + to;\n"
    "\n"
    "    var queue = false;\n"
    "    if (typeof moreArgs === 'object')\n"
    "    {\n"
    "        if (moreArgs.process === 'sequential')\n"
    "            queue = true;\n"
    "\n"
    "        if (moreArgs.duration)\n"
    "            duration = moreArgs.duration;\n"
    "    }\n"
    "    if (duration === undefined) // wenn weder direkt, noch in moreArgs übergeben, dann eben 0\n"
    "        duration = 0;\n"
    "\n"
    "\n"
    "    // Zu animierende Property. Den string direkt im Objekt angeben, klappt nicht. Deswegen danach per 'Array'-Syntax setzen\n"
    "    var p = {}\n"
    "    p[prop] = to;\n"
    "\n"
    "    // Der eigentliche Aufruf der Animation:\n"
    "    if (prop !== 'spacing')\n"
    "    {\n"
    "        // Animationen laufen in jQuery immer parallel ab (s. Bsp. 17.8, deswegen queue = false)\n"
    "        $(this).animate(p, { duration : duration, queue : queue, easing : motion, step : function(now,fx) { $(this).triggerHandler('on'+originalProp,now); } });\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        var from = this.spacing;\n"
    "        var delta = from - to;\n"
    "\n"
    "        // $(this).animate({ spacing : 1 }, { duration : duration }); // <-- Doesn't work. Iwie landet falsches this im setter\n"
    "        // opacity, um einfach nur irgendwas (nicht) zu animieren, die eigentliche Animation dann über step\n"
    "        $(this).animate({ opacity : $(this).css('opacity') }, { duration : duration, queue : queue, easing : motion, step : function(now,fx) { this.setAttribute_('spacing',from - delta * fx.state); } });\n"
    "    }\n"
    "\n"
    "\n"
    "    // return new lz.animator(this,prop,to,duration,undefined,undefined,motion,isRelative,false,moreArgs);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.animate = animateFunction;\n"
    "HTMLInputElement.prototype.animate = animateFunction;\n"
    "HTMLSelectElement.prototype.animate = animateFunction;\n"
    "HTMLButtonElement.prototype.animate = animateFunction;\n"
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
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'options'                         //\n"
    "// INIT-ONLY (deswegen ohne setAttribute_()            //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'options', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('options_');\n"
    "    },\n"
    "    set : function(newValue){ if (isDOM(this)) $(this).data('options_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'styleclass'                      //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'styleclass', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('styleclass_');\n"
    "    },\n"
    "    set : function(newValue){ if (isDOM(this)) this.setAttribute_('styleclass',newValue,undefined,false); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'transition'                      //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'transition', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('transition_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('transition_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'initstage'                       //\n"
    "// INIT-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'initstage', {\n"
    "    get : function(){\n"
    "        return $(this).data('initstage_');\n"
    "    },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'nodeLevel'                       //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'nodeLevel', {\n"
    "    get : function(){\n"
    "        return 3 // To Do;\n"
    "    },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    //"/////////////////////////////////////////////////////////\n"
    //"// Getter/Setter for 'defaultplacement'                //\n"
    //"// INIT-ONLY                                           //\n"
    //"/////////////////////////////////////////////////////////\n"
    //"Object.defineProperty(HTMLElement.prototype, 'defaultplacement', {\n"
    //"    get : function(){\n"
    //"        return $(this).data('defaultplacement_');\n"
    //"    },\n"
    //"    enumerable : false,\n"
    //"    configurable : true\n"
    //"});\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Attribute/Methoden von <div> (OL: <replicator>)     //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// nodes / ToDo                                         //\n"
    "//////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.nodes = [];\n"
    "HTMLInputElement.prototype.nodes = [];\n"
    "HTMLSelectElement.prototype.nodes = [];\n"
    "HTMLButtonElement.prototype.nodes = [];\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// AttributeMethoden von <div class=\"div_text\"> (OL: <text>) //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Nur für class='div_text' sind diese Methoden gültig //\n"
    "/////////////////////////////////////////////////////////\n"
    "function warnOnWrongClass(me) {\n"
    "    if (!$(me).hasClass('div_text')) {\n"
    "        alert('Wieso meinst du mich aufrufen zu können? Du bist doch gar kein \\'div_text\\'. Ernsthafte Frage!');\n"
    "        return true;\n"
    "    }\n"
    "    return false;\n"
    "}\n"
    "\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// addFormat()                                          //\n"
    "//////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.addFormat = function() {\n"
    "    warnOnWrongClass(this);\n"
    "    $(this).append(sprintf.apply(null, arguments));\n"
    "    $(this).triggerHandler('ontext',sprintf.apply(null, arguments));\n"
    "}\n"
    "\n"
    "\n"
    "//////////////////////////////////////////////////////////\n"
    "// addText()                                            //\n"
    "//////////////////////////////////////////////////////////\n"
    "HTMLDivElement.prototype.addText = function(s) {\n"
    "    warnOnWrongClass(this);\n"
    "\n"
    "    if (s === undefined)\n"
    "        throw new Error('addText() - argument should not be undefined');\n"
    "    s = String(s); // Damit s.replace keinen Error wirft bei übergebenen numbers\n"
    "\n"
    "    s = s.replace(/\\n/g,'<br />');\n"
    "    $(this).append(s);\n"
    "    $(this).triggerHandler('ontext',s);\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// clearText()                                         //\n"
    "/////////////////////////////////////////////////////////\n"
    "var clearTextFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    this.setAttribute_('text', '');\n"
    "}\n"
    "// Nur für div! Da es die Methode nur bei <div class=\"div_text\"> gibt\n"
    "HTMLDivElement.prototype.clearText = clearTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// escapeText()                                        //\n"
    "/////////////////////////////////////////////////////////\n"
    "var escapeTextFunction = function (s) {\n"
    "    // warnOnWrongClass(this);\n"
    "\n"
    "    var escapedText = s;\n"
    "    if (escapedText == undefined)\n"
    "        escapedText = this.text;\n"
    "    // Wenn dann immer noch undefined, dann raus.\n"
    "    if (escapedText == undefined)\n"
    "        return undefined;\n"
    "\n"
    "    // \" und ' doppelt, damit sich der TextEditor daran nicht verschluckt und allen nachfolgenden Code als String auffasst. OMG!\n"
    "    var findReplace = [[/&/g, '&amp;'], [/</g, '&lt;'], [/>/g, '&gt;'], [/\"/g, '&quot;'], [/\"/g, '&quot;'], [/'/g, '&apos;'], [/'/g, '&apos;']];\n"
    "    for(var item in findReplace)\n"
    "        escapedText = escapedText.replace(findReplace[item][0], findReplace[item][1]);\n"
    "\n"
    "    return escapedText;\n"
    "}\n"
    "HTMLDivElement.prototype.escapeText = escapeTextFunction;\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// getText() - nachimplementiert - deprecated!         //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getTextFunction = function () {\n"
    "    warnOnWrongClass(this);\n"
    "    return $(this).html();\n"
    "}\n"
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
    "    s = s.replace(/\\n/g,'<br />');\n"
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
    "// Attribute/Methoden von <input type=\"text\"> (OL: <edittext>) //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'text'                            //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLInputElement.prototype, 'text', {\n"
    "    get : function() { return $(this).val(); },\n"
    "    set : function(newValue) { $(this).val(newValue); }, \n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
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
    "// Attribute/Methoden von <input type=\"checkbox\"> (OL: <checkbox>)//\n"
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
    "// Attribute/Methoden von <select> (OL: <basecombobox>)//\n"
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
    "// Attribute/Methoden von <select> (OL: <list>)        //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
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
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Attribute/Methoden von <canvas> (OL: <drawview>)    //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// clear() - nachimplementiert (interner Aufruf)       //\n"
    "/////////////////////////////////////////////////////////\n"
    "var clearFunction = function () {\n"
    "    var context = this.getContext('2d');\n"
    "    context.clearRect(0, 0, this.width, this.height);\n"
    "}\n"
    "\n"
    "HTMLCanvasElement.prototype.clear = clearFunction;\n"
    "\n"
    //"CanvasRenderingContext2D.prototype.context = true;\n"
    //"// Auch das direkte CanvasRendering-Objekt kriegt die Clear-Methode\n"
    //"CanvasRenderingContext2D.prototype.clear = function() { this.clearRect(0, 0, this.canvas.width, this.canvas.height); } ;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// clear() - nachimplementiert (externer Aufruf)       //\n"
    "// Kann auch extern aufgerufen werden (Bsp. 13.10). Dann an div binden, weil canvas ein umgebendes Div hat.//\n"
    "/////////////////////////////////////////////////////////\n"
    "var clearFunction = function () {\n"
    "    if ($(this).children().eq(0).is('canvas'))\n"
    "        $(this).children().eq(0).get(0).clear();\n"
    "    else\n"
    "        throw new Error('function clear() for Element canvas - This call went wrong.');\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.clear = clearFunction;\n"
    "\n"
    "// Für OL sind das HTMLCanvasElement und CanvasRenderingContext2D auf der gleichen 'this'-ebene angesiedelt.\n"
    "// Der erste Ansatz war das this in Handlern, Methoden und Attributen von drawviews auf element.getContext('2d')\n"
    "// zu mappen. Aber das hätte noch umfangreichere Folgeänderungen zu folgen. In InterpretObject das neue zuweisen\n"
    "// der Attribute und auch alle Getter und Setter müssten nur für diesen Fall auf das Canvas-Element testen und dann\n"
    "// den Aufruf immer an this.getContext('2d') weiterleiten. Dies sind zu große Folgeänderungen und zerstören die\n"
    "// derzeit einfach zu lesenden Setter/Getter. - Neuer Ansatz: Mappen der Methoden im getContext('2d')-Objekt\n"
    "// direkt in das Canvas-Objekt, um so der OL-Logik zu entsprechen (That's JavaScript on its Edge).\n"
    "// Attribute:\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'aliaslines', {\n"
    "    get : function(){ this.getContext('2d').aliaslines; },\n"
    "    set : function(newValue){ this.getContext('2d').aliaslines = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'cachebitmap', {\n"
    "    get : function(){ this.getContext('2d').cachebitmap; },\n"
    "    set : function(newValue){ this.getContext('2d').cachebitmap = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'fillStyle', {\n"
    "    get : function(){ this.getContext('2d').fillStyle; },\n"
    "    set : function(newValue){ this.getContext('2d').fillStyle = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'globalAlpha', {\n"
    "    get : function(){ this.getContext('2d').globalAlpha; },\n"
    "    set : function(newValue){ this.getContext('2d').globalAlpha = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'lineCap', {\n"
    "    get : function(){ this.getContext('2d').lineCap; },\n"
    "    set : function(newValue){ this.getContext('2d').lineCap = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'lineJoin', {\n"
    "    get : function(){ this.getContext('2d').lineJoin; },\n"
    "    set : function(newValue){ this.getContext('2d').lineJoin = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'lineWidth', {\n"
    "    get : function(){ this.getContext('2d').lineWidth; },\n"
    "    set : function(newValue){ this.getContext('2d').lineWidth = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'measuresize', {\n"
    "    get : function(){ this.getContext('2d').measuresize; },\n"
    "    set : function(newValue){ this.getContext('2d').measuresize = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'miterLimit', {\n"
    "    get : function(){ this.getContext('2d').miterLimit; },\n"
    "    set : function(newValue){ this.getContext('2d').miterLimit = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLCanvasElement.prototype, 'strokeStyle', {\n"
    "    get : function(){ this.getContext('2d').strokeStyle; },\n"
    "    set : function(newValue){ this.getContext('2d').strokeStyle = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "// Methoden:\n"
    "HTMLCanvasElement.prototype.arc = function(a,b,c,d,e,f) { this.getContext('2d').arc(a,b,c,d,e,f); };\n"
    "HTMLCanvasElement.prototype.beginPath = function() { this.getContext('2d').beginPath(); };\n"
    "HTMLCanvasElement.prototype.bezierCurveTo = function(a,b,c,d,e,f) { this.getContext('2d').bezierCurveTo(a,b,c,d,e,f); };\n"
    "HTMLCanvasElement.prototype.closePath = function() { this.getContext('2d').closePath(); };\n"
    "HTMLCanvasElement.prototype.createLinearGradient = function(a,b,c,d) { return this.getContext('2d').createLinearGradient(a,b,c,d); };\n"
    "HTMLCanvasElement.prototype.createRadialGradient = function(a,b,c,d,e,f) { return this.getContext('2d').createRadialGradient(a,b,c,d,e,f); };\n"
    "HTMLCanvasElement.prototype.fill = function() { this.getContext('2d').fill(); };\n"
    "HTMLCanvasElement.prototype.lineTo = function(a,b) { this.getContext('2d').lineTo(a,b); };\n"
    "HTMLCanvasElement.prototype.moveTo = function(a,b) { this.getContext('2d').moveTo(a,b); };\n"
    "HTMLCanvasElement.prototype.oval = function(a,b,c,d) { this.getContext('2d').oval(a,b,c,d); };\n"
    "HTMLCanvasElement.prototype.quadraticCurveTo = function(a,b,c,d) { this.getContext('2d').quadraticCurveTo(a,b,c,d); };\n"
    "HTMLCanvasElement.prototype.rect = function(a,b,c,d,e,f,g,h) { this.getContext('2d').rect(a,b,c,d,e,f,g,h); };\n"
    "HTMLCanvasElement.prototype.stroke = function() { this.getContext('2d').stroke(); };\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Attribute/Methoden von <input> (OL: <basevaluecomponent>)//\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////COMPLETE////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "// Das Original 'value' von inputs ist ein hart gecodeter String\n"
    "// Es mus jedoch z. B. wegen Beispiel <checkbox> ein Boolean sein\n"
    "// Wirklich alle versuchen das umzubiegen oder zu überschreiben, hat nicht geklappt\n"
    "// Deswegen eigene myValue-Property, die beim Konvertieren angepasst wird\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'myValue'                         //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLInputElement.prototype, 'myValue', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        if ($(this).is('input') && $(this).attr('type') === 'checkbox')\n"
    "            return $(this).is(':checked');\n"
    "\n"
    "        if ($(this).is('input'))\n"
    "            return this.value;\n"
    "\n"
    "        return $(this).data('value_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('value_',newValue); this.value = newValue; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "Object.defineProperty(HTMLOptionElement.prototype, 'myValue', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).val();\n"
    "    },\n"
    "    set : function(newValue){ $(this).val(newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'type'                            //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLInputElement.prototype, 'type', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('type_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('type_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// acceptValue()                                       //\n"
    "/////////////////////////////////////////////////////////\n"
    "var acceptValueFunction = function (data, type) {\n"
    "    if (type === undefined) type = this.type;\n"
    "    // ...\n"
    "}\n"
    "HTMLInputElement.prototype.acceptValue = acceptValueFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// getValue()                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "// schonmal weiter oben definiert bei <edittext>\n"
    "// HTMLInputElement.prototype.getValue = getTextFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// presentValue()                                      //\n"
    "/////////////////////////////////////////////////////////\n"
    "var presentValueFunction = function (type) {\n"
    "    if (type === undefined) type = $(this).data('type_');\n"
    "\n"
    "    if (type === 'color')\n"
    "    {\n"
    "        if (this.getValue() == 0)\n"
    "            return 'black';\n"
    "        else if (this.getValue() == 16777215)\n"
    "            return 'white';\n"
    "        else\n"
    "            return '#'+Number(this.value).toString(16);\n"
    "    }\n"
    "\n"
    "    // Value als String zurückliefern\n"
    "    return String(this.getValue());\n"
    "}\n"
    "HTMLInputElement.prototype.presentValue = presentValueFunction;\n"
    "\n"
    "// field ist der undokumentierte Zugriff auf das eigentliche field\n"
    "// Zugriff darauf wird derzeit nicht unterstützt bzw,. einfach this\n"
    "HTMLInputElement.prototype.field = function() { return this; }\n"
    "\n"
    "// undokumentierte Zugriff auf ein pattern...\n"
    "// Zugriff darauf wird derzeit nicht unterstützt\n"
    "HTMLInputElement.prototype.setPattern = function() { }\n"
    "\n"
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
    "/////////////////////////////////////////////////////////\n"
    "// Attribute/Methoden von <div> (OL: <vbox> / <hbox>)  //\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////COMPLETE////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'inset'                           //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'inset', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('inset_');\n"
    "    },\n"
    "    set : function(newValue){ this.setAttribute_('inset',newValue,undefined,false); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'spacing' (HTMLElement.prototype, bricht sonst jQuery) //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'spacing', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('spacing_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('spacing_',newValue); /* this.setAttribute_('spacing',newValue,undefined,false); */ },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Methoden von <div> (OL: <state>)                    //\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////COMPLETE////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// apply()                                             //\n"
    "/////////////////////////////////////////////////////////\n"
    "var applyFunction = function () {\n"
    "    this.setAttribute_('applied', true);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.apply = applyFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// remove()                                            //\n"
    "/////////////////////////////////////////////////////////\n"
    "var removeFunction = function () {\n"
    "    this.setAttribute_('applied', false);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.remove = removeFunction;\n"
    "\n"
    "\n"
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
    "// getAttributeRelative() - nachimplementiert          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getAttributeRelativeFunction = function (prop, ref) {\n"
    "    if (typeof prop !== 'string' && prop !== 'x' && prop !== 'y' && prop !== 'width' && prop !== 'height')\n"
    "        throw new Error('getAttributeRelative() - Unsupported value for first argument.');\n"
    "    if (prop === 'x') return $(this).offset().left - $(ref).offset().left;\n"
    "    if (prop === 'y') return $(this).offset().top; - $(ref).offset().top;\n"
    "    if (prop === 'width') return $(this).width() - $(ref).width();\n"
    "    if (prop === 'height') return $(this).height() - $(ref).height();\n"
    "\n"
    "    return undefined;\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.getAttributeRelative = getAttributeRelativeFunction;\n"
    "HTMLInputElement.prototype.getAttributeRelative = getAttributeRelativeFunction;\n"
    "HTMLSelectElement.prototype.getAttributeRelative = getAttributeRelativeFunction;\n"
    "HTMLButtonElement.prototype.getAttributeRelative = getAttributeRelativeFunction;\n"
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
    "/////////////////////////////////////////////////////////\n"
    "// bringToFront() - nachimplementiert                  //\n"
    "/////////////////////////////////////////////////////////\n"
    "var bringToFrontFunction = function (oThis) {\n"
    "    $(this).css('zIndex', Math.max.apply(null, $.map($('div:first').find('*'), function(e,i) { return e.style.zIndex; }))+1);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.bringToFront = bringToFrontFunction;\n"
    "HTMLInputElement.prototype.bringToFront = bringToFrontFunction;\n"
    "HTMLSelectElement.prototype.bringToFront = bringToFrontFunction;\n"
    "HTMLButtonElement.prototype.bringToFront = bringToFrontFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// sendBehind() - nachimplementiert                    //\n"
    "/////////////////////////////////////////////////////////\n"
    "var sendBehindFunction = function (el) {\n"
    "    var z = $(el).css('zIndex');\n"
    "    if (z == 'auto')\n"
    "        z = $(el).parents('[zIndex!=\"auto\"]').css('zIndex');\n"
    "\n"
    "    $(this).css('zIndex', z-1);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.sendBehind = sendBehindFunction;\n"
    "HTMLInputElement.prototype.sendBehind = sendBehindFunction;\n"
    "HTMLSelectElement.prototype.sendBehind = sendBehindFunction;\n"
    "HTMLButtonElement.prototype.sendBehind = sendBehindFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// sendInFrontOf() - nachimplementiert                 //\n"
    "/////////////////////////////////////////////////////////\n"
    "var sendInFrontOfFunction = function (el) {\n"
    "    var z = $(el).css('zIndex');\n"
    "    if (z == 'auto')\n"
    "        z = $(el).parents('[zIndex!=\"auto\"]').css('zIndex');\n"
    "\n"
    "\n"
    "    $(this).css('zIndex', z+1);\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.sendInFrontOf = sendInFrontOfFunction;\n"
    "HTMLInputElement.prototype.sendInFrontOf = sendInFrontOfFunction;\n"
    "HTMLSelectElement.prototype.sendInFrontOf = sendInFrontOfFunction;\n"
    "HTMLButtonElement.prototype.sendInFrontOf = sendInFrontOfFunction;\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// presentAttribute() - nachimplementiert              //\n"
    "// undokumentiert, aber taucht in Example 20.5 auf und in Doku nur am Rande erwähnt//\n"
    "/////////////////////////////////////////////////////////\n"
    "var presentAttributeFunction = function (attr,as) {\n"
    "    function rgb2hex(rgb) {\n"
    "        function hex(x) {\n"
    "            return ('0' + parseInt(x).toString(16)).slice(-2);\n"
    "        }\n"
    //"        rgb = rgb.match(/^rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*(\\d+))?\\)$/);\n"
    // Besser:
    "        rgb = rgb.match(/^rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*(1|0|0?\\.\\d+))?\\)$/);\n"
    "        return '#' + hex(rgb[1]) + hex(rgb[2]) + hex(rgb[3]);\n"
    "    }\n"
    "\n"
    "    if (attr === 'bgcolor' && as === 'color')\n"
    "    {\n"
    "        var c = $(this).css('background-color');\n"
    "        c = rgb2hex(c);\n"
    "\n"
    "        if (c === '#000000') c = 'black';\n"
    "        if (c === '#800000') c = 'maroon';\n"
    "        if (c === '#008000') c = 'green';\n"
    "        if (c === '#000080') c = 'navy';\n"
    "        if (c === '#c0c0c0') c = 'silver';\n"
    "        if (c === '#ff0000') c = 'red';\n"
    "        if (c === '#00ff00') c = 'lime';\n"
    "        if (c === '#0000ff') c = 'blue';\n"
    "        if (c === '#808080') c = 'gray';\n"
    "        if (c === '#800080') c = 'purple';\n"
    "        if (c === '#808000') c = 'olive';\n"
    "        if (c === '#008080') c = 'teal';\n"
    "        if (c === '#ffffff') c = 'white';\n"
    "        if (c === '#ff00ff') c = 'fuchsia';\n"
    "        if (c === '#ffff00') c = 'yellow';\n"
    "        if (c === '#00ffff') c = 'aqua';\n"
    "\n"
    "        return c;\n"
    "    }\n"
    "\n"
    "    throw new TypeError('So far unsupported call of presentAttribute');\n"
    "}\n"
    "\n"
    "HTMLDivElement.prototype.presentAttribute = presentAttributeFunction;\n"
    "HTMLInputElement.prototype.presentAttribute = presentAttributeFunction;\n"
    "HTMLSelectElement.prototype.presentAttribute = presentAttributeFunction;\n"
    "HTMLButtonElement.prototype.presentAttribute = presentAttributeFunction;\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "// Attribute          von <div> (OL: <view>)           //\n"
    "/////////////////////////////////////////////////////////\n"
    "////////////////////////INCOMPLETE///////////////////////\n"
    "/////////////////////////////////////////////////////////\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'aaactive'                        //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'aaactive', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('aaactive_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('aaactive_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'aadescription'                   //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'aadescription', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('aadescription_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('aadescription_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'aaname'                          //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'aaname', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('aaname_') || $(this).html();\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('aaname_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'aasilent'                        //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'aasilent', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('aasilent_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('aasilent_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'aatabindex'                      //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'aatabindex', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "\n"
    "        return $(this).data('aatabindex_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('aatabindex_',newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'layout'                          //\n"
    "// READ/WRITE                                          //\n"
    "// Speichern des Wertes per jQuery in 'layout_', sonst infinite loop\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'layout', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "        if (!$(this).data('layout_')) $(this).data('layout_', new lz.layout());\n"
    "\n"
    "        return $(this).data('layout_');\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('layout_',newValue); $(this).triggerHandler('onlayout', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'loadratio'                       //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'loadratio', {\n"
    "    get : function(){ return 1; },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter for 'mask' (setter only to trigger an event) //\n"
    "// mask seems to be the next clipped parent.           //\n"
    "/////////////////////////////////////////////////////////\n"
    "var findNextMaskedElement = function(e) {\n"
    "    return $(e).parents().filter(function() {\n"
    "        return $(this).css('clip').startsWith('rect');\n"
    "    });\n"
    "}\n"
    "\n"
    "// ... aber der Getter gibt stets den korrekt berechneten Wert zurück...\n"
    "// ... und der Setter triggert im wesentlichen nur 'onmask'. Ein übergebener Wert \n"
    "// wird trotzdem mal gespeichert. Aber er sollte nie über 'mask' accessible sein.\n"
    "Object.defineProperty(HTMLElement.prototype, 'mask', {\n"
    "    get : function(){ return findNextMaskedElement(this).get(0) ? findNextMaskedElement(this).get(0) : null; },\n"
    "    set : function(newValue){ $(this).data('mask_',newValue); $(this).triggerHandler('onmask',newValue); },\n"
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
    // "    get : function(){ return $(this).find('*').get(); },\n"
    // Damit er rotatenumber auswerten kann, muss es children sein und nicht find!
    "    get : function(){ return $(this).children('*').get(); },\n"
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
    "// bei jQueri UI gibt es auch parent. Um Kompatibilität damit aufrecht zu erhalten, myParent\n"
    "// Umstieg auf HTMLElement.prototype! Evtl. jetzt kompatibel?\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'myParent'                        //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'myParent', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "        return this.getTheParent();\n"
    "    },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'immediateparent'                 //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'immediateparent', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return this.getTheParent(true); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'context'                         //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'context', {\n"
    "    get : function(){ if ($(this).is('canvas')) return (this.getContext('2d')); return null; },\n"
    "    // Der triggerHandler() MUSS drin bleiben, sonst aktualisiert sich Drawview nicht richtig bei Animationen\n"
    "    set : function(newValue){ if ($(this).is('canvas')) { this.getContext('2d') = newValue; $(this).triggerHandler('oncontext', newValue); } },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'y'                               //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'y', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('top')); },\n"
    "    set : function(newValue){ $(this).css('top', newValue); $(this).triggerHandler('ony', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'x'                               //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'x', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('left')); },\n"
    "    set : function(newValue){ $(this).css('left', newValue); $(this).triggerHandler('onx', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'bgcolor'                         //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'bgcolor', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).css('background-color'); },\n"
    "    set : function(newValue){ $(this).css('background-color', newValue); $(this).triggerHandler('onbgcolor', newValue); },\n"
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
    "    set : function(newValue){ this.setAttribute_('opacity', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'height'                          //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'height', {\n"
    //"    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('height'));  },\n"
    // Gemäß Beispiel 7.4 sind es die outer-Werte!
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).outerHeight();  },\n"
    "    set : function(newValue){ if (isDOM(this)) $(this).css('height',newValue); $(this).triggerHandler('onheight', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'width'                           //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'width', {\n"
    //"    get : function(){ if (!isDOM(this)) return undefined; return parseInt($(this).css('width'));  },\n"
    // Gemäß Beispiel 7.4 ist es outerWidth!
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).outerWidth();  },\n"
    "    set : function(newValue){ if (isDOM(this)) $(this).css('width',newValue); $(this).triggerHandler('onwidth', newValue); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'unstretchedheight'               //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'unstretchedheight', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).outerHeight(); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'unstretchedwidth'                //\n"
    "// READ-ONLY                                           //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'unstretchedwidth', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).outerWidth(); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Getter/Setter for 'visible'                         //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "// Es MUSS HTMLElement sein, sonst bricht das sichern der Attribute in 'interpretObject()', weil 'visible' immer undefined zurückliefert (das Objekt in dem gesichert wird, ist kein DOM)\n"
    "Object.defineProperty(HTMLElement.prototype, 'visible', {\n"
    "    get : function(){ if (!isDOM(this)) return undefined; return $(this).is(':visible');  },\n"
    "    // Eigentlich immer über setAttribute setzen. Falls doch direkte Zuweisung, dann nicht triggern\n"
    "    set : function(newValue){ if (isDOM(this)) this.setAttribute_('visible',newValue,undefined,false); },\n"
    "    enumerable : false,\n"
    "    configurable : true\n"
    "});\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "\n"
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
    "// Getter/Setter for 'styleable'                       //\n"
    "// (von 'basecomponent')                               //\n"
    "// READ/WRITE                                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "Object.defineProperty(HTMLElement.prototype, 'styleable', {\n"
    "    get : function(){\n"
    "        if (!isDOM(this)) return undefined;\n"
    "        if ($(this).data('styleable_') !== undefined) return $(this).data('styleable_');\n"
    "        return true; /* => Default Value */\n"
    "    },\n"
    "    set : function(newValue){ $(this).data('styleable_', newValue); },\n"
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
    //"Object.defineProperty(HTMLElement.prototype, 'align', {\n"
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
    //
    //
    //
    // Wo kommt das her???? Es gibt gar kein Attribut textalign gemäß Doku. --> Doch, gibt es, s. Example 21.21
    // Es hat bei mir die Auswertung von 'radiobutton' gebrochen, deswegen raus genommen.
    //"/////////////////////////////////////////////////////////\n"
    //"// Getter/Setter for 'textalign'                       //\n"
    //"// READ/WRITE                                          //\n"
    //"/////////////////////////////////////////////////////////\n"
    //"Object.defineProperty(HTMLElement.prototype, 'textalign', {\n"
    //"    get : function(){ if (!isDOM(this)) return undefined; return $(this).css('text-align'); },\n"
    //"    set : function(newValue){\n"
    //"        if (newValue !== 'left' && newValue !== 'center' && newValue !== 'right')\n"
    //"            throw new Error('Unsupported value for textalign.');\n"
    //"\n"
    //"        $(this).css('text-align', newValue);\n"
    //"        $(this).triggerHandler('textalign', newValue);\n"
    //"    },\n"
    //"    enumerable : false,\n"
    //"    configurable : true\n"
    //"});\n"
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
    "    // Text SOLL (im Normalfall) resizen, deswegen für 'text' keine fixe Breite/Höhe und raus hier.\n"
    "    // Auch wenn wir gar keine Kinder haben, dann sofort raus hier.\n"
    "    if ($(el).data('olel') === 'text' || $(el).children().length == 0)\n"
    "        return;\n"
    "\n"
    "    if (isMultiEl(el)) // Dann Sprung, weil manche Elemente aus mehreren Elementen bestehen\n"
    "        el = $(el).parent().get(0);\n"
    "\n"
    "    var sumXYHW = 0;\n"
    "    $(el).children().map(function ()\n"
    "    {\n"
    "        // Falls es Änderungen an den Kindern gibt, muss ich stets die Größe anpassen!\n"
    "        // dazu per 'on' auf onx,ony,onwidth und onheight horchen, vorher aber per off entfernen, falls rekursiver Aufruf\n"
    "        $(this).off('onx.adjustHeightAndWidth');\n"
    "        $(this).off('ony.adjustHeightAndWidth');\n"
    "        $(this).off('onwidth.adjustHeightAndWidth');\n"
    "        $(this).off('onheight.adjustHeightAndWidth');\n"
    "\n"
    "        $(this).on('onx.adjustHeightAndWidth', function() { adjustHeightAndWidth(el); } );\n"
    "        $(this).on('ony.adjustHeightAndWidth', function() { adjustHeightAndWidth(el); } );\n"
    "        $(this).on('onwidth.adjustHeightAndWidth', function() { adjustHeightAndWidth(el); } );\n"
    "        $(this).on('onheight.adjustHeightAndWidth', function() { adjustHeightAndWidth(el); } );\n"
    "\n"
    "\n"
    "        var n = this.nodeName.toLowerCase();\n"
    "        if (n === 'a' || n === 'b' || n === 'i' || n === 'p' || n === 'pre' || n === 'u' || n === 'br' || n === 'font' || n === 'img')\n"
    "            return;\n"
    "        sumXYHW += parseInt('0'+$(this).css('top'));\n"
    "        sumXYHW += parseInt('0'+$(this).css('left'));\n"
    "        sumXYHW += $(this).height();\n"
    "        sumXYHW += $(this).width();\n"
    "    });\n"
    "    if (sumXYHW > 0 && ($(el).get(0).style.height == '' || $(el).data('heightOnlySetByHelperFn')))\n"
    "    {\n"
    "        // Bitte erkläre mir mal warum wir hier top zur Höhe mit dazurechnen. Bricht z. B. Bsp. <checkbox>\n"
    "        // Das muss DEFINITIV mit rein! Wegen Kurzbeispiel vor Bsp. 26.12\n"
    "        var heights = $(el).children().map(function () { return $(this).outerHeight(true)+$(this).position().top; }).get();\n"
    "        if (!($(el).hasClass('div_rudElement')) && !($(el).hasClass('canvas_standard')))\n"
    "        {\n"
    "            if (($(el).hasClass('div_window')))\n"
    "            {\n"
    "                el.setAttribute_('height',getMaxOfArray(heights)+10);\n"
    "                $('#'+el.id+'_content_').get(0).setAttribute_('height',getMaxOfArray(heights)-10)\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                // Umgekehrt gilt aber auch:\n"
    "                // Wenn bei windowContent das Window keine Höhe hat, dann dieses mitsetzen\n"
    "                if ($(el).hasClass('div_windowContent') && $(el).parent().get('0').style.height == '')\n"
    "                    $(el).parent().get(0).setAttribute_('height',getMaxOfArray(heights)+20);\n"
    "                el.setAttribute_('height',getMaxOfArray(heights));\n"
    "            }\n"
    "            $(el).data('heightOnlySetByHelperFn',true); // wrappinglayout z. B. testet darauf\n"
    "        }\n"
    "    }\n"
    "    // Analog muss die Breite gesetzt werden\n"
    "    if (sumXYHW > 0 && ($(el).get(0).style.width == '' || $(el).data('widthOnlySetByHelperFn')))\n"
    "    {\n"
    "        // Bitte erkläre mir mal warum wir hier left zur Breite mit dazurechnen.\n"
    "        // Das muss DEFINITIV mit rein! Wegen Kurzbeispiel vor Bsp. 26.12\n"
    "        var widths = $(el).children().map(function () { if (isMultiEl(this)) return $(this).outerWidth(true)+$(this).next().outerWidth(true); return $(this).outerWidth(true)+$(this).position().left; }).get();\n"
    "\n"
    "        // Bei einem Window entscheidet der content mit über das breiteste Element!\n"
    "        if ($('#'+el.id+'_content_').length > 0)\n"
    //"            widths = widths.concat($('#'+el.id+'_content_').children().map(function () { return $(this).outerWidth(true)+$(this).position().left; }).get());\n"
    // Neu, aber ungetestet (Damit es auch bei unsichtbaren Windows klappt Umstieg von position auf css bei 'left'):
    "            widths = widths.concat($('#'+el.id+'_content_').children().map(function () { return $(this).outerWidth(true)+parseInt($(this).css('left')); }).get());\n"
    "\n"
    "        if (!($(el).hasClass('canvas_standard')))\n"
    "        {\n"
    "            el.setAttribute_('width',getMaxOfArray(widths))\n"
    "            $(el).data('widthOnlySetByHelperFn',true); // wrappinglayout z. B. testet darauf\n"
    "        }\n"
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
    "    if (el.defaultplacement && el.defaultplacement != '' && el[el.defaultplacement])\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content_').get(0);\n"
    "\n"
    "    if ($(el).children().length == 0) return; // Schutz, falls es gar keine Kinder gibt\n"
    "\n"
    "    var widths = $(el).children().map(function () {\n"
    "        // checkboxen und radiobuttons bestehen aus 2 nebeneinander liegenden Elementen. In so einem Fall die gemeinsame Breite ermitteln\n"
    "        if ($(this).children().length == 2 && $(this).children().eq(0).is('input'))\n"
    "            return $(this).children().eq(0).outerWidth(true) + $(this).children().eq(1).outerWidth(true)\n"
    "\n"
    "        return $(this).outerWidth(true);\n"
    "    }).get();\n"
    "    if (el.style.width == '' || $(el).data('widthOnlySetByHelperFn')) {\n"
    "        el.setAttribute_('width',getMaxOfArray(widths));\n"
    "        $(el).data('widthOnlySetByHelperFn',true);\n"
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
    "    if (el.defaultplacement && el.defaultplacement != '' && el[el.defaultplacement])\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content_').get(0);\n"
    "\n"
    "    var heights = $(el).children().map(function () { return $(this).outerHeight(true); }).get();\n"
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
    "// (Jedoch bei rudElement MUSS es 'auto' bleiben, damit es richtig scrollt)\n"
    "var adjustHeightOfEnclosingDivWithSumOfAllChildrenOnSimpleLayoutY = function (el,spacing) {\n"
    "    if (el.defaultplacement && el.defaultplacement != '' && el[el.defaultplacement])\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content_').get(0);\n"
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
    "    {\n"
    "        if (el.style.height == '' || $(el).data('heightOnlySetByHelperFn'))\n"
    "        {\n"
    "            el.setAttribute_('height',sumH);\n"
    "            $(el).data('heightOnlySetByHelperFn',true);\n"
    "        }\n"
    "    }\n"
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
    "    if (el.defaultplacement && el.defaultplacement != '' && el[el.defaultplacement])\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content_').get(0);\n"
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
    "var setSimpleLayoutYIn = function (el,spacing,inset) {\n"
    "    // spacing speichern, z. B. falls spacing animiert wird, brauche ich den aktuellen spacing-Wert\n"
    "    $(el).data('spacing_',spacing);\n"
    "\n"
    "    if (el.defaultplacement && el.defaultplacement != '' && el[el.defaultplacement])\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content_').get(0);\n"
    "\n"
    "    if ($(el).data('layout_') && $(el).data('layout_').locked)\n"
    "        return;\n"
    "\n"
    "    // Vor Änderung event wegnehmen, sonst quadratisches Wachstum der Aufrufe!\n"
    "    $(el).off('onaddsubview.SAY');\n"
    "\n"
    "    for (var i = 0; i < $(el).children().length; i++)\n"
    "    {\n"
    "        var kind = $(el).children().eq(i);\n"
    "        if (kind.get(0).id === 'debugWindow') continue; // Das debugWindow bleibt unberücksichtigt\n"
    //"        if (!$(kind).is(':visible')) continue; // Unsichtbare Elemente kann ich überspringen\n"
    // Nein, sonst sind die Werte beim auslesen des nächsten Elements in kind.prev() nicht richtig gesetzt
    "\n"
    "        // Auch dieses event wegnehmen, analoge Begründung wie oben\n"
    "        $(kind).off('onheight.SAY');\n"
    "        $(kind).off('onvisible.SAY');\n"
    "\n"
    "        if (inset != undefined)\n"
    "            kind.get(0).setAttribute_('y',inset+'px');\n"
    "\n"
    "        if (@@positionAbsoluteReplaceMe@@)\n"
    "        {\n"
    // var topValue = kind.prev().get(0).offsetTop + kind.prev().outerHeight() + spacing; <- Kommt aus der alten interpretObject()-Auswertung
    "            var topValue = parseInt(kind.prev().css('top')) + kind.prev().outerHeight() + spacing;\n"
    "            if (i == 0) topValue = 0; // Korrektur des ersten Kindes, falls vorher abweichender 'y'-Wert gesetzt wurde\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            var topValue = i * spacing;\n"
    "            if (kind.css('position') === 'relative')\n"
    "            {\n"
    "                // Wenn wir hinten nicht runter gefallen sind\n"
    "                if ($(el).children().eq(0).position().left != kind.position().left)\n"
    "                {\n"
    "                    // topValue = i * spacing + kind.prev().outerHeight()/* + parseInt(kind.prev().css('top'))*/;\n"
    "                    // Nur so klappt es bei Beispiel <basebutton>:\n"
    "                    topValue = spacing + kind.prev().outerHeight() + parseInt(kind.prev().css('top'));\n"
    "                    // var leftValue = parseInt(kind.prev().css('left'))-kind.prev().outerWidth();\n"
    "                    // leftValue = leftValue * i;\n"
    "                    // nur so klappt es bei Bsp. 27.1 (Constraints in tags):\n"
    "                    var width = 0;\n"
    "                    kind.prevAll().each(function() { width += $(this).outerWidth(); });\n"
    "                    var leftValue = width * -1;\n"
    "                    kind.get(0).setAttribute_('x',leftValue+'px');\n"
    "                }\n"
    "            }\n"
    "        }\n"
    "        // Wenn Element unsichtbar, dann ohne die Höhe des Elements und ohne spacing-Angabe\n"
    "        // Ich kann nicht direkt auf die Visibility testen, sondern nur auf die explizit von setAttribute_() gesetzte\n"
    "        if (typeof kind.data('visible_') === 'boolean' && kind.data('visible_') === false) topValue = parseInt(kind.prev().css('top'));\n"
    "\n"
    //"        if (!$(kind.prev()).is(':visible')) { topValue = !isNaN(parseInt(kind.prev().css('top'))) ? parseInt(kind.prev().css('top')) : 0; } // Well... Why does this work? (Bsp. <checkbox>)\n"
    "        kind.get(0).setAttribute_('y',topValue+'px');\n"
    "\n"
    "        // Falls es geklonte Geschwister gibt:\n"
    "        var c = 2;\n"
    "        while ($('#'+el.id+'_repl'+c).length)\n"
    "        {\n"
    "            setSimpleLayoutYIn($('#'+el.id+'_repl'+c).get(0),spacing,inset);\n"
    "            c++;\n"
    "        }\n"
    "\n"
    "        // Aber auf event lauschen, soll er bei jedem Kind (um u. U. SA zu aktualisieren)\n"
    "        $(kind).on('onheight.SAY', function() { setSimpleLayoutYIn(el,spacing,inset); } );\n"
    "        $(kind).on('onvisible.SAY', function() { setSimpleLayoutYIn(el,spacing,inset); } );\n"
    "    }\n"
    "\n"
    "    $(el).on('onaddsubview.SAY', function() { setSimpleLayoutYIn(el,spacing,inset); } );\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein SimpleLayout X zu setzen      //\n"
    "// setSimpleLayoutXIn()                                //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setSimpleLayoutXIn = function (el,spacing,inset) {\n"
    "    // spacing speichern, z. B. falls spacing animiert wird, brauche ich den aktuellen spacing-Wert\n"
    "    $(el).data('spacing_',spacing);\n"
    "\n"
    "    if (el.defaultplacement && el.defaultplacement != '' && el[el.defaultplacement])\n"
    "       el = el[el.defaultplacement];\n"
    "\n"
    "    if ($(el).hasClass('div_window'))\n"
    "        el = $('#'+el.id+'_content_').get(0);\n"
    "\n"
    "    if ($(el).data('layout_') && $(el).data('layout_').locked)\n"
    "        return;\n"
    "\n"
    "    // Vor Änderung event wegnehmen, sonst quadratisches Wachstum der Aufrufe!\n"
    "    $(el).off('onaddsubview.SAX');\n"
    "\n"
    "    for (var i = 0; i < $(el).children().length; i++)\n"
    "    {\n"
    "        var kind = $(el).children().eq(i);\n"
    "        if (kind.get(0).id === 'debugWindow') continue; // Das debugWindow bleibt unberücksichtigt\n"
    //"        if (!$(kind).is(':visible')) continue; // Unsichtbare Elemente kann ich überspringen\n"
    // Nein, sonst sind die Werte beim auslesen des nächsten Elements in kind.prev() nicht richtig gesetzt
    "\n"
    "        // Auch dieses event wegnehmen, analoge Begründung wie oben\n"
    "        $(kind).off('onwidth.SAX');\n"
    "        $(kind).off('onvisible.SAX');\n"
    "\n"
    "        if (inset != undefined)\n"
    "            kind.get(0).setAttribute_('x',inset+'px');\n"
    "\n"
    "        if (@@positionAbsoluteReplaceMe@@) {\n"
    // var leftValue = kind.prev().get(0).offsetLeft + kind.prev().outerWidth() + spacing; <- Kommt aus der alten interpretObject()-Auswertung
    "            var leftValue = parseInt(kind.prev().css('left')) + kind.prev().outerWidth() + spacing;\n"
    "            if (i == 0) leftValue = 0; // Korrektur des ersten Kindes, falls vorher abweichender 'x'-Wert gesetzt wurde\n"
    "        }\n"
    "        else {\n"
    "            var leftValue = spacing * i;\n"
    "        }\n"
    "\n"
    "        // Wenn Element unsichtbar, dann ohne die Breite des Elements und ohne spacing-Angabe\n"
    "        // Ich kann nicht direkt auf die Visibility testen, sondern nur auf die explizit von setAttribute_() gesetzte\n"
    "        if (typeof kind.data('visible_') === 'boolean' && kind.data('visible_') === false) leftValue = parseInt(kind.prev().css('left'));\n"
    "\n"
    //"            if (!$(kind.prev()).is(':visible')) { leftValue = !isNaN(parseInt(kind.prev().css('left'))) ? parseInt(kind.prev().css('left')) : 0; } // Well... Why does this work? (Bsp. <checkbox>)\n"
    "        kind.get(0).setAttribute_('x',leftValue+'px');\n"
    "\n"
    "        // Falls es geklonte Geschwister gibt:\n"
    "        var c = 2;\n"
    "        while ($('#'+el.id+'_repl'+c).length)\n"
    "        {\n"
    "            setSimpleLayoutXIn($('#'+el.id+'_repl'+c).get(0),spacing,inset);\n"
    "            c++;\n"
    "        }\n"
    "\n"
    "        // Aber auf event lauschen, soll er bei jedem Kind (um u. U. SA zu aktualisieren)\n"
    "        $(kind).on('onwidth.SAX', function() { setSimpleLayoutXIn(el,spacing,inset); } );\n"
    "        $(kind).on('onvisible.SAX', function() { setSimpleLayoutXIn(el,spacing,inset); } );\n"
    "    }\n"
    "\n"
    "    $(el).on('onaddsubview.SAX', function() { setSimpleLayoutXIn(el,spacing,inset); } );\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein StableBorderLayout Y zu setzen//\n"
    "// setStableBorderLayoutYIn()                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setStableBorderLayoutYIn = function (el) {\n"
    "    $(el).off('onheight.SBLY');\n"
    "\n"
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
    "        $(el).get(0).setAttribute_('height',parseInt($(el).children().eq(2).css('top'))+$(el).children().eq(2).height());\n"
    "    }\n"
    "\n"
    "    $(el).on('onheight.SBLY', function() { setStableBorderLayoutYIn(el); } );\n"
    "}"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um ein StableBorderLayout X zu setzen//\n"
    "// setStableBorderLayoutXIn()                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var setStableBorderLayoutXIn = function (el) {\n"
    "    $(el).off('onwidth.SBLX');\n"
    "\n"
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
    "        if (!@@positionAbsoluteReplaceMe@@)\n"
    "            $(el).children().each(function() { $(this).css('position','absolute'); });\n"
    "\n"
    // So funktioniert es besser?
    // "  $(el).children().eq(2).css('left',$(el).children().eq(0).width()+$(el).children().eq(1).width()+'px');\n"
    "        $(el).children().eq(1).get(0).setAttribute_('x',$(el).children().first().css('width'));\n"
    "        $(el).children().eq(1).get(0).setAttribute_('width',$(el).width()-$(el).children().first().width()-$(el).children().eq(2).width());\n"
    "        $(el).children().eq(2).get(0).setAttribute_('x',$(el).width()-$(el).children().eq(2).width()+'px');\n"
    "        // Noch die Height vom umgebenden anpassen, damit es so hoch ist, wie auch der Inhalt hoch ist\n"
    "        $(el).get(0).setAttribute_('height',getHeighestHeightOfChilds(el));\n"
    "    }\n"
    "\n"
    "    $(el).on('onwidth.SBLX', function() { setStableBorderLayoutXIn(el); } );\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um einen absolut gesetzten Datapath auszuwerten\n"
    "// setAbsoluteDataPathIn()                             //\n"
    "/////////////////////////////////////////////////////////\n"
    "// Ich werte die XPath-Angabe über einen temporär angelegten Datapointer aus.\n"
    "// Das Ergebnis des XPath-Requests wird als text des Elements gesetzt\n"
    "// Aber nur, wenn es eine Text-Node ist. Denn es kann auch nur ein Pfad angegeben sein, auf den sich dann tiefer verschachtelte Elemente beziehen.\n"
    "// Liefert der XPath-Request mehrere Ergebnisse zurück, muss ich hingegen das Div entsprechend oft duplizieren.\n"
    "var setAbsoluteDataPathIn = function (el,path) {\n"
    "    // XPath speichern, damit Kinder darauf zugreifen können.\n"
    "    $('#'+el.id).data('XPath',path);\n"
    "    // Letzten Datapointer global speichern, damit evtl. nachfolgende relative Datapointer darauf zugreifen können\n"
    "    lastDP_ = new lz.datapointer(path,false);\n"
    "\n"
    "\n"
    "    if (lastDP_.getXPathIndex() > 1)\n"
    "    {\n"
    "        // Markieren, weil dies Auswirkungen auf viele Dinge hat...\n"
    "        $('#'+el.id).data('IAmAReplicator',true);\n"
    "\n"
    "\n"
    "\n"
    "        // Alle hinzugefügten Methoden vorher sichern\n"
    "        var gesicherteMethoden = {};\n"
    "        for(var func in el) {\n"
    "            if (el.hasOwnProperty(func) && typeof el[func] === 'function') {\n"
    "                gesicherteMethoden[func] = el[func];\n"
    "            }\n"
    "        }\n"
    "\n"
    "\n"
    "\n"
    "        // Counter\n"
    "        var c = 0;\n"
    "        // Klon erzeugen inklusive Kinder\n"
    "        var clone = $('#'+el.id).clone(true);\n"
    "        // Das komplette Element löschen,vorher parent sichern\n"
    "        var p = $('#'+el.id).parent();\n"
    "        $('#'+el.id).remove();\n"
    "\n"
    "        for (var i=0;i<lastDP_.getXPathIndex();i++)\n"
    "        {\n"
    "            c++;\n"
    "            // Muss es jedes mal nochmal klonen, sonst wäre der Klon-Vorgang nur 1x erfolgreich\n"
    "            var clone2 = clone.clone(true);\n"
    "            // Ab dem 2. mal alle id's austauschen, damit ich später geklonte Zwillinge erkennen kann und damit es id's nicht doppelt gibt\n"
    "            if (i >= 1)\n"
    "            {\n"
    "                clone2.find('*').andSelf().each(function() {\n"
    "                    $(this).attr('id',$(this).attr('id')+'_repl'+c);\n"
    "                    // Die neu geschaffene id noch global bekannt machen\n"
    "                    window[$(this).attr('id')] = this;\n"
    "                });\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                // Ansonsten nur die Elemente neu bekannt geben (ohne var, damit global)\n"
    "                clone2.find('*').andSelf().each(function() {\n"
    "                    window[$(this).attr('id')] = this;\n"
    "\n"
    "                    // Falls es ein 'name'-Attribut gab, sollte ich wohl auch das global neu bekannt machen\n"
    "                    // (und im Eltern-Element die Referenz darauf neu setzen)\n"
    "                    if ($(this).data('name'))\n"
    "                    {\n"
    "                        window[$(this).data('name')] = this;\n"
    "                        p.get(0)[$(this).data('name')] = this;\n"
    "                    }\n"
    "                });\n"
    "            }\n"
    "            // Den Klon an das parent-Element anfügen\n"
    "            clone2.appendTo(p);\n"
    "\n"
    "            // Kann ich erst jetzt setzen, da jetzt erst erst das Element wieder im DOM hängt!\n"
    "            if (i == 0)\n"
    "            {\n"
    "                // Die Replicator-Attribute/Methoden an das Element binden\n"
    "                $('#'+el.id).get(0).clones = [];\n"
    "                $('#'+el.id).get(0).getCloneForNode = function(p,dontmake) { }\n"
    "                $('#'+el.id).get(0).getCloneNumber = function(n) { return this.clones[n]; }\n"
    "\n"
    "                // Und die zuvor gesicherten Methoden wieder herstellen\n"
    "                Object.keys(gesicherteMethoden).forEach(function(key)\n"
    "                {\n"
    "                    $('#'+el.id).get(0)[key] = gesicherteMethoden[key];\n"
    "                });\n"
    "            }\n"
    "\n"
    "\n"
    "            // Und neu: Den Klon in clones speichern (und dieses per triggerHandler bekannt machen)\n"
    //"            el.clones.push(clone2.get(0));\n" // <-- geht mit der gleichen Begründung nicht wie das eins drunter.
    "            $('#'+el.id).get(0).clones.push(clone2.get(0));\n"
    //"            $(el).triggerHandler('onclones');\n"
    // Ähmmm, geht nicht?!?! Wtf. I don't understand. Nur so: // Evtl. weil ich 'el' ja aus dem DOM hier entferne / überschreibe
    "            $('#'+el.id).triggerHandler('onclones');\n"
    "            // Und direkt 'oninit' hinterher triggern (Wegen Bsp. 30.3)\n"
    "            $('#'+el.id).triggerHandler('oninit');\n"
    "        }\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        if (lastDP_.getNodeType() == 3)\n"
    "            $('#'+el.id).html(lastDP_.getNodeText());\n"
    "    }\n"
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
    "// setSizeOfSelectBoxIn()                              //\n"
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
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um Mauscursur anzuzeigen             //\n"
    "// enableMouseCursorOnHover()                          //\n"
    "/////////////////////////////////////////////////////////\n"
    "var enableMouseCursorOnHover = function (el) {\n"
    "    $(el).hover(function(e) {\n"
    "        if (this == e.target)\n"
    "            $(this).css('cursor','pointer');\n"
    "    }, function(e) {\n"
    "        if (this == e.target)\n"
    "            $(this).css('cursor','auto');\n"
    "    });\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Hilfsfunktion, um bei 'input' und 'select' das umgebende id-lose div zu erwischen//\n"
    "// Nötig, weil diese Elemente aus mehreren Unterelementen bestehen//\n"
    "// isMultiEl()                                         //\n"
    "/////////////////////////////////////////////////////////\n"
    "var isMultiEl = function (el) {\n"
    "    if ($(el).is('input') || $(el).is('select'))\n"
    "        return true;\n"
    "\n"
    "    return false;\n"
    "}\n"
    "\n"
    "\n"
    // Diese Methode gibt es aus performance-Gründen sowohl in Objective C, als auch in JS
    // Alles was ich in Objective C (während dem Konverterlauf) machen kann, spart JS-Rechenzeit beim Laden der Seite
    // Diese JS-Methode ist im wesentlichen für Klassen, die erst zur Laufzeit constraints auswerten
    "/////////////////////////////////////////////////////////\n"
    "// Wichtige Hilfsfunktion, um alle Vars einer constraint zu ermitteln//\n"
    "// getTheDependingVarsOfTheConstraint()                //\n"
    "/////////////////////////////////////////////////////////\n"
    "var getTheDependingVarsOfTheConstraint = function (s,scope) {\n"
    "    vars = [];\n"
    "\n"
    "    // Im wesentlichen, um Anfangs- und Endmarkierung der Constraint zu entfernen\n"
    "    s = s.replace(/\\$/g, '');\n"
    "    s = s.replace(/\\{/g, '');\n"
    "    s = s.replace(/\\}/g, '');\n"
    "\n"
    "    // Remove everything between ' (including the ')\n"
    "    s = s.replace(/'[^']*'/g,'');\n"
    "\n"
    "    // Remove everything between \" (including the \")\n"
    "    s = s.replace(/\"[^\"]*\"/g,'');\n"
    "\n"
    // Noch nicht nach JS übertragen, aber die Logik dahinter wirkt eh etwas unsauber
    //"// Okay, falls es ein ? : Ausdruck ist, remove nun alles nach dem ? (inklusive dem ?)\n"
    //s = [[s componentsSeparatedByString: @"?"] objectAtIndex:0];
    "\n"
    "    // Remove leading and ending Whitespaces and NewlineCharacters\n"
    "    s = $.trim(s);\n"
    "\n"
    "    // Now get all var-names, that are left\n"
    "    // Auch per Punkt verkettete Vars erlauben ( _ ist automatisch mit drin bei \\W )\n"
    "\n"
    "    var Ergebnis = s.match(/[^\\W\\d](\\w|[.]{1,2}(?=\\w))*/g);\n"
    "    if (Ergebnis)\n"
    "    {\n"
    "        for (var i = 0; i < Ergebnis.length; ++i)\n"
    "        {\n"
    "            var varName = Ergebnis[i];\n"
    "\n"
    "            // Dann noch eventuelle spezielle Wörter austauschen\n"
    "            varName = varName.replace(/immediateparent/g,'getTheParent(true)');\n"
    "            varName = varName.replace(/parent/g,'getTheParent()');\n"
    "            varName = varName.replace(/\\.dataset/g,'.myDataset');\n"
    "            varName = varName.replace(/\\.value/g,'.myValue');\n"
    "\n"
    "            // Falls ganz vorne jetzt getTheParent() steht, dann muss ich unser aktuelles Element\n"
    "            // davorsetzen. Weil jetzt nochmal extra mit 'with () {}' zu arbeiten ist wohl nicht nötig\n"
    "            // da wir ja auf Ebene der einzelnen Variable sind und individuell reagieren können.\n"
    "            if (varName.startsWith('getTheParent'))\n"
    "                varName = scope + '.' + varName;\n"
    "\n"
    "            // Gefundene reservierte JS-Wörter muss ich an dieser Stelle fallen lassen. Dies sind keine Var-Namen\n"
    "\n"
    "            // Objektnamen\n"
    "            if (varName == 'Boolean') continue;\n"
    "            if (varName == 'Date') continue;\n"
    "            if (varName == 'Number') continue;\n"
    "            if (varName == 'String') continue;\n"
    "            if (varName == 'Array') continue;\n"
    "\n"
    "            // Funktionsnamen\n"
    "            if (varName == 'eval') continue;\n"
    "            if (varName == 'isNaN') continue;\n"
    "            if (varName == 'parseFloat') continue;\n"
    "            if (varName == 'parseInt') continue;\n"
    "\n"
    "            // reservierte Wörter\n"
    "            if (varName == 'break') continue;\n"
    "            if (varName == 'case') continue;\n"
    "            if (varName == 'catch') continue;\n"
    "            if (varName == 'continue') continue;\n"
    "            if (varName == 'default') continue;\n"
    "            if (varName == 'delete') continue;\n"
    "            if (varName == 'do') continue;\n"
    "            if (varName == 'else') continue;\n"
    "            if (varName == 'false') continue;\n"
    "            if (varName == 'finally') continue;\n"
    "            if (varName == 'for') continue;\n"
    "            if (varName == 'function') continue;\n"
    "            if (varName == 'if') continue;\n"
    "            if (varName == 'in') continue;\n"
    "            if (varName == 'instanceof') continue;\n"
    "            if (varName == 'new') continue;\n"
    "            if (varName == 'null') continue;\n"
    "            if (varName == 'return') continue;\n"
    "            if (varName == 'switch') continue;\n"
    "            if (varName == 'throw') continue;\n"
    "            if (varName == 'true') continue;\n"
    "            if (varName == 'try') continue;\n"
    "            if (varName == 'typeof') continue;\n"
    "            if (varName == 'var') continue;\n"
    "            if (varName == 'void') continue;\n"
    "            if (varName == 'while') continue;\n"
    "\n"
    "            // Falls mehrmals auf den gleichen Wert getestet wird (z. B. if (x == 2 || x == 3)\n"
    "            // brauche (und sollte) ich natürlich auf das 'x' nur einmal horchen.\n"
    "            if (jQuery.inArray(varName,vars) == -1)\n"
    "                vars.push(varName);\n"
    "        }\n"
    "    }\n"
    "\n"
    "    return vars;\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Wichtige Hilfsfunktion, um Startwert von constraints zu setzen (insb. wegen evtl. Klone nötig)//\n"
    "// setInitialConstraintValue()                         //\n"
    "/////////////////////////////////////////////////////////\n"
    "// Ich brauche func hier als string, damit ich den string wegen der Klone zerlegen kann\n"
    "var setInitialConstraintValue = function (el,prop,func) {\n"
    "    if (typeof el !== 'object') throw new TypeError('setInitialConstraintValue called on non-object')\n"
    "    if (typeof prop !== 'string') throw new TypeError('setInitialConstraintValue - second arg must be a string')\n"
    "    if (typeof func !== 'string') throw new TypeError('setInitialConstraintValue - third arg must be a string (will be evaluated as a function)')\n"
    "\n"
    "    // Falls es Klone gibt, führt er hier drin auch schon für alle Klone eine Vorbelegung durch.\n"
    "    // Lasse ich erstmal so, bewirkt quasi einen Defaultwert für Klone, der aber sogleich überschrieben wird.\n"
    "    var s = '(function() { with (' + el.id + ') { return ' + func + '; } }).bind(' + el.id + ')()';\n"
    //"    // alert(s);\n"
    //"    el.setAttribute_(prop,eval(s));\n"
    // Besser ohne eval:
    "    // Über 'Function' den String als function ausführen (zur Vermeidung von eval)\n"
    "    el.setAttribute_(prop,Function('return ' + s)());\n"
    "\n"
    "    // Falls es geklonte Geschwister gibt:\n"
    "    var c = 2;\n"
    "    while ($('#'+el.id+'_repl'+c).length)\n"
    "    {\n"
    "        var newID = el.id+'_repl'+c;\n"
    "        var s = '(function() { with (' + newID + ') { return ' + func + '; } }).bind(' + newID + ')()';\n"
    "\n"
    "        $('#'+newID).get(0).setAttribute_(prop,Function('return ' + s)());\n"
    "        c++;\n"
    "    }\n"
    "}\n"
    "\n"
    "\n"
    "/////////////////////////////////////////////////////////\n"
    "// Wichtige Hilfsfunktion, um constraints zu setzen    //\n"
    "// setConstraint()                                     //\n"
    "/////////////////////////////////////////////////////////\n"
    // Weil setInitialConstraint einen String braucht, jetzt auch hier die Funktion als String
    // (Ziel: Beide Aufrufe in einer Funktion zusammenfassen)
    "var setConstraint = function (el,expression,func,namespace) {\n"
    "    if (typeof expression !== 'string' || expression === '') throw new TypeError('setConstraint - second arg must be a non-empty string')\n"
    "    if (typeof func !== 'string') throw new TypeError('setConstraint - third arg must be a function (will be evaluated as a function)')\n"
    "\n"
    "\n"
    "    // Falls wir mit 'this.' starten muss ich this durch die aktuelle ID ersetzen.\n"
    "    // (sonst würde 'this' auf 'window' verweisen)\n"
    "    if (expression.startsWith('this.'))\n"
    "    {\n"
    "        expression = expression.substring(4);\n"
    "        expression = el.id + expression;\n"
    "    }\n"
    "    // Falls wir mit 'parent.' oder 'immediateparent.' starten, muss ich die aktuelle ID davor setzen.\n"
    "    if ((expression.startsWith('parent')) || (expression.startsWith('immediateparent')))\n"
    "    {\n"
    "        alert('Komme hier zumindestens im Taxango-Code nie rein. Oder? Kann diese Abfrage evtl. weg.');\n"
    "        expression = el.id + '.' + expression;\n"
    "    }\n"
    "\n"
    "    // Expression ist der Ausdruck, den wir zerlegen müssen in Objekt (alle vorderen Elemente) und prop (letztes Element)\n"
    "    var tempArray = expression.split('.');\n"
    "\n"
    "    var obj;\n"
    "    var prop;\n"
    "\n"
    "    // Wenn kein Objekt vorhanden (= tempArray besteht aus einem Element) ist es implizit 'window' (bzw. 'this')\n"
    "    if (tempArray.length == 1)\n"
    "    {\n"
    "        obj = 'window';\n"
    "        prop = tempArray[0];\n"
    "\n"
    "        expression = 'el.' + expression; // Damit er unten den expression-String korrekt in einen JS-Ausdruck umwandeln kann\n"
    "    }\n"
    "\n"
    "    if (tempArray.length > 1)\n"
    "    {\n"
    "        obj = tempArray[0];\n"
    "        prop = tempArray[tempArray.length-1];\n"
    "\n"
    "        // Falls es mehr als 2 Element im Array gibt, alle mittleren Elemente dem Objekt hinzufügen.\n"
    "        if (tempArray.length > 2)\n"
    "        {\n"
    "            for (var i=1;i<tempArray.length-1;i++)\n"
    "            {\n"
    "                obj = obj + '.' + tempArray[i];\n"
    "            }\n"
    "        }\n"
    "    }\n"
    "\n"
    "\n"
    "    // setAttribute_ verschickt events nur an 'onvalue' usw...\n"
    "    if (prop === 'myDataset')\n"
    "        prop = 'dataset';\n"
    "    if (prop === 'myValue')\n"
    "        prop = 'value';\n"
    "\n"
    //"var vorher = expression;\n"
    "    // expression-string als echten JS-Ausdruck auflösen\n"
    "    // Auflösen über window['obj'] klappt nicht... why?\n"
    "    expression = eval(expression);\n"
    "    obj = eval(obj);\n"
    "\n"
    "    if (!namespace)\n"
    "        namespace = '';\n"
    "\n"
    //"Check-Möglichkeit auf 'undefined'\n"
    //"if (expression === undefined)\n"
    //"    alert(vorher);\n"
    "\n"
    "    // Bei change aktualisieren bzw. auf ein event horchen, da constraint-value\n"
    "    if (typeof expression === 'object')\n"
    "    {\n"
    // "        $(expression).on('change', func);\n" // <-- Als früher noch direkt die function übergeben wurde
    //"        eval(\"$(expression).on('change', \"+func+\");\");\n"
    // Besser ohne eval:
    "        $(expression).on('change'+namespace, Function(func));\n"
    "    }\n"
    "    else if (typeof expression === 'function') // Wegen Bsp. 20.3 und 32.1, 32.2\n"
    "    {\n"
    //"        $(obj).on('change', func);\n" // <-- Als früher noch direkt die function übergeben wurde
    //"        eval(\"$(obj).on('change', \"+func+\");\");\n"
    // Besser ohne eval:
    "        $(obj).on('change'+namespace, Function(func));\n"
    "    }\n"
    "    else\n"
    "    {\n"
    //"        $(obj).on('on'+prop, func);\n" // <-- Als früher noch direkt die function übergeben wurde
    //"        eval(\"$(obj).on('on'+prop, \"+func+\");\");\n"
    // Besser ohne eval:
    "        $(obj).on('on'+prop+namespace, Function(func));\n"
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
    "// Bei diesen Attributen wird nicht setAttribute_ aufgerufen //\n"
    "///////////////////////////////////////////////////////////////\n"
    "var eventHandlerAttributes = ['oninit','onclick','ondblclick','onmouseover','onmouseout','onmouseup','onmousedown','onfocus','onblur','onkeyup','onkeydown'];\n"
    "\n"
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
    "// Aus 'obj' ziehen wir den ganzen Inhalt raus, wie das Objekt aussehen muss\n"
    "// und 'id' wird dem entsprechend mit diesen Attributen und Methoden erweitert.\n"
    "// 'iv' enthält mögliche InstanzVariablen der Instanz\n"
    // Diese wurden früher vor interpretObject() gesetzt. Später wurde hier beim setzen der 'Klassenwert' der Variablen
    // getestet, ob dieser undefined war und nur dann gesetzt (um InstanzVariablen nicht zu überschreiben).
    // Jedoch haben die getter (von z. B. 'bgcolor') das gebrochen, da diese ja nicht undefined zurückliefern.
    "function interpretObject(obj,id,iv)\n"
    "{\n"
    "  // http://www.openlaszlo.org/lps4.9/docs/developers/introductory-classes.html#introductory-classes.placement\n"
    "  // 2.5 Placement -> By default, instances which appear inside a class are made children of the top level instance of the class.\n"
    "  var kinderVorDemAppenden = $(id).children(); // die existierenden Kinder sichern\n"
    "\n"
    "  // Neu Durchlauf 1: Alle selbst definierten Attribute (und Methoden) werden direkt an das Element gebunden\n"
    "  // Dies muss als allererstes passieren, da in Unterklassen definierte Methoden oder Attrbute bereits darauf zugreifen können\n"
    "  // Muss deswegen auch rückwärts ausgewertet werden\n"
    "  var currentObj = obj; // Zwischenspeichern\n"
    "  var rueckwaertsArray = [];\n"
    "  var inherit_defaultplacement = undefined;\n"
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
    "          var value = obj.selfDefinedAttributes[key];\n"
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
    "\n"
    "          if (i == rueckwaertsArray.length-2) // zusätzlich -1, weil das Ausgangselement unberücksichtigt bleibt\n"
    "          {\n"
    "            if (key == 'defaultplacement')\n"
    "            {\n"
    "                inherit_defaultplacement = value;\n"
    "            }\n"
    "          }\n"
    "      });\n"
    "    }\n"
    "\n"
    "    if (obj.methods)\n"
    "    {\n"
    "      Object.keys(obj.methods).forEach(function(key)\n"
    "      {\n"
    "          id[key] = obj.methods[key];\n"
    "      });\n"
    "    }\n"
    "\n"
    "  }\n"
    "\n"
    "  // Neu: Hier Setzen der instanzvariablen der Instanz (nicht mehr vor der Klasse)\n"
    "  Object.keys(iv).forEach(function(key)\n"
    "  {\n"
    "    id[key] = iv[key];\n"
    "  });\n"
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
    "    if (obj.inherit.attributeNames && obj.inherit.attributeNames.length > 0)\n"
    "      currentObj.attributeNames = currentObj.attributeNames.concat(obj.inherit.attributeNames);\n"
    "\n"
    "    // attributeValues übernehmen\n"
    "    if (obj.inherit.attributeValues && obj.inherit.attributeValues.length > 0)\n"
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
    "    if (obj.inherit.name === 'text' || obj.inherit.name === 'basewindow' || obj.inherit.name === 'button' || obj.inherit.name === 'basecombobox' || obj.inherit.name === 'baselistitem'\n"
    "    || obj.inherit.name === 'drawview')\n"
    "    {\n"
    "        // Attribute sichern\n"
    "        var gesicherteAttribute = {};\n"
    "        if (obj.selfDefinedAttributes) // Schutz gegen Objekte die keine selfDefinedAttributes haben\n"
    "        {\n"
    "            Object.keys(obj.selfDefinedAttributes).forEach(function(key)\n"
    "            {\n"
    "                gesicherteAttribute[key] = id[key];\n"
    "            });\n"
    "        }\n"
    "\n"
    "        // Alle auf vorherigen Vererbungs-Ebenen hinzugefügten Methoden sichern\n"
    "        var gesicherteMethoden = {};\n"
    "        for(var prop in id) {\n"
    "            if (id.hasOwnProperty(prop) && typeof id[prop] === 'function') {\n"
    "                gesicherteMethoden[prop] = id[prop];\n"
    "            }\n"
    "        }\n"
    "\n"
    "        // Events sichern\n"
    //"        var gesicherteEvents = $(id).data('events'); // Will break on jQuery 1.8\n"
    "        var gesicherteEvents = $._data(id,'events'); // Will work on jQuery 1.8\n"
    "\n"
    "        // Kinder sichern\n"
    "        // Ist klonen hier überhaupt nötig? Falls jQuery die Kinder aus dem Speicher entfernt,\n"
    "        // sobald das Elternelement gelöscht ist, zur Sicherheit klonen.\n"
    "        var gesicherteKinder = $(id).children().clone(true);\n"
    "\n"
    "\n"
    "        // Da wir ersetzen, bekommt dieses Element den Universal-id-Namen\n"
    "        obj.inherit.contentHTML = replaceID(obj.inherit.contentHTML,''+$(id).attr('id'));\n"
    "        var theSavedCSSFromRemovedElement = $(id).replaceWith(obj.inherit.contentHTML).attr('style');\n"
    "        // Interne ID dieser Funktion neu setzen\n"
    "        id = document.getElementById(id.id);\n"
    "        // Und externen Elementnamen neu setzen\n"
    "        window[id.id] = id; // Falls es irgendwo als parent gesetzt wurde, puh... überlegen, wie ich da dran käme\n"
    "\n"
    "        // Und das gerettete CSS wieder einsetzen\n"
    //"        $(id).attr('style',$(id).attr('style') + theSavedCSSFromRemovedElement);\n"
    // Warum $(id).attr('style') ??. Das ist doch eh immer undefined und bricht dadurch das erste Attribut. Deswegen neu:
    "        $(id).attr('style',theSavedCSSFromRemovedElement);\n"
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
    "        // Und die Original-Propertys wieder herstellen mit den Nicht-Default-Werten\n"
    "        if (obj.selfDefinedAttributes) // Schutz gegen Objekte die keine selfDefinedAttributes haben\n"
    "        {\n"
    "            Object.keys(obj.selfDefinedAttributes).forEach(function(key)\n"
    "            {\n"
    //"              id[key] = obj.selfDefinedAttributes[key]; // Das sind die Default-Werte.Aber wir wollen Nicht-Default\n"
    "                id[key] = gesicherteAttribute[key];\n"
    "            });\n"
    "        }\n"
    "\n"
    "        // Und die Methoden wieder herstellen\n"
    "        Object.keys(gesicherteMethoden).forEach(function(key)\n"
    "        {\n"
    "            id[key] = gesicherteMethoden[key];\n"
    "        });\n"
    "\n"
    "        // Und die Kinder wieder herstellen\n"
    "        $(id).append(gesicherteKinder);\n"
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
    "\n"
    // Muss auch zusätzlich hier drin vor executeJSCode sein, damit super_ bekannt ist
    "      // Alle auf vorherigen Vererbungs-Ebenen hinzugefügten Methoden in das super_Objekt stecken\n"
    "      var methodenDerVorfahren = { init: function() {} };\n"
    "      for(var prop in id) {\n"
    "        if (id.hasOwnProperty(prop) && typeof id[prop] === 'function') {\n"
    "          methodenDerVorfahren[prop] = id[prop];\n"
    "        }\n"
    "      }\n"
    "      // 'super' wurde durch 'super_' ersetzt und muss im Element bekannt sein, damit überschriebene Methoden erreichbar bleiben\n"
    "      id.super_ = methodenDerVorfahren;\n"
    "\n"
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
    "  // Alle auf vorherigen Vererbungs-Ebenen hinzugefügten Methoden in das super_Objekt stecken\n"
    "  var methodenDerVorfahren = { init: function() {} };\n"
    "  for(var prop in id) {\n"
    "    if (id.hasOwnProperty(prop) && typeof id[prop] === 'function') {\n"
    "      methodenDerVorfahren[prop] = id[prop];\n"
    "    }\n"
    "  }\n"
    "  // 'super' wurde durch 'super_' ersetzt und muss im Element bekannt sein, damit überschriebene Methoden erreichbar bleiben\n"
    "  id.super_ = methodenDerVorfahren;\n"
    "\n"
    "\n"
    "\n"
    "\n"
    "  // Alle per style gegebenen Attribute muss ich ermitteln und später damit vergleichen\n"
    "  // Denn die per style direkt in der Instanz gesetzten Attribute haben Vorrang vor denen\n"
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
    "      if (attr == 'background-image') attr = 'resource';\n"
    "      if (attr == 'background-color') attr = 'bgcolor';\n"
    "      if (attr != '')\n"
    "        attrArr.push(attr);\n"
    "    }\n"
    "  }\n"
    "\n"
    "  var onInitFunc = undefined;\n"
    "\n"
    "  // Erst die Attribute auswerten\n"
    "  var an = obj.attributeNames ? obj.attributeNames : [];\n"
    "  var av = obj.attributeValues ? obj.attributeValues : [];\n"
    "\n"
    // Wenn ich es drin lassen würde, wohl 0,1 Sekunden schnelleres Laden (weil ich weniger Constraints habe, die sich ändern)
    //"  // height und width müssen immer als erstes ausgewertet werden\n"
    //"  // z. B. 'layout' verlässt sich darauf, dass 'width' vorher gesetzt wurde\n"
    //"  var posHeightInArray = $.inArray('height', an);\n"
    //"  if (posHeightInArray != -1)\n"
    //"  {\n"
    //"    an.move(posHeightInArray,0);\n"
    //"    av.move(posHeightInArray,0);\n"
    //"  }\n"
    //"  var posWidthInArray = $.inArray('width', an);\n"
    //"  if (posWidthInArray != -1)\n"
    //"  {\n"
    //"    an.move(posWidthInArray,0);\n"
    //"    av.move(posWidthInArray,0);\n"
    //"  }\n"
    //"\n"
    "  for (var i = 0;i<an.length;i++)\n"
    "  {\n"
    "    if (jQuery.inArray(an[i],eventHandlerAttributes) != -1)\n"
    "    {\n"
    "      if (an[i] === 'oninit') \n"
    "      {\n"
    "        // Kann erst später ausgeführt, werden, wenn alle Methoden bekannt sind.\n"
    "        onInitFunc = av[i];\n"
    "      }\n"
    "      else\n"
    "      {\n"
    "        // Da es JS-Code ist, Anpassungen vornehmen.\n"
    "        av[i] = av[i].replace(/setAttribute/g,'setAttribute_');\n"
    "        av[i] = av[i].replace(/\\.dataset/g,'.myDataset');\n"
    "        av[i] = av[i].replace(/\\.value/g,'.myValue');\n"
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
    "        enableMouseCursorOnHover(id);\n"
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
    "        // Neuer Code: Ich muss den KOMPLETTEN on-Befehl per eval setzen,\n"
    "        // damit die Variable direkt verwertet wird.\n"
    "        eval('$(id).on(an[i], function() { with (this) { '+av[i]+'; } });');\n"
    "      }\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        if (jQuery.inArray(an[i],attrArr) == -1)\n"
    "        {\n"
    "            if (typeof av[i] === 'string' && av[i].startsWith('$')) // = Constraint value\n"
    "            {\n"
    "                if (av[i].startsWith('$once{')) // Ist dann gar kein Constraint value\n"
    "                {\n"
    "                    av[i] = '${' + av[i].substring(6);\n"
    "                    av[i] = av[i].substring(2,av[i].length-1);\n"
    "                    id.setAttribute_(an[i],av[i]);\n"
    "                    continue;\n"
    "                }\n"
    "\n"
    "                if (av[i].startsWith('$style{')) // Ist dann gar kein Constraint value\n"
    "                {\n"
    "                    av[i] = '${' + av[i].substring(7);\n"
    "                    av[i] = av[i].substring(2,av[i].length-1);\n"
    "                    id.setAttribute_(an[i],av[i]);\n"
    "                    continue;\n"
    "                }\n"
    "\n"
    "                // Alle Variablen ermitteln, die die zu setzende Variable beeinflussen können...\n"
    "                var vars = getTheDependingVarsOfTheConstraint(av[i],id.id);\n"
    "\n"
    "                av[i] = av[i].substring(2,av[i].length-1);\n"
    "                av[i] = av[i].replace(/immediateparent/g,'getTheParent(true)');\n"
    "                av[i] = av[i].replace(/parent/g,'getTheParent()');\n"
    "                av[i] = av[i].replace(/\\.dataset/g,'.myDataset');\n"
    "                av[i] = av[i].replace(/\\.value/g,'.myValue');\n"
    "\n"
    //"                // sich selbst ausführende Funktion mit bind, um Scope korrekt zu setzen\n"
    //"                var result = (function() { with (id) { return eval(av[i]); } }).bind(id)();\n"
    //"                av[i] = result;\n"
    //"\n"
    "                setInitialConstraintValue(id,an[i],av[i]);\n"
    "\n"
    "                // Jede var, von der die constraint abhängt, beobachten\n"
    "                for (var j = 0; j < vars.length; j++)\n"
    "                {\n"
    "                    setConstraint(id,vars[j],'return (function() { with ('+id.id+') { '+id.id+'.setAttribute_(\"'+an[i]+'\",'+av[i]+'); } }).bind('+id.id+')();');\n"
    "                }\n"
    "            }\n"
    "            else\n"
    "            {\n"
    "                id.setAttribute_(an[i],av[i]);\n"
    "            }\n"
    "        }\n"
    "    }\n"
    "  }\n"
    "\n"
    "  // Replace-IDs von contentHTML ersetzen\n"
    "  var s = replaceID(obj.contentHTML,$(id).attr('id'));\n"
    "\n"
    "  // ********* Ich muss jedoch auch MICH selber an die richtige Stelle vom inherit setzen *********\n"
    "  // ********* Wenn der ein defaultplacement hat, muss ich da rein schlüpfen *********\n"
    "  if (inherit_defaultplacement && inherit_defaultplacement !== '')\n"
    "  {\n"
    "    // Da der 'name' als inherit gesetzt wurde, spreche ich es darüber an\n"
    //"    if ($(id[inherit_defaultplacement]).length == 0)\n"
    // Neu, damit er "rollUpDown" auswerten kann (da war das elem nicht auf oberster Ebene, sondern steckte in '_scrollview'):
    "    if ($(id).find(\"[data-name='\"+inherit_defaultplacement+\"']\").length == 0)\n"
    "    {\n"
    "      console.log('Error: Can not access defaultplacement. There is no view with this name in this class.');\n"
    "      $(id).append(s);\n"
    "      $(id).triggerHandler('onaddsubview');\n"
    "    }\n"
    "    else\n"
    "    {\n"
    //"      $(id[inherit_defaultplacement]).prepend(s);\n"
    //"      $(id[inherit_defaultplacement]).triggerHandler('onaddsubview');\n" // Weil ich es im anderen Zweig auch triggere
    // Neu, Folgeänderung, siehe gerade eben:
    "      $(id).find(\"[data-name='\"+inherit_defaultplacement+\"']\").prepend(s);\n"
    "      $(id).find(\"[data-name='\"+inherit_defaultplacement+\"']\").triggerHandler('onaddsubview');\n"
    "    }\n"
    "  }\n"
    "  else\n"
    "  {\n"
    // Warum hatte ich mich hier für prepend entschieden? (Sogar entgegen dem Comment...?!)
    // Gemäß Bsp. 33.2 muss es append sein
    // Gemäß Bsp. 33.12 muss es aber prepend sein! (Sagt auch die Code-Inspektion!) -> Gelöst über Fallunterscheidung
    // Total falsch alles: Der Fehler war: Ich muss die 'kinderVorDemAppenden' ganz am Anfang von interpretObject isolieren
    // sonst adden inherits ja schon wieder neue Kinder und dann kommt alles durcheinaner... :-)
    "    $(id).append(s); // dann den neuen Code anfügen\n"
    "    $(id).triggerHandler('onaddsubview');\n" // Wegen Bsp. 33.2
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
    "    // Replace-IDs von contentJS ersetzen\n"
    "    var s = replaceID(obj.contentJS,$(id).attr('id'));\n"
    "    evalCode(s);\n"
    "\n"
    // Zugriff auf 'defaultplacement' per 'id', nicht mehr per 'obj'. Das Attribut wurde ja übertragen in id bereits weiter oben.
    "  // Abfrage 2 nötig, falls das defaultplacment einen korrupten String enthält (wie in Bsp. 33.16)\n"
    "  if (id.defaultplacement !== '' && window[id.defaultplacement]) // dann die vorher existierenden Kinder korrekt positionieren\n"
    "  {\n"
    "      $(kinderVorDemAppenden).appendTo($(window[id.defaultplacement]));\n"
    "  }\n"
    "  else\n"
    "  {\n"
    "      // Vorher bereits im Div existierende Kinder dann auf jeden Fall ans Ende verschieben\n"
    "      $(kinderVorDemAppenden).appendTo(id);\n"
    "  }\n"
    "\n"
    "\n"
    "  // Kinder können ein eigenes 'placement'-Attribut haben, dann nochmal verschieben des Kindes\n"
    "  // Gemäß Code-Inspektion Example 26.22 wirklich mit 'appendTo()' verschieben und nicht mit 'replaceWith()'\n"
    "  // Jedes Kind einzeln überprüfen\n"
    "  kinderVorDemAppenden.each(function() {\n"
    "    if ($(this).data('placement'))\n"
    "    {\n"
    "      $(this).appendTo(window[$(this).data('placement')]);\n"
    "    }\n"
    "  });\n"
    "\n"
    "\n"
    "  // JS erst jetzt ausführen, sonst stimmen bestimmte width/height's nicht, weil ja etwas verschoben wurde\n"
    "  executeJSCodeOfThisObject(obj, id, $(id).attr('id'), undefined, true);\n"
    "\n"
    "\n"
    "  // Einen als Attribut gesetzten 'oninit'-Handler, kann ich erst jetzt ausführen, da jetzt erst alle Methoden bekannt sind\n"
    "  if (onInitFunc)\n"
    "  {\n"
    "    // sich selbst ausführende Funktion mit bind, um Scope korrekt zu setzen\n"
    "    (function() { with (id) { eval(onInitFunc); } }).bind(id)();\n"
    "  }\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "// executes the complete JS-Code of the given Object         //\n"
    "///////////////////////////////////////////////////////////////\n"
    "// @arg r = replacement-String\n"
    "// @arg r2 = Ersatz-replacement-String. - Erklärung bei replaceID()\n"
    "// @arg skipContentJS = weil ich die defaultPlacement-Var, die in contentJS steckt, u. U. gesondert auslese.\n"
    "function executeJSCodeOfThisObject(obj, id, r, r2, skipContentJS)\n"
    "{\n"
    "    // Replace-IDs von contentLeadingJSHead ersetzen\n"
    "    var s = replaceID(obj.contentLeadingJSHead, r, r2);\n"
    "    // Dann den LeadingJSHead-Content hinzufügen/auswerten\n"
    "    if (s.length > 0)\n"
    "        evalCode(s);\n"
    "\n"
    "    // Replace-IDs von contentJSHead ersetzen\n"
    "    var s = replaceID(obj.contentJSHead, r, r2);\n"
    "    // Dann den JSHead-Content hinzufügen/auswerten\n"
    "    if (s.length > 0)\n"
    "        evalCode(s);\n"
    "\n"
    "    if (!skipContentJS)\n"
    "    {\n"
    "        // Replace-IDs von contentJS ersetzen\n"
    "        var s = replaceID(obj.contentJS, r, r2);\n"
    "        // Dann den JS-Content hinzufügen/auswerten\n"
    "        if (s.length > 0)\n"
    "            evalCode(s);\n"
    "    }\n"
    "\n"
    "    // Replace-IDs von contentLeadingJQuery ersetzen\n"
    "    var s = replaceID(obj.contentLeadingJQuery, r, r2);\n"
    "    // Dann den LeadingJQuery-Content hinzufügen/auswerten\n"
    "    // evalCode benötigt Referenz auf id, damit es Methoden direkt adden kann\n"
    "    if (s.length > 0)\n"
    "        evalCode(s,id);\n"
    "\n"
    "    // Replace-IDs von den Computed Values ersetzen\n"
    "    var s = replaceID(obj.contentJSComputedValues, r, r2);\n"
    "    // Dann den ComputedValues-Content hinzufügen/auswerten\n"
    "    if (s.length > 0)\n"
    "        evalCode(s);\n"
    "\n"
    "    // Replace-IDs von den Constraint Values ersetzen\n"
    "    var s = replaceID(obj.contentJSConstraintValues, r, r2);\n"
    "    // Dann den ConstraintValues-Content hinzufügen/auswerten\n"
    "    if (s.length > 0)\n"
    "        evalCode(s);\n"
    "\n"
    "    // Replace-IDs von contentJQuery ersetzen\n"
    "    if (typeof obj.contentJQuery === 'function')\n"
    "    {\n"
    "        obj.contentJQuery(id);\n"
    "    }\n"
    "    else\n"
    "    {\n"
    "        var s = replaceID(obj.contentJQuery, r, r2);\n"
    "        // Dann den jQuery-Content hinzufügen/auswerten\n"
    "        if (s.length > 0)\n"
    "            evalCode(s);\n"
    "    }\n"
    "\n"
    "    // Replace-IDs von contentJSToUseLater ersetzen\n"
    "    var s = replaceID(obj.contentJSToUseLater, r, r2);\n"
    "    // Dann den jQuery-Content hinzufügen/auswerten\n"
    "    if (s.length > 0)\n"
    "        evalCode(s);\n"
    "\n"
    "    // Replace-IDs von contentJSInitstageDefer ersetzen\n"
    "    var s = replaceID(obj.contentJSInitstageDefer, r, r2);\n"
    "    // Dann den initstage-Defer-Content hinzufügen/auswerten\n"
    "    if (s.length > 0)\n"
    "        evalCode(s);\n"
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
    "    var an = neu.attributeNames ? neu.attributeNames : [];\n"
    "    var av = neu.attributeValues ? neu.attributeValues : [];\n"
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
    "  this.selfDefinedAttributes = { }\n"
    "\n"
    "  this.contentHTML = '';\n"
    //"  this.contentHTML = '<div id=\"@!JS,PLZ!REPLACE!ME!@\" class=\"div_standard noPointerEvents\" />';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = basescrollbar (native class)                     //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.basescrollbar = function() {\n"
    "  this.name = 'oo.basescrollbar';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.selfDefinedAttributes = { axis : 'y', focusview : null, mousewheelactive : false, mousewheelevent_off : 'onblur', mousewheelevent_on : 'onfocus', pagesize : null, scrollable : true, scrollattr : '', scrollmax : null, scrolltarget : null, stepsize : 10, usemousewheel : true }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = vscrollbar (native class)                        //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.vscrollbar = function() {\n"
    "  this.name = 'vscrollbar';\n"
    "  this.inherit = new oo.basescrollbar();\n"
    "\n"
    "  this.selfDefinedAttributes = { disabledbgcolor : null }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = drawview (native class)                          //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.drawview = function() {\n"
    "  this.name = 'drawview';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.selfDefinedAttributes = { width:300, height:150 }\n"
    "\n"
    "  this.contentHTML = '<div class=\"canvas_element noPointerEvents\"><canvas id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_standard noPointerEvents\"></canvas></div>';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = state (native class)                             //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.state = function() {\n"
    "  this.name = 'state';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.selfDefinedAttributes = { applied: false, pooling: false }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = dragstate (native class)                         //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.dragstate = function() {\n"
    "  this.name = 'dragstate';\n"
    "  this.inherit = new oo.state();\n"
    "\n"
    "  this.selfDefinedAttributes = { drag_axis: 'both', drag_max_x: null, drag_max_y:null, drag_min_x: null, drag_min_y:null }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = replicator (native class)                        //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.replicator = function() {\n"
    "  this.name = 'replicator';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.selfDefinedAttributes = { axis:'y', _clonepool:null, _cloneprops:null, clones:null, container: null, dataset:null, mask: null, nodes:[], pool:true, replicatedsize:null, _sizes: {x:'width', y:'height' }, spacing:0, xpath:'' }\n"
    "\n"
    "  this.contentHTML = '';\n"
    "\n"
    "  this.contentJQuery = \"\" +\n"
    "  \"  @@@P-L,A#TZHALTER@@@.container = @@@P-L,A#TZHALTER@@@.getTheParent(true);\\n\" +\n"
    "  \"  @@@P-L,A#TZHALTER@@@.mask = @@@P-L,A#TZHALTER@@@.getTheParent(true).getTheParent(true);\\n\" +\n"
    "  \"\";\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = radiogroup (native class)                        //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.radiogroup = function() {\n"
    "  this.name = 'radiogroup';\n"
    "  this.inherit = new oo.view();\n"
    "\n"
    "  this.selfDefinedAttributes = { }\n"
    "\n"
    "  this.contentHTML = '';\n"
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
    "  this.selfDefinedAttributes = { resize:true, selectable:false, text:textBetweenTags }\n"
    "\n"
    "  this.contentHTML = '<div id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_text noPointerEvents\">'+textBetweenTags+'</div>';\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = edittext (native class)                          //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.edittext = function(textBetweenTags) {\n"
    "\n"
    "  this.name = 'edittext';\n"
    "  this.inherit = new oo.baseformitem(textBetweenTags);\n"
    "\n"
    "  this.selfDefinedAttributes = { height: 26, maxlength: null, multiline: false, password: false, pattern: '', resizable:false, text: textBetweenTags, text_y: (this.multiline ? 2 : 2), width: 106 }\n"
    "\n"
    "  this.contentHTML = '<input id=\"@@@P-L,A#TZHALTER@@@\" class=\"input_standard\" value=\"'+textBetweenTags+'\" />'\n"
    "\n"
    // Hier mal neuer Approach und nicht als String, sondern als Funktion probieren:
    "  this.contentJQuery = function(el) {\n"
    "    el.field = el;\n"
    "\n"
    "    el.setHTML = function(flag) { el.flagHTML = flag; }// s\n"
    "  }\n"
    "}\n"
    "\n"
    "\n"
    "\n"
    "///////////////////////////////////////////////////////////////\n"
    "//  class = inputtext (native class)                         //\n"
    "///////////////////////////////////////////////////////////////\n"
    "oo.inputtext = function(textBetweenTags) {\n"
    "\n"
    "  this.name = 'inputtext';\n"
    "  this.inherit = new oo.text(textBetweenTags);\n"
    "\n"
    "  this.selfDefinedAttributes = { enabled: true, passowrd: false }\n"
    "\n"
    "  this.contentHTML = '<div id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_text noPointerEvents\" />';\n"
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
    // kann nicht '_content' heißen, weil fixe property bei Firefox... Halber Tag.... Deswegen um Unterstrich ergänzt
    "  this.selfDefinedAttributes = { text:textBetweenTags, defaultplacement: '_content_' }\n"
    "\n"
    "  this.contentHTML = '' +\n"
    "  '<div id=\"@@@P-L,A#TZHALTER@@@\" class=\"div_window ui-corner-all\">\\n' +\n"
    "  '  <div id=\"@@@P-L,A#TZHALTER@@@_title\" class=\"div_text div_windowTitle\"></div>\\n' +\n"
    "  '  <div id=\"@@@P-L,A#TZHALTER@@@_content_\" class=\"div_windowContent\">\\n' +\n"
    "  '  </div>\\n' +\n"
    "  '</div>\\n' +\n"
    "  '';\n"
    "\n"
    "  this.contentJS = \"\" +\n"
    "  \"  _content_ = document.getElementById('@@@P-L,A#TZHALTER@@@_content_');\\n\" +\n"
    "  \"  document.getElementById('@@@P-L,A#TZHALTER@@@_content_').getTheParent()._content_ = _content_;\\n\" +\n"
    "  \"  $(@@@P-L,A#TZHALTER@@@_content_).data('name','_content_');\\n\" +\n"
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
    //"\n"
    //"  this.name = 'window';\n"
    //"  this.inherit = new basewindow(textBetweenTags);\n"
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
    "  this.selfDefinedAttributes = { text:textBetweenTags }\n"
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
    "  this.inherit = new oo.baseformitem(textBetweenTags);\n"
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
    "  this.inherit = new oo.basevaluecomponent(textBetweenTags);\n"
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
    "\n"
    "  this.name = 'basevaluecomponent';\n"
    "  this.inherit = new oo.basecomponent(textBetweenTags);\n"
    "\n"
    "  this.selfDefinedAttributes = { type:'none', myValue:null }\n"
    "\n"
    "  this.methods = { getValue: function() { if (this.myValue) return this.myValue; else return this.text; } }\n"
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
    "  this.selfDefinedAttributes = { doesenter:false, enabled:true, hasdefault:false, isdefault:false, style: null, styleable: true, text: textBetweenTags }\n"
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
    NSString *errorString = [NSString stringWithFormat:@"Error code %ld", [parseError code]];
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
