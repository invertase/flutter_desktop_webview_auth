// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:googleapis/identitytoolkit/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/facebook.dart';
import 'package:desktop_webview_auth/github.dart';
import 'package:desktop_webview_auth/google.dart';
import 'package:desktop_webview_auth/twitter.dart';

void main() {
  runApp(const MyApp());
}

typedef SignInCallback = Future<void> Function();
const String apiKey = 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0';

const GOOGLE_CLIENT_ID =
    '448618578101-sg12d2qin42cpr00f8b0gehs5s7inm0v.apps.googleusercontent.com';
const REDIRECT_URI =
    'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler';
const TWITTER_API_KEY = 'YEXSiWv5UeCHyy0c61O2LBC3B';
const TWITTER_API_SECRET_KEY =
    'DOd9dCCRFgtnqMDQT7A68YuGZtvcO4WP1mEFS4mEJAUooM4yaE';
const FACEBOOK_CLIENT_ID = '128693022464535';

const GITHUB_CLIENT_ID = '582d07c80a9afae77406';
const GITHUB_CLIENT_SECRET = '2d60f5e850bc178dfa6b7f6c6e37a65b175172d3';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  SignInCallback signInWithArgs(BuildContext context, ProviderArgs args) =>
      () async {
        final result = await DesktopWebviewAuth.signIn(args);
        notify(context, result?.toString());
      };

  void notify(BuildContext context, String? result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Result: $result'),
      ),
    );
  }

  Future<void> getRecaptchaVerification(BuildContext context) async {
    final client = clientViaApiKey(apiKey);
    final identityToolkit = IdentityToolkitApi(client);
    final res = identityToolkit.relyingparty;

    final recaptchaResponse = await res.getRecaptchaParam();

    final args = RecaptchaArgs(
      siteKey: recaptchaResponse.recaptchaSiteKey!,
      siteToken: recaptchaResponse.recaptchaStoken!,
    );

    final result = await DesktopWebviewAuth.recaptchaVerification(
      args,
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
                    clientId: GOOGLE_CLIENT_ID,
                    redirectUri: REDIRECT_URI,
                    scope: 'https://www.googleapis.com/auth/plus.me '
                        'https://www.googleapis.com/auth/userinfo.email',
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Sign in with Twitter'),
                onPressed: signInWithArgs(
                  context,
                  TwitterSignInArgs(
                    apiKey: TWITTER_API_KEY,
                    apiSecretKey: TWITTER_API_SECRET_KEY,
                    redirectUri: REDIRECT_URI,
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Sign in with Facebook'),
                onPressed: signInWithArgs(
                  context,
                  FacebookSignInArgs(
                    clientId: FACEBOOK_CLIENT_ID,
                    redirectUri: REDIRECT_URI,
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Sign in with GitHub'),
                onPressed: signInWithArgs(
                  context,
                  GitHubSignInArgs(
                    clientId: GITHUB_CLIENT_ID,
                    clientSecret: GITHUB_CLIENT_SECRET,
                    redirectUri: REDIRECT_URI,
                  ),
                ),
              ),
              ElevatedButton(
                child: const Text('Recaptcha Verification'),
                onPressed: () => getRecaptchaVerification(context),
              ),
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
