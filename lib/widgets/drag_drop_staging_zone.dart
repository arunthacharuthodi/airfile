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
  final List<String> watchedFolders;
  final Function(String path) onFileAdded;
  final Function(String path)? onFolderAdded;
  final Function(String path)? onFolderRemoved;
  final VoidCallback? onRefreshFolders;
  final Function(String id) onFileRemoved;
  final VoidCallback onClearAll;

  const DragDropStagingZone({
    super.key,
    required this.stagedFiles,
    this.watchedFolders = const [],
    required this.onFileAdded,
    this.onFolderAdded,
    this.onFolderRemoved,
    this.onRefreshFolders,
    required this.onFileRemoved,
    required this.onClearAll,
  });

  @override
  State<DragDropStagingZone> createState() => _DragDropStagingZoneState();
}

class _DragDropStagingZoneState extends State<DragDropStagingZone> {
  bool _isDraggingOver = false;
  bool _isPicking = false;
  bool _isPickingFolder = false;

  Future<void> _pickFiles() async {
    if (_isPicking || _isPickingFolder) return;
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

  Future<void> _pickFolder() async {
    if (_isPickingFolder || _isPicking) return;
    setState(() => _isPickingFolder = true);
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select folder to stage files from',
      );
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        widget.onFolderAdded?.call(selectedDirectory);
      }
    } catch (e) {
      debugPrint('Error picking folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open folder picker: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingFolder = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildWatchedFoldersBar() {
    if (widget.watchedFolders.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_open_rounded, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 5),
                Text(
                  'Watched Folders:',
                  style: GoogleFonts.ptSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            ...widget.watchedFolders.map((folder) {
              final prefix = TransferServer.generateFolderPrefix(folder);
              final count = widget.stagedFiles.where((f) => f.folderSource == folder).length;
              return Tooltip(
                message: folder,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorderHover, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prefix,
                        style: GoogleFonts.ptSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentWhite,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.ptSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (widget.onFolderRemoved != null)
                        InkWell(
                          onTap: () => widget.onFolderRemoved!(folder),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded, size: 12, color: AppTheme.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (widget.onFolderAdded != null)
              InkWell(
                onTap: _isPickingFolder ? null : _pickFolder,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        'Add',
                        style: GoogleFonts.ptSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
                    style: GoogleFonts.ptSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
                      style: GoogleFonts.ptSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.onRefreshFolders != null && widget.watchedFolders.isNotEmpty) ...[
                    IconButton(
                      onPressed: widget.onRefreshFolders,
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textSecondary),
                      tooltip: 'Rescan watched folders',
                      splashRadius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (widget.stagedFiles.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: widget.onClearAll,
                      icon: const Icon(Icons.clear_rounded, size: 13, color: AppTheme.textMuted),
                      label: Text(
                        'Clear',
                        style: GoogleFonts.ptSans(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (widget.onFolderAdded != null) ...[
                    OutlinedButton.icon(
                      onPressed: (_isPickingFolder || _isPicking) ? null : _pickFolder,
                      icon: _isPickingFolder
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentWhite),
                            )
                          : const Icon(Icons.create_new_folder_outlined, size: 14),
                      label: Text(
                        _isPickingFolder ? 'Selecting...' : 'Add Folder',
                        style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold),
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
                    const SizedBox(width: 6),
                  ],
                  OutlinedButton.icon(
                    onPressed: (_isPickingFolder || _isPicking) ? null : _pickFiles,
                    icon: _isPicking
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentWhite),
                          )
                        : const Icon(Icons.add_rounded, size: 14),
                    label: Text(
                      _isPicking ? 'Loading...' : 'Browse Files',
                      style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold),
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

          // Watched Folders Bar (if any configured)
          _buildWatchedFoldersBar(),

          // Drop Area / Staged Files Content
          if (widget.stagedFiles.isEmpty)
            InkWell(
              onTap: (_isPicking || _isPickingFolder) ? null : _pickFiles,
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
                          : (_isPicking || _isPickingFolder
                              ? 'Preparing selected items...'
                              : (Platform.isAndroid || Platform.isIOS
                                  ? 'Tap to select files from device storage'
                                  : 'Drag & drop files here from Finder, or select files & folders above')),
                      style: GoogleFonts.ptSans(
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
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.stagedFiles.length,
                separatorBuilder: (_, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final file = widget.stagedFiles[index];
                  final isApk = file.name.toLowerCase().endsWith('.apk');

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          isApk ? Icons.android_rounded : Icons.insert_drive_file_outlined,
                          color: isApk ? const Color(0xFF3DDC84) : AppTheme.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      file.name,
                                      style: GoogleFonts.ptSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (file.folderSource != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: AppTheme.cardBorder, width: 0.5),
                                      ),
                                      child: Text(
                                        'WATCHED',
                                        style: GoogleFonts.ptSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textMuted,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
                              // File path in subtitle
                              Tooltip(
                                message: file.path,
                                child: Text(
                                  file.path,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: Platform.isMacOS ? 'Menlo' : 'monospace',
                                    color: AppTheme.textMuted,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${_formatSize(file.size)} • ${file.mimeType}',
                                style: GoogleFonts.ptSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
