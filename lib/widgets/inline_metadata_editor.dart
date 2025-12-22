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
  final VoidCallback? onSearch; // Triggers online search

  const InlineMetadataEditor({
    super.key,
    required this.originalName,
    required this.initialResult,
    required this.onSave,
    required this.onCancel,
    this.onRename,
    this.onSearch,
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

    // Smart type detection
    _type = _detectContentType(res);

    // Add listeners to auto-save changes
    _titleController.addListener(_saveChanges);
    _yearController.addListener(_saveChanges);
    _seasonController.addListener(_saveChanges);
    _episodeController.addListener(_saveChanges);
    _episodeTitleController.addListener(_saveChanges);
    _descriptionController.addListener(_saveChanges);
    _genresController.addListener(_saveChanges);
    _directorController.addListener(_saveChanges);
    _actorsController.addListener(_saveChanges);
  }

  /// Saves current editor state to parent
  void _saveChanges() {
    if (!mounted) return;

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
      newName: _nameController.text,
      posterUrl:
          _posterUrlController.text.isEmpty ? null : _posterUrlController.text,
      coverBytes: _updatedCoverBytes ?? widget.initialResult.coverBytes,
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
      director:
          _directorController.text.isEmpty ? null : _directorController.text,
      actors: actors,
      rating: double.tryParse(_ratingController.text),
      contentRating: _contentRatingController.text.isEmpty
          ? null
          : _contentRatingController.text,
      runtime: int.tryParse(_runtimeController.text),
      studio: widget.initialResult.studio,
      imdbId: widget.initialResult.imdbId,
      tmdbId: widget.initialResult.tmdbId,
      alternativePosterUrls: widget.initialResult.alternativePosterUrls,
      searchResults: widget.initialResult.searchResults,
    );

    widget.onSave(result);
  }

  /// Detects if content is Movie or TV Show based on available data
  String _detectContentType(MatchResult res) {
    // Priority 1: Has season/episode data => TV Show
    if (res.season != null && res.episode != null) {
      return 'episode';
    }

    // Priority 2: Check filename for TV patterns (S##E##, episode, etc.)
    String filename = widget.originalName.toLowerCase();
    if (RegExp(r's\d{1,2}e\d{1,2}').hasMatch(filename) ||
        RegExp(r'\d{1,2}x\d{1,2}').hasMatch(filename) ||
        filename.contains('episode') ||
        filename.contains('season')) {
      return 'episode';
    }

    // Priority 3: Use stored type if available
    if (res.type != null && res.type!.isNotEmpty) {
      return res.type!;
    }

    // Default: Movie
    return 'movie';
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

      // Reset cover bytes so it uses new data from search
      _updatedCoverBytes = null;

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
              Icon(Icons.content_paste, size: 18),
              SizedBox(width: 8),
              Text('Paste Image'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'pick',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18),
              SizedBox(width: 8),
              Text('Choose File...'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'gallery',
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 18),
              SizedBox(width: 8),
              Text('Browse Gallery'),
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
        _pasteImageFromClipboard();
      } else if (value == 'pick') {
        _pickCustomImage();
      } else if (value == 'gallery') {
        _openCoverGallery();
      } else if (value == 'clear') {
        setState(() {
          _posterUrlController.text = '';
          _updatedCoverBytes = null;
        });
        _saveChanges();
      }
    });
  }

  /// Paste image from clipboard
  Future<void> _pasteImageFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final url = data.text!.trim();
        if (url.startsWith('http')) {
          setState(() => _posterUrlController.text = url);
          // Download the image
          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200 && mounted) {
              setState(() => _updatedCoverBytes = response.bodyBytes);
              _saveChanges();
            }
          } catch (e) {
            debugPrint("⚠️  Failed to download pasted URL: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️  Failed to paste from clipboard: $e");
    }
  }

  /// Pick custom image from file system
  Future<void> _pickCustomImage() async {
    var res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res != null && res.files.single.path != null) {
      final path = res.files.single.path!;
      try {
        final file = File(path);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _posterUrlController.text = path;
            _updatedCoverBytes = bytes;
          });
          _saveChanges();
        }
      } catch (e) {
        debugPrint("⚠️  Failed to load custom image: $e");
      }
    }
  }

  /// Open cover gallery dialog
  void _openCoverGallery() {
    if (widget.initialResult.alternativePosterUrls != null &&
        widget.initialResult.alternativePosterUrls!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => CoverPickerModal(
          posterUrls: widget.initialResult.alternativePosterUrls!,
          currentPosterUrl: _posterUrlController.text,
          onSelected: (url) async {
            setState(() {
              _posterUrlController.text = url;
              _updatedCoverBytes = null;
            });
            if (url.startsWith('http')) {
              try {
                final response = await http.get(Uri.parse(url));
                if (response.statusCode == 200 && mounted) {
                  setState(() => _updatedCoverBytes = response.bodyBytes);
                  _saveChanges();
                }
              } catch (e) {
                debugPrint("⚠️  Failed to download cover: $e");
              }
            }
          },
        ),
      );
    } else {
      widget.onSearch?.call();
    }
  }

  /// Open search results dialog
  void _openSearchResults() {
    if (widget.initialResult.searchResults != null &&
        widget.initialResult.searchResults!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => SearchResultsPickerModal(
          searchResults: widget.initialResult.searchResults!,
          currentResult: widget.initialResult,
          onSelected: (selectedResult) {
            setState(() {
              _titleController.text = selectedResult.title ?? "";
              _yearController.text = selectedResult.year?.toString() ?? "";
              _seasonController.text = selectedResult.season?.toString() ?? "";
              _episodeController.text =
                  selectedResult.episode?.toString() ?? "";
              _episodeTitleController.text = selectedResult.episodeTitle ?? "";
              _descriptionController.text = selectedResult.description ?? "";
              _genresController.text = selectedResult.genres?.join(', ') ?? "";
              _directorController.text = selectedResult.director ?? "";
              _actorsController.text = selectedResult.actors?.join(', ') ?? "";
              _ratingController.text = selectedResult.rating?.toString() ?? "";
              _contentRatingController.text =
                  selectedResult.contentRating ?? "";
              _runtimeController.text =
                  selectedResult.runtime?.toString() ?? "";
              _posterUrlController.text = selectedResult.posterUrl ?? "";
              _type = selectedResult.type ?? 'movie';
            });
          },
        ),
      );
    } else {
      widget.onSearch?.call();
    }
  }

  /// Build no cover placeholder
  Widget _buildNoCoverPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
        const SizedBox(height: 8),
        Text("Click or Drop Image",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: settings.accentColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Type Selector
          Row(
            children: [
              Text(
                "Edit Metadata",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: settings.accentColor,
                ),
              ),
              const Spacer(),
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
                    _buildTypeButton("TV Show", "episode"),
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
                        onTap: () => _openCoverGallery(),
                        onSecondaryTapUp: (details) {
                          _showCoverContextMenu(
                              context, details.globalPosition);
                        },
                        child: DropTarget(
                          onDragDone: (detail) async {
                            if (detail.files.isNotEmpty) {
                              final path = detail.files.first.path;
                              try {
                                final file = File(path);
                                if (file.existsSync()) {
                                  final bytes = await file.readAsBytes();
                                  setState(() {
                                    _posterUrlController.text = path;
                                    _updatedCoverBytes = bytes;
                                  });
                                  _saveChanges();
                                }
                              } catch (e) {
                                debugPrint(
                                    "⚠️  Failed to load dropped image: $e");
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: settings.accentColor.withOpacity(0.2),
                              ),
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
                                              (context, error, stack) =>
                                                  _buildNoCoverPlaceholder(),
                                        )
                                      : _buildNoCoverPlaceholder()),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Centered action icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.image_outlined,
                              color: settings.accentColor),
                          tooltip: 'Custom Image',
                          onPressed: () => _pickCustomImage(),
                        ),
                        IconButton(
                          icon: Icon(Icons.photo_library_outlined,
                              color: settings.accentColor),
                          tooltip: 'Gallery',
                          onPressed: () => _openCoverGallery(),
                        ),
                        IconButton(
                          icon: Icon(Icons.manage_search,
                              color: settings.accentColor),
                          tooltip: 'Fix Match',
                          onPressed: () => _openSearchResults(),
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
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    bool selected = _type == value;
    IconData icon = value == 'movie' ? Icons.movie_outlined : Icons.tv_outlined;
    Color accentColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: accentColor, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? accentColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? accentColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
