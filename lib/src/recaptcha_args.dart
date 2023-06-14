import 'dart:async';

import 'package:flutter/foundation.dart';

import 'jsonable.dart';

class RecaptchaArgs implements JsonSerializable {
  final String siteKey;
  final String siteToken;

  const RecaptchaArgs({
    required this.siteKey,
    required this.siteToken,
  });

  @override
  Future<Map<String, String?>> toJson() {
    return SynchronousFuture({
      'siteKey': siteKey,
      'siteToken': siteToken,
    });
  }
}

class RecaptchaVerificationInvokeArgs extends RecaptchaArgs {
  final String redirectUrl;

  const RecaptchaVerificationInvokeArgs({
    required String siteKey,
    required String siteToken,
    required this.redirectUrl,
  }) : super(siteKey: siteKey, siteToken: siteToken);

  factory RecaptchaVerificationInvokeArgs.fromArgs(
    RecaptchaArgs args,
    String redirectUrl,
  ) {
    return RecaptchaVerificationInvokeArgs(
      siteKey: args.siteKey,
      siteToken: args.siteToken,
      redirectUrl: redirectUrl,
    );
  }

  @override
  Future<Map<String, String?>> toJson() async {
    return SynchronousFuture({
      ...await super.toJson(),
      'redirectUrl': redirectUrl,
    });
  }
}
