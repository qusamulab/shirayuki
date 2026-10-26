#import "SYSearchHandler.h"
#import "Hex.hpp"
#import "Memory.hpp"
#import "SYDispatchUtil.h"
#import "SYResultCell.h"
#import "SYScanHelper.hpp"
#import "SYTheme.h"
#import "SYToast.h"
#import "SYValueTypeUtil.h"
#import "Scanner.hpp"
#import "ShirayukiConfig.hpp"
#import "ShirayukiViewController.h"

using namespace Shirayuki;

static NSString *const kCellID = @"SYCell";

@interface SYSearchHandler () {
    std::vector<Scanner::Candidate> _candidates;
}
@property (nonatomic, strong) NSMutableArray<NSString *> *history;
@property (nonatomic, assign) BOOL searching;
@property (nonatomic, assign) BOOL hasSearched;
@end

@implementation SYSearchHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _history = [NSMutableArray new];
        _searchType = @"int32";
        _hasResults = NO;
        _isNarrowing = NO;
    }
    return self;
}

#pragma mark - SYTabHandler

- (NSString *)tabTitle {
    return @"Search";
}
- (NSString *)tabIcon {
    return @"magnifyingglass";
}
- (NSString *)placeholder {
    if (_isNarrowing)
        return @"New value; empty = Changed";
    if ([_searchType isEqualToString:@"hex"])
        return @"FF 00 ?? 01";
    if ([_searchType isEqualToString:@"string"])
        return @"Text to find";
    if ([_searchType isEqualToString:@"regex"])
        return @"Regular expression";
    return @"Value or ? for unknown";
}
- (NSString *)typeLabel {
    return [self shortType];
}
- (NSString *)actionIcon {
    return _isNarrowing ? @"line.3.horizontal.decrease" : @"play.fill";
}

- (NSString *)shortType {
    if ([_searchType isEqualToString:@"hex"])
        return @"hex";
    if ([_searchType isEqualToString:@"string"])
        return @"str";
    if ([_searchType isEqualToString:@"regex"])
        return @"rex";
    return SYValueTypeUtil::shortLabel(SYValueTypeUtil::fromString(_searchType));
}

- (NSArray<NSString *> *)availableTypes {
    return
        [SYValueTypeUtil::allTags() arrayByAddingObjectsFromArray:@[ @"hex", @"string", @"regex" ]];
}

- (void)selectType:(NSString *)type {
    if (_searching || [_searchType isEqualToString:type] ||
        ![[self availableTypes] containsObject:type])
        return;
    _searchType = [type copy];
    [self resetSearch];
}

- (void)cycleType {
    NSArray *types = [self availableTypes];
    NSUInteger index = [types indexOfObject:_searchType];
    [self selectType:types[index == NSNotFound ? 0 : (index + 1) % types.count]];
}

- (BOOL)isBusy {
    return _searching;
}

- (NSString *)statusText {
    if (_searching)
        return _isNarrowing ? @"Filtering results…" : @"Searching memory…";
    if (_candidates.size() >= kMaxScanResults)
        return [NSString
            stringWithFormat:@"%lu results · limit reached", (unsigned long)_candidates.size()];
    return [NSString stringWithFormat:@"%lu results%@", (unsigned long)_candidates.size(),
                                      _isNarrowing ? @" · tap to edit" : @""];
}

- (NSString *)emptyStateMessage {
    if (_hasSearched)
        return @"No matches\nTry another value or search type.";
    return [self isNumericType] ? @"Find a value in memory\nEnter a value, or ? to start unknown."
                                : @"Find bytes or text\nEnter a query, then tap Search.";
}

- (BOOL)beginSearch {
    if (_searching)
        return NO;
    _searching = YES;
    [self.viewController reloadTable];
    return YES;
}

- (void)finishSearch {
    _searching = NO;
    _hasSearched = YES;
    _hasResults = !_candidates.empty();
    _isNarrowing = _hasResults && [self isNumericType];
    [self.viewController reloadTable];
}

- (void)performAction:(NSString *)input {
    if (_searching)
        return;
    if (_isNarrowing) {
        if (!input.length) {
            [self narrow:@"changed"];
        } else {
            [self narrowExact:input];
        }
        return;
    }
    // "?" or empty input on a numeric type starts an unknown-initial-value scan —
    // it seeds candidates over all readable regions without a comparison target,
    // so the user can subsequently narrow via changed/inc/dec.
    if ([self isNumericType] && ([input isEqualToString:@"?"] || !input.length)) {
        [self performUnknownScan];
        return;
    }
    [self performSearch:input];
}

- (BOOL)isNumericType {
    return ![_searchType isEqualToString:@"hex"] && ![_searchType isEqualToString:@"string"] &&
           ![_searchType isEqualToString:@"regex"];
}

