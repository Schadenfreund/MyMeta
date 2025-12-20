import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/match_result.dart';
import '../backend/core_backend.dart';
import '../services/settings_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';

class EditMetadataDialog extends StatefulWidget {
  final String originalName;
  final MatchResult initialResult;
  final Function(MatchResult) onSave;

  const EditMetadataDialog({
    super.key,
    required this.originalName,
    required this.initialResult,
    required this.onSave,
  });

  @override
  State<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<EditMetadataDialog> {
  late TextEditingController _nameController;
  late TextEditingController _posterUrlController;

  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _seasonController;
  late TextEditingController _episodeController;
  late TextEditingController _episodeTitleController;

  // Extended metadata controllers
  late TextEditingController _descriptionController;
  late TextEditingController _genresController;
  late TextEditingController _directorController;
  late TextEditingController _actorsController;
  late TextEditingController _ratingController;
  late TextEditingController _contentRatingController;
  late TextEditingController _runtimeController;

  String _type = 'movie';

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

    // Extended metadata
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

  @override
  Widget build(BuildContext context) {
    // Premium Design Layout
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Edit Metadata",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ],
            ),
            const SizedBox(height: 8),
            Text("Original File: ${widget.originalName}",
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),

            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Cover Image & Type
                  SizedBox(
                    width: 250,
                    child: Column(
                      children: [
                        // Type Selector
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _buildTypeButton("Movie", "movie")),
                              Expanded(
                                  child:
                                      _buildTypeButton("Episode", "episode")),
                            ],
                          ),
                        ),

                        // Cover Drop Zone
                        AspectRatio(
                          aspectRatio: 2 / 3,
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
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                        style: BorderStyle.solid),
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8)),
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
                                                return const Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.broken_image,
                                                          size: 48,
                                                          color: Colors.grey),
                                                      SizedBox(height: 8),
                                                      Text("Image Error",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey)),
                                                    ],
                                                  ),
                                                );
                                              },
                                            )
                                          : const Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .add_photo_alternate_outlined,
                                                      size: 48,
                                                      color: Colors.grey),
                                                  SizedBox(height: 8),
                                                  Text("Drop Cover Here",
                                                      style: TextStyle(
                                                          color: Colors.grey)),
                                                ],
                                              ),
                                            )),
                                )),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Import Button
                        ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            onPressed: () async {
                              var res = await FilePicker.platform
                                  .pickFiles(type: FileType.image);
                              if (res != null) {
                                setState(() {
                                  _posterUrlController.text =
                                      res.files.single.path!;
                                });
                              }
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Select File")),
                        const SizedBox(height: 8),

                        // Find Alternative Covers Button
                        OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            onPressed: _findAlternativeCovers,
                            icon: const Icon(Icons.image_search),
                            label: const Text("Find Alternative Covers")),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Column: Metadata Fields
                  Expanded(
                      child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Metadata",
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: _buildTextField(
                                    _titleController,
                                    _type == 'episode'
                                        ? "Series Name"
                                        : "Movie Title")),
                            const SizedBox(width: 12),
                            Expanded(
                                flex: 1,
                                child:
                                    _buildTextField(_yearController, "Year")),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_type == 'episode') ...[
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTextField(
                                      _seasonController, "Season")),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildTextField(
                                      _episodeController, "Episode")),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                              _episodeTitleController, "Episode Title"),
                          const SizedBox(height: 24),
                        ],

                        const Divider(),
                        const SizedBox(height: 16),

                        // Extended Metadata Section
                        Text("Extended Metadata",
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 16),

                        // Description
                        TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                              labelText: "Description / Plot",
                              labelStyle:
                                  TextStyle(color: Theme.of(context).hintColor),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16)),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),

                        // Genres
                        _buildTextField(_genresController, "Genres",
                            hint: "Action, Drama, Sci-Fi"),
                        const SizedBox(height: 12),

                        // Rating and Content Rating Row
                        Row(
                          children: [
                            Expanded(
                                child: _buildTextField(
                                    _ratingController, "Rating",
                                    hint: "7.5")),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    _contentRatingController, "Content Rating",
                                    hint: "PG-13")),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Director and Runtime (for movies)
                        if (_type == 'movie') ...[
                          Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                      _directorController, "Director")),
                              const SizedBox(width: 12),
                              Expanded(
                                  flex: 1,
                                  child: _buildTextField(
                                      _runtimeController, "Runtime (min)",
                                      hint: "142")),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Actors/Cast
                        _buildTextField(_actorsController, "Cast / Actors",
                            hint: "Actor 1, Actor 2, Actor 3"),
                        const SizedBox(height: 24),

                        const Divider(),
                        const SizedBox(height: 16),

                        // Output Section
                        Row(
                          children: [
                            const Text("Output Filename",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            TextButton.icon(
                                onPressed: _regenerateName,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text("Regenerate"))
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Theme.of(context).cardColor),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ))
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16)),
                    child: const Text("Cancel")),
                const SizedBox(width: 12),
                ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16)),
                    child: const Text("Save Changes",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)))
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    bool selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 4)
                    ]
                  : []),
          child: Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant))),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Theme.of(context).hintColor),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
    );
  }

  Future<void> _findAlternativeCovers() async {
    SnackbarHelper.showInfo(
      context,
      'Alternative cover search coming soon! Drag and drop an image file onto the cover area.',
    );
  }

  void _save() {
    String newName = _nameController.text;
    String? poster =
        _posterUrlController.text.isEmpty ? null : _posterUrlController.text;

    // Parse genres and actors from comma-separated strings
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

    widget.onSave(MatchResult(
      newName: newName,
      posterUrl: poster,
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
    ));
    Navigator.pop(context);
  }
}
