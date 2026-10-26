#import "Freeze.hpp"
#import "SYDumpHandler.h"
#import "SYFreezeHandler.h"
#import "SYModuleHandler.h"
#import "SYPatchHandler.h"
#import "SYPointerHandler.h"
#import "SYSearchHandler.h"
#import "SYSearchHistoryView.h"
#import "SYTabHandler.h"
#import "SYTheme.h"
#import "SYThreadHandler.h"
#import "SYToast.h"
#import "SYWatchHandler.h"
#import "Session.hpp"
#import "ShirayukiViewController+Private.h"
#import "ShirayukiWindow.h"

using namespace Shirayuki;

@implementation ShirayukiViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [SYTheme bgPrimary];
    self.view.layer.cornerRadius = [SYTheme radiusLarge];
    self.view.clipsToBounds = YES;
    self.view.layer.borderColor = [SYTheme accentDim].CGColor;
    self.view.layer.borderWidth = 0.5;

    _inputDrafts = [NSMutableDictionary new];
    [self setupHandlers];
    [self buildHeader];
    [self buildTabBar];
    [self buildInputArea];
    [self buildNarrowBar];
    [self buildTableView];
    [self setupGestures];
    [self updateForCurrentTab:NO];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appDidEnterBackground {
    [self autoSaveSession];
}

- (void)autoSaveSession {
    // Collect current state into a Session and save
    Shirayuki::Session session;

    // Bundle ID of host app
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    session.targetBundle = [bundleId UTF8String];
    session.name = "autosave";

    // Freeze entries
    session.freezeEntries = Shirayuki::FreezeManager::shared().entries();

    // Patches from handler
    for (NSDictionary *p in self.patchHandler.allPatches) {
        Shirayuki::Session::PatchRecord pr;
        pr.address = [p[@"address"] unsignedLongLongValue];
        pr.patchHex = [p[@"hex"] UTF8String] ?: "";
        pr.originalHex = [p[@"original"] UTF8String] ?: "";
        pr.label = [p[@"label"] UTF8String] ?: "";
        pr.autoApply = NO;
        session.patches.push_back(pr);
    }

    // Search history
    for (NSString *s in [self.searchHandler searchHistory]) {
        session.searchHistory.push_back([s UTF8String]);
    }

    std::string path = Shirayuki::SessionManager::autoSavePath(session.targetBundle);
    Shirayuki::SessionManager::save(session, path);
}

- (void)setupHandlers {
    _searchHandler = [SYSearchHandler new];
    _searchHandler.viewController = self;
    _patchHandler = [SYPatchHandler new];
    _patchHandler.viewController = self;
    _freezeHandler = [SYFreezeHandler new];
    _freezeHandler.viewController = self;
    _watchHandler = [SYWatchHandler new];
    _watchHandler.viewController = self;
    SYPointerHandler *ptr = [SYPointerHandler new];
    ptr.viewController = self;
    SYDumpHandler *dump = [SYDumpHandler new];
    dump.viewController = self;
    SYThreadHandler *thr = [SYThreadHandler new];
    thr.viewController = self;
    SYModuleHandler *mod = [SYModuleHandler new];
    mod.viewController = self;

    _handlers =
        @[ _searchHandler, _patchHandler, _freezeHandler, _watchHandler, ptr, dump, thr, mod ];
    _currentTabIndex = [_handlers indexOfObject:_searchHandler];
}

- (id<SYTabHandler>)currentHandler {
    return _handlers[_currentTabIndex];
}

#pragma mark - Tab

- (void)tabTapped:(UIButton *)sender {
    if (sender.tag == _currentTabIndex)
        return;
    _inputDrafts[@(_currentTabIndex)] = _inputField.text ?: @"";
    [self dismissHistory];
    [_inputField resignFirstResponder];
    _currentTabIndex = sender.tag;
    _inputField.text = _inputDrafts[@(_currentTabIndex)] ?: @"";
    [self updateForCurrentTab:YES];
    [_tableView reloadData];
}

