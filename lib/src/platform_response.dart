class PlatformResponse {
  final String flow;
  final String? url;

  PlatformResponse._(this.flow, [this.url]);

  factory PlatformResponse.fromJson(Map<String, dynamic> json) {
    return PlatformResponse._(
      json['flow'],
      json['url'],
    );
  }
}
