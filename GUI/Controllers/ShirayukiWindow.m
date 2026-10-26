#import "ShirayukiWindow.h"
#import "ShirayukiViewController.h"

@implementation ShirayukiWindow

+ (instancetype)shared {
    static ShirayukiWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat width = MIN(360, CGRectGetWidth(screen) - 24);
        CGFloat height = MIN(540, CGRectGetHeight(screen) - 100);
        CGRect frame = CGRectMake((CGRectGetWidth(screen) - width) / 2, 60, width, height);
        instance = [[ShirayukiWindow alloc] initWithFrame:frame];
        instance.windowLevel = UIWindowLevelAlert + 100;
        instance.backgroundColor = [UIColor clearColor];
        instance.rootViewController = [[ShirayukiViewController alloc] init];
        instance.layer.cornerRadius = 12;
        instance.clipsToBounds = YES;
        instance.hidden = YES;
    });
    return instance;
}

- (void)show {
    self.hidden = NO;
    [self makeKeyAndVisible];
}

- (void)hide {
    self.hidden = YES;
}

- (void)toggle {
    if (self.hidden)
        [self show];
    else
        [self hide];
}

@end
