# Pulse Loom

Pulse Loom is a native SwiftUI rhythm-practice app. It turns silent fingertip taps into an early/on-time/late Timing Ribbon and a focused weak-cell replay.

## Build

```sh
xcodebuild -project PulseLoom.xcodeproj -scheme PulseLoom -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
swift test
```

The app targets iOS 14 and compiles in Swift 5 language mode. StoreKit 2 features activate on iOS 15 and later; the free practice loop remains available on every supported version.

