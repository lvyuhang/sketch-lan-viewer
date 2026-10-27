#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thin ObjC wrapper so Swift does not depend on Flipper selector → Swift name mapping.
@interface USBTunnelHost : NSObject
- (void)startWithProxyPort:(NSUInteger)proxyPort muxPort:(NSUInteger)muxPort;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
