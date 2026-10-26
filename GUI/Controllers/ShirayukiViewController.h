#import <UIKit/UIKit.h>

@interface ShirayukiViewController : UIViewController
- (void)reloadTable;
- (void)showSearchHistory;
@end

@interface ShirayukiViewController (MemoryEditing)
- (void)showModifyAlertForAddress:(uintptr_t)addr type:(NSString *)type;
@end
