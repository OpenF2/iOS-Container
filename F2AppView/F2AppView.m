//
//  F2AppWebView.m
//  F2 Demo
//
//  Created by Nathan Johnson on 3/20/14.
//  Copyright (c) 2014 Markit. All rights reserved.
//

#import "F2AppView.h"

@implementation F2AppView{
    // the webview for the F2 App
    UIWebView*  _webView;
    
    //The app configuration, this is passed from the user and parsed into the dictionary
    NSMutableDictionary*    _appConfig;
    
    /* Values Taken From The Configuration */
    NSString*   _appName;       //the app name
    NSURL*      _manifestURL;   //The url to get the app manifest from
    NSString*   _appData;       //extra data. this data gets passed back to the app on init
    
    //The manifest retrieved from the URL, the manifest contains everything we need to build the html
    NSDictionary*   _appManifest;
    
    /* Values Taken From The Manifest */
    /* Note: if there is more than one app in the manifest, we will only take the first one. */
    NSString*   _appHTML;       //the body of html
    NSString*   _appStatus;     //the status of the request for the manifest
    NSString*   _appStatusMessage; //status message
    NSString*   _appID;         //the app id
    NSArray*    _scripts;       //javascript URLs to load into the html
    NSArray*    _inlineScripts; //inline javascript to insert into the html
    NSArray*    _styles;        //stylesheet URLs to load into the html


    /*these are the strings of javascript that will get called at the 
     end of the html, registering the events that the user wants to listen to */
    NSMutableArray* _eventRegesteringStrings;
    
    //the session task currently getting data
    NSURLSessionDataTask*   _sessionTask;
}

-(id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        //set defaults
        _userScalable=NO;
        _scrollable=NO;
        _shouldOpenLinksExternally=YES;
        _scale=1.0f;
        _eventRegesteringStrings = [NSMutableArray new];
        
        //create web view
        _webView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [_webView.scrollView setScrollEnabled:NO];
        [_webView setScalesPageToFit:YES];
        [_webView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
        [_webView setDelegate:self];
        [_webView setBackgroundColor:[UIColor clearColor]];
        [self addSubview:_webView];
    }
    return self;
}

#pragma mark - Public Methods
-(NSError*)setAppJSONConfig:(NSString*)config{
    NSError* error;
    //parse te configuration file
    NSArray* parsedFromJSON = [NSJSONSerialization JSONObjectWithData:[config dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    if (!error){
        //configuration comes in as an array with a single object, the one object is a dictionary with the configuration data
        _appConfig = [NSMutableDictionary dictionaryWithDictionary:[parsedFromJSON objectAtIndex:0]];
        
        //we take the configuration, package it into a URL request and send back to the URL that is in the configuration
        NSString* encodedString = [config stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
        if (_appConfig[@"manifestUrl"]) {
            //if the configuration contains a URL
            _manifestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/json?params=%@",_appConfig[@"manifestUrl"],encodedString]];
        }
        else{
            //send an error if no URL
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:[NSString stringWithFormat:@"missing manifestUrl in config"] forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"F2AppView" code:100 userInfo:errorDetail];
        }
        
        //if "name" exists in configuration, we keep it in our ivar
        if (_appConfig[@"name"]) {
            _appName = _appConfig[@"name"];
        }else{
            _appName = NULL;
        }
    }
    return error;
}


-(void)registerEvent:(NSString*)event key:(NSString*)key dataValueGetter:(NSString*)dataValueGetter{
    [_eventRegesteringStrings addObject:[NSString stringWithFormat:@"F2.Events.on(%@, function(data){sendMessageToNativeMobileApp('%@',%@)});",event,key,dataValueGetter]];
}

-(void)setScrollable:(BOOL)scrollable{
    [_webView.scrollView setScrollEnabled:scrollable];
}

-(void)loadApp{
    if (_manifestURL) {
        //cancel the current task if it is running
        [_sessionTask cancel];
        
        //build new request
        NSURLRequest* request = [NSURLRequest requestWithURL:_manifestURL];
        NSURLSession* session = [NSURLSession sharedSession];
        _sessionTask = [session dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
            //our return block after the request was made
            if (!error){
                //parse the data we get back from the request for a manifest
                NSDictionary* parsedFromJSON = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                if (!error){
                    //we have a manifest! we can now try to build the HTML
                    _appManifest = parsedFromJSON;
                    NSArray* apps = _appManifest[@"apps"];
                    NSDictionary* app = [apps firstObject];
                    if (app[@"status"]) {
                        _appStatus = app[@"status"];
                        if ([_appStatus isEqualToString:@"SUCCESS"]) {
                            //Status is "SUCCESS", so we have all we need to build the app html
                            
                            //load in the data
                            _appHTML = app[@"html"];
                            _appID = app[@"id"];
                            _appStatusMessage = app[@"statusMessage"];
                            _appData = app[@"data"];
                            _inlineScripts = _appManifest[@"inlineScripts"];
                            _scripts = _appManifest[@"scripts"];
                            _styles = _appManifest[@"styles"];
                            
                            /*** This is where we build the full html to put into the web view ***/
                            NSString* htmlContent = [NSString stringWithFormat:@"%@%@%@",[self header],[self body],[self footer]];
                            
                            //log the generated html
                            NSLog(@"GENERATED %@ HTML:\n%@\n\n",_appName,htmlContent);
                            
                            //Put our newly made html into the webview to load
                            [_webView loadHTMLString:htmlContent baseURL:nil];
                        }
                        else{
                            //Manifest status was not SUCCESS
                            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
                            [errorDetail setValue:[NSString stringWithFormat:@"Manifest Status:%@",_appStatus] forKey:NSLocalizedDescriptionKey];
                            error = [NSError errorWithDomain:@"F2AppView" code:100 userInfo:errorDetail];
                        }
                    }
                    else{
                        // we didn't get a "status" element in the manifest.
                        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
                        [errorDetail setValue:[NSString stringWithFormat:@"Unrecognised Manifest Format"] forKey:NSLocalizedDescriptionKey];
                        error = [NSError errorWithDomain:@"F2AppView" code:100 userInfo:errorDetail];
                    }
                }
            }
            //loading was completed, let's tell our delegate and pass it whatever error we collected
            if ([self.delegate respondsToSelector:@selector(F2View:appFinishedLoading:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate F2View:self appFinishedLoading:error];
                });
            }
        }];
        //start the request
        [_sessionTask resume];
    }
}

