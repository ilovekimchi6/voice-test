import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AudioStreamPage(),
    );
  }
}

class AudioStreamPage extends StatefulWidget {
  const AudioStreamPage({super.key});

  @override
  State<AudioStreamPage> createState() => _AudioStreamPageState();
}

class _AudioStreamPageState extends State<AudioStreamPage> {
  final Logger _logger = Logger();
  final Record _recorder = Record();
  WebSocketChannel? _channel;
  bool _isRecording = false;
  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://www.kimchi.com/audio'), //link
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          encoder: AudioEncoder.aacLc,
          samplingRate: 16000,
          numChannels: 1,
          bitRate: 32000,
        );

        setState(() => _isRecording = true);

        _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((data) {
          if (_channel != null) {
            _channel!.sink.add(data.current);
          }
        });
      }
    } catch (e) {
      _logger.e('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() => _isRecording = false);
    } catch (e) {
      _logger.e('Error stopping recording: $e');
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Streamer')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 64,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
