import 'package:flutter/material.dart';
import '../backend/match_result.dart';

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
                                    color: Theme.of(context).colorScheme.primary,
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
class SearchResultsPickerModal extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),
            const Divider(height: 1),
            // List of search results
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  final isSelected =
                      result.tmdbId == currentResult?.tmdbId ||
                      result.imdbId == currentResult?.imdbId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
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
                                errorBuilder: (context, error, stackTrace) {
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
                              child: const Icon(Icons.image_not_supported),
                            ),
                      title: Text(
                        result.title ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
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
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        onSelected(result);
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
      parts.add('⭐ ${result.rating}');
    }

    return parts.join(' • ');
  }
}
