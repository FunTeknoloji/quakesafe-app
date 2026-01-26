import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sound_stream/sound_stream.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'p2p_connection_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter/foundation.dart';

class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();

  StreamSubscription? _recorderSubscription;
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isRemoteMuted = false;
  bool _isSpeakerPhone = true;

  bool _isRecording = false;
  File? _recordFile;
  IOSink? _recordSink;

  void toggleMute(bool mute) {
    _isMuted = mute;
  }

  void toggleRemoteMute(bool mute) {
    _isRemoteMuted = mute;
    if (mute) {
      _player.stop();
    } else if (_isCallActive) {
      _player.start();
    }
  }

  Future<void> toggleSpeaker(bool speakerOn) async {
    _isSpeakerPhone = speakerOn;
    final audioSession = await session.AudioSession.instance;
    await audioSession.configure(session.AudioSessionConfiguration(
      avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: speakerOn
          ? session.AVAudioSessionCategoryOptions.defaultToSpeaker
          : session.AVAudioSessionCategoryOptions.none,
      avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
      androidAudioAttributes: session.AndroidAudioAttributes(
        contentType: session.AndroidAudioContentType.speech,
        usage: session.AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
    ));
    await audioSession.setActive(true);
  }

  int _currentSampleRate = 16000;

  Future<void> init({int sampleRate = 16000}) async {
    _currentSampleRate = sampleRate;
    await _recorder.initialize(sampleRate: sampleRate);
    await _player.initialize(sampleRate: sampleRate);
    await toggleSpeaker(true);
  }

  Future<void> setQuality(int sampleRate) async {
    if (_currentSampleRate == sampleRate) return;
    debugPrint('Switching Audio Quality to: $sampleRate Hz');
    _currentSampleRate = sampleRate;
    try {
      await _recorder.stop();
      await _player.stop();
      await _recorder.initialize(sampleRate: sampleRate);
      await _player.initialize(sampleRate: sampleRate);
    } catch (e) {
      debugPrint('SetQuality Error: $e');
    }
  }

  final ValueNotifier<bool> isTransmitting = ValueNotifier<bool>(false);
  Timer? _pttTimer;

  void startCall(String endpointId) {
    if (_isCallActive) return;
    _isCallActive = true;

    _player.start();
  }

  void startPTT(String endpointId) {
    if (isTransmitting.value) return;
    isTransmitting.value = true;

    _recorder.start();

    List<int> buffer = [];
    _recorderSubscription = _recorder.audioStream.listen((Uint8List data) {
      if (_isMuted) return;

      if (_isRecording) _recordSink?.add(data);

      bool hasSound = false;
      for (int i = 0; i < data.length; i+=2) {
        if (data[i].abs() > 30) {
          hasSound = true;
          break;
        }
      }

      if (!hasSound) return;

      buffer.addAll(data);
      if (buffer.length >= 1024) {
        Uint8List payload = Uint8List.fromList(buffer);
        if (endpointId == 'all') {
          for (var eid in P2PConnectionService().endpointMap.keys) {
             Nearby().sendBytesPayload(eid, payload);
          }
        } else {
          Nearby().sendBytesPayload(endpointId, payload);
        }
        buffer.clear();
      }
    });

    // Auto-stop after 10s
    _pttTimer = Timer(const Duration(seconds: 10), () {
      stopPTT();
    });
  }

  void stopPTT() {
    if (!isTransmitting.value) return;
    isTransmitting.value = false;
    _pttTimer?.cancel();
    _recorder.stop();
    _recorderSubscription?.cancel();
    _recorderSubscription = null;
  }

  void receiveAudio(Uint8List data) {
    if (!_isCallActive) {
      _isCallActive = true;
      _player.start();
    }

    if (_isRecording) _recordSink?.add(data);

    if (!_isRemoteMuted) {
      _player.writeChunk(data);
    }
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/call_rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    _recordFile = File(path);
    _recordSink = _recordFile!.openWrite();

    // Write placeholder WAV header (44 bytes)
    _recordSink?.add(Uint8List(44));

    _isRecording = true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    await _recordSink?.flush();
    await _recordSink?.close();
    _recordSink = null;

    // Patch WAV header with correct sizes
    if (_recordFile != null) {
      final bytes = await _recordFile!.readAsBytes();
      final wavHeader = _createWavHeader(bytes.length - 44, 16000);
      final completeWav = Uint8List.fromList(wavHeader + bytes.sublist(44));
      await _recordFile!.writeAsBytes(completeWav);
    }

    return _recordFile?.path;
  }

  List<int> _createWavHeader(int dataLength, int sampleRate) {
    final int fileSize = dataLength + 36;
    final int byteRate = sampleRate * 2; // 16-bit mono

    return [
      // RIFF header
      ...utf8.encode('RIFF'),
      ..._int32ToBytes(fileSize),
      ...utf8.encode('WAVE'),
      // fmt subchunk
      ...utf8.encode('fmt '),
      ..._int32ToBytes(16), // Subchunk1Size
      ..._int16ToBytes(1),  // AudioFormat (PCM)
      ..._int16ToBytes(1),  // NumChannels (Mono)
      ..._int32ToBytes(sampleRate),
      ..._int32ToBytes(byteRate),
      ..._int16ToBytes(2),  // BlockAlign
      ..._int16ToBytes(16), // BitsPerSample
      // data subchunk
      ...utf8.encode('data'),
      ..._int32ToBytes(dataLength),
    ];
  }

  List<int> _int32ToBytes(int value) => Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);
  List<int> _int16ToBytes(int value) => Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);

  bool get isRecording => _isRecording;

  void stopCall() {
    _isCallActive = false;
    _recorder.stop();
    _player.stop();
    _recorderSubscription?.cancel();
    _recorderSubscription = null;
    stopRecording();
  }

  Future<void> playAudioFile(String path) async {
    await _audioPlayer.play(DeviceFileSource(path));
  }

  void dispose() {
    _audioPlayer.dispose();
    stopCall();
  }
}
