# Desktop webview auth

 <a href="https://invertase.link/discord">
   <img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord">
 </a>

This package enables Firebase OAuth on desktop platforms via webview

## Supported providers:

- Google
- Facebook
- Twitter

## Installation

### macOS setup

The recaptcha verification flow is done on the local server, and it requires that the app has the following in the `Release.entitlements`:

```xml
<key>com.apple.security.network.server</key>
<true/>
```

### Linux setup

To display webview on Linux, WebKit2GTK development libraries are used, if you don't have it already installed:

**Ubuntu:**

```bash
apt install libwebkit2gtk-4.0-dev
```

**Fedora:**

```bash
dnf install webkit2gtk3-devel
```

Additionally, if Flutter is installed using snap, you might face issues compiling the app, to fix you would need to uninstall the snap version and [install Flutter manually on Linux](https://docs.flutter.dev/get-started/install/linux#install-flutter-manually).

## Windows setup

Make sure you are on latest stable channle of Flutter, and have installed the requirements [as mentioned here](https://docs.flutter.dev/desktop#additional-windows-requirements).

Nothing extra is needed to get started on Windows.

### Add dependency

```bash
flutter pub add desktop_webview_auth
```

### Imports

```dart
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:desktop_webview_auth/facebook.dart';
import 'package:desktop_webview_auth/twitter.dart';
```

## Usage

- Configure OAuth providers in firebase console
- Create an instance of `ProviderArgs`

```dart
final googleSignInArgs = GoogleSignInArgs(
  clientId:
    '448618578101-sg12d2qin42cpr00f8b0gehs5s7inm0v.apps.googleusercontent.com',
  redirectUri:
    'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler',
  scope: 'email',
)
```

- call `DesktopWebviewAuth.signIn`

```dart
try {
    final result = await DesktopWebviewAuth.signIn(args);

    print(result?.accessToken);
    print(result?.tokenSecret);
} catch (err) {
    // something went wrong
}
```

- create an instance of `OAuthCredential` and sign in

```dart
import 'package:firebase_auth/firebase_auth.dart';

final credential = GoogleAuthProvider.credential(accessToken: result.accessToken)

FirebaseAuth.instance.signInWithCredential(credential);
```
