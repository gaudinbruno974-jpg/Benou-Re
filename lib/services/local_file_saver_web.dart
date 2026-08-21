// Enregistrement natif sur le web : utilise l'API File System Access
// (`showSaveFilePicker`, non encore couverte par les bindings de
// `package:web`, d'où l'interop JS manuelle ci-dessous) pour laisser
// l'utilisateur choisir le dossier et le nom du fichier, comme le fait déjà
// l'import via `FilePicker.platform.pickFiles`. Si le navigateur ne
// supporte pas cette API (Firefox, Safari), on se rabat sur un
// téléchargement classique (Blob + lien caché), qui va dans le dossier de
// téléchargements par défaut du navigateur.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

extension type _AcceptMap._(JSObject _) implements JSObject {
  external factory _AcceptMap();

  @JS(_xlsxMimeType)
  external set xlsx(JSArray<JSString> value);
}

extension type _FileTypeOption._(JSObject _) implements JSObject {
  external factory _FileTypeOption({String? description, _AcceptMap? accept});
}

extension type _SaveFilePickerOptions._(JSObject _) implements JSObject {
  external factory _SaveFilePickerOptions({
    String? suggestedName,
    JSArray<_FileTypeOption>? types,
  });
}

@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(
  _SaveFilePickerOptions options,
);

bool get _supportsFileSystemAccess =>
    globalContext.has('showSaveFilePicker');

Future<bool> trySaveFileNatively(String fileName, List<int> bytes) async {
  final data = Uint8List.fromList(bytes);
  if (!_supportsFileSystemAccess) {
    _downloadViaAnchor(fileName, data);
    return true;
  }
  try {
    final accept = _AcceptMap()..xlsx = [ '.xlsx'.toJS ].toJS;
    final options = _SaveFilePickerOptions(
      suggestedName: fileName,
      types: [
        _FileTypeOption(description: 'Classeur Excel', accept: accept),
      ].toJS,
    );
    final handle = await _showSaveFilePicker(options).toDart;
    final writable = await handle.createWritable().toDart;
    await writable.write(data.toJS).toDart;
    await writable.close().toDart;
    return true;
  } catch (e) {
    // AbortError : l'utilisateur a annulé la boîte de dialogue — ne pas
    // forcer un téléchargement dans ce cas, comme le ferait un dialogue
    // « Enregistrer sous » natif classique.
    return true;
  }
}

void _downloadViaAnchor(String fileName, Uint8List data) {
  final blob = web.Blob(
    <web.BlobPart>[data.toJS].toJS,
    web.BlobPropertyBag(type: _xlsxMimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
