# Applying capabilities

Each capability = entitlement keys in `Config/<AppName>.entitlements` +
(sometimes) usage-description / linker lines in `Config/Shared.xcconfig`.
Never edit the pbxproj for capabilities.

Usage descriptions must be real sentences about *this* app (what is read,
what is written, why) — derive them from the vision/pitch, not boilerplate.
Apple rejects vague ones.

## HealthKit

Entitlements:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>  <!-- only if background observers are actually planned -->
```
Shared.xcconfig:
```
INFOPLIST_KEY_NSHealthShareUsageDescription = <why the app reads Health data>
INFOPLIST_KEY_NSHealthUpdateUsageDescription = <why the app writes Health data>
OTHER_LDFLAGS = $(inherited) -framework HealthKit
```
Also: create `Sources/Integrations/AppleHealth` as the integration target.
Background delivery only works on a physical device — note that in AGENTS.md.

## CloudKit

```xml
<key>com.apple.developer.icloud-services</key>
<array><string>CloudKit</string></array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.<bundle.id></string></array>
```

## Push notifications

```xml
<key>aps-environment</key>
<string>development</string>  <!-- Xcode flips to production at distribution -->
```

## App Groups

```xml
<key>com.apple.security.application-groups</key>
<array><string>group.<bundle.id></string></array>
```

The entitlement is only step one — the shared-defaults access point,
store-file placement, and consumer sweep are the `ios-app-group`
skill's job. Suggest running it after the scaffold when this capability
is selected.

## Keychain sharing

```xml
<key>keychain-access-groups</key>
<array><string>$(AppIdentifierPrefix)<bundle.id></string></array>
```

## Background modes

```xml
<key>com.apple.developer.background-modes</key>
<array><string>remote-notification</string></array>  <!-- pick actual modes -->
```
Common modes: `fetch`, `processing`, `remote-notification`, `audio`,
`location`, `bluetooth-central`.

## Location / Camera / Microphone / Contacts / Photos

No entitlement — usage description keys in Shared.xcconfig only, e.g.:
```
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = <why>
INFOPLIST_KEY_NSCameraUsageDescription = <why>
INFOPLIST_KEY_NSMicrophoneUsageDescription = <why>
INFOPLIST_KEY_NSContactsUsageDescription = <why>
INFOPLIST_KEY_NSPhotoLibraryUsageDescription = <why>
```
