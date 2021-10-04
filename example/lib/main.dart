import 'package:desktop_webview_auth/twitter.dart';
import 'package:flutter/material.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Column(
              children: [
                ElevatedButton(
                  child: const Text('Sign in with google'),
                  onPressed: () async {
                    final accessToken = await DesktopWebviewAuth.signIn(
                      GoogleSignInArgs(
                        clientId:
                            '448618578101-sg12d2qin42cpr00f8b0gehs5s7inm0v.apps.googleusercontent.com',
                        redirectUri:
                            'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler',
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('access token: $accessToken'),
                      ),
                    );
                  },
                ),
                ElevatedButton(
                  child: const Text('Sign in with twitter'),
                  onPressed: () async {
                    final accessToken = await DesktopWebviewAuth.signIn(
                      TwitterSignInArgs(
                        apiKey: 'YEXSiWv5UeCHyy0c61O2LBC3B',
                        apiSecretKey:
                            'DOd9dCCRFgtnqMDQT7A68YuGZtvcO4WP1mEFS4mEJAUooM4yaE',
                        redirectUri:
                            'https://react-native-firebase-testing.firebaseapp.com/__/auth/handler',
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('access token: $accessToken'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
