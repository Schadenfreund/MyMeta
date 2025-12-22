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
}
