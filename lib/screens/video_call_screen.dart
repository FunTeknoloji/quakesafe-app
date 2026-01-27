import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:quakesafe_app/services/p2p_connection_service.dart';
import '../services/video_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String endpointId;
  final String endpointName;

  const VideoCallScreen({
    super.key,
    required this.endpointId,
    required this.endpointName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late VideoCallService _videoCallService;
  CameraController? _cameraController;
  bool _isMuted = false;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _videoCallService = VideoCallService(widget.endpointId);
    availableCameras().then((cameras) {
      _cameras = cameras;
      if (_cameras.isNotEmpty) {
        _initializeCamera(_cameras.first);
      }
    });
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.low,
    );

    await _cameraController!.initialize();
    _cameraController!.startImageStream((image) {
      if (!_isMuted) {
        _videoCallService.sendVideoFrame(image);
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoCallService.dispose();
    super.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      await _initializeCamera(_cameras[_selectedCameraIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${P2PConnectionService().endpointMap[widget.endpointId]?.username ?? 'Bilinmeyen'} ile Görüntülü Görüşme'),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _cameraController != null && _cameraController!.value.isInitialized
                  ? CameraPreview(_cameraController!)
                  : const CircularProgressIndicator(),
            ),
          ),
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: _videoCallService.videoStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data);
                } else {
                  return const Center(child: Text('Peerden video yok'));
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _videoCallService.sendSignal('END');
          Navigator.pop(context);
        },
        child: const Icon(Icons.call_end),
      ),
    );
  }
}
