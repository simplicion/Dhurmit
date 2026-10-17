import 'one_eighty_launcher_stub.dart'
    if (dart.library.js_interop) 'one_eighty_launcher_web.dart';

Future<bool> trigger180WebBottomSheet(String clientId, String redirectUri) {
  return launch180WebBottomSheet(clientId, redirectUri);
}
