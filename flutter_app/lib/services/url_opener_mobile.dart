import 'package:flutter/services.dart';

const MethodChannel _urlChannel = MethodChannel('re.benou.benou_re/urls');

Future<void> openExternalUrl(String url) async {
  await _urlChannel.invokeMethod<bool>('openUrl', {'url': url});
}
