class MatchResult {
  String newName; // Mutable to allow manual edits
  String? posterUrl;

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

  MatchResult({
    required this.newName,
    this.posterUrl,
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
  });
}
