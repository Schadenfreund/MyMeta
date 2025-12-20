import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';

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
                              child: widget.initialResult.coverBytes != null
                                  ? Image.memory(
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      onPressed: () async {
                        var res = await FilePicker.platform
                            .pickFiles(type: FileType.image);
                        if (res != null) {
                          setState(() {
                            _posterUrlController.text = res.files.single.path!;
                          });
                        }
                      },
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text("Select Image"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _posterUrlController,
                      decoration: const InputDecoration(
                        hintText: "Or paste URL...",
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (_) => setState(() {}),
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

          // Action Buttons - Simplified: Cancel or Apply & Rename
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _isProcessing ? null : widget.onCancel,
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
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

                          List<String>? genres =
                              _genresController.text.isNotEmpty
                                  ? _genresController.text
                                      .split(',')
                                      .map((g) => g.trim())
                                      .where((g) => g.isNotEmpty)
                                      .toList()
                                  : null;

                          List<String>? actors =
                              _actorsController.text.isNotEmpty
                                  ? _actorsController.text
                                      .split(',')
                                      .map((a) => a.trim())
                                      .where((a) => a.isNotEmpty)
                                      .toList()
                                  : null;

                          final result = MatchResult(
                            newName: newName,
                            posterUrl: poster,
                            coverBytes: widget.initialResult.coverBytes,
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
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_isProcessing ? "Processing..." : "Apply & Rename"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
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
