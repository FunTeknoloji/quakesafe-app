import 'dart:async';
import 'package:camera/camera.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'p2p_connection_service.dart';

class VideoCallService {
  final String _endpointId;
  final P2PConnectionService _p2pConnectionService = P2PConnectionService();
  final StreamController<dynamic> _videoStreamController = StreamController.broadcast();

  Stream<dynamic> get videoStream => _videoStreamController.stream;

  VideoCallService(this._endpointId) {
    _p2pConnectionService.addListener(_onDataReceived);
  }

  void _onDataReceived() {
    // Handle incoming video frames
  }

  void sendVideoFrame(CameraImage image) {
    // Convert CameraImage to bytes and send over P2P connection
  }

  void dispose() {
    _videoStreamController.close();
    _p2pConnectionService.removeListener(_onDataReceived);
  }
}