- (void)performUnknownScan {
    if (![self beginSearch])
        return;

    ValueType vtype = SYValueTypeUtil::fromString(_searchType);
    __block std::vector<Scanner::Candidate> candidates;
    SYAsync(
        ^{
            auto regions = Memory::listRegionsFiltered(RegionFilter::ReadWrite);
            for (const auto &region : regions) {
                if (candidates.size() >= kMaxScanResults)
                    break;
                if (region.size > kMaxRegionSize)
                    continue;
                auto seeded = Scanner::seedUnknownCandidates(region.start, region.size, vtype,
                                                             kMaxScanResults - candidates.size());
                for (auto &candidate : seeded)
                    candidates.push_back(std::move(candidate));
            }
        },
        ^{
            self->_candidates = std::move(candidates);
            [self finishSearch];
            [SYToast show:[self statusText] type:SYToastInfo];
        });
}

- (void)performSearch:(NSString *)input {
    if ([self isNumericType]) {
        uint8_t bytes[kMaxValueSize] = {};
        if (!ValueFormat::parse([input UTF8String], SYValueTypeUtil::fromString(_searchType),
                                bytes)) {
            [SYToast show:@"Invalid value for the selected type" type:SYToastError];
            return;
        }
    } else if (!input.length) {
        [SYToast show:@"Enter a valid search query" type:SYToastError];
        return;
    }
    if (![self beginSearch])
        return;

    if (input.length && ![_history containsObject:input]) {
        [_history insertObject:input atIndex:0];
        if (_history.count > 20)
            [_history removeLastObject];
    }

    NSString *searchType = _searchType;

    __block std::vector<Scanner::Candidate> candidates;
    SYAsync(
        ^{
            ScanResults scan;
            scan.data = SYScanAll([searchType UTF8String], [input UTF8String], kMaxScanResults,
                                  kMaxRegionSize, &scan.count, &scan.valSize);
            candidates.reserve(scan.count);
            for (size_t i = 0; i < scan.count; ++i) {
                Scanner::Candidate candidate{scan.data[i], {}};
                if (scan.valSize > 0) {
                    candidate.snapshotValue.resize(scan.valSize);
                    if (Memory::read(candidate.address, candidate.snapshotValue.data(),
                                     scan.valSize) != Status::Success)
                        continue;
                }
                candidates.push_back(std::move(candidate));
            }
        },
        ^{
            self->_candidates = std::move(candidates);
            [self finishSearch];
            [SYToast show:[self statusText] type:self.hasResults ? SYToastSuccess : SYToastWarning];
        });
}

- (void)narrow:(NSString *)mode {
    [self narrowWithMode:mode target:nil toastPrefix:@"Narrowed to"];
}

- (void)narrowExact:(NSString *)input {
    uint8_t targetBuf[kMaxValueSize] = {};
    // Report a bad value instead of filtering for zero: the discarded return
    // meant a typo silently narrowed the result set to addresses holding 0.
    const size_t n = SYValueTypeUtil::parseValue(input, _searchType, targetBuf);
    if (n == 0) {
        [SYToast show:[NSString stringWithFormat:@"Invalid %@ value", _searchType]
                 type:SYToastError];
        return;
    }
    NSData *targetData = [NSData dataWithBytes:targetBuf length:n];
    [self narrowWithMode:@"exact" target:targetData toastPrefix:@"Exact:"];
}

// Unified narrow: `target` is nil for changed/unchanged/increased/decreased,
// non-nil for the "exact match" variant. Result publishing is identical for both.
- (void)narrowWithMode:(NSString *)mode
                target:(NSData *)target
           toastPrefix:(NSString *)toastPrefix {
    CompareMode compareMode;
    if ([mode isEqualToString:@"exact"])
        compareMode = CompareMode::Exact;
    else if ([mode isEqualToString:@"changed"])
        compareMode = CompareMode::Changed;
    else if ([mode isEqualToString:@"unchanged"])
        compareMode = CompareMode::Unchanged;
    else if ([mode isEqualToString:@"increased"])
        compareMode = CompareMode::Increased;
    else if ([mode isEqualToString:@"decreased"])
        compareMode = CompareMode::Decreased;
    else
        return;
    if (![self isNumericType] || !_isNarrowing || ![self beginSearch])
        return;
    auto snapshot = _candidates;
    ValueType type = SYValueTypeUtil::fromString(_searchType);
    __block std::vector<Scanner::Candidate> kept;
    SYAsync(
        ^{
            kept = Scanner::narrowResults(snapshot, type, compareMode,
                                          target ? target.bytes : nullptr);
        },
        ^{
            self->_candidates = std::move(kept);
            [self finishSearch];
            [SYToast show:[NSString stringWithFormat:@"%@ %lu", toastPrefix,
                                                     (unsigned long)self->_candidates.size()]
                     type:SYToastInfo];
        });
}

