//
//  F2AppView.h
//  F2 Demo
//
//  Created by Nathan Johnson on 3/20/14.
//  Copyright (c) 2014 Markit. All rights reserved.
//

#import <UIKit/UIKit.h>

@class F2AppView;

/*
 * F2AppViewDelegate specifies the methods that a F2App may respond to.
 */
@protocol F2AppViewDelegate<NSObject>

@optional

/** this delegate method will get called when the javascript funcion called sendMessageToNativeMobileApp(_key, _val) is called from the webView.
 @param appView F2AppView
 @param message the message recieved
 @param key the key used when registering the event
 @see registerEvent:key:dataValueGetter:
 */
-(void)F2View:(F2AppView*)appView messageRecieved:(NSString*)message withKey:(NSString*)key;

/** Use this delegate method to get notified when the app is finished generating the app. (The javascript in the app its self might still be loading or running)
 @param appView F2AppView
 @param error an error if occured or NULL if success
 */
-(void)F2View:(F2AppView*)appView appFinishedLoading:(NSError*)error;

@end

@interface F2AppView : UIView <UIWebViewDelegate>

/** The UIWebViewDelegate for the F2View */
@property (nonatomic, weak) id<F2AppViewDelegate> delegate;

/** Should links open in view or externally
    If YES, links in the webview will open in safari, if yes, the links will open in the F2View

    @warning This will only come into effect if done before loadApp
    @see loadApp
 */
@property (nonatomic) BOOL shouldOpenLinksExternally;

/** Should the app view be scrollable
    If YES, the app will be scrollable (Default:NO)
 
    @warning This will only come into effect if done before loadApp
    @see loadApp
 */
@property (nonatomic) BOOL scrollable;

/** Should the app view be scalable (pinch zoom)
    If YES, the app will be scalable (Default:NO)
 
    @warning This will only come into effect if done before loadApp
    @see loadApp
 */
@property (nonatomic) BOOL userScalable;

/** any additional CSS properties
    aditional CSS to include in the F2 APP (this css gets loaded at the end of all other app Styles)
 
    @warning This will only come into effect if done before loadApp
    @see loadApp
 */
@property (nonatomic) NSString* additionalCss;

/** The scale of the F2 app
    change this if you would like the app to be smaller or bigger (default:1.0)
 
    @warning This will only come into effect if done before loadApp
    @see loadApp
 */
@property (nonatomic) float scale;

/** Use this method to set the configuration of the F2 app.
    for more info on supported configuration properies, see //http://docs.openf2.org/sdk/classes/F2.AppConfig.html
 
    @warning This will only come into effect if done before loadApp
    @see loadApp
 
    @param config The configuration as a JSON string
 */
-(NSError*)setAppJSONConfig:(NSString*)config;

/** Use this method to send any Javascript functions to the app.
    @param javaScript The javascript to run
    @return the sting returned after evaluating the javascript
 */
-(NSString*)sendJavaScript:(NSString *)javaScript;

/** Use this method to register any events you would like to be notified for
    set this before loading the app, after registering the app the event will call the deligate method F2View:messageRecieved:withKey: whenever the event is emitted
 
    @warning This will only come into effect if done before loadApp

    @param event the event to listen for (eg. @"F2.Constants.Events.APP_SYMBOL_CHANGE")
    @param key the key to use to identify the event, this must be all lower case and have no special characters.
    @param dataValueGetter the value you wish to recieve as part of the request (eg. @"data.symbol")
 
    @see F2View:messageRecieved:withKey:
    @see loadApp
 */
-(void)registerEvent:(NSString*)event key:(NSString*)key dataValueGetter:(NSString*)dataValueGetter;

/** Call this method when your configuration is complete and you wish to load/reload the f2 app in the view */
-(void)loadApp;

@end
