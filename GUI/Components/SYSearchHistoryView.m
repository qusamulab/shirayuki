#import "SYSearchHistoryView.h"
#import "SYTheme.h"

static NSString *const kHistoryCellID = @"SYHistoryCell";

@interface SYSearchHistoryView () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<NSString *> *entries;
@property (nonatomic, copy) void (^selection)(NSString *entry);
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@end

@implementation SYSearchHistoryView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        UIButton *backdrop = [UIButton buttonWithType:UIButtonTypeCustom];
        backdrop.translatesAutoresizingMaskIntoConstraints = NO;
        backdrop.accessibilityLabel = @"Dismiss search history";
        [backdrop addTarget:self
                      action:@selector(dismiss)
            forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:backdrop];

        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = [SYTheme bgSecondary];
        _tableView.layer.cornerRadius = [SYTheme radiusSmall];
        _tableView.layer.borderColor = [SYTheme accentDim].CGColor;
        _tableView.layer.borderWidth = 0.5;
        _tableView.separatorColor = [SYTheme accentDim];
        _tableView.rowHeight = 44;
        _tableView.translatesAutoresizingMaskIntoConstraints = NO;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kHistoryCellID];
        [self addSubview:_tableView];

        _heightConstraint = [_tableView.heightAnchor constraintEqualToConstant:0];
        [NSLayoutConstraint activateConstraints:@[
            _heightConstraint,
            [backdrop.topAnchor constraintEqualToAnchor:self.topAnchor],
            [backdrop.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [backdrop.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [backdrop.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];
    }
    return self;
}

- (void)showInView:(UIView *)view
         belowView:(UIView *)anchor
     alignedToView:(UIView *)input
           entries:(NSArray<NSString *> *)entries
         selection:(void (^)(NSString *))selection {
    if (!entries.count) {
        [self dismiss];
        return;
    }
    _entries = [entries copy];
    _selection = [selection copy];
    if (!self.superview) {
        [view addSubview:self];
        [NSLayoutConstraint activateConstraints:@[
            [self.topAnchor constraintEqualToAnchor:view.topAnchor],
            [self.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
            [self.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [self.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [_tableView.topAnchor constraintEqualToAnchor:anchor.bottomAnchor constant:2],
            [_tableView.leadingAnchor constraintEqualToAnchor:input.leadingAnchor],
            [_tableView.trailingAnchor constraintEqualToAnchor:input.trailingAnchor],
        ]];
    }
    // Recompute on every presentation as history grows, including after dismissal.
    _heightConstraint.constant = MIN((NSUInteger)5, entries.count) * _tableView.rowHeight;
    [_tableView reloadData];
    [view bringSubviewToFront:self];
}

- (void)dismiss {
    [self removeFromSuperview];
    _selection = nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kHistoryCellID
                                                            forIndexPath:indexPath];
    cell.textLabel.text = _entries[indexPath.row];
    cell.textLabel.font = [SYTheme monoMedium];
    cell.textLabel.textColor = [SYTheme textPrimary];
    cell.backgroundColor = [UIColor clearColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    void (^selection)(NSString *) = _selection;
    NSString *entry = _entries[indexPath.row];
    [self dismiss];
    if (selection)
        selection(entry);
}

@end
