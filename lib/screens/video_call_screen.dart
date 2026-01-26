import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

  @override
  void initState() {
    super.initState();
    _videoCallService = VideoCallService(widget.endpointId);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.low,
    );

    await _cameraController!.initialize();
    _cameraController!.startImageStream((image) {
      _videoCallService.sendVideoFrame(image);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoCallService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call with ${widget.endpointName}'),
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
                  return const Center(child: Text('No video from peer'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
