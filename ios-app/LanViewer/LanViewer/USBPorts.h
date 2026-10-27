#pragma once
/// Peertalk multiplexing channel (Mac helper connects here over USB via usbmuxd).
#define LAN_USB_MUX_PORT 19777
/// Local TCP proxy on the iPhone; MirrorClient connects to http://127.0.0.1:9777.
/// Mac helper relays each accepted socket to Mac 览LAN (usually 9777).
#define LAN_USB_PROXY_PORT 9777
