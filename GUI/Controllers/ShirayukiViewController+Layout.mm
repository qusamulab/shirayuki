#import "SYResultCell.h"
#import "SYTheme.h"
#import "ShirayukiViewController+Private.h"

static NSString *const kCellID = @"SYCell";

@implementation ShirayukiViewController (Layout)

#pragma mark - Build UI

- (void)buildHeader {
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [SYTheme bgSecondary];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.headerView];

    UIImageView *logo = [[UIImageView alloc] initWithImage:[SYTheme icon:@"snowflake"
                                                                    size:17
                                                                   color:[SYTheme accent]]];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:logo];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Shirayuki";
    title.font = [SYTheme titleFont];
    title.textColor = [SYTheme textPrimary];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerView addSubview:title];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setImage:[SYTheme icon:@"xmark" size:11 color:[SYTheme danger]]
              forState:UIControlStateNormal];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    closeBtn.accessibilityLabel = @"Close panel";
    [closeBtn addTarget:self
                  action:@selector(closeTapped)
        forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.headerView.heightAnchor constraintEqualToConstant:44],
        [logo.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:12],
        [logo.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [title.leadingAnchor constraintEqualToAnchor:logo.trailingAnchor constant:6],
        [title.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor
                                                constant:-8],
        [closeBtn.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:44],
        [closeBtn.heightAnchor constraintEqualToConstant:44],
    ]];
}

- (void)buildTabBar {
    self.tabBar = [[UIScrollView alloc] init];
    self.tabBar.showsHorizontalScrollIndicator = NO;
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tabBar];

    NSMutableArray *buttons = [NSMutableArray new];
    CGFloat x = 6;

    for (NSUInteger i = 0; i < self.handlers.count; i++) {
        id<SYTabHandler> h = self.handlers[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *icon = [SYTheme icon:[h tabIcon] size:12 color:[SYTheme textMuted]];
        [btn setImage:icon forState:UIControlStateNormal];
        [btn setTitle:[NSString stringWithFormat:@" %@", [h tabTitle]]
             forState:UIControlStateNormal];
        [btn setTitleColor:[SYTheme textMuted] forState:UIControlStateNormal];
        btn.titleLabel.font = [SYTheme captionFont];
        btn.tag = i;
        [btn sizeToFit];
        btn.frame = CGRectMake(x, 0, MAX(54, btn.frame.size.width + 18), 36);
        btn.accessibilityLabel = [h tabTitle];
        [btn addTarget:self
                      action:@selector(tabTapped:)
            forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addSubview:btn];
        [buttons addObject:btn];
        x += btn.frame.size.width + 3;
    }
    self.tabBar.contentSize = CGSizeMake(x, 38);
    self.tabButtons = buttons;

    self.tabIndicator = [[UIView alloc] initWithFrame:CGRectMake(6, 36, 40, 2)];
    self.tabIndicator.backgroundColor = [SYTheme accent];
    self.tabIndicator.layer.cornerRadius = 1;
    [self.tabBar addSubview:self.tabIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.tabBar.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
        [self.tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tabBar.heightAnchor constraintEqualToConstant:38],
    ]];
}

