import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'campaigns.dart';

const notebookBackupLimit = 48 * 1024 * 1024;
const _manifestPath = 'caderno.json';

Set<String> notebookBackupImages(Notebook notebook) => {
  for (final record in [
    ...notebook.records,
    ...notebook.sessions,
    ...notebook.trash,
  ]) ...[
    ?record.coverHash,
    for (final picture in record.presentation.pictures) ...[
      ?picture.hash,
      ?picture.cutoutHash,
    ],
  ],
};

Future<Uint8List> createNotebookBackup(
  Notebook notebook,
  Future<Uint8List> Function(String hash) load,
) async {
  final manifest = utf8.encode(
    jsonEncode({
      'format': 'rpg-master-set:notebook:1',
      'notebook': notebook.toJson(),
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile(_manifestPath, manifest.length, manifest));
  var total = manifest.length;
  for (final hash in notebookBackupImages(notebook)) {
    final bytes = await load(hash);
    if (sha256.convert(bytes).toString() != hash) {
      throw const FormatException('Uma imagem do caderno está incompleta.');
    }
    total += bytes.length;
    if (total > notebookBackupLimit) {
      throw const FormatException('O backup ultrapassa 48 MB.');
    }
    archive.addFile(ArchiveFile('imagens/$hash.png', bytes.length, bytes));
  }
  final bytes = ZipEncoder().encodeBytes(archive);
  if (bytes.length > notebookBackupLimit) {
    throw const FormatException('O backup ultrapassa 48 MB.');
  }
  return bytes;
}

({Notebook notebook, Map<String, Uint8List> images}) readNotebookBackup(
  Uint8List bytes,
) {
  if (bytes.length > notebookBackupLimit) {
    throw const FormatException('O backup ultrapassa 48 MB.');
  }
  var total = 0;
  final archive = ZipDecoder().decodeBytes(
    bytes,
    verify: true,
    callback: (file) {
      total += file.size;
      if (file.size < 0 || total > notebookBackupLimit) {
        throw const FormatException(
          'O conteúdo descompactado ultrapassa 48 MB.',
        );
      }
    },
  );
  final manifestFile = archive.findFile(_manifestPath);
  if (manifestFile == null ||
      !manifestFile.isFile ||
      manifestFile.isSymbolicLink) {
    throw const FormatException('O ZIP não contém um backup do caderno.');
  }
  final manifest = jsonDecode(utf8.decode(manifestFile.content));
  if (manifest is! Map || manifest['format'] != 'rpg-master-set:notebook:1') {
    throw const FormatException('Formato do backup não reconhecido.');
  }
  final notebook = Notebook.fromRpc(manifest['notebook']);
  final images = <String, Uint8List>{};
  for (final hash in notebookBackupImages(notebook)) {
    final file = archive.findFile('imagens/$hash.png');
    if (file == null ||
        !file.isFile ||
        file.isSymbolicLink ||
        sha256.convert(file.content).toString() != hash) {
      throw const FormatException(
        'Há uma imagem ausente ou danificada no ZIP.',
      );
    }
    images[hash] = file.content;
  }
  return (notebook: notebook, images: images);
}