-(NSString*)sendJavaScript:(NSString*)javaScript{
    return [_webView stringByEvaluatingJavaScriptFromString:javaScript];
}

#pragma mark - String Construction
-(NSString*)header{
    //build the html header
    NSMutableString* headContent = [NSMutableString new];
    [headContent appendString:@"<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'><title>F2 App</title>"];
    [headContent appendFormat:@"<meta name='viewport' content='initial-scale=%0.2f, user-scalable=%@'>",_scale,(_userScalable)?@"YES":@"NO"];
    [headContent appendString:@"<link href='http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.min.css' rel='stylesheet'>"];
    [headContent appendString:@"<link rel='stylesheet' href='//ajax.googleapis.com/ajax/libs/jqueryui/1.10.4/themes/smoothness/jquery-ui.css' />"];
    
    //add the styles from the manifest
    if (_styles) {
        for (NSString* styleResourceURL in _styles) {
            [headContent appendFormat:@"<link href='%@' rel='stylesheet'>",styleResourceURL];
        }
    }
    
    //add CSS from user
    if (_additionalCss) {
        [headContent appendFormat:@"<style>%@</style>",_additionalCss];
    }
    
    //close header
    [headContent appendString:@"</head>"];
    return headContent;
}

-(NSString*)body{
    NSMutableString* bodyContent = [NSMutableString new];
    //note: we open <body> here, but the footer will be the one closing it
    [bodyContent appendFormat:@"<body><div class='container'><div class='row'><div class='span12'><section id='iOS-F2-App' class='f2-app %@' style='position:static;'>",_appID];
    
    if (_appName) {
        [bodyContent appendFormat:@"<header class='clearfix'><h2 class='pull-left f2-app-title'>%@</h2></header>",_appName];
    }else{
        //we'll make the <header> anyways, the app might populate it
        [bodyContent appendString:@"<header class='clearfix'><h2 class='pull-left f2-app-title'></h2></header>"];
    }
    
    /*** here we put in the html that we get from the manifest ***/
    [bodyContent appendString:_appHTML];
    
    //close our elements
    [bodyContent appendString:@"</div></section></div></div></div>"];
    
    return bodyContent;
}

