import 'dart:js_interop';

@JS('window.launch180BottomSheet')
external JSPromise<JSString?> _launch180BottomSheet(JSString clientId, JSString redirectUri);

Future<String?> launch180WebBottomSheet(String clientId, String redirectUri) async {
  try {
    final promise = _launch180BottomSheet(clientId.toJS, redirectUri.toJS);
    final result = await promise.toDart;
    return result?.toDart;
  } catch (_) {
    return null;
  }
}
