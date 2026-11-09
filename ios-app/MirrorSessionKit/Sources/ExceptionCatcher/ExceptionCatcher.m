#import "ExceptionCatcher.h"

NSException * _Nullable LVCatchException(void (^NS_NOESCAPE block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *ex) {
        return ex;
    }
}
