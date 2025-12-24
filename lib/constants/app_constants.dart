/// Application-wide constants and enums for MyMeta

/// Metadata source options for online searches
enum MetadataSource {
  tmdb('tmdb', 'TMDB'),
  omdb('omdb', 'OMDb'),
  anidb('anidb', 'AniDB');

  final String value;
  final String displayName;

  const MetadataSource(this.value, this.displayName);

  static MetadataSource fromString(String value) {
    return MetadataSource.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => MetadataSource.tmdb,
    );
  }
}

/// Content type for media files
enum ContentType {
  movie('movie'),
  episode('episode');

  final String value;

  const ContentType(this.value);

  static ContentType fromString(String? value) {
    if (value == 'episode') return ContentType.episode;
    return ContentType.movie;
  }
}

/// HTTP request configuration
class HttpConfig {
  /// Default timeout for API requests
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Timeout for image downloads
  static const Duration imageTimeout = Duration(seconds: 30);

  /// Retry delay for rate-limited requests
  static const Duration retryDelay = Duration(milliseconds: 500);

  /// Maximum number of retries for failed requests
  static const int maxRetries = 2;
}

/// Image configuration
class ImageConfig {
  /// Minimum valid image size in bytes
  static const int minImageSizeBytes = 5000;

  /// TMDB image base URL
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/';

  /// TMDB poster size for standard display
  static const String tmdbPosterSize = 'w500';

  /// TMDB poster size for thumbnails
  static const String tmdbPosterSizeSmall = 'w185';
}

/// Tool subdirectory mappings for UserData/tools
class ToolConfig {
  static const Map<String, String> toolSubdirectories = {
    'ffmpeg': 'ffmpeg',
    'ffprobe': 'ffmpeg',
    'mkvpropedit': 'mkvtoolnix',
    'atomicparsley': 'atomicparsley',
  };

  /// Get subdirectory for a tool name
  static String getSubdirectory(String toolName) {
    return toolSubdirectories[toolName.toLowerCase()] ?? toolName.toLowerCase();
  }
}

/// Search result limits
class SearchConfig {
  /// Maximum number of search results to return
  static const int maxSearchResults = 10;

  /// Number of results to fetch full details for
  static const int detailedResultsLimit = 10;
}

/// File validation constants
class FileConfig {
  /// Characters not allowed in Windows filenames
  static final RegExp invalidFilenameChars = RegExp(r'[\\/:*?"<>|]');

  /// Pattern to collapse multiple spaces
  static final RegExp multipleSpaces = RegExp(r'\s+');

  /// Supported video file extensions
  static const List<String> videoExtensions = [
    '.mkv',
    '.mp4',
    '.avi',
    '.mov',
    '.wmv',
    '.m4v',
  ];

  /// Check if a file extension is a supported video format
  static bool isVideoFile(String path) {
    final ext = path.toLowerCase();
    return videoExtensions.any((e) => ext.endsWith(e));
  }
}
