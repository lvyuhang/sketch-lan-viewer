/*
 * LanUSBHelper — reverse USB port forward for 览LAN / LanViewer
 *
 * iPhone App listens on 127.0.0.1:9777 + Peertalk mux 19777.
 * This Mac tool attaches over USB (usbmuxd) and relays each pipe to
 * Mac localhost 览LAN (port from ~/.sketch-lan-mirror/runtime.json, else 9777).
 *
 * Not stock iproxy (which is Mac→device only). Based on Flipper FKPortForwarding
 * + rsms/peertalk (MIT). No jailbreak.
 */

#import <Foundation/Foundation.h>
#import "FKPortForwardingClient.h"
#import "USBPorts.h"

static NSUInteger ReadMirrorPort(void) {
  NSString *home = NSHomeDirectory();
  NSString *path = [home stringByAppendingPathComponent:@".sketch-lan-mirror/runtime.json"];
  NSData *data = [NSData dataWithContentsOfFile:path];
  if (!data) {
    NSLog(@"[LanUSBHelper] no %@ — defaulting to port %d", path, LAN_USB_PROXY_PORT);
    return LAN_USB_PROXY_PORT;
  }
  NSError *err = nil;
  id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
  if (![obj isKindOfClass:[NSDictionary class]]) {
    NSLog(@"[LanUSBHelper] bad runtime.json: %@", err);
    return LAN_USB_PROXY_PORT;
  }
  NSNumber *port = obj[@"port"];
  if (port == nil) {
    return LAN_USB_PROXY_PORT;
  }
  NSLog(@"[LanUSBHelper] runtime.json → 览LAN port %@", port);
  return port.unsignedIntegerValue;
}

static NSUInteger ParseArgsPort(int argc, const char *argv[], NSUInteger fallback) {
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--port") == 0 && i + 1 < argc) {
      return (NSUInteger)atoi(argv[++i]);
    }
    if (strncmp(argv[i], "--port=", 7) == 0) {
      return (NSUInteger)atoi(argv[i] + 7);
    }
  }
  return fallback;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSUInteger mirrorPort = ParseArgsPort(argc, argv, ReadMirrorPort());

    NSLog(@"========================================");
    NSLog(@"  览LAN USB 助手  LanUSBHelper");
    NSLog(@"  设备 mux 端口 : %d", LAN_USB_MUX_PORT);
    NSLog(@"  转到 Mac 览LAN: 127.0.0.1:%lu", (unsigned long)mirrorPort);
    NSLog(@"========================================");
    NSLog(@"步骤：");
    NSLog(@"  1) Sketch ▸ 插件 ▸ 览LAN ▸ 开启预览");
    NSLog(@"  2) 数据线连接 iPhone（已信任本机）");
    NSLog(@"  3) iPhone 打开「览LAN」App → 选 USB → 点「USB 连接」");
    NSLog(@"保持本窗口开着。Ctrl+C 退出。");
    NSLog(@"");

    FKPortForwardingClient *client = [[FKPortForwardingClient alloc] init];
    [client forwardConnectionsToPort:mirrorPort];
    [client connectToMultiplexingChannelOnPort:LAN_USB_MUX_PORT];

    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
