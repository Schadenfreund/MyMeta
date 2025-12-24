import 'dart:typed_data';

class MatchResult {
  String newName; // Mutable to allow manual edits
  String? posterUrl; // Keep for online images
  Uint8List? coverBytes; // In-memory cover art

  // Basic Metadata
  String? title;
  int? year;
  int? season;
  int? episode;
  String? type; // 'movie' or 'episode'
  String? episodeTitle;

  // Extended Metadata
  String? description;
  List<String>? genres;
  String? director;
  List<String>? actors;
  double? rating; // e.g., 8.5 out of 10
  String? contentRating; // e.g., "PG-13", "TV-14"
  String? studio;
  int? runtime; // in minutes

  // Additional metadata
  String? imdbId;
  int? tmdbId;

  // Alternative covers from the same search result
  List<String>? alternativePosterUrls; // List of poster URLs from TMDB/OMDB

  // Search results for re-matching
  List<MatchResult>? searchResults; // List of alternative matches from last search

  MatchResult({
    required this.newName,
    this.posterUrl,
    this.coverBytes,
    this.title,
    this.year,
    this.season,
    this.episode,
    this.type,
    this.episodeTitle,
    this.description,
    this.genres,
    this.director,
    this.actors,
    this.rating,
    this.contentRating,
    this.studio,
    this.runtime,
    this.imdbId,
    this.tmdbId,
    this.alternativePosterUrls,
    this.searchResults,
  });

  /// Creates a copy of this MatchResult with the given fields replaced.
  /// This ensures all fields are properly preserved during copy operations.
  MatchResult copyWith({
    String? newName,
    String? posterUrl,
    Uint8List? coverBytes,
    String? title,
    int? year,
    int? season,
    int? episode,
    String? type,
    String? episodeTitle,
    String? description,
    List<String>? genres,
    String? director,
    List<String>? actors,
    double? rating,
    String? contentRating,
    String? studio,
    int? runtime,
    String? imdbId,
    int? tmdbId,
    List<String>? alternativePosterUrls,
    List<MatchResult>? searchResults,
    // Use special markers for nullable fields that should be explicitly set to null
    bool clearPosterUrl = false,
    bool clearCoverBytes = false,
    bool clearDescription = false,
    bool clearDirector = false,
    bool clearContentRating = false,
    bool clearStudio = false,
    bool clearImdbId = false,
    bool clearEpisodeTitle = false,
  }) {
    return MatchResult(
      newName: newName ?? this.newName,
      posterUrl: clearPosterUrl ? null : (posterUrl ?? this.posterUrl),
      coverBytes: clearCoverBytes ? null : (coverBytes ?? this.coverBytes),
      title: title ?? this.title,
      year: year ?? this.year,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      type: type ?? this.type,
      episodeTitle:
          clearEpisodeTitle ? null : (episodeTitle ?? this.episodeTitle),
      description: clearDescription ? null : (description ?? this.description),
      genres: genres ?? this.genres,
      director: clearDirector ? null : (director ?? this.director),
      actors: actors ?? this.actors,
      rating: rating ?? this.rating,
      contentRating:
          clearContentRating ? null : (contentRating ?? this.contentRating),
      studio: clearStudio ? null : (studio ?? this.studio),
      runtime: runtime ?? this.runtime,
      imdbId: clearImdbId ? null : (imdbId ?? this.imdbId),
      tmdbId: tmdbId ?? this.tmdbId,
      alternativePosterUrls:
          alternativePosterUrls ?? this.alternativePosterUrls,
      searchResults: searchResults ?? this.searchResults,
    );
  }
}
