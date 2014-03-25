//
//  MainViewController.m
//  F2 Demo
//
//  Created by Nathan Johnson on 1/28/14.
//  Copyright (c) 2014 Markit. All rights reserved.
//

#import "MainViewController.h"
#import "F2AppView.h"


#define kNameKey @"Name"
#define kSymbolKey @"Symbol"
#define kExhangeKey @"Exchange"

//these must be lower case, and no special characters
#define kEventContainerSymbolChange @"containercymbolchange"
#define kEventAppSymbolChange @"appsymbolchange"

@implementation MainViewController{
    F2AppView*                  _f2ChartView;
    F2AppView*                  _f2WatchlistView;
    F2AppView*                  _f2QuoteView;
    F2AppView*                  _f2CustomView;

    UIView*                     _customEditView;
    UITextView*                 _configurationTextView;
    
    NSString*                   _currentSymbol;
    UIView*                     _searchBarContainer;
    UISearchBar*                _searchBar;
    UISearchDisplayController*  _searchDisplayController;
    NSURLSessionDataTask*       _searchTask;
    NSMutableArray*             _symbolArray;
}

#pragma mark UIViewController Methods
- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor colorWithRed:29.0f/255 green:104.0f/255 blue:153.0f/255 alpha:1]];
    
    float margin = 8;
    _symbolArray = [NSMutableArray new];
    
    _searchBarContainer = [UIView new];
    [_searchBarContainer setFrame:CGRectMake(56, 20, 904, 45)];
    [_searchBarContainer setBackgroundColor:[UIColor whiteColor]];
    [_searchBarContainer setClipsToBounds:YES];
    [self.view addSubview:_searchBarContainer];
    
    _searchBar = [UISearchBar new];
    [_searchBar setDelegate:self];
    [_searchBar setPlaceholder:@"Search a Symbol"];
    [_searchBar setBarTintColor:[UIColor clearColor]];
    [_searchBar setSearchBarStyle:UISearchBarStyleProminent];
    [_searchBar setTintColor:self.view.backgroundColor];
    [_searchBar setFrame:_searchBarContainer.bounds];
    [_searchBarContainer addSubview:_searchBar];
    
    _searchDisplayController = [[UISearchDisplayController alloc]initWithSearchBar:_searchBar contentsController:self];
    [_searchDisplayController setDelegate:self];
    [_searchDisplayController setSearchResultsDataSource:self];
    [_searchDisplayController setSearchResultsDelegate:self];
    
    UIButton* refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [refreshButton.titleLabel setFont:[UIFont fontWithName:@"CourierNewPSMT" size:48]];
    [refreshButton setTitle:@"🔄" forState:UIControlStateNormal];
    [refreshButton setFrame:CGRectMake(CGRectGetMaxX(_searchBarContainer.frame)+8, 24, 48, 48)];
    [refreshButton addTarget:self action:@selector(resfresh) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:refreshButton];
    
    UIButton* f2Logo = [UIButton buttonWithType:UIButtonTypeCustom];
    [f2Logo addTarget:self action:@selector(f2ButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [f2Logo setImage:[UIImage imageNamed:@"Icon-40"] forState:UIControlStateNormal];
    [f2Logo setFrame:CGRectMake(margin, 22, 40, 40)];
    [self.view addSubview:f2Logo];
    
    //Create the Watchlist F2 View
    _f2WatchlistView = [[F2AppView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_f2ChartView.frame)+margin, CGRectGetMaxY(_searchBarContainer.frame)+margin, 310, 336)];
    [_f2WatchlistView setDelegate:self];
    [_f2WatchlistView setScrollable:YES];
    [_f2WatchlistView setScale:0.9f];
    [_f2WatchlistView setAppJSONConfig:@"[{\"appId\": \"com_f2_examples_javascript_watchlist\",\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\"name\": \"Watchlist\"}]"];
    [_f2WatchlistView registerEvent:@"F2.Constants.Events.APP_SYMBOL_CHANGE" key:kEventAppSymbolChange dataValueGetter:@"data.symbol"];
    [_f2WatchlistView loadApp];
    [self.view addSubview:_f2WatchlistView];
    
    //Create the Quote F2 View
    _f2QuoteView = [[F2AppView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_f2WatchlistView.frame)+margin, CGRectGetMaxY(_searchBarContainer.frame)+margin, 350, 336)];
    [_f2QuoteView setDelegate:self];
    [_f2QuoteView setScrollable:NO];
    [_f2QuoteView setScale:0.9f];
    [_f2QuoteView setAppJSONConfig:@"[{\"appId\": \"com_openf2_examples_javascript_quote\",\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\"name\": \"Quote\"}]"];
    [_f2QuoteView registerEvent:@"F2.Constants.Events.CONTAINER_SYMBOL_CHANGE" key:kEventContainerSymbolChange dataValueGetter:@"data.symbol"];
    [_f2QuoteView loadApp];
    [self.view addSubview:_f2QuoteView];
    
    //Create the Chart F2 View
    _f2ChartView = [[F2AppView alloc]initWithFrame:CGRectMake(margin, CGRectGetMaxY(_f2QuoteView.frame)+margin, CGRectGetMaxX(_f2QuoteView.frame)-margin, 343)];
    [_f2ChartView setDelegate:self];
    [_f2ChartView setScrollable:NO];
    [_f2ChartView setScale:0.8f];
    [_f2ChartView setAdditionalCss:@"h2 {font-size:23px}"];
    [_f2ChartView setAppJSONConfig:@"[{\"appId\": \"com_openf2_examples_csharp_chart\",\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\"name\": \"One Year Price Movement\"}]"];
    [_f2ChartView registerEvent:@"F2.Constants.Events.CONTAINER_SYMBOL_CHANGE" key:kEventContainerSymbolChange dataValueGetter:@"data.symbol"];
    [_f2ChartView loadApp];
    [self.view addSubview:_f2ChartView];
    
    //Create Flip Containter
    UIView* flipContainer = [[UIView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_f2QuoteView.frame)+margin, CGRectGetMaxY(_searchBarContainer.frame)+margin, 332, 687)];
    [self.view addSubview:flipContainer];
    
    
    CGRect _editViewFrame = flipContainer.bounds;
    _editViewFrame.size.height = 336;
    _customEditView = [[UIView alloc]initWithFrame:_editViewFrame];
    [_customEditView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.5]];
    

    _configurationTextView = [[UITextView alloc]initWithFrame:CGRectMake(margin, margin, CGRectGetWidth(flipContainer.frame)-(margin*2), 224)];
    [_configurationTextView setText:@"[{\n\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]"];
    [_configurationTextView setFont:[UIFont fontWithName:@"CourierNewPSMT" size:15]];
    [_customEditView addSubview:_configurationTextView];
    
    UIButton* customViewMarketNewsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customViewMarketNewsButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
    [customViewMarketNewsButton setTitle:@"Market News" forState:UIControlStateNormal];
    [customViewMarketNewsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [customViewMarketNewsButton.layer setBorderColor:[UIColor whiteColor].CGColor];
    [customViewMarketNewsButton.layer setBorderWidth:1];
    [customViewMarketNewsButton setFrame:CGRectMake(margin, CGRectGetMaxY(_configurationTextView.frame)+margin, (CGRectGetWidth(_customEditView.frame)/2)-(margin*1.5), 40)];
    [customViewMarketNewsButton addTarget:self action:@selector(marketNewsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_customEditView addSubview:customViewMarketNewsButton];
    
    UIButton* customViewStockNewsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customViewStockNewsButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
    [customViewStockNewsButton setTitle:@"Stock News" forState:UIControlStateNormal];
    [customViewStockNewsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [customViewStockNewsButton.layer setBorderColor:[UIColor whiteColor].CGColor];
    [customViewStockNewsButton.layer setBorderWidth:1];
    [customViewStockNewsButton setFrame:CGRectMake(CGRectGetMaxX(customViewMarketNewsButton.frame)+margin, CGRectGetMaxY(_configurationTextView.frame)+margin, (CGRectGetWidth(_customEditView.frame)/2)-(margin*1.5), 40)];

    [customViewStockNewsButton addTarget:self action:@selector(stockNewsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_customEditView addSubview:customViewStockNewsButton];
    
    UIButton* customViewDoneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customViewDoneButton.titleLabel setFont:[UIFont fontWithName:@"Helvetica-Bold" size:20]];
    [customViewDoneButton setTitle:@"Done" forState:UIControlStateNormal];
    [customViewDoneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [customViewDoneButton setBackgroundColor:[UIColor colorWithRed:29.0f/255 green:104.0f/255 blue:153.0f/255 alpha:1]];
    [customViewDoneButton setFrame:CGRectMake(CGRectGetWidth(_customEditView.frame)/4, CGRectGetMaxY(customViewStockNewsButton.frame)+margin, CGRectGetWidth(_customEditView.frame)/2, 40)];
    [customViewDoneButton addTarget:self action:@selector(donePressed) forControlEvents:UIControlEventTouchUpInside];
    [_customEditView addSubview:customViewDoneButton];
    
    //Create the Custom F2 View
    _f2CustomView = [[F2AppView alloc]initWithFrame:flipContainer.bounds];
    [_f2CustomView setDelegate:self];
    [_f2CustomView setScrollable:YES];
    [_f2CustomView setScale:0.9f];
    [_f2CustomView setAppJSONConfig:@"[{\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]"];
    [_f2CustomView registerEvent:@"F2.Constants.Events.CONTAINER_SYMBOL_CHANGE" key:kEventContainerSymbolChange dataValueGetter:@"data.symbol"];
    [_f2CustomView loadApp];
    [flipContainer addSubview:_f2CustomView];
    
     UIButton* customViewInfoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [customViewInfoButton setFrame:CGRectMake(CGRectGetWidth(flipContainer.frame)-32, CGRectGetHeight(flipContainer.frame)-32, 32, 32)];
    [customViewInfoButton addTarget:self action:@selector(infoPressed) forControlEvents:UIControlEventTouchUpInside];
    [_f2CustomView addSubview:customViewInfoButton];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

#pragma mark "Private" Methods
- (void)searchFor:(NSString*)searchText {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSString* searchURL = [NSString stringWithFormat:@"http://dev.markitondemand.com/Api/v2/Lookup/json?input=%@",searchText];
    NSURL* URL = [NSURL URLWithString:searchURL];
    NSURLRequest* request = [NSURLRequest requestWithURL:URL];
    NSURLSession* session = [NSURLSession sharedSession];
    _searchTask = [session dataTaskWithRequest:request
                             completionHandler:^(NSData* data, NSURLResponse* response, NSError* sessionError) {
                                 if (!sessionError) {
                                     NSError* JSONerror = nil;
                                     NSArray* responses = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONerror];
                                     if (JSONerror){
                                         NSLog(@"JSONObjectWithData error: %@", JSONerror);
                                     }else{
                                         dispatch_sync(dispatch_get_main_queue(), ^{
                                             _symbolArray = [NSMutableArray arrayWithArray:responses];
                                             [_searchDisplayController.searchResultsTableView reloadData];
                                         });
                                     }
                                 }
                                 dispatch_sync(dispatch_get_main_queue(), ^{
                                     //getting main thread just to be safe
                                     [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                 });
                                 
                             }];
    [_searchTask resume];
}

- (void)goForSymbol:(NSString*)symbol {
    if (![_currentSymbol isEqualToString:symbol]) {
        _currentSymbol = symbol;
        [_f2ChartView sendJavaScript:[NSString stringWithFormat:@"F2.Events.emit(F2.Constants.Events.CONTAINER_SYMBOL_CHANGE, { 'symbol': '%@' });",symbol]];
        [_f2QuoteView sendJavaScript:[NSString stringWithFormat:@"F2.Events.emit(F2.Constants.Events.CONTAINER_SYMBOL_CHANGE, { 'symbol': '%@' });",symbol]];
        [_f2CustomView sendJavaScript:[NSString stringWithFormat:@"F2.Events.emit(F2.Constants.Events.CONTAINER_SYMBOL_CHANGE, { 'symbol': '%@' });",symbol]];
    }
}

-(void)infoPressed{
    [_configurationTextView becomeFirstResponder];
    [UIView transitionFromView:_f2CustomView toView:_customEditView duration:1 options:UIViewAnimationOptionTransitionFlipFromRight completion:^(BOOL finished) {
       
    }];
}
-(void)donePressed{
    NSString * newConfig = _configurationTextView.text;
    if ([_configurationTextView isFirstResponder]) {
        [_configurationTextView resignFirstResponder];
    }
    NSError* error = [_f2CustomView setAppJSONConfig:newConfig];
    if (error) {
        [[[UIAlertView alloc]initWithTitle:@"Error" message:error.localizedDescription delegate:NULL cancelButtonTitle:@"OK" otherButtonTitles:NULL]show];
    }else{
        [_f2CustomView loadApp];
        [UIView transitionFromView:_customEditView toView:_f2CustomView duration:1 options:UIViewAnimationOptionTransitionFlipFromLeft completion:^(BOOL finished) {
        }];
    }
}

-(void)marketNewsButtonPressed{
    [_configurationTextView setText:@"[{\n\"appId\": \"com_openf2_examples_csharp_marketnews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Market News\"\n}]"];
}

-(void)stockNewsButtonPressed{
    [_configurationTextView setText:@"[{\n\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]"];
}

-(void)resfresh{
    NSString * customConfig = @"[{\n\"appId\": \"com_openf2_examples_csharp_stocknews\",\n\"manifestUrl\": \"http://www.openf2.org/Examples/Apps\",\n\"name\": \"Stock News\"\n}]";
    [_configurationTextView setText:customConfig];
    [_f2CustomView setAppJSONConfig:customConfig];
    _currentSymbol = @"MSFT";//this seems to be the default
    [_f2CustomView loadApp];
    [_f2ChartView loadApp];
    [_f2QuoteView loadApp];
    [_f2WatchlistView loadApp];
}

- (void)f2ButtonPressed {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"http://www.openf2.org"]];
}

#pragma mark UISearchBarDelegate Methods
- (void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)searchText{
    [_searchTask cancel];
    if (searchText.length>0) {
        [self searchFor:searchText];
    }else{
        [_symbolArray removeAllObjects];
        [_searchDisplayController.searchResultsTableView reloadData];
    }
}

#pragma mark UITableViewDataSource Methods
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section{
    return _symbolArray.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"searchResultCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"searchResultCell"];
        [cell.textLabel setTextColor:[UIColor blackColor]];
        [cell.detailTextLabel setTextColor:self.view.backgroundColor];
    }
    NSDictionary* symbol = [_symbolArray objectAtIndex:indexPath.row];
    [cell.textLabel setText:symbol[kSymbolKey]];
    [cell.detailTextLabel setText:[NSString stringWithFormat:@"%@ - %@",symbol[kNameKey],symbol[kExhangeKey]]];
    return cell;
}

#pragma mark UITableViewDelegate Methods
-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath{
    NSDictionary* symbol = [_symbolArray objectAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [_searchDisplayController setActive:NO animated:YES];
    [_searchBar setText:[NSString stringWithFormat:@"%@ %@",symbol[kSymbolKey],symbol[kNameKey]]];
    [self goForSymbol:symbol[kSymbolKey]];
}

#pragma mark F2AppViewDelegate methods
-(void)F2View:(F2AppView*)appView messageRecieved:(NSString*)message withKey:(NSString*)key{
    if ([key isEqualToString:kEventContainerSymbolChange]) {
        NSLog(@"Container Symbol Change");
    }else if ([key isEqualToString:kEventAppSymbolChange]){
        NSLog(@"App Symbol Change");
        [self goForSymbol:message];
        [_searchBar setText:message];
    }
}

-(void)F2View:(F2AppView *)appView appFinishedLoading:(NSError *)error{
    if (error) {
        [[[UIAlertView alloc]initWithTitle:@"An error occured." message:[NSString stringWithFormat:@"%@",error.localizedDescription]  delegate:NULL cancelButtonTitle:@"Close" otherButtonTitles:NULL]show];
    }
}

@end