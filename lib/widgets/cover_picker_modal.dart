import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../services/settings_service.dart';
import '../services/tmdb_service.dart';
import '../services/omdb_service.dart';
import '../services/anidb_service.dart';

/// Modal for selecting alternative cover art with search capability
class CoverPickerModal extends StatefulWidget {
  final List<String> posterUrls;
  final String? currentPosterUrl;
  final Function(String) onSelected;
  final String? initialSearchQuery;
  final bool isMovie;
  final int? season; // when set, TMDB search returns season-specific posters

  const CoverPickerModal({
    super.key,
    required this.posterUrls,
    this.currentPosterUrl,
    required this.onSelected,
    this.initialSearchQuery,
    this.isMovie = true,
    this.season,
  });

  @override
  State<CoverPickerModal> createState() => _CoverPickerModalState();
}

class _CoverPickerModalState extends State<CoverPickerModal> {
  late TextEditingController _searchController;
  late List<String> _currentPosters;
  late String _selectedSource;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    _currentPosters = List.from(widget.posterUrls);
    _selectedSource = _resolveSource(context.read<SettingsService>());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _resolveSource(SettingsService settings) {
    final preferred = settings.metadataSource;
    final keys = {
      'tmdb': settings.tmdbApiKey,
      'omdb': settings.omdbApiKey,
      'anidb': settings.anidbClientId,
    };
    if (keys[preferred]?.isNotEmpty == true) return preferred;
    for (final e in keys.entries) {
      if (e.value.isNotEmpty) return e.key;
    }
    return preferred;
  }