- (void)updateForCurrentTab:(BOOL)animated {
    id<SYTabHandler> h = [self currentHandler];

    // Update tab indicator
    UIButton *btn = _tabButtons[_currentTabIndex];
    CGFloat dur = animated ? 0.25 : 0;
    [UIView animateWithDuration:dur
                          delay:0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0
                        options:0
                     animations:^{
                         self.tabIndicator.frame =
                             CGRectMake(btn.frame.origin.x, 36, btn.frame.size.width, 2);
                     }
                     completion:nil];

    // Update button colors
    for (NSUInteger i = 0; i < _tabButtons.count; i++) {
        UIColor *c = (i == (NSUInteger)_currentTabIndex) ? [SYTheme accent] : [SYTheme textMuted];
        [_tabButtons[i] setImage:[SYTheme icon:[_handlers[i] tabIcon] size:11 color:c]
                        forState:UIControlStateNormal];
        [_tabButtons[i] setTitleColor:c forState:UIControlStateNormal];
        _tabButtons[i].accessibilityTraits =
            UIAccessibilityTraitButton |
            (i == (NSUInteger)_currentTabIndex ? UIAccessibilityTraitSelected : 0);
    }

    if (CGRectGetWidth(_tabBar.bounds) > 0)
        [_tabBar scrollRectToVisible:btn.frame animated:animated];

    BOOL busy = [h respondsToSelector:@selector(isBusy)] && [h isBusy];
    _inputField.enabled = !busy;
    _tableView.userInteractionEnabled = !busy;
    _actionButton.enabled = !busy;
    _actionButton.alpha = busy ? 0.55 : 1;
    if (busy)
        [_activityIndicator startAnimating];
    else
        [_activityIndicator stopAnimating];
    _actionButton.accessibilityLabel =
        h == self.searchHandler
            ? (self.searchHandler.isNarrowing ? @"Narrow results" : @"Search memory")
            : [h tabTitle];
    _inputField.accessibilityLabel = [NSString stringWithFormat:@"%@ input", [h tabTitle]];
    [self updateTypeMenu];
    _statusLabel.text = [h respondsToSelector:@selector(statusText)]
                            ? [h statusText]
                            : [NSString stringWithFormat:@"%ld entries", (long)[h numberOfRows]];
    _emptyStateLabel.text =
        [h respondsToSelector:@selector(emptyStateMessage)]
            ? [h emptyStateMessage]
            : [NSString stringWithFormat:@"No %@ entries yet\n%@", [h tabTitle], [h placeholder]];
    _tableView.backgroundView = !busy && [h numberOfRows] == 0 ? _emptyStateLabel : nil;

    // Update input
    _inputField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:[h placeholder]
            attributes:@{NSForegroundColorAttributeName : [SYTheme textMuted]}];
    [_typeButton setTitle:[h typeLabel] forState:UIControlStateNormal];
    [_actionButton
        setImage:busy ? nil : [SYTheme icon:[h actionIcon] size:16 color:[UIColor blackColor]]
        forState:UIControlStateNormal];

    // Show narrow bar only for search in narrowing mode
    BOOL showNarrow = (h == self.searchHandler && [self.searchHandler isNarrowing]);
    _narrowBar.hidden = !showNarrow;
    _narrowHeightConstraint.constant = showNarrow ? 32 : 0;
    _narrowBar.userInteractionEnabled = !busy;
    _narrowBar.alpha = busy ? 0.5 : 1;

    // Adjust row height
    if ([h respondsToSelector:@selector(rowHeight)]) {
        _tableView.rowHeight = [h rowHeight];
    } else {
        _tableView.rowHeight = 56;
    }
}

#pragma mark - Actions

- (void)closeTapped {
    [UIView animateWithDuration:0.2
        animations:^{
            [ShirayukiWindow shared].transform = CGAffineTransformMakeScale(0.9, 0.9);
            [ShirayukiWindow shared].alpha = 0;
        }
        completion:^(BOOL finished) {
            [[ShirayukiWindow shared] hide];
            [ShirayukiWindow shared].transform = CGAffineTransformIdentity;
            [ShirayukiWindow shared].alpha = 1;
        }];
}

- (void)updateTypeMenu {
    BOOL searchable = [self currentHandler] == self.searchHandler;
    _typeButton.enabled = searchable && ![self.searchHandler isBusy];
    _typeButton.accessibilityLabel = searchable ? @"Search value type" : @"Value type";
    _typeButton.accessibilityValue = [[self currentHandler] typeLabel];
    NSMutableArray<UIAction *> *actions = [NSMutableArray new];
    __weak typeof(self) weakSelf = self;
    for (NSString *type in [self.searchHandler availableTypes]) {
        UIAction *action = [UIAction actionWithTitle:type
                                               image:nil
                                          identifier:nil
                                             handler:^(UIAction *a) {
                                                 __strong typeof(weakSelf) self = weakSelf;
                                                 if (!self)
                                                     return;
                                                 [self dismissHistory];
                                                 [self.searchHandler selectType:type];
                                                 [self reloadTable];
                                             }];
        action.state = [type isEqualToString:self.searchHandler.searchType] ? UIMenuElementStateOn
                                                                            : UIMenuElementStateOff;
        [actions addObject:action];
    }
    _typeButton.menu = [UIMenu menuWithTitle:@"Search type" children:actions];
}

