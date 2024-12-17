import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Voice App',
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
  late final AudioRecorder audioRecorder;
  WebSocketChannel? channel;
  bool isRecording = false;
  final logger = Logger(printer: PrettyPrinter());

  @override
  void initState() {
    super.initState();
    audioRecorder = AudioRecorder();
    _requestPermission();
    logger.i('AudioStreamPage initialized');
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    logger.i('Microphone permission status: $status');
  }

  void _connectWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('wss://www.kimchi.com/audio'),
    );
    logger.i('WebSocket connected');
  }

  Future<void> _startRecording() async {
    try {
      if (await audioRecorder.hasPermission()) {
        _connectWebSocket();

        // Get temporary directory for file storage
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/temp_audio.aac';

        // Start recording to file
        await audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: path,
        );

        // Start streaming audio
        final stream = await audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1,
          ),
        );

        // Listen to audio stream
        stream.listen((data) {
          if (channel != null) {
            channel!.sink.add(data);
            logger.d('Sent audio chunk of size: ${data.length}');
          }
        });

        setState(() => isRecording = true);
        logger.i('Recording started');
      }
    } catch (e) {
      logger.e('Error starting recording', error: e);
    }
  }

  Future<void> _stopRecording() async {
    try {
      await audioRecorder.stop();
      channel?.sink.close();
      channel = null;
      setState(() => isRecording = false);
      logger.i('Recording stopped');
    } catch (e) {
      logger.e('Error stopping recording', error: e);
    }
  }

  @override
  void dispose() {
    audioRecorder.dispose();
    channel?.sink.close();
    logger.i('AudioStreamPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Streaming')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              size: 64,
              color: isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isRecording ? _stopRecording : _startRecording,
              child: Text(isRecording ? 'Stop Streaming' : 'Start Streaming'),
            ),
          ],
        ),
      ),
    );
  }
}
