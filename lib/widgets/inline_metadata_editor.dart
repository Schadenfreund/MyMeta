import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'cover_picker_modal.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io';

class InlineMetadataEditor extends StatefulWidget {
  final String originalName;
  final MatchResult initialResult;
  final Function(MatchResult) onSave;
  final VoidCallback onCancel;
  final Future<void> Function(MatchResult)?
      onRename; // Receives result directly

  const InlineMetadataEditor({
    super.key,
    required this.originalName,
    required this.initialResult,
    required this.onSave,
    required this.onCancel,
    this.onRename,
  });

  @override
  State<InlineMetadataEditor> createState() => _InlineMetadataEditorState();
}

class _InlineMetadataEditorState extends State<InlineMetadataEditor> {
  late TextEditingController _nameController;
  late TextEditingController _posterUrlController;
  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _seasonController;
  late TextEditingController _episodeController;
  late TextEditingController _episodeTitleController;
  late TextEditingController _descriptionController;
  late TextEditingController _genresController;
  late TextEditingController _directorController;
  late TextEditingController _actorsController;
  late TextEditingController _ratingController;
  late TextEditingController _contentRatingController;
  late TextEditingController _runtimeController;

  String _type = 'movie';
  bool _isProcessing = false; // Prevents double-clicking
  Uint8List? _updatedCoverBytes; // Stores new cover when user changes it

  @override
  void initState() {
    super.initState();
    final res = widget.initialResult;
    _nameController = TextEditingController(text: res.newName);
    _posterUrlController = TextEditingController(text: res.posterUrl ?? "");
    _titleController = TextEditingController(text: res.title ?? "");
    _yearController = TextEditingController(text: res.year?.toString() ?? "");
    _seasonController =
        TextEditingController(text: res.season?.toString() ?? "");
    _episodeController =
        TextEditingController(text: res.episode?.toString() ?? "");
    _episodeTitleController =
        TextEditingController(text: res.episodeTitle ?? "");
    _descriptionController = TextEditingController(text: res.description ?? "");
    _genresController =
        TextEditingController(text: res.genres?.join(', ') ?? "");
    _directorController = TextEditingController(text: res.director ?? "");
    _actorsController =
        TextEditingController(text: res.actors?.join(', ') ?? "");
    _ratingController =
        TextEditingController(text: res.rating?.toString() ?? "");
    _contentRatingController =
        TextEditingController(text: res.contentRating ?? "");
    _runtimeController =
        TextEditingController(text: res.runtime?.toString() ?? "");

    _type = res.type ?? 'movie';
  }

