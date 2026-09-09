import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/transfer_server.dart';
import '../theme/app_theme.dart';

class DragDropStagingZone extends StatefulWidget {
  final List<StagedFile> stagedFiles;
  final Function(String path) onFileAdded;
  final Function(String id) onFileRemoved;
  final VoidCallback onClearAll;

  const DragDropStagingZone({
    super.key,
    required this.stagedFiles,
    required this.onFileAdded,
    required this.onFileRemoved,
    required this.onClearAll,
  });

  @override
  State<DragDropStagingZone> createState() => _DragDropStagingZoneState();
}

class _DragDropStagingZoneState extends State<DragDropStagingZone> {
  bool _isDraggingOver = false;
  bool _isPicking = false;

  Future<void> _pickFiles() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final files = await FilePicker.pickFiles(
        allowMultiple: true,
        dialogTitle: 'Select files to share',
      );

      if (files.isEmpty) return;

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        String? resolvedPath;

        // 1. Direct path check (Desktop / local direct path)
        if (file.path != null && file.path!.isNotEmpty && await File(file.path!).exists()) {
          resolvedPath = file.path!;
        } else {
          // 2. Android Content URI / SAF resolution:
          // Modern Android returns content:// URIs where file.path is null.
          // We stream/copy the file into a dedicated app cache staging directory with its original filename.
          try {
            final tempDir = await getTemporaryDirectory();
            final stagingDir = Directory(
              p.join(tempDir.path, 'airfile_staged_${DateTime.now().millisecondsSinceEpoch}_$i'),
            );
            await stagingDir.create(recursive: true);
            final destFile = File(p.join(stagingDir.path, file.name));

            try {
              await file.xFile.saveTo(destFile.path);
            } catch (_) {
              final sink = destFile.openWrite();
              await sink.addStream(file.readAsByteStream());
              await sink.flush();
              await sink.close();
            }

            if (await destFile.exists()) {
              resolvedPath = destFile.path;
            }
          } catch (copyErr) {
            debugPrint('Error caching picked file ${file.name}: $copyErr');
          }
        }

        if (resolvedPath != null) {
          widget.onFileAdded(resolvedPath);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCardDecoration(isHighlighted: _isDraggingOver),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Title & Action Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.drive_file_move_outlined, color: AppTheme.accentWhite, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Staged Files for Sharing',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                      ),
                      child: Text(
                        '${widget.stagedFiles.length}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.stagedFiles.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: widget.onClearAll,
                        icon: const Icon(Icons.clear_rounded, size: 13, color: AppTheme.textMuted),
                        label: Text(
                          'Clear',
                          style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isPicking ? null : _pickFiles,
                      icon: _isPicking
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentWhite),
                            )
                          : const Icon(Icons.add_rounded, size: 14),
                      label: Text(
                        _isPicking ? 'Loading...' : 'Browse Files',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentWhite,
                        side: const BorderSide(color: AppTheme.cardBorderHover, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Drop Area / Staged Files Content
            if (widget.stagedFiles.isEmpty)
              InkWell(
                onTap: _isPicking ? null : _pickFiles,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isDraggingOver ? AppTheme.accentWhite : AppTheme.cardBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isDraggingOver ? Icons.file_download_outlined : Icons.upload_file_outlined,
                        size: 24,
                        color: _isDraggingOver ? AppTheme.accentWhite : AppTheme.textMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isDraggingOver
                            ? 'Drop files to stage them'
                            : (_isPicking
                                ? 'Preparing selected files...'
                                : (Platform.isAndroid || Platform.isIOS
                                    ? 'Tap to select files from device storage'
                                    : 'Drag & drop files here from Finder, or click to browse')),
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _isDraggingOver ? AppTheme.accentWhite : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.stagedFiles.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final file = widget.stagedFiles[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, color: AppTheme.textSecondary, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_formatSize(file.size)} • ${file.mimeType}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                            onPressed: () => widget.onFileRemoved(file.id),
                            tooltip: 'Remove',
                            splashRadius: 14,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );

    if (Platform.isAndroid || Platform.isIOS) {
      return container;
    }

    return DropTarget(
      onDragEntered: (details) => setState(() => _isDraggingOver = true),
      onDragExited: (details) => setState(() => _isDraggingOver = false),
      onDragDone: (details) {
        setState(() => _isDraggingOver = false);
        for (final file in details.files) {
          widget.onFileAdded(file.path);
        }
      },
      child: container,
    );
  }
}
