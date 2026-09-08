import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        allowMultiple: true,
        dialogTitle: 'Select files to share',
      );

      for (final file in files) {
        if (file.path != null) {
          widget.onFileAdded(file.path!);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDraggingOver = true),
      onDragExited: (details) => setState(() => _isDraggingOver = false),
      onDragDone: (details) {
        setState(() => _isDraggingOver = false);
        for (final file in details.files) {
          widget.onFileAdded(file.path);
        }
      },
      child: AnimatedContainer(
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
                      style: GoogleFonts.alumniSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.4,
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
                        style: GoogleFonts.alumniSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
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
                          style: GoogleFonts.alumniSans(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: Text(
                        'Browse Files',
                        style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w400),
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
                onTap: _pickFiles,
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
                            : 'Drag & drop files here from Finder, or click to browse',
                        style: GoogleFonts.alumniSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
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
                                  style: GoogleFonts.alumniSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_formatSize(file.size)} • ${file.mimeType}',
                                  style: GoogleFonts.alumniSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
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
      ),
    );
  }
}