-(NSString*)footer{
    //Buld the footer for the html
    NSMutableString* footerContent =[NSMutableString string];
    
    //common scripts
    [footerContent appendString:@"<script src='http://code.jquery.com/jquery-2.1.0.min.js'></script>"];
    [footerContent appendString:@"<script src='http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/js/bootstrap.min.js'></script>"];
    [footerContent appendString:@"<script src='http://ajax.googleapis.com/ajax/libs/jqueryui/1.10.4/jquery-ui.min.js'></script>"];
    [footerContent appendString:@"<script type='text/javascript' src='http://cdnjs.cloudflare.com/ajax/libs/F2/1.3.3/f2.min.js'></script>"];
    
    //inline scriptURLs from the manifest
    if (_scripts) {
        for (NSString* jsResourceURL in _scripts) {
            [footerContent appendFormat:@"<script type='text/javascript' src='%@'></script>",jsResourceURL];
        }
    }
    
    //register app (javascript)
    [footerContent appendString:[self jSRegisterApp]];
    
    //declair the method that can "talk" back to us
    [footerContent appendString:[self jSMessageSend]];
    
    //register any F2 events we are told to listen to
    [footerContent appendString:[self jsRegisterEvents]];
    
    //close html
    [footerContent appendString:@"</body></html>"];
    return footerContent;
}

-(NSString*)jSRegisterApp{
    //add "root" to config and rebuild JSON
    [_appConfig setValue:@"#iOS-F2-App" forKey:@"root"];
    [_appConfig setValue:_appData forKey:@"data"];
    NSString* jsonConfig = [self JSONStringFromDictionary:_appConfig];
    //this javascript will register tha app and send it the configuration
    NSString* jsFunction = [NSString stringWithFormat:
                                @"  <script type='text/javascript'>             \
                                        var _appConfig = %@ ;                   \
                                        $(function(){                           \
                                        F2.init();                          \
                                        F2.registerApps(_appConfig);        \
                                        });                                     \
                                    </script>",jsonConfig];
    return jsFunction;
}

-(NSString*)jSMessageSend{
    /*  this declairs a javascript function called sendMessageToNativeMobileApp in the webview for the js in the view to communicate with us
        This works by trying to load up an iframe with the message included in its attributes. We will catch this using the webview
        delegate method webView:shouldStartLoadWithRequest:navigationType: */
    NSString* jsFunction = @"  <script type='text/javascript'>                                                              \
                                    var sendMessageToNativeMobileApp = function(_key, _val) {                               \
                                        var iframe = document.createElement('IFRAME');                                      \
                                        iframe.setAttribute(\"src\", _key + \":##sendMessageToNativeMobileApp##\" + _val);  \
                                        document.documentElement.appendChild(iframe);                                       \
                                        iframe.parentNode.removeChild(iframe);                                              \
                                        iframe = null;                                                                      \
                                    };                                                                                      \
                                </script>                                                                                   ";
    return jsFunction;
}

-(NSString*)jsRegisterEvents{
    //this will generate javascript elements that will register all F2 events declaired in _eventRegesteringStrings
    NSMutableString* eventRegisteringJS = [NSMutableString stringWithString:@"<script>"];
    for (NSString* eventRegister in _eventRegesteringStrings) {
        [eventRegisteringJS appendString:eventRegister];
    }
    [eventRegisteringJS appendString:@"</script>"];
    return eventRegisteringJS;
}

#pragma mark - UIWebViewDelegate methods
- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType{
    //we use this delegate method to catch any instances of the sendMessageToNativeMobileApp javascript method and pass the data to our delegate
    NSString* requestString = [[[request URL] absoluteString] stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    NSArray* requestArray = [requestString componentsSeparatedByString:@":##sendMessageToNativeMobileApp##"];
    //if the array is bigger than 0, then we know that it wasn't an actual request, but from the javascript function we made called sendMessageToNativeMobileApp
    if ([requestArray count] > 1){
        NSString* requestPrefix = [[requestArray objectAtIndex:0] lowercaseString];
        NSString* requestMssg = ([requestArray count] > 0) ? [requestArray objectAtIndex:1] : @"";
        if (_delegate) {
            if ([_delegate respondsToSelector:@selector(F2View:messageRecieved:withKey:)]) {
                [_delegate F2View:self messageRecieved:requestMssg withKey:requestPrefix];
            }
        }
        return NO;
    }
    else if (navigationType == UIWebViewNavigationTypeLinkClicked && _shouldOpenLinksExternally) {
        //if we aren't supposed to open the link up in the web view, we'll open it in safari
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }
    return YES;
}

#pragma mark - helper methods
- (NSString*)stringByDecodingURLFormat:(NSString*)string{
    //URL decoded to normal string
    NSString* result = [string stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return result;
}

- (NSString*)JSONStringFromDictionary:(NSDictionary*)dictionary{
    //dictionary converted into NSString
    NSString* jSONResult;
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    NSAssert(!error, @"error generating JSON: %@", error);
    jSONResult = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jSONResult;
}
@end
