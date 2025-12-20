import 'package:path/path.dart' as p;

class ParsedMetadata {
  final String? title;
  final int? year;
  final int? season;
  final int? episode;
  final String type; // 'movie' or 'episode'
  final String container;

  ParsedMetadata({
    this.title,
    this.year,
    this.season,
    this.episode,
    required this.type,
    required this.container,
  });

  @override
  String toString() {
    return 'ParsedMetadata(title: $title, year: $year, season: $season, episode: $episode, type: $type, container: $container)';
  }
}

class FilenameParser {
  // Regex for S01E01 format
  static final RegExp _sXXeXX = RegExp(r'[sS](\d{1,2})[eE](\d{1,2})', caseSensitive: false);
  // Regex for 1x01 format
  static final RegExp _numXnum = RegExp(r'(\d{1,2})x(\d{1,2})', caseSensitive: false);
  // Regex for Year (19xx or 20xx)
  static final RegExp _yearCheck = RegExp(r'\b(19|20)\d{2}\b');
  // Common separators
  static final RegExp _separators = RegExp(r'[.\s\-_]+');

  static ParsedMetadata parse(String filePath) {
    String fileName = p.basename(filePath);
    String container = p.extension(fileName).replaceAll('.', '');
    String nameWithoutExt = p.basenameWithoutExtension(fileName);

    int? season;
    int? episode;
    int? year;
    String? title;
    String type = 'movie';

    // 1. Check for Season/Episode info
    Match? sMatch = _sXXeXX.firstMatch(nameWithoutExt);
    if (sMatch != null) {
      season = int.tryParse(sMatch.group(1)!);
      episode = int.tryParse(sMatch.group(2)!);
      type = 'episode';
      
      // Assume title is everything before the match
      title = nameWithoutExt.substring(0, sMatch.start).replaceAll(_separators, ' ').trim();
    } else {
      Match? xMatch = _numXnum.firstMatch(nameWithoutExt);
      if (xMatch != null) {
        season = int.tryParse(xMatch.group(1)!);
        episode = int.tryParse(xMatch.group(2)!);
        type = 'episode';
        title = nameWithoutExt.substring(0, xMatch.start).replaceAll(_separators, ' ').trim();
      }
    }

    // 2. Check for Year
    // If we haven't found a title yet (movie case usually), or if we want to extract year from title
    // Search for year in the whole string
    Iterable<Match> yearMatches = _yearCheck.allMatches(nameWithoutExt);
    if (yearMatches.isNotEmpty) {
      // Usually the last year found matches the release year? or the first?
      // "Movie Name 2023 Something else" -> 2023
      String yStr = yearMatches.last.group(0)!;
      year = int.tryParse(yStr);

      if (type == 'movie') {
        // Title is likely everything before the year
        // But only if we didn't already identify it as an episode
        int yIndex = nameWithoutExt.lastIndexOf(yStr);
        String potentialTitle = nameWithoutExt.substring(0, yIndex).replaceAll(_separators, ' ').trim();
        // Clean up trailing chars like '('
        if (potentialTitle.endsWith('(')) {
          potentialTitle = potentialTitle.substring(0, potentialTitle.length - 1).trim();
        }
        title = potentialTitle;
      }
    } else {
      // If no year and hasn't been identified as episode, take whole name as title
      if (title == null) {
         title = nameWithoutExt.replaceAll(_separators, ' ').trim();
         // If it looks like a movie, keep type movie.
      }
    }
    
    // Clean up title
    if (title != null) {
       title = _cleanTitle(title);
    }

    return ParsedMetadata(
      title: title,
      year: year,
      season: season,
      episode: episode,
      type: type,
      container: container,
    );
  }

  static String _cleanTitle(String raw) {
    // Remove common release group junk if needed, or just keep it simple
    return raw;
  }
}
