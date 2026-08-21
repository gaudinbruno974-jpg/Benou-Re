/// Toujours `false` hors web : l'appelant se rabat alors sur
/// `FilePicker.platform.saveFile`, qui affiche déjà un sélecteur natif
/// « Enregistrer sous » sur Android.
Future<bool> trySaveFileNatively(String fileName, List<int> bytes) async =>
    false;