- (size_t)currentValueSize {
    // Defer to the core rather than re-deriving widths from strings here. The
    // hand-rolled version this replaces returned 4 for int8, uint8, uint16 and
    // every unsigned type, and 4 for "hex"/"string"/"regex" too.
    return SYValueTypeUtil::sizeOfTag(_searchType);
}

- (void)batchModify:(NSString *)value {
    if (_searching || ![self isNumericType])
        return;
    uint8_t buf[kMaxValueSize] = {};
    // The discarded parse result meant an unparseable value wrote the zeroed
    // buffer to every address in the result set.
    const size_t n = SYValueTypeUtil::parseValue(value, _searchType, buf);
    if (n == 0) {
        [SYToast show:[NSString stringWithFormat:@"Invalid %@ value", _searchType]
                 type:SYToastError];
        return;
    }

    size_t count = 0;
    for (const auto &candidate : _candidates) {
        if (Memory::write(candidate.address, buf, n) == Status::Success)
            count++;
    }
    const size_t total = _candidates.size();
    if (count == total) {
        [SYToast show:[NSString stringWithFormat:@"Modified %zu addresses", count]
                 type:SYToastSuccess];
    } else {
        [SYToast show:[NSString stringWithFormat:@"Modified %zu of %zu (%zu failed)", count, total,
                                                 total - count]
                 type:SYToastWarning];
    }
}

- (void)resetSearch {
    if (_searching)
        return;
    _hasSearched = NO;
    _candidates.clear();
    _hasResults = NO;
    _isNarrowing = NO;
    [self.viewController reloadTable];
}

- (NSArray<NSString *> *)searchHistory {
    return [_history copy];
}

- (NSString *)exportResultsAsJSON {
    if (_candidates.empty())
        return nil;

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:_candidates.size()];
    for (const auto &candidate : _candidates) {
        uintptr_t addr = candidate.address;
        uint8_t buf[kMaxValueSize] = {};
        size_t width = [self isNumericType] ? [self currentValueSize] : sizeof(buf);
        if (Memory::read(addr, buf, width) != Status::Success)
            continue;
        NSString *val = [self isNumericType] ? SYValueTypeUtil::formatValue(buf, _searchType)
                                             : @(Hex::fromBytes(buf, width).c_str());
        [items addObject:@{
            @"address" : [NSString stringWithFormat:@"0x%lX", addr],
            @"value" : val,
            @"type" : _searchType
        }];
    }

    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:items
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&err];
    if (!data || err)
        return nil;

    // Save to Documents/Shirayuki/
    NSArray *paths =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = paths.firstObject;
    NSString *dir = [docs stringByAppendingPathComponent:@"Shirayuki"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
    NSString *filename = [NSString stringWithFormat:@"results_%lld.json", (long long)ts];
    NSString *path = [dir stringByAppendingPathComponent:filename];
    return [data writeToFile:path atomically:YES] ? path : nil;
}

#pragma mark - Table

- (NSInteger)numberOfRows {
    return _candidates.size();
}

- (UITableViewCell *)cellForRow:(NSInteger)row inTableView:(UITableView *)tableView {
    SYResultCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kCellID
                                        forIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];

    uintptr_t addr = _candidates[row].address;
    uint8_t buf[kMaxValueSize] = {};
    // displayValue, not formatValue: the cell wants the annotated form. Say so
    // plainly when the address can no longer be read, rather than formatting a
    // zeroed buffer as if it were a real value.
    NSString *valueStr = @"<unreadable>";
    size_t width = [self isNumericType] ? [self currentValueSize] : sizeof(buf);
    if (Memory::read(addr, buf, width) == Status::Success)
        valueStr = [self isNumericType] ? SYValueTypeUtil::displayValue(buf, _searchType)
                                        : @(Hex::fromBytes(buf, width).c_str());

    [cell configureWithIcon:[SYTheme icon:@"memorychip" size:14]
                      title:[NSString stringWithFormat:@"0x%lX", addr]
                     detail:valueStr
                      badge:[self shortType]
                 badgeColor:[SYTheme accentDim]];
    return cell;
}

- (void)didSelectRow:(NSInteger)row {
    if (![self isNumericType]) {
        [self didLongPressRow:row];
        return;
    }
    uintptr_t addr = _candidates[row].address;
    [self.viewController showModifyAlertForAddress:addr type:_searchType];
}

- (void)didLongPressRow:(NSInteger)row {
    uintptr_t addr = _candidates[row].address;
    NSString *addrStr = [NSString stringWithFormat:@"0x%lX", addr];
    [UIPasteboard generalPasteboard].string = addrStr;
    [SYToast show:[NSString stringWithFormat:@"Copied %@", addrStr] type:SYToastInfo];
}

@end
