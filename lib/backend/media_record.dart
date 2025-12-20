import 'dart:io';
import 'package:path/path.dart' as p;
import 'filename_parser.dart';

class MediaRecord {
  final String fullFilePath;
  final String fileName;
  late ParsedMetadata metadata;
  String? formattedTitle; // To store the result
  String? renamedPath;
  bool get isRenamed => renamedPath != null;

  MediaRecord(this.fullFilePath) : fileName = p.basename(fullFilePath) {
    _analyze();
  }

  void _analyze() {
    // In original: logic to strip excluded folders
    // Here we just use the parser on the filename for simplicity
    metadata = FilenameParser.parse(fullFilePath);
  }

  String get container => metadata.container;
  String get type => metadata.type;
  String? get title => metadata.title;
  int? get year => metadata.year;
  int? get season => metadata.season;
  int? get episode => metadata.episode;

  @override
  String toString() {
    return fileName;
  }
}
