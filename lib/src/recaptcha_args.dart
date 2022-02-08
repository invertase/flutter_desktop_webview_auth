import 'dart:async';
import 'dart:io';

class RecaptchaArgs {
  final String siteKey;
  final String siteToken;

  RecaptchaArgs({
    required this.siteKey,
    required this.siteToken,
  });

  String? _redirectUrl;

  /// [redirectUrl] is set after starting to listen to [getLocalServer].
  /// If called before [getLocalServer], will be `null`.
  String? get redirectUrl => _redirectUrl;

  HttpServer? _server;

  StreamController<HttpRequest>? sub;

  Future<String?> getLocalServer() async {
    if (_server == null) {
      sub = StreamController<HttpRequest>();

      final address = InternetAddress.loopbackIPv4;
      _server = await HttpServer.bind(address, 0);

      final port = _server!.port;

      _server!.listen(sub?.add);

      _redirectUrl = 'http://${address.host}:$port';
    }

    return _redirectUrl;
  }

  void closeLocalServer() {
    sub?.close();

    _server?.close();
    _server = null;
  }

  Future<Map<String, String?>> toJson() async {
    return {
      'siteKey': siteKey,
      'siteToken': siteToken,
      'redirectUrl': _redirectUrl,
    };
  }
}
