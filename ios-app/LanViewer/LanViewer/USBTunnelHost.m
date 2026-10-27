#import "USBTunnelHost.h"
#import "FKPortForwardingServer.h"

@implementation USBTunnelHost {
  FKPortForwardingServer *_server;
}

- (void)startWithProxyPort:(NSUInteger)proxyPort muxPort:(NSUInteger)muxPort {
  if (_server) {
    return;
  }
  _server = [[FKPortForwardingServer alloc] init];
  [_server listenForMultiplexingChannelOnPort:muxPort];
  [_server forwardConnectionsFromPort:proxyPort];
  NSLog(@"[LanViewer USB] proxy 127.0.0.1:%lu + mux %lu",
        (unsigned long)proxyPort,
        (unsigned long)muxPort);
}

- (void)stop {
  [_server close];
  _server = nil;
}

@end
