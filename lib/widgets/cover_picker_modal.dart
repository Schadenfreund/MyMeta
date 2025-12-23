import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../services/settings_service.dart';

/// Modal for selecting alternative cover art from the same search result
class CoverPickerModal extends StatelessWidget {
  final List<String> posterUrls;
  final String? currentPosterUrl;
  final Function(String) onSelected;

  const CoverPickerModal({
    super.key,
    required this.posterUrls,
    this.currentPosterUrl,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Select Cover Art',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Grid of posters
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2 / 3,
                ),
                itemCount: posterUrls.length,
                itemBuilder: (context, index) {
                  final posterUrl = posterUrls[index];
                  final isSelected = posterUrl == currentPosterUrl;

                  return GestureDetector(
                    onTap: () {
                      onSelected(posterUrl);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              posterUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 40,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal for selecting from search results (re-matching)
class SearchResultsPickerModal extends StatefulWidget {
  final List<MatchResult> searchResults;
  final MatchResult? currentResult;
  final Function(MatchResult) onSelected;

  const SearchResultsPickerModal({
    super.key,
    required this.searchResults,
    this.currentResult,
    required this.onSelected,
  });

  @override
  State<SearchResultsPickerModal> createState() =>
      _SearchResultsPickerModalState();
}

class _SearchResultsPickerModalState extends State<SearchResultsPickerModal> {
  String _selectedSource = 'tmdb'; // 'tmdb' or 'omdb'
  List<MatchResult> _currentResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentResults = widget.searchResults;
    // Detect initial source from results (TMDB has tmdbId, OMDb has imdbId)
    if (_currentResults.isNotEmpty) {
      if (_currentResults.first.imdbId != null &&
          _currentResults.first.tmdbId == null) {
        _selectedSource = 'omdb';
      }
    }
  }

  Future<void> _performSearch() async {
    if (widget.currentResult == null || widget.currentResult!.title == null) {
      setState(() {
        _errorMessage = 'No title to search for';
      });
      return;
    }

    final settings = context.read<SettingsService>();
    final title = widget.currentResult!.title!;
    final year = widget.currentResult!.year;
    final isMovie = widget.currentResult!.type == 'movie';

    // Check if API key is configured
    String apiKey;
    if (_selectedSource == 'tmdb') {
      if (settings.tmdbApiKey.isEmpty) {
        setState(() {
          _errorMessage = 'TMDB API key not configured';
        });
        return;
      }
      apiKey = settings.tmdbApiKey;
    } else if (_selectedSource == 'omdb') {
      if (settings.omdbApiKey.isEmpty) {
        setState(() {
          _errorMessage = 'OMDb API key not configured';
        });
        return;
      }
      apiKey = settings.omdbApiKey;
    } else {
      // anidb
      if (settings.anidbClientId.isEmpty) {
        setState(() {
          _errorMessage = 'AniDB Client ID not configured';
        });
        return;
      }
      apiKey = settings.anidbClientId;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    debugPrint('🔍 Modal calling centralized search:');
    debugPrint('   Title: $title');
    debugPrint('   Year: $year');
    debugPrint('   IsMovie: $isMovie');
    debugPrint('   Source: $_selectedSource');
    debugPrint('   Season: ${widget.currentResult!.season}');
    debugPrint('   Episode: ${widget.currentResult!.episode}');
    debugPrint('   EpisodeTitle: ${widget.currentResult!.episodeTitle}');

    try {
      // Use the centralized search method
      final results = await CoreBackend.searchMetadata(
        title: title,
        year: year,
        isMovie: isMovie,
        source: _selectedSource,
        apiKey: apiKey,
        season: widget.currentResult!.season,
        episode: widget.currentResult!.episode,
        episodeTitle: widget.currentResult!.episodeTitle,
      );

      setState(() {
        _currentResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            // Header with toggle
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Select Match',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Source Toggle
                  Row(
                    children: [
                      const Text(
                        'Search with:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.2),
                            ),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedSource,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down),
                            items: const [
                              DropdownMenuItem(
                                value: 'tmdb',
                                child: Row(
                                  children: [
                                    Icon(Icons.movie_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('TMDB'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'omdb',
                                child: Row(
                                  children: [
                                    Icon(Icons.local_movies_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('OMDb'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'anidb',
                                child: Row(
                                  children: [
                                    Icon(Icons.theaters_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('AniDB'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (String? newSource) {
                              if (newSource != null &&
                                  newSource != _selectedSource) {
                                setState(() {
                                  _selectedSource = newSource;
                                });
                                _performSearch();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            // List of search results or loading
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Searching...'),
                        ],
                      ),
                    )
                  : _currentResults.isEmpty
                      ? const Center(
                          child: Text('No results found'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _currentResults.length,
                          itemBuilder: (context, index) {
                            final result = _currentResults[index];

                            // Better selection logic - compare by unique IDs or title+year
                            final isSelected = widget.currentResult != null &&
                                ((result.tmdbId != null &&
                                        result.tmdbId ==
                                            widget.currentResult?.tmdbId) ||
                                    (result.imdbId != null &&
                                        result.imdbId ==
                                            widget.currentResult?.imdbId) ||
                                    (result.tmdbId == null &&
                                        result.imdbId == null &&
                                        result.title ==
                                            widget.currentResult?.title &&
                                        result.year ==
                                            widget.currentResult?.year));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1)
                                  : null,
                              child: ListTile(
                                leading: result.posterUrl != null &&
                                        result.posterUrl!.startsWith('http')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          result.posterUrl!,
                                          width: 40,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              width: 40,
                                              height: 60,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 16,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 60,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                            Icons.image_not_supported),
                                      ),
                                title: Text(
                                  result.title ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight:
                                        isSelected ? FontWeight.bold : null,
                                  ),
                                ),
                                subtitle: Text(
                                  _buildSubtitle(result),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: () {
                                  widget.onSelected(result);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(MatchResult result) {
    List<String> parts = [];

    if (result.type == 'episode') {
      parts.add('TV Show');
      if (result.season != null && result.episode != null) {
        parts.add('S${result.season}E${result.episode}');
      }
    } else {
      parts.add('Movie');
    }

    if (result.year != null) {
      parts.add('${result.year}');
    }

    if (result.rating != null) {
      parts.add('⭐ ${result.rating!.toStringAsFixed(1)}');
    }

    return parts.join(' • ');
  }
}
