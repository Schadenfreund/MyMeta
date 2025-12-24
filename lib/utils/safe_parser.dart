/// Safe parsing utilities with bounds checking and error handling

/// Safely extracts a year from various string formats
class SafeParser {
  /// Valid year range for media
  static const int minYear = 1888; // First movie ever made
  static const int maxYear = 2100;

  /// Extract year from a date string (e.g., "2023-12-25" or "2023")
  /// Returns null if parsing fails or year is invalid
  static int? parseYear(dynamic value) {
    if (value == null) return null;

    final str = value.toString().trim();
    if (str.isEmpty) return null;

    // Try direct integer parse first
    final directParse = int.tryParse(str);
    if (directParse != null && _isValidYear(directParse)) {
      return directParse;
    }

    // Try to extract 4-digit year from string
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(str);
    if (yearMatch != null) {
      final year = int.tryParse(yearMatch.group(0)!);
      if (year != null && _isValidYear(year)) {
        return year;
      }
    }

    // Try substring if string is at least 4 characters
    if (str.length >= 4) {
      final year = int.tryParse(str.substring(0, 4));
      if (year != null && _isValidYear(year)) {
        return year;
      }
    }

    return null;
  }

  /// Check if a year is within valid range
  static bool _isValidYear(int year) {
    return year >= minYear && year <= maxYear;
  }

  /// Parse a double from various types safely
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// Parse an integer from various types safely
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      // Handle "N/A" and similar
      if (trimmed.toLowerCase() == 'n/a') return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  /// Safely get first N characters of a string
  static String? safeSubstring(String? value, int start, [int? end]) {
    if (value == null || value.isEmpty) return null;
    if (start < 0 || start >= value.length) return null;

    final actualEnd = end ?? value.length;
    if (actualEnd <= start || actualEnd > value.length) {
      return value.substring(start);
    }

    return value.substring(start, actualEnd);
  }

  /// Parse runtime from string (handles "120 min", "2h 30m", etc.)
  static int? parseRuntime(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    final str = value.toString().trim().toLowerCase();
    if (str.isEmpty || str == 'n/a') return null;

    // Try direct parse first
    final direct = int.tryParse(str);
    if (direct != null) return direct;

    // Handle "120 min" format
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(str);
    if (minMatch != null) {
      return int.tryParse(minMatch.group(1)!);
    }

    // Handle "2h 30m" or "2h30m" format
    final hourMinMatch = RegExp(r'(\d+)\s*h\s*(\d+)?\s*m?').firstMatch(str);
    if (hourMinMatch != null) {
      final hours = int.tryParse(hourMinMatch.group(1)!) ?? 0;
      final minutes = int.tryParse(hourMinMatch.group(2) ?? '0') ?? 0;
      return hours * 60 + minutes;
    }

    return null;
  }

  /// Parse a comma-separated string into a list
  static List<String>? parseCommaSeparated(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();

    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'n/a') return null;

    return str
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Clean a string value (trim, handle N/A, etc.)
  static String? cleanString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'n/a') return null;
    return str;
  }

  /// Extract season and episode numbers from a pattern string
  static ({int? season, int? episode}) parseSeasonEpisode(String? pattern) {
    if (pattern == null || pattern.isEmpty) {
      return (season: null, episode: null);
    }

    // Try S##E## format
    final sXeMatch =
        RegExp(r'[Ss](\d{1,2})\s*[Ee](\d{1,3})').firstMatch(pattern);
    if (sXeMatch != null) {
      return (
        season: int.tryParse(sXeMatch.group(1)!),
        episode: int.tryParse(sXeMatch.group(2)!),
      );
    }

    // Try ##x## format
    final xMatch = RegExp(r'(\d{1,2})[xX](\d{1,3})').firstMatch(pattern);
    if (xMatch != null) {
      return (
        season: int.tryParse(xMatch.group(1)!),
        episode: int.tryParse(xMatch.group(2)!),
      );
    }

    // Try Season # Episode # format
    final wordMatch =
        RegExp(r'Season\s*(\d{1,2}).*Episode\s*(\d{1,3})', caseSensitive: false)
            .firstMatch(pattern);
    if (wordMatch != null) {
      return (
        season: int.tryParse(wordMatch.group(1)!),
        episode: int.tryParse(wordMatch.group(2)!),
      );
    }

    return (season: null, episode: null);
  }
}
