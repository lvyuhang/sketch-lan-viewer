#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block` and returns any thrown NSException instead of aborting.
/// Used by tests to prove the old URLSession invalidate race throws.
FOUNDATION_EXPORT NSException * _Nullable LVCatchException(void (^NS_NOESCAPE block)(void));

NS_ASSUME_NONNULL_END
