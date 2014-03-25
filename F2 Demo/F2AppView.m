//
//  F2AppWebView.m
//  F2 Demo
//
//  Created by Nathan Johnson on 3/20/14.
//  Copyright (c) 2014 Markit. All rights reserved.
//

#import "F2AppView.h"

@implementation F2AppView{
    UIWebView*              _webView;
    NSURL*                  _manifestURL;
    NSMutableDictionary*    _appConfig;
    NSDictionary*           _appManifest;
    NSURLSessionDataTask*   _sessionTask;
    NSString*               _appHTML;
    NSString*               _appStatus;
    NSString*               _appID;
    NSString*               _appName;
    NSString*               _appStatusMessage;
    NSArray*                _scripts;
    NSArray*                _styles;
    NSArray*                _inlineScripts;
    NSString*               _appData;
    NSMutableArray*         _eventRegesteringStrings;
}

-(id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _userScalable=NO;
        _scrollable=NO;
        _shouldOpenLinksExternally=YES;
        _scale=1.0f;
        _eventRegesteringStrings = [NSMutableArray new];
        
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

-(void)setScrollable:(BOOL)scrollable{
    [_webView.scrollView setScrollEnabled:scrollable];
}

#pragma mark - Public Methods
-(void)loadApp{
    if (_manifestURL) {
        [_sessionTask cancel];
        NSURLRequest* request = [NSURLRequest requestWithURL:_manifestURL];
        NSURLSession* session = [NSURLSession sharedSession];
        _sessionTask = [session dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
            if (!error){
                NSDictionary* parsedFromJSON = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                if (!error){
                    _appManifest = parsedFromJSON;
                    NSLog(@"Manifest:%@",_appManifest);
                    NSArray* apps = _appManifest[@"apps"];
                    NSDictionary* app = [apps firstObject];
                    if (app[@"status"]) {
                        _appStatus = app[@"status"];
                        if ([_appStatus isEqualToString:@"SUCCESS"]) {
                            
                            //load up data
                            _appHTML = app[@"html"];
                            _appID = app[@"id"];
                            _appName =
                            _appStatusMessage = app[@"statusMessage"];
                            
                            //turn the "data" dictionary back into JSON string - though I don't use the data at the moment anyways
                            _appData = [self JSONStringFromDictionary:app[@"data"]];
                            
                            _inlineScripts = _appManifest[@"inlineScripts"];
                            _scripts = _appManifest[@"scripts"];
                            _styles = _appManifest[@"styles"];
                            
                            NSString* htmlContent = [NSString stringWithFormat:@"%@%@%@",[self header],[self body],[self footer]];
                            NSLog(@"%@",htmlContent);
                            [_webView loadHTMLString:htmlContent baseURL:nil];
                        }
                        else{
                            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
                            [errorDetail setValue:[NSString stringWithFormat:@"Manifest Status:%@",_appStatus] forKey:NSLocalizedDescriptionKey];
                            error = [NSError errorWithDomain:@"F2AppView" code:100 userInfo:errorDetail];
                        }
                    }
                    else{
                        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
                        [errorDetail setValue:[NSString stringWithFormat:@"Unrecognised Manifest Format"] forKey:NSLocalizedDescriptionKey];
                        error = [NSError errorWithDomain:@"F2AppView" code:100 userInfo:errorDetail];
                    }
                }
            }
            if ([self.delegate respondsToSelector:@selector(F2View:appFinishedLoading:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate F2View:self appFinishedLoading:error];
                });
            }
        }];
        [_sessionTask resume];
    }
}

