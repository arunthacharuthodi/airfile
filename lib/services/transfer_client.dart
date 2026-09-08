import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import '../models/file_payload.dart';
import '../models/peer_device.dart';

class TransferClient extends ChangeNotifier {
  final String senderDeviceId;
  final String senderDeviceName;

  final List<FilePayload> _outgoingTransfers = [];
  final Map<String, HttpClientRequest> _activeRequests = {};

  List<FilePayload> get outgoingTransfers => List.unmodifiable(_outgoingTransfers);

  TransferClient({
    required this.senderDeviceId,
    required this.senderDeviceName,
  });

  Future<bool> sendFile({
    required PeerDevice peer,
    required String filePath,
    void Function(FilePayload payload)? onProgress,
    void Function(FilePayload payload)? onComplete,
    void Function(FilePayload payload, String error)? onError,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('File does not exist: $filePath');
      return false;
    }

    final stat = await file.stat();
    final fileName = p.basename(filePath);
    final mime = lookupMimeType(filePath) ?? 'application/octet-stream';
    final payloadId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${_outgoingTransfers.length}';

    if (!peer.hasDirectIp) {
      final payload = FilePayload(
        id: payloadId,
        name: fileName,
        size: stat.size,
        localPath: filePath,
        mimeType: mime,
        isOutgoing: true,
        peerName: peer.name,
        peerAddress: 'Bluetooth Device',
        status: TransferStatus.failed,
        errorMessage: 'Device was found via Bluetooth. Use "QR Code / Web Share" to share files with it via Safari.',
      );
      _outgoingTransfers.insert(0, payload);
      onError?.call(payload, payload.errorMessage!);
      notifyListeners();
      return false;
    }

    final payload = FilePayload(
      id: payloadId,
      name: fileName,
      size: stat.size,
      localPath: filePath,
      mimeType: mime,
      isOutgoing: true,
      peerName: peer.name,
      peerAddress: peer.address,
      status: TransferStatus.connecting,
    );

    _outgoingTransfers.insert(0, payload);
    notifyListeners();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      // 1. Verify remote peer has AirFile app listening
      try {
        final pingUri = Uri.parse('${peer.address}/api/ping');
        final pingReq = await client.getUrl(pingUri).timeout(const Duration(seconds: 2));
        final pingResp = await pingReq.close().timeout(const Duration(seconds: 2));
        if (pingResp.statusCode != HttpStatus.ok) {
          throw Exception('Target returned status ${pingResp.statusCode}');
        }
      } catch (e) {
        payload.status = TransferStatus.failed;
        payload.errorMessage = 'Target device is not running AirFile app. Use QR Code / Safari to download this file on your iPhone.';
        onError?.call(payload, payload.errorMessage!);
        notifyListeners();
        return false;
      }

      final uploadUri = Uri.parse('${peer.address}/api/transfer/upload');
      final request = await client.postUrl(uploadUri);
      _activeRequests[payloadId] = request;

      request.headers.set('X-Device-Name', senderDeviceName);
      request.headers.set('X-Device-Id', senderDeviceId);
      request.headers.set('X-File-Name', Uri.encodeComponent(fileName));
      request.headers.set('X-File-Size', stat.size.toString());
      request.headers.set('Content-Type', mime);
      request.contentLength = stat.size;

      payload.status = TransferStatus.transferring;
      notifyListeners();

      final fileStream = file.openRead();
      int sentBytes = 0;
      final stopwatch = Stopwatch()..start();
      DateTime lastUpdate = DateTime.now();

      final transformedStream = fileStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, sink) {
            sink.add(chunk);
            sentBytes += chunk.length;

            final now = DateTime.now();
            if (now.difference(lastUpdate).inMilliseconds >= 100 || sentBytes == stat.size) {
              lastUpdate = now;
              payload.progress = (sentBytes / stat.size).clamp(0.0, 1.0);
              final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
              if (elapsedSec > 0) {
                payload.speedBytesPerSec = sentBytes / elapsedSec;
              }
              onProgress?.call(payload);
              notifyListeners();
            }
          },
          handleError: (error, stackTrace, sink) {
            sink.addError(error, stackTrace);
          },
          handleDone: (sink) {
            sink.close();
          },
        ),
      );

      await request.addStream(transformedStream);
      final response = await request.close();

      _activeRequests.remove(payloadId);

      if (response.statusCode == HttpStatus.ok) {
        payload.status = TransferStatus.completed;
        payload.progress = 1.0;
        onComplete?.call(payload);
        notifyListeners();
        return true;
      } else {
        final respBody = await utf8.decoder.bind(response).join();
        payload.status = TransferStatus.failed;
        payload.errorMessage = 'Server error: ${response.statusCode} - $respBody';
        onError?.call(payload, payload.errorMessage!);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _activeRequests.remove(payloadId);
      payload.status = TransferStatus.failed;
      payload.errorMessage = e.toString();
      onError?.call(payload, e.toString());
      notifyListeners();
      return false;
    } finally {
      client.close();
    }
  }

  void cancelTransfer(String payloadId) {
    final request = _activeRequests.remove(payloadId);
    request?.abort();

    final payload = _outgoingTransfers.firstWhere((p) => p.id == payloadId, orElse: () => throw Exception('Not found'));
    payload.status = TransferStatus.cancelled;
    notifyListeners();
  }

  void clearCompleted() {
    _outgoingTransfers.removeWhere((t) => t.status.isDone);
    notifyListeners();
  }

  void dismissTransfer(String id) {
    _outgoingTransfers.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
