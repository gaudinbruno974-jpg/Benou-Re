// Enregistrement d'un fichier généré (export .xlsx) directement sur le
// disque de l'utilisateur, à l'emplacement de son choix.
// - Web : boîte de dialogue « Enregistrer sous » native du navigateur (API
//   File System Access), avec repli sur un téléchargement classique si le
//   navigateur ne la supporte pas (Firefox, Safari).
// - Autres plateformes (Android) : non géré ici, l'appelant utilise
//   `FilePicker.platform.saveFile`, qui y fonctionne déjà nativement.
export 'local_file_saver_mobile.dart'
    if (dart.library.js_interop) 'local_file_saver_web.dart';
