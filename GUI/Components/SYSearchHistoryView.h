#import <UIKit/UIKit.h>

// Owns the dropdown's table and backdrop, independently of the results table.
@interface SYSearchHistoryView : UIView
- (void)showInView:(UIView *)view
         belowView:(UIView *)anchor
     alignedToView:(UIView *)input
           entries:(NSArray<NSString *> *)entries
         selection:(void (^)(NSString *entry))selection;
- (void)dismiss;
@end
