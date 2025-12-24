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

  // Constructor with season/episode overrides for search
  MediaRecord.withOverrides(
    this.fullFilePath, {
    int? season,
    int? episode,
  }) : fileName = p.basename(fullFilePath) {
    _analyze();
    // Override specific fields after parsing
    if (season != null || episode != null) {
      metadata = ParsedMetadata(
        title: metadata.title,
        year: metadata.year,
        season: season ?? metadata.season,
        episode: episode ?? metadata.episode,
        type: metadata.type,
        container: metadata.container,
      );
    }
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
