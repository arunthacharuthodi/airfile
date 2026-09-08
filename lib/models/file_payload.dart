enum TransferStatus {
  queued,
  connecting,
  transferring,
  completed,
  failed,
  cancelled;

  bool get isActive =>
      this == TransferStatus.queued ||
      this == TransferStatus.connecting ||
      this == TransferStatus.transferring;

  bool get isDone =>
      this == TransferStatus.completed ||
      this == TransferStatus.failed ||
      this == TransferStatus.cancelled;
}

class FilePayload {
  final String id;
  final String name;
  int size;
  final String? localPath;
  final String mimeType;
  final bool isOutgoing;
  final String peerName;
  final String peerAddress;
  final DateTime timestamp;
  TransferStatus status;
  double progress;
  double speedBytesPerSec;
  String? savedPath;
  String? errorMessage;
  String? sha256;

  FilePayload({
    required this.id,
    required this.name,
    required this.size,
    this.localPath,
    required this.mimeType,
    required this.isOutgoing,
    required this.peerName,
    required this.peerAddress,
    DateTime? timestamp,
    this.status = TransferStatus.queued,
    this.progress = 0.0,
    this.speedBytesPerSec = 0.0,
    this.savedPath,
    this.errorMessage,
    this.sha256,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedSpeed {
    if (speedBytesPerSec < 1024) {
      return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
    }
    if (speedBytesPerSec < 1024 * 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'mimeType': mimeType,
      'sha256': sha256,
    };
  }

  factory FilePayload.fromJson(
    Map<String, dynamic> json, {
    required bool isOutgoing,
    required String peerName,
    required String peerAddress,
  }) {
    return FilePayload(
      id: json['id'] as String? ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Unnamed File',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      isOutgoing: isOutgoing,
      peerName: peerName,
      peerAddress: peerAddress,
      sha256: json['sha256'] as String?,
    );
  }
}
