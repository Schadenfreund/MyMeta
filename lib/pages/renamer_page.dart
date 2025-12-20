import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/settings_service.dart';
import '../services/file_state_service.dart';
import '../backend/media_record.dart';
import '../backend/match_result.dart';
import '../widgets/inline_metadata_editor.dart';
import 'package:path/path.dart' as p;

class RenamerPage extends StatefulWidget {
  const RenamerPage({super.key});

  @override
  State<RenamerPage> createState() => _RenamerPageState();
}

class _RenamerPageState extends State<RenamerPage> {
  int? _expandedIndex;

  Future<void> _pickFiles(BuildContext context) async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      List<XFile> xFiles = result.paths.map((path) => XFile(path!)).toList();
      context.read<FileStateService>().addFiles(xFiles);
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileState = context.watch<FileStateService>();
    final settings = context.watch<SettingsService>();

    return Column(
      children: [
        // Toolbar - Clean & Integrated
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Primary Actions
              ElevatedButton.icon(
                onPressed: () => _pickFiles(context),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text("Add Files"),
              ),

              if (fileState.isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: fileState.inputFiles.isEmpty
                      ? null
                      : () => fileState.matchFiles(settings),
                  icon: const Icon(Icons.search),
                  label: const Text("Match"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (!fileState.isLoading &&
                        fileState.inputFiles.isNotEmpty &&
                        fileState.matchResults.isNotEmpty &&
                        !fileState.inputFiles.every((f) => f.isRenamed))
                    ? () {
                        setState(() => _expandedIndex = null);
                        fileState.renameFiles();
                      }
                    : null,
                icon: const Icon(Icons.drive_file_rename_outline, size: 20),
                label: const Text("Rename Files"),
              ),

              const Spacer(),

              // Secondary Actions
              if (fileState.canUndo) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _expandedIndex = null);
                    fileState.undo();
                  },
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text("Undo"),
                ),
                const SizedBox(width: 8),
              ],
              if (fileState.inputFiles.any((f) => f.isRenamed)) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() => _expandedIndex = null);
                    fileState.clearRenamedFiles();
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text("Clear Finished"),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (fileState.inputFiles.isNotEmpty)
                TextButton.icon(
                  onPressed: () => fileState.clearAll(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Clear All"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                ),
            ],
          ),
        ),

        // Main List
        Expanded(
          child: DropTarget(
            onDragDone: (detail) {
              context.read<FileStateService>().addFiles(detail.files);
            },
            child: fileState.inputFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.file_upload_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Drop files here or click Add Files",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Supported formats: MP4, MKV",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: fileState.inputFiles.length,
                    itemBuilder: (context, index) {
                      final input = fileState.inputFiles[index];
                      MatchResult? output;
                      if (index < fileState.matchResults.length) {
                        output = fileState.matchResults[index];
                      }

                      bool isRenamed = input.isRenamed;
                      bool isExpanded = _expandedIndex == index;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFileCard(
                          context,
                          index,
                          input,
                          output,
                          isRenamed,
                          isExpanded,
                          fileState,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    int index,
    MediaRecord input,
    MatchResult? output,
    bool isRenamed,
    bool isExpanded,
    FileStateService fileState,
  ) {
    return Card(
      elevation: isExpanded ? 2 : 0,
      color: isRenamed
          ? const Color(0xFF10B981).withOpacity(0.1)
          : Theme.of(context).cardColor,
      child: Column(
        children: [
          // Main Row
          InkWell(
            onTap: () => _toggleExpanded(index), // Always allow editing
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Expand Icon
                  if (!isRenamed)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  if (isRenamed)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: const Color(0xFF10B981),
                    ),
                  const SizedBox(width: 12),

                  // Cover Image Thumbnail
                  if (output?.posterUrl != null)
                    Container(
                      width: 40,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: output!.posterUrl!.startsWith('http')
                              ? NetworkImage(output.posterUrl!)
                              : FileImage(File(output.posterUrl!))
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // File Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          input.fileName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration:
                                isRenamed ? TextDecoration.lineThrough : null,
                            color: isRenamed
                                ? Colors.grey
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (output != null)
                          Text(
                            _buildMetadataPreview(output),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          const Text(
                            "Click to add metadata manually or Match to auto-fetch",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Arrow Icon / Status
                  const SizedBox(width: 12),
                  Icon(
                    isRenamed ? Icons.check : Icons.arrow_forward,
                    color: isRenamed
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade400,
                  ),

                  const SizedBox(width: 12),

                  // Output Name
                  Expanded(
                    child: Text(
                      isRenamed
                          ? p.basename(input.renamedPath!)
                          : (output?.newName ?? "Pending..."),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isRenamed
                            ? const Color(0xFF10B981)
                            : Theme.of(context).colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade600,
                    onPressed: () {
                      if (isExpanded) _toggleExpanded(index);
                      fileState.removeFileAt(index);
                    },
                    tooltip: "Remove",
                  ),
                ],
              ),
            ),
          ),

          // Expanded Metadata Editor - Works Always!
          if (isExpanded)
            InlineMetadataEditor(
              originalName: input.fileName,
              initialResult: output ?? MatchResult(newName: input.fileName),
              onSave: (newResult) {
                fileState.updateManualMatch(index, newResult);
                _toggleExpanded(index);
              },
              onCancel: () => _toggleExpanded(index),
            ),
        ],
      ),
    );
  }

  String _buildMetadataPreview(MatchResult output) {
    if (output.type == 'episode') {
      return "${output.title} • S${output.season?.toString().padLeft(2, '0')}E${output.episode?.toString().padLeft(2, '0')} • ${output.year ?? ''}";
    } else {
      return "${output.title} • ${output.year ?? ''} • ${output.genres?.take(2).join(', ') ?? ''}";
    }
  }
}
