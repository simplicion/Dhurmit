import 'dart:js_interop';

@JS('window.launch180BottomSheet')
external JSBoolean? _launch180BottomSheet(JSString clientId, JSString redirectUri);

Future<bool> launch180WebBottomSheet(String clientId, String redirectUri) async {
  try {
    final result = _launch180BottomSheet(clientId.toJS, redirectUri.toJS);
    return result?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
