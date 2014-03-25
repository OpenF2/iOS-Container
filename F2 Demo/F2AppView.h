//
//  F2AppView.h
//  F2 Demo
//
//  Created by Nathan Johnson on 3/20/14.
//  Copyright (c) 2014 Markit. All rights reserved.
//

#import <UIKit/UIKit.h>

@class F2AppView;

@protocol F2AppViewDelegate<NSObject>

@optional
//this delegate method will get called when the javascript funcion called sendMessageToNativeMobileApp(_key, _val) is called from the webView
-(void)F2View:(F2AppView*)appView messageRecieved:(NSString*)message withKey:(NSString*)key;
-(void)F2View:(F2AppView*)appView appFinishedLoading:(NSError*)error;

@end

@interface F2AppView : UIView <UIWebViewDelegate>

//The Delegate
@property (nonatomic, weak) id<F2AppViewDelegate> delegate;

//Should links open in view or externally
@property (nonatomic) BOOL shouldOpenLinksExternally;

//If the app is scrollable
@property (nonatomic) BOOL scrollable;

//if the app is scalable (pinch zoom)
@property (nonatomic) BOOL userScalable;

//any additional CSS properties
@property (nonatomic) NSString* additionalCss;

//App Scale
@property (nonatomic) float scale;

//The app config as JSON
//http://docs.openf2.org/sdk/classes/F2.AppConfig.html
-(NSError*)setAppJSONConfig:(NSString*)config;

//call a funtion in the app
-(NSString*)sendJavaScript:(NSString *)javaScript;

//used to register events that will call the delegate
-(void)registerEvent:(NSString*)event key:(NSString*)key dataValueGetter:(NSString*)dataValueGetter;

//load/reload the app
-(void)loadApp;

@end
