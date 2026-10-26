#import "Memory.hpp"
#import "SYFreezeHandler.h"
#import "SYInput.h"
#import "SYPatchHandler.h"
#import "SYSearchHandler.h"
#import "SYTheme.h"
#import "SYToast.h"
#import "SYValueTypeUtil.h"
#import "SYWatchHandler.h"
#import "ShirayukiViewController+Private.h"

using namespace Shirayuki;

@implementation ShirayukiViewController (Actions)

- (void)presentActionSheet:(UIAlertController *)sheet sourceView:(UIView *)source {
    sheet.popoverPresentationController.sourceView = source;
    sheet.popoverPresentationController.sourceRect = source.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)actionLongPressed:(UILongPressGestureRecognizer *)gesture {
    id<SYTabHandler> handler = [self currentHandler];
    if (gesture.state != UIGestureRecognizerStateBegan ||
        ([handler respondsToSelector:@selector(isBusy)] && [handler isBusy]))
        return;

    // On search tab: offer export + batch modify
    if ([self currentHandler] == self.searchHandler && self.searchHandler.hasResults) {
        UIAlertController *sheet =
            [UIAlertController alertControllerWithTitle:@"Search Actions"
                                                message:nil
                                         preferredStyle:UIAlertControllerStyleActionSheet];

        [sheet addAction:[UIAlertAction
                             actionWithTitle:@"Export to JSON"
                                       style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction *a) {
                                         NSString *path = [self.searchHandler exportResultsAsJSON];
                                         if (path) {
                                             NSString *fn = [path lastPathComponent];
                                             [SYToast
                                                 show:[NSString stringWithFormat:@"Saved: %@", fn]
                                                 type:SYToastSuccess];
                                         } else {
                                             [SYToast show:@"Export failed" type:SYToastError];
                                         }
                                     }]];

        if ([self.searchHandler isNumericType]) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"Batch Modify"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                                                        [self showBatchModifyAlert];
                                                    }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"New Search"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    [self.searchHandler resetSearch];
                                                }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [self presentActionSheet:sheet sourceView:self.actionButton];
        return;
    }

    // On patch tab: offer undo/redo
    if ([self currentHandler] == self.patchHandler) {
        UIAlertController *sheet =
            [UIAlertController alertControllerWithTitle:@"Patch Actions"
                                                message:nil
                                         preferredStyle:UIAlertControllerStyleActionSheet];

        if ([self.patchHandler canUndo]) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"Undo"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                                                        [self.patchHandler undo];
                                                    }]];
        }
        if ([self.patchHandler canRedo]) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"Redo"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *a) {
                                                        [self.patchHandler redo];
                                                    }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [self presentActionSheet:sheet sourceView:self.actionButton];
    }
}

- (void)showBatchModifyAlert {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Batch Modify"
                                            message:@"Set all results to value"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"value";
        tf.keyboardType = UIKeyboardTypeASCIICapable;
        tf.font = [SYTheme monoMedium];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Apply"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                                NSString *val = alert.textFields.firstObject.text;
                                                if (val.length)
                                                    [self.searchHandler batchModify:val];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showModifyAlertForAddress:(uintptr_t)addr type:(NSString *)type {
    const size_t valSize = Shirayuki::valueTypeSize(SYValueTypeUtil::fromString(type));

    // Read first and bail out if it fails. Formatting a zero-filled buffer would
    // prefill the edit field with "0", and accepting that prefill writes a real
    // zero into memory — a failed read turning into actual corruption. The
    // per-type if/else this replaces also treated int16 and every unsigned type
    // as int32.
    uint8_t buf[Shirayuki::kMaxValueSize] = {};
    if (Memory::read(addr, buf, valSize) != Status::Success) {
        [SYToast show:[NSString stringWithFormat:@"Cannot read %@", SYFormatAddress(addr)]
                 type:SYToastError];
        return;
    }

    // Plain form for the edit field (re-parseable), annotated form for the label.
    NSString *editStr = SYValueTypeUtil::formatValue(buf, type);
    NSString *displayStr = SYValueTypeUtil::displayValue(buf, type);

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:SYFormatAddress(addr)
                         message:[NSString stringWithFormat:@"Current: %@ (%@)", displayStr, type]
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = editStr;
        tf.font = [SYTheme monoMedium];
        // Not DecimalPad: negative values, hex entry and exponents all need the
        // full keyboard, and every type is parsed through ValueFormat anyway.
        tf.keyboardType = UIKeyboardTypeASCIICapable;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.clearButtonMode = UITextFieldViewModeAlways;
    }];

    [alert
        addAction:[UIAlertAction
                      actionWithTitle:@"Write"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *a) {
                                  NSString *val = alert.textFields.firstObject.text;
                                  uint8_t out[Shirayuki::kMaxValueSize] = {};
                                  const size_t n = SYValueTypeUtil::parseValue(val, type, out);
                                  if (n == 0) {
                                      [SYToast
                                          show:[NSString stringWithFormat:@"Invalid %@ value", type]
                                          type:SYToastError];
                                      return;
                                  }
                                  if (Memory::write(addr, out, n) != Status::Success) {
                                      [SYToast show:@"Write failed" type:SYToastError];
                                      return;
                                  }
                                  [SYToast show:@"Written" type:SYToastSuccess];
                                  [self reloadTable];
                              }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Freeze"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                                NSString *val = alert.textFields.firstObject.text;
                                                NSString *cmd = [NSString
                                                    stringWithFormat:@"%@ %@ %@",
                                                                     SYFormatAddress(addr), val,
                                                                     type];
                                                [self.freezeHandler performAction:cmd];
                                            }]];

    [alert addAction:[UIAlertAction
                         actionWithTitle:@"Watch"
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                     [self.watchHandler
                                         performAction:[NSString
                                                           stringWithFormat:@"%@ %@",
                                                                            SYFormatAddress(addr),
                                                                            type]];
                                 }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
