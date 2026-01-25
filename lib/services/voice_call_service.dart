import 'dart:async';
import 'dart:typed_data';
import 'package:sound_stream/sound_stream.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceCallService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();

  StreamSubscription? _recorderSubscription;
  bool _isCallActive = false;

  Future<void> init() async {
    // Use a lower sample rate for better performance over P2P mesh
    await _recorder.initialize(sampleRate: 16000);
    await _player.initialize(sampleRate: 16000);
  }

  void startCall(String endpointId) {
    if (_isCallActive) return;
    _isCallActive = true;

    _player.start();
    _recorder.start();

    List<int> buffer = [];
    _recorderSubscription = _recorder.audioStream.listen((Uint8List data) {
      // Send audio data in chunks.
      // Small chunks cause high overhead in Nearby Connections.
      // We group a few chunks together to reduce packet frequency.
      buffer.addAll(data);
      if (buffer.length >= 4096) {
        Nearby().sendBytesPayload(endpointId, Uint8List.fromList(buffer));
        buffer.clear();
      }
    });
  }

  void receiveAudio(Uint8List data) {
    if (!_isCallActive) {
      _isCallActive = true;
      _player.start();
    }
    _player.writeChunk(data);
  }

  void stopCall() {
    _isCallActive = false;
    _recorder.stop();
    _player.stop();
    _recorderSubscription?.cancel();
    _recorderSubscription = null;
  }

  Future<void> playAudioFile(String path) async {
    await _audioPlayer.play(DeviceFileSource(path));
  }

  void dispose() {
    _audioPlayer.dispose();
    stopCall();
  }
}