#pragma mark - Accessors
-(NSError*)setAppJSONConfig:(NSString*)config{
    NSError* error;
    NSArray* parsedFromJSON = [NSJSONSerialization JSONObjectWithData:[config dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    if (!error){
        _appConfig = [NSMutableDictionary dictionaryWithDictionary:[parsedFromJSON objectAtIndex:0]];
        NSString* encodedString = [config stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
        if (_appConfig[@"manifestUrl"]) {
            _manifestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/json?params=%@",_appConfig[@"manifestUrl"],encodedString]];
        }
        else{
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:[NSString stringWithFormat:@"missing manifestURL in config"] forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"F2AppView" code:100 userInfo:errorDetail];
        }
        
        if (_appConfig[@"name"]) {
            _appName = _appConfig[@"name"];
        }else{
            _appName = NULL;
        }
    }
    return error;
}

#pragma mark - String Construction
-(NSString*)header{
    NSMutableString* header = [NSMutableString string];
    [header appendFormat:@"<!DOCTYPE html><html lang='en'><head>%@</head><body>",[self headContent]];
    return header;
    
}

-(NSString*)headContent{
    NSMutableString* headContent = [NSMutableString new];
    [headContent appendString:@"<meta charset='utf-8'><title>F2 App</title>"];
    [headContent appendFormat:@"<meta name='viewport' content='initial-scale=%0.2f, user-scalable=%@'>",_scale,(_userScalable)?@"YES":@"NO"];
    
    [headContent appendString:@"<link href='http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.min.css' rel='stylesheet'>"];
    [headContent appendString:@"<link rel='stylesheet' href='//ajax.googleapis.com/ajax/libs/jqueryui/1.10.4/themes/smoothness/jquery-ui.css' />"];
    
    if (_styles) {
        for (NSString* styleResourceURL in _styles) {
            [headContent appendFormat:@"<link href='%@' rel='stylesheet'>",styleResourceURL];
        }
    }
    
    if (_additionalCss) {
        [headContent appendFormat:@"<style>%@</style>",_additionalCss];
    }
    
    return headContent;
}

-(NSString*)jSMessageSend{
    //this declairs a javascript function called sendToApp in the webview for the js in the view to communicate with us
    //it starts a new load request in an iframe which the webview responds to and calls a delegate method
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

-(NSString*)jSRegisterApp{
    //add "root" to config and rebuild JSON
    [_appConfig setValue:@"#iOS-F2-App" forKey:@"root"];
    NSString* jsonConfig = [self JSONStringFromDictionary:_appConfig];
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

-(NSString*)jsRegisterEvents{
    NSMutableString* eventRegisteringJS = [NSMutableString stringWithString:@"<script>"];
    for (NSString* eventRegister in _eventRegesteringStrings) {
        [eventRegisteringJS appendString:eventRegister];
    }
    [eventRegisteringJS appendString:@"</script>"];
    return eventRegisteringJS;
}

-(void)registerEvent:(NSString*)event key:(NSString*)key dataValueGetter:(NSString*)dataValueGetter{
    [_eventRegesteringStrings addObject:[NSString stringWithFormat:@"F2.Events.on(%@, function(data){sendMessageToNativeMobileApp('%@',%@)});",event,key,dataValueGetter]];
}

-(NSString*)body{
    NSMutableString* bodyContent = [NSMutableString new];
    
    [bodyContent appendFormat:@"<div class='container'><div class='row'><div class='span12'><section id='iOS-F2-App' class='f2-app %@' style='position:static;'>",_appID];
    
    if (_appName) {
        [bodyContent appendFormat:@"<header class='clearfix'><h2 class='pull-left f2-app-title'>%@</h2></header>",_appName];
    }
    
    [bodyContent appendString:_appHTML];
    
    [bodyContent appendString:@"</div></section></div></div></div>"];
    
    return bodyContent;
}

-(NSString*)footer{
    NSMutableString* footerContent =[NSMutableString string];
    [footerContent appendString:@"<script src='http://code.jquery.com/jquery-2.1.0.min.js'></script>"];
    [footerContent appendString:@"<script src='http://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/js/bootstrap.min.js'></script>"];
    [footerContent appendString:@"<script src='http://ajax.googleapis.com/ajax/libs/jqueryui/1.10.4/jquery-ui.min.js'></script>"];
    [footerContent appendString:@"<script type='text/javascript' src='http://cdnjs.cloudflare.com/ajax/libs/F2/1.3.2/f2.min.js'></script>"];
    
    if (_scripts) {
        for (NSString* jsResourceURL in _scripts) {
            [footerContent appendFormat:@"<script type='text/javascript' src='%@'></script>",jsResourceURL];
        }
    }
    
    [footerContent appendString:[self jSRegisterApp]];
    [footerContent appendString:[self jSMessageSend]];
    [footerContent appendString:[self jsRegisterEvents]];
    
    [footerContent appendString:@"</body></html>"];
    return footerContent;
}

-(NSString*)sendJavaScript:(NSString*)javaScript{
    return [_webView stringByEvaluatingJavaScriptFromString:javaScript];
}

#pragma mark - UIWebViewDelegate methods
- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString* requestString = [[[request URL] absoluteString] stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    NSArray* requestArray = [requestString componentsSeparatedByString:@":##sendMessageToNativeMobileApp##"];
    
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
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }
    return YES;
}

#pragma mark - helper methods
- (NSString*)stringByDecodingURLFormat:(NSString*)string
{
    NSString* result = [string stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return result;
}

- (NSString*)JSONStringFromDictionary:(NSDictionary*)dictionary {
    NSString* jSONResult;
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    if (error) {
        NSLog(@"error generating JSON: %@", error);
    } else {
        jSONResult = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jSONResult;
}
@end
