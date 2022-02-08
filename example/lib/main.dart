import 'package:flutter/material.dart';
import 'package:googleapis/identitytoolkit/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:desktop_webview_auth/facebook.dart';
import 'package:desktop_webview_auth/twitter.dart';

void main() {
  runApp(const MyApp());
}

typedef SignInCallback = Future<void> Function();
const String apiKey = 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  SignInCallback signInWithArgs(BuildContext context, ProviderArgs args) =>
      () async {
        final result = await DesktopWebviewAuth.signIn(args);
        notify(context, result?.accessToken);
      };

  void notify(BuildContext context, String? result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('access token: $result'),
      ),
    );
  }

  getRecaptchaVerification(BuildContext context) async {
    final identityToolkit =
        IdentityToolkitApi(clientViaApiKey(apiKey)).relyingparty;
    final recaptchaResponse = await identityToolkit.getRecaptchaParam();
    final result = await DesktopWebviewAuth.recaptchaVerification(
      RecaptchaArgs(
        siteKey: recaptchaResponse.recaptchaSiteKey!,
        siteToken: recaptchaResponse.recaptchaStoken!,
      ),
      height: 600,
      width: 600,
    );

    notify(context, result?.verificationId);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: MaterialStateProperty.all(const EdgeInsets.all(20)),
          ),
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final buttons = [
              ElevatedButton(
                child: const Text('Sign in with Google'),
                onPressed: signInWithArgs(
                  context,
                  GoogleSignInArgs(
                    clientId:
                        '448618578101-sg12d2qin42cpr00f8b0gehs5s7inm0v.apps.googleusercontent.com',
                    redirectUri:
                        'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler',
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Sign in with Twitter'),
                onPressed: signInWithArgs(
                  context,
                  TwitterSignInArgs(
                    apiKey: 'YEXSiWv5UeCHyy0c61O2LBC3B',
                    apiSecretKey:
                        'DOd9dCCRFgtnqMDQT7A68YuGZtvcO4WP1mEFS4mEJAUooM4yaE',
                    redirectUri:
                        'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler',
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Sign in with Facebook'),
                onPressed: signInWithArgs(
                  context,
                  FacebookSignInArgs(
                    clientId: '128693022464535',
                    redirectUri:
                        'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler',
                  ),
                ),
              ),
              ElevatedButton(
                  child: const Text('Recaptcha Verification'),
                  onPressed: () => getRecaptchaVerification(context)),
            ];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: ListView.separated(
                  itemCount: buttons.length,
                  shrinkWrap: true,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    return buttons[index];
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