- (void)actionTapped {
    id<SYTabHandler> handler = [self currentHandler];
    if ([handler respondsToSelector:@selector(isBusy)] && [handler isBusy])
        return;
    [self dismissHistory];
    NSString *input = _inputField.text;
    [_inputField resignFirstResponder];

    UIImpactFeedbackGenerator *haptic =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    [[self currentHandler] performAction:input ?: @""];
}

- (void)narrowTapped:(UIButton *)sender {
    static NSArray *modes = nil;
    if (!modes)
        modes = @[ @"changed", @"unchanged", @"increased", @"decreased" ];

    if (sender.tag < (NSInteger)modes.count) {
        [self.searchHandler narrow:modes[sender.tag]];
    } else {
        [self.searchHandler resetSearch];
    }
    [self updateForCurrentTab:NO];
}

#pragma mark - Search history dropdown

- (void)showSearchHistory {
    if ([self currentHandler] != self.searchHandler || [self.searchHandler isBusy])
        return;
    if (!_historyView)
        _historyView = [SYSearchHistoryView new];
    __weak typeof(self) weakSelf = self;
    [_historyView showInView:self.view
                   belowView:_inputContainer
               alignedToView:_inputField
                     entries:[self.searchHandler searchHistory]
                   selection:^(NSString *entry) {
                       __strong typeof(weakSelf) self = weakSelf;
                       if (!self)
                           return;
                       self.inputField.text = entry;
                       [self.inputField resignFirstResponder];
                   }];
}

- (void)dismissHistory {
    [_historyView dismiss];
}

#pragma mark - Drag

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    UIWindow *window = [ShirayukiWindow shared];
    CGPoint translation = [gesture translationInView:window.superview];
    CGRect bounds = CGRectInset(window.screen.bounds, 8, 8);
    CGFloat halfWidth = CGRectGetWidth(window.bounds) / 2;
    CGFloat halfHeight = CGRectGetHeight(window.bounds) / 2;
    window.center =
        CGPointMake(MIN(MAX(window.center.x + translation.x, CGRectGetMinX(bounds) + halfWidth),
                        CGRectGetMaxX(bounds) - halfWidth),
                    MIN(MAX(window.center.y + translation.y, CGRectGetMinY(bounds) + halfHeight),
                        CGRectGetMaxY(bounds) - halfHeight));
    [gesture setTranslation:CGPointZero inView:window.superview];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan)
        return;

    CGPoint point = [gesture locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
    if (!indexPath)
        return;

    // Freeze tab: show auto-increment menu on long press
    if ([self currentHandler] == self.freezeHandler) {
        UIAlertController *sheet =
            [UIAlertController alertControllerWithTitle:@"Freeze Options"
                                                message:nil
                                         preferredStyle:UIAlertControllerStyleActionSheet];
        NSInteger row = indexPath.row;
        [sheet addAction:[UIAlertAction actionWithTitle:@"Toggle Auto-Increment"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    [self.freezeHandler
                                                        toggleAutoIncrementForRow:row];
                                                }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Copy Address"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    [self.freezeHandler didLongPressRow:row];
                                                }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [self presentActionSheet:sheet
                      sourceView:[_tableView cellForRowAtIndexPath:indexPath] ?: _tableView];
        return;
    }

    id<SYTabHandler> h = [self currentHandler];
    if ([h respondsToSelector:@selector(didLongPressRow:)]) {
        [h didLongPressRow:indexPath.row];
    }
}

#pragma mark - Public

- (void)reloadTable {
    [_tableView reloadData];
    [self updateForCurrentTab:NO];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self currentHandler] numberOfRows];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self currentHandler] cellForRow:indexPath.row inTableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<SYTabHandler> h = [self currentHandler];
    if ([h respondsToSelector:@selector(didSelectRow:)]) {
        [h didSelectRow:indexPath.row];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    id<SYTabHandler> h = [self currentHandler];
    if ([h respondsToSelector:@selector(canDeleteRow:)]) {
        return [h canDeleteRow:indexPath.row];
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)style
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete)
        return;
    id<SYTabHandler> h = [self currentHandler];
    if ([h respondsToSelector:@selector(deleteRow:)]) {
        [h deleteRow:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - UITextField

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self dismissHistory];
    [self actionTapped];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if ([self currentHandler] == self.searchHandler) {
        [self showSearchHistory];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self dismissHistory];
}

@end