  @override
  void didUpdateWidget(InlineMetadataEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialResult != oldWidget.initialResult) {
      final res = widget.initialResult;
      // Update all controllers with new values
      _nameController.text = res.newName;
      _posterUrlController.text = res.posterUrl ?? "";
      _titleController.text = res.title ?? "";
      _yearController.text = res.year?.toString() ?? "";
      _seasonController.text = res.season?.toString() ?? "";
      _episodeController.text = res.episode?.toString() ?? "";
      _episodeTitleController.text = res.episodeTitle ?? "";
      _descriptionController.text = res.description ?? "";
      _genresController.text = res.genres?.join(', ') ?? "";
      _directorController.text = res.director ?? "";
      _actorsController.text = res.actors?.join(', ') ?? "";
      _ratingController.text = res.rating?.toString() ?? "";
      _contentRatingController.text = res.contentRating ?? "";
      _runtimeController.text = res.runtime?.toString() ?? "";

      // Also update internal state if needed
      if ((res.type == 'movie' || res.type == 'episode') && res.type != _type) {
        setState(() {
          _type = res.type!;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _posterUrlController.dispose();
    _titleController.dispose();
    _yearController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
    _episodeTitleController.dispose();
    _descriptionController.dispose();
    _genresController.dispose();
    _directorController.dispose();
    _actorsController.dispose();
    _ratingController.dispose();
    _contentRatingController.dispose();
    _runtimeController.dispose();
    super.dispose();
  }

  void _regenerateName() {
    final settings = context.read<SettingsService>();
    String format =
        (_type == 'episode') ? settings.seriesFormat : settings.movieFormat;

    Map<String, dynamic> contextData = {};

    if (_type == 'episode') {
      contextData = {
        "series_name": _titleController.text,
        "year": int.tryParse(_yearController.text),
        "season_number":
            int.tryParse(_seasonController.text)?.toString().padLeft(2, '0') ??
                "00",
        "episode_number":
            int.tryParse(_episodeController.text)?.toString().padLeft(2, '0') ??
                "00",
        "episode_title": _episodeTitleController.text,
      };
    } else {
      contextData = {
        "movie_name": _titleController.text,
        "year": int.tryParse(_yearController.text),
      };
    }

    String extension = "";
    if (_nameController.text.contains('.')) {
      extension = _nameController.text.split('.').last;
    } else {
      if (widget.originalName.contains('.')) {
        extension = widget.originalName.split('.').last;
      }
    }

    String newName = CoreBackend.createFormattedTitle(format, contextData);
    if (extension.isNotEmpty) {
      newName += ".$extension";
    }

    setState(() {
      _nameController.text = newName;
    });
  }

  /// Paste image URL or path from clipboard
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      final text = clipboardData.text!.trim();
      // Check if it's a URL or a file path
      if (text.startsWith('http') ||
          text.startsWith('https') ||
          text.contains('\\') ||
          text.contains('/')) {
        setState(() {
          _posterUrlController.text = text;
        });
      }
    }
  }

  /// Show context menu for cover art
  void _showCoverContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.paste, size: 18),
              SizedBox(width: 8),
              Text('Paste Image URL'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.clear, size: 18),
              SizedBox(width: 8),
              Text('Clear Image'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'paste') {
        _pasteFromClipboard();
      } else if (value == 'clear') {
        setState(() {
          _posterUrlController.text = '';
        });
      }
    });
  }

  bool _isMetadataSuccessful() {
    // Check if online metadata search was successful by looking for key fields
    return widget.initialResult.title != null &&
        (widget.initialResult.title!.isNotEmpty) &&
        (widget.initialResult.year != null ||
            widget.initialResult.genres != null ||
            widget.initialResult.posterUrl != null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Type Selector
          Row(
            children: [
              Expanded(
                child: Text(
                  "Edit Metadata",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // Type Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypeButton("Movie", "movie"),
                    const SizedBox(width: 4),
                    _buildTypeButton("Episode", "episode"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Cover Image
              SizedBox(
                width: 180,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: GestureDetector(
                        onSecondaryTapUp: (details) {
                          _showCoverContextMenu(
                              context, details.globalPosition);
                        },
                        child: DropTarget(
                          onDragDone: (detail) {
                            if (detail.files.isNotEmpty) {
                              setState(() {
                                _posterUrlController.text =
                                    detail.files.first.path;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (_updatedCoverBytes != null ||
                                      widget.initialResult.coverBytes != null)
                                  ? Image.memory(
                                      _updatedCoverBytes ??
                                          widget.initialResult.coverBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : (_posterUrlController.text.isNotEmpty
                                      ? Image.network(
                                          _posterUrlController.text,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder:
                                              (context, error, stack) {
                                            return Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.broken_image,
                                                    size: 40,
                                                    color: Colors.grey),
                                                SizedBox(height: 8),
                                                Text("Image Error",
                                                    style: TextStyle(
                                                        color: Colors.grey)),
                                              ],
                                            );
                                          },
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 40,
                                                color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text("Drop Image",
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                          ],
                                        )),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Select Image',
                          icon: const Icon(Icons.upload_file),
                          onPressed: () async {
                            var res = await FilePicker.platform
                                .pickFiles(type: FileType.image);
                            if (res != null && res.files.single.path != null) {
                              final path = res.files.single.path!;
                              setState(() {
                                _posterUrlController.text = path;
                              });

                              // Load file bytes for local file
                              try {
                                final file = File(path);
                                if (file.existsSync()) {
                                  final bytes = await file.readAsBytes();
                                  setState(() {
                                    _updatedCoverBytes = bytes;
                                  });
                                  debugPrint(
                                      "✅ Local cover loaded (${bytes.length} bytes)");

                                  // Update the MatchResult immediately so thumbnail updates
                                  final updatedResult = MatchResult(
                                    newName: widget.initialResult.newName,
                                    posterUrl: path,
                                    coverBytes: bytes,
                                    title: widget.initialResult.title,
                                    year: widget.initialResult.year,
                                    season: widget.initialResult.season,
                                    episode: widget.initialResult.episode,
                                    episodeTitle:
                                        widget.initialResult.episodeTitle,
                                    type: widget.initialResult.type,
                                    description:
                                        widget.initialResult.description,
                                    genres: widget.initialResult.genres,
                                    director: widget.initialResult.director,
                                    actors: widget.initialResult.actors,
                                    rating: widget.initialResult.rating,
                                    contentRating:
                                        widget.initialResult.contentRating,
                                    studio: widget.initialResult.studio,
                                    runtime: widget.initialResult.runtime,
                                    imdbId: widget.initialResult.imdbId,
                                    tmdbId: widget.initialResult.tmdbId,
                                    alternativePosterUrls: widget
                                        .initialResult.alternativePosterUrls,
                                    searchResults:
                                        widget.initialResult.searchResults,
                                  );
                                  widget.onSave(updatedResult);
                                }
                              } catch (e) {
                                debugPrint(
                                    "⚠️  Failed to load local cover: $e");
                              }
                            }
                          },
                        ),
                        if (widget.initialResult.alternativePosterUrls !=
                                null &&
                            widget.initialResult.alternativePosterUrls!
                                .isNotEmpty)
                          IconButton(
                            tooltip: 'Choose Cover',
                            icon: const Icon(Icons.image_search),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => CoverPickerModal(
                                  posterUrls: widget
                                      .initialResult.alternativePosterUrls!,
                                  currentPosterUrl: _posterUrlController.text,
                                  onSelected: (url) async {
                                    // Download new cover immediately
                                    setState(() {
                                      _posterUrlController.text = url;
                                      _updatedCoverBytes =
                                          null; // Clear old bytes
                                    });

                                    if (url.startsWith('http')) {
                                      try {
                                        final response =
                                            await http.get(Uri.parse(url));
                                        if (response.statusCode == 200 &&
                                            mounted) {
                                          setState(() {
                                            _updatedCoverBytes =
                                                response.bodyBytes;
                                          });
                                          debugPrint(
                                              "✅ New cover downloaded (${response.bodyBytes.length} bytes)");

                                          // Update the MatchResult immediately so thumbnail updates
                                          final updatedResult = MatchResult(
                                            newName:
                                                widget.initialResult.newName,
                                            posterUrl: url,
                                            coverBytes: response.bodyBytes,
                                            title: widget.initialResult.title,
                                            year: widget.initialResult.year,
                                            season: widget.initialResult.season,
                                            episode:
                                                widget.initialResult.episode,
                                            episodeTitle: widget
                                                .initialResult.episodeTitle,
                                            type: widget.initialResult.type,
                                            description: widget
                                                .initialResult.description,
                                            genres: widget.initialResult.genres,
                                            director:
                                                widget.initialResult.director,
                                            actors: widget.initialResult.actors,
                                            rating: widget.initialResult.rating,
                                            contentRating: widget
                                                .initialResult.contentRating,
                                            studio: widget.initialResult.studio,
                                            runtime:
                                                widget.initialResult.runtime,
                                            imdbId: widget.initialResult.imdbId,
                                            tmdbId: widget.initialResult.tmdbId,
                                            alternativePosterUrls: widget
                                                .initialResult
                                                .alternativePosterUrls,
                                            searchResults: widget
                                                .initialResult.searchResults,
                                          );
                                          widget.onSave(updatedResult);
                                        }
                                      } catch (e) {
                                        debugPrint(
                                            "⚠️  Failed to download new cover: $e");
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        if (widget.initialResult.searchResults != null &&
                            widget.initialResult.searchResults!.isNotEmpty)
                          IconButton(
                            tooltip: 'Choose Match',
                            icon: const Icon(Icons.compare_arrows),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => SearchResultsPickerModal(
                                  searchResults:
                                      widget.initialResult.searchResults!,
                                  currentResult: widget.initialResult,
                                  onSelected: (selectedResult) {
                                    setState(() {
                                      _titleController.text =
                                          selectedResult.title ?? "";
                                      _yearController.text =
                                          selectedResult.year?.toString() ?? "";
                                      _seasonController.text =
                                          selectedResult.season?.toString() ??
                                              "";
                                      _episodeController.text =
                                          selectedResult.episode?.toString() ??
                                              "";
                                      _episodeTitleController.text =
                                          selectedResult.episodeTitle ?? "";
                                      _descriptionController.text =
                                          selectedResult.description ?? "";
                                      _genresController.text =
                                          selectedResult.genres?.join(', ') ??
                                              "";
                                      _directorController.text =
                                          selectedResult.director ?? "";
                                      _actorsController.text =
                                          selectedResult.actors?.join(', ') ??
                                              "";
                                      _ratingController.text =
                                          selectedResult.rating?.toString() ??
                                              "";
                                      _contentRatingController.text =
                                          selectedResult.contentRating ?? "";
                                      _runtimeController.text =
                                          selectedResult.runtime?.toString() ??
                                              "";
                                      _posterUrlController.text =
                                          selectedResult.posterUrl ?? "";
                                      _type = selectedResult.type ?? 'movie';
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Right: Metadata Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              _titleController,
                              _type == 'episode'
                                  ? "Series Name"
                                  : "Movie Title",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(_yearController, "Year"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Episode-specific fields
                      if (_type == 'episode') ...[
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _buildTextField(_seasonController, "Season"),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                  _episodeController, "Episode"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                            _episodeTitleController, "Episode Title"),
                        const SizedBox(height: 12),
                      ],

                      // Description
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: "Description",
                          hintText: "Plot summary...",
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),

                      // Metadata Row 1
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              _genresController,
                              "Genres",
                              hint: "Action, Drama",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              _ratingController,
                              "Rating",
                              hint: "7.5",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              _contentRatingController,
                              "Rating",
                              hint: "PG-13",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Movie-specific: Director & Runtime
                      if (_type == 'movie') ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                _directorController,
                                "Director",
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                _runtimeController,
                                "Runtime (min)",
                                hint: "142",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Cast
                      _buildTextField(
                        _actorsController,
                        "Cast",
                        hint: "Actor 1, Actor 2",
                      ),
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 12),

                      // Output Filename
                      Row(
                        children: [
                          const Text(
                            "Output Filename",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _regenerateName,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Regenerate"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          filled: true,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Rename icon button
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              tooltip: 'Rename',
              icon: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      Icons.done,
                      color: _isMetadataSuccessful()
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      // Prevent double-clicks
                      if (_isProcessing) return;
                      setState(() => _isProcessing = true);

                      try {
                        // Build the result first
                        String newName = _nameController.text;
                        String? poster = _posterUrlController.text.isEmpty
                            ? null
                            : _posterUrlController.text;

                        List<String>? genres = _genresController.text.isNotEmpty
                            ? _genresController.text
                                .split(',')
                                .map((g) => g.trim())
                                .where((g) => g.isNotEmpty)
                                .toList()
                            : null;

                        List<String>? actors = _actorsController.text.isNotEmpty
                            ? _actorsController.text
                                .split(',')
                                .map((a) => a.trim())
                                .where((a) => a.isNotEmpty)
                                .toList()
                            : null;

                        final result = MatchResult(
                          newName: newName,
                          posterUrl: poster,
                          coverBytes: _updatedCoverBytes ??
                              widget.initialResult.coverBytes,
                          title: _titleController.text,
                          year: int.tryParse(_yearController.text),
                          season: int.tryParse(_seasonController.text),
                          episode: int.tryParse(_episodeController.text),
                          episodeTitle: _episodeTitleController.text,
                          type: _type,
                          description: _descriptionController.text.isEmpty
                              ? null
                              : _descriptionController.text,
                          genres: genres,
                          director: _directorController.text.isEmpty
                              ? null
                              : _directorController.text,
                          actors: actors,
                          rating: double.tryParse(_ratingController.text),
                          contentRating: _contentRatingController.text.isEmpty
                              ? null
                              : _contentRatingController.text,
                          runtime: int.tryParse(_runtimeController.text),
                          studio: widget.initialResult.studio,
                          imdbId: widget.initialResult.imdbId,
                          tmdbId: widget.initialResult.tmdbId,
                          alternativePosterUrls:
                              widget.initialResult.alternativePosterUrls,
                          searchResults: widget.initialResult.searchResults,
                        );

                        // Save first, then rename with the result
                        widget.onSave(result);
                        if (widget.onRename != null) {
                          await widget.onRename!(result);
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessing = false);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    bool selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