- (void)buildInputArea {
    self.inputContainer = [[UIView alloc] init];
    self.inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.inputContainer];

    self.typeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.typeButton setTitle:@"i32" forState:UIControlStateNormal];
    [self.typeButton setTitleColor:[SYTheme accent] forState:UIControlStateNormal];
    self.typeButton.titleLabel.font = [SYTheme captionFont];
    self.typeButton.backgroundColor = [SYTheme bgTertiary];
    self.typeButton.layer.cornerRadius = [SYTheme radiusSmall];
    self.typeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeButton.showsMenuAsPrimaryAction = YES;
    [self.inputContainer addSubview:self.typeButton];

    self.inputField = [[UITextField alloc] init];
    self.inputField.backgroundColor = [SYTheme bgTertiary];
    self.inputField.textColor = [SYTheme textPrimary];
    self.inputField.font = [SYTheme monoMedium];
    self.inputField.layer.cornerRadius = [SYTheme radiusSmall];
    self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 0)];
    self.inputField.leftViewMode = UITextFieldViewModeAlways;
    self.inputField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.inputField.returnKeyType = UIReturnKeyGo;
    self.inputField.delegate = self;
    self.inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField.keyboardType = UIKeyboardTypeASCIICapable;
    self.inputField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputContainer addSubview:self.inputField];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.backgroundColor = [SYTheme accent];
    self.actionButton.layer.cornerRadius = [SYTheme radiusSmall];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionButton addTarget:self
                          action:@selector(actionTapped)
                forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *actionLongPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(actionLongPressed:)];
    actionLongPress.minimumPressDuration = 0.5;
    [self.actionButton addGestureRecognizer:actionLongPress];
    [self.inputContainer addSubview:self.actionButton];
    self.activityIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.color = [SYTheme textPrimary];
    self.activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.userInteractionEnabled = NO;
    [self.inputContainer addSubview:self.activityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.inputContainer.topAnchor constraintEqualToAnchor:self.tabBar.bottomAnchor constant:5],
        [self.inputContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor
                                                          constant:8],
        [self.inputContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                           constant:-8],
        [self.inputContainer.heightAnchor constraintEqualToConstant:44],
        [self.typeButton.leadingAnchor constraintEqualToAnchor:self.inputContainer.leadingAnchor],
        [self.typeButton.centerYAnchor constraintEqualToAnchor:self.inputContainer.centerYAnchor],
        [self.typeButton.widthAnchor constraintEqualToConstant:54],
        [self.typeButton.heightAnchor constraintEqualToConstant:44],
        [self.inputField.leadingAnchor constraintEqualToAnchor:self.typeButton.trailingAnchor
                                                      constant:5],
        [self.inputField.centerYAnchor constraintEqualToAnchor:self.inputContainer.centerYAnchor],
        [self.inputField.trailingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor
                                                       constant:-5],
        [self.inputField.heightAnchor constraintEqualToConstant:44],
        [self.actionButton.trailingAnchor
            constraintEqualToAnchor:self.inputContainer.trailingAnchor],
        [self.actionButton.centerYAnchor constraintEqualToAnchor:self.inputContainer.centerYAnchor],
        [self.actionButton.widthAnchor constraintEqualToConstant:44],
        [self.actionButton.heightAnchor constraintEqualToConstant:44],
        [self.activityIndicator.centerXAnchor
            constraintEqualToAnchor:self.actionButton.centerXAnchor],
        [self.activityIndicator.centerYAnchor
            constraintEqualToAnchor:self.actionButton.centerYAnchor],
    ]];
}

- (void)buildNarrowBar {
    self.narrowBar = [[UIScrollView alloc] init];
    self.narrowBar.showsHorizontalScrollIndicator = NO;
    self.narrowBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.narrowBar.hidden = YES;
    [self.view addSubview:self.narrowBar];

    NSArray *modes = @[ @"Changed", @"Unchanged", @"Increased", @"Decreased", @"Reset" ];
    CGFloat x = 0;

    for (NSUInteger i = 0; i < modes.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:modes[i] forState:UIControlStateNormal];
        [btn setTitleColor:[SYTheme textSecondary] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        btn.backgroundColor = [SYTheme bgTertiary];
        btn.layer.cornerRadius = 4;
        btn.tag = i;
        [btn sizeToFit];
        btn.frame = CGRectMake(x, 0, btn.frame.size.width + 18, 32);
        [btn addTarget:self
                      action:@selector(narrowTapped:)
            forControlEvents:UIControlEventTouchUpInside];
        [self.narrowBar addSubview:btn];
        x += btn.frame.size.width + 4;
    }

    self.narrowBar.contentSize = CGSizeMake(x, 32);
    self.narrowHeightConstraint = [self.narrowBar.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.narrowBar.topAnchor constraintEqualToAnchor:self.inputContainer.bottomAnchor
                                                 constant:4],
        [self.narrowBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.narrowBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                      constant:-8],
        self.narrowHeightConstraint,
    ]];
}

- (void)buildTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 56;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.tableFooterView = [UIView new];
    self.emptyStateLabel = [UILabel new];
    self.emptyStateLabel.font = [SYTheme monoMedium];
    self.emptyStateLabel.textColor = [SYTheme textSecondary];
    self.emptyStateLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyStateLabel.numberOfLines = 0;

    self.statusLabel = [UILabel new];
    self.statusLabel.font = [SYTheme captionFont];
    self.statusLabel.textColor = [SYTheme textSecondary];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.accessibilityTraits =
        UIAccessibilityTraitStaticText | UIAccessibilityTraitUpdatesFrequently;
    [self.view addSubview:self.statusLabel];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[SYResultCell class] forCellReuseIdentifier:kCellID];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.narrowBar.bottomAnchor constant:4],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor
                                                       constant:12],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor
                                                        constant:-12],
        [self.statusLabel.heightAnchor constraintEqualToConstant:22],
        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:4],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupGestures {
    UIPanGestureRecognizer *drag =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.headerView addGestureRecognizer:drag];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.tableView addGestureRecognizer:longPress];
}

@end