  Future<void> _searchPosters() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final settings = context.read<SettingsService>();
    final apiKey = _selectedSource == 'tmdb'
        ? settings.tmdbApiKey
        : _selectedSource == 'omdb'
            ? settings.omdbApiKey
            : settings.anidbClientId;
    if (apiKey.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<String> posters = [];

      if (_selectedSource == 'tmdb') {
        final tmdb = TmdbService(apiKey);
        if (widget.isMovie) {
          final result = await tmdb.searchMovie(query, null);
          if (result != null) posters = await tmdb.getMoviePosters(result['id'] as int);
        } else {
          final result = await tmdb.searchTV(query);
          if (result != null) {
            final tvId = result['id'] as int;
            if (widget.season != null) {
              // Season-specific gallery first; fall back to show-level posters
              posters = await tmdb.getSeasonPosters(tvId, widget.season!);
              if (posters.isEmpty) posters = await tmdb.getTVPosters(tvId);
            } else {
              posters = await tmdb.getTVPosters(tvId);
            }
          }
        }
      } else if (_selectedSource == 'omdb') {
        final omdb = OmdbService(apiKey);
        final results = widget.isMovie
            ? await omdb.searchMovieAll(query, null)
            : await omdb.searchSeriesAll(query);
        posters = results
            .map((r) => r['Poster'] as String?)
            .where((p) => p != null && p != 'N/A')
            .cast<String>()
            .toList();
      } else if (_selectedSource == 'anidb') {
        final anidb = AnidbService(apiKey);
        final results = await anidb.searchAnimeAll(query);
        posters = results
            .map((r) => r['poster_url'] as String?)
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toList();
      }

      if (mounted) {
        setState(() {
          _currentPosters = posters;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Cover search failed: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    final providerItems = <DropdownMenuItem<String>>[
      if (settings.tmdbApiKey.isNotEmpty)
        const DropdownMenuItem(value: 'tmdb', child: Text('TMDB')),
      if (settings.omdbApiKey.isNotEmpty)
        const DropdownMenuItem(value: 'omdb', child: Text('OMDb')),
      if (settings.anidbClientId.isNotEmpty)
        const DropdownMenuItem(value: 'anidb', child: Text('AniDB')),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_library,
                          color: settings.accentColor, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Select Cover Art',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar with provider dropdown
                  Row(
                    children: [
                      if (providerItems.isNotEmpty) ...[
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedSource,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down,
                                size: 20),
                            items: providerItems,
                            onChanged: (v) {
                              if (v != null && v != _selectedSource) {
                                setState(() => _selectedSource = v);
                                _searchPosters();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search posters by title...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: settings.accentColor, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _searchPosters(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSearching ? null : _searchPosters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: settings.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Grid of posters or loading
            Expanded(
              child: _isSearching
                  ? Center(
                      child: CircularProgressIndicator(
                          color: settings.accentColor))
                  : _currentPosters.isEmpty
                      ? const Center(child: Text('No posters found'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: _currentPosters.length,
                          itemBuilder: (context, index) {
                            final posterUrl = _currentPosters[index];
                            final isSelected =
                                posterUrl == widget.currentPosterUrl;

                            return GestureDetector(
                              onTap: () {
                                widget.onSelected(posterUrl);
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? settings.accentColor
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
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey),
                                          );
                                        },
                                      ),
                                      if (isSelected)
                                        Container(
                                          color:
                                              Colors.black.withValues(alpha: 0.3),
                                          child: Center(
                                            child: Icon(
                                              Icons.check_circle,
                                              size: 40,
                                              color: settings.accentColor,
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

/// Modal for selecting from search results (re-matching) with search bar
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
  late TextEditingController _searchController;
  String _selectedSource = 'tmdb';
  List<MatchResult> _currentResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.currentResult?.title ?? '');
    _currentResults = widget.searchResults;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initSource();
  }

  void _initSource() {
    final settings = context.read<SettingsService>();
    final hasTmdb = settings.tmdbApiKey.isNotEmpty;
    final hasOmdb = settings.omdbApiKey.isNotEmpty;
    final hasAnidb = settings.anidbClientId.isNotEmpty;

    // Detect source from existing results
    if (_currentResults.isNotEmpty) {
      if (_currentResults.first.imdbId != null &&
          _currentResults.first.tmdbId == null &&
          hasOmdb) {
        _selectedSource = 'omdb';
      } else if (_currentResults.first.tmdbId != null && hasTmdb) {
        _selectedSource = 'tmdb';
      } else if (hasAnidb) {
        _selectedSource = 'anidb';
      }
    } else {
      if (hasTmdb) {
        _selectedSource = 'tmdb';
      } else if (hasOmdb) {
        _selectedSource = 'omdb';
      } else if (hasAnidb) {
        _selectedSource = 'anidb';
      }

      // Auto-search if no initial results
      if (_currentResults.isEmpty) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _performSearch());
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Enter a title to search');
      return;
    }

    final settings = context.read<SettingsService>();
    final isMovie = widget.currentResult?.type == 'movie';

    String apiKey;
    if (_selectedSource == 'tmdb') {
      apiKey = settings.tmdbApiKey;
    } else if (_selectedSource == 'omdb') {
      apiKey = settings.omdbApiKey;
    } else {
      apiKey = settings.anidbClientId;
    }

    if (apiKey.isEmpty) {
      setState(() => _errorMessage = 'No API key for $_selectedSource');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await CoreBackend.searchMetadata(
        title: query,
        year: null,
        isMovie: isMovie,
        source: _selectedSource,
        apiKey: apiKey,
        season: widget.currentResult?.season,
        episode: widget.currentResult?.episode,
        episodeTitle: widget.currentResult?.episodeTitle,
      );

      setState(() {
        _currentResults = results;
        _isSearching = false;
        if (results.isEmpty) _errorMessage = 'No results found for "$query"';
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
    final settings = context.watch<SettingsService>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.search,
                          color: settings.accentColor, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Select Match',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar with source dropdown
                  Row(
                    children: [
                      // Source dropdown (compact)
                      Consumer<SettingsService>(
                        builder: (context, settings, _) {
                          final items = <DropdownMenuItem<String>>[];
                          if (settings.tmdbApiKey.isNotEmpty) {
                            items.add(const DropdownMenuItem(
                                value: 'tmdb', child: Text('TMDB')));
                          }
                          if (settings.omdbApiKey.isNotEmpty) {
                            items.add(const DropdownMenuItem(
                                value: 'omdb', child: Text('OMDb')));
                          }
                          if (settings.anidbClientId.isNotEmpty) {
                            items.add(const DropdownMenuItem(
                                value: 'anidb', child: Text('AniDB')));
                          }
                          if (items.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedSource,
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down,
                                  size: 20),
                              items: items,
                              onChanged: (v) {
                                if (v != null && v != _selectedSource) {
                                  setState(() => _selectedSource = v);
                                  _performSearch();
                                }
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      // Search text field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search title...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: settings.accentColor, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSearching ? null : _performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: settings.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Search'),
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
            const SizedBox(height: 4),
            // Results list or loading
            Expanded(
              child: _isSearching
                  ? Center(
                      child: CircularProgressIndicator(
                          color: settings.accentColor))
                  : _currentResults.isEmpty
                      ? const Center(child: Text('No results found'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _currentResults.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final result = _currentResults[index];
                            final isSelected =
                                widget.currentResult != null &&
                                    ((result.tmdbId != null &&
                                            result.tmdbId ==
                                                widget.currentResult
                                                    ?.tmdbId) ||
                                        (result.imdbId != null &&
                                            result.imdbId ==
                                                widget.currentResult
                                                    ?.imdbId) ||
                                        (result.tmdbId == null &&
                                            result.imdbId == null &&
                                            result.title ==
                                                widget.currentResult
                                                    ?.title &&
                                            result.year ==
                                                widget.currentResult
                                                    ?.year));

                            final subtitle = [
                              result.type == 'episode'
                                  ? 'TV Show'
                                  : 'Movie',
                              if (result.year != null) '${result.year}',
                              if (result.rating != null)
                                '\u2605 ${result.rating!.toStringAsFixed(1)}',
                              if (result.genres != null &&
                                  result.genres!.isNotEmpty)
                                result.genres!.take(2).join(', '),
                            ].join(' \u2022 ');

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: result.posterUrl != null &&
                                        result.posterUrl!
                                            .startsWith('http')
                                    ? Image.network(
                                        result.posterUrl!,
                                        width: 40,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                          width: 40,
                                          height: 56,
                                          child: Icon(Icons.movie),
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 40,
                                        height: 56,
                                        child: Icon(Icons.movie),
                                      ),
                              ),
                              title: Text(
                                result.title ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight:
                                      isSelected ? FontWeight.bold : null,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: settings.accentColor)
                                  : const Icon(Icons.chevron_right),
                              onTap: () {
                                widget.onSelected(result);
                                Navigator.pop(context);
                              },
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
