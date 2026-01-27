import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:nearby_connections/nearby_connections.dart';
import 'p2p_connection_service.dart';

class VideoCallService {
  final String _endpointId;
  final P2PConnectionService _p2pConnectionService = P2PConnectionService();
  final StreamController<dynamic> _videoStreamController = StreamController.broadcast();

  Stream<dynamic> get videoStream => _videoStreamController.stream;
  final StreamController<String> _callStateController = StreamController.broadcast();

  Stream<String> get callStateStream => _callStateController.stream;

  VideoCallService(this._endpointId) {
    _p2pConnectionService.videoStream.listen(_onDataReceived);
    _p2pConnectionService.videoSigStream.listen(_onSignalReceived);
  }

  void _onDataReceived(Map<String, dynamic> data) {
    if (data['id'] == _endpointId) {
      _videoStreamController.add(data['payload']);
    }
  }

  void _onSignalReceived(Map<String, dynamic> data) {
    if (data['id'] == _endpointId) {
      _callStateController.add(data['cmd']);
    }
  }

  void sendVideoFrame(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    final yuvBytes = List<int>.filled(width * height * 3, 0);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        yuvBytes[index * 3] = r;
        yuvBytes[index * 3 + 1] = g;
        yuvBytes[index * 3 + 2] = b;
      }
    }

    final img.Image rgbImage = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: Uint8List.fromList(yuvBytes).buffer,
      format: img.Format.uint8,
    );

    final jpegBytes = img.encodeJpg(rgbImage, quality: 50);

    _p2pConnectionService.sendProtocolMessage(_endpointId, {
      'type': 'VIDEO_FRAME',
      'payload': jpegBytes,
    });
  }

  void sendSignal(String cmd) {
    _p2pConnectionService.sendProtocolMessage(_endpointId, {
      'type': 'VIDEO_SIG',
      'cmd': cmd,
    });
  }

  void dispose() {
    _videoStreamController.close();
    _callStateController.close();
  }
}
