#pragma once

#import "SYTabHandler.h"
#import "ShirayukiViewController.h"

@class SYSearchHandler, SYPatchHandler, SYFreezeHandler, SYWatchHandler, SYSearchHistoryView;

@interface ShirayukiViewController () <UITableViewDelegate, UITableViewDataSource,
                                       UITextFieldDelegate>
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIScrollView *tabBar;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIView *tabIndicator;
@property (nonatomic, strong) UIView *inputContainer;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIButton *typeButton;
@property (nonatomic, strong) UIScrollView *narrowBar; // for search narrowing buttons
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SYSearchHistoryView *historyView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyStateLabel;
@property (nonatomic, strong) NSLayoutConstraint *narrowHeightConstraint;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *inputDrafts;

@property (nonatomic, strong) NSArray<id<SYTabHandler>> *handlers;
@property (nonatomic, assign) NSInteger currentTabIndex;

@property (nonatomic, strong) SYSearchHandler *searchHandler;
@property (nonatomic, strong) SYPatchHandler *patchHandler;
@property (nonatomic, strong) SYFreezeHandler *freezeHandler;
@property (nonatomic, strong) SYWatchHandler *watchHandler;
- (id<SYTabHandler>)currentHandler;
- (void)closeTapped;
- (void)tabTapped:(UIButton *)sender;
- (void)updateTypeMenu;
- (void)dismissHistory;
- (void)actionTapped;
- (void)narrowTapped:(UIButton *)sender;
- (void)handleDrag:(UIPanGestureRecognizer *)gesture;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@interface ShirayukiViewController (Layout)
- (void)buildHeader;
- (void)buildTabBar;
- (void)buildInputArea;
- (void)buildNarrowBar;
- (void)buildTableView;
- (void)setupGestures;
@end

@interface ShirayukiViewController (Actions)
- (void)actionLongPressed:(UILongPressGestureRecognizer *)gesture;
- (void)showBatchModifyAlert;
- (void)presentActionSheet:(UIAlertController *)sheet sourceView:(UIView *)source;
@end
