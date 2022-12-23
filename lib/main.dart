import 'package:flutter/material.dart';
import 'package:flutter_cast_video/flutter_cast_video.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CastSample());
  }
}

class CastSample extends StatefulWidget {
  static const _iconSize = 50.0;
  static const csengo =
      "https://raw.githubusercontent.com/megamegax/christmas-app/master/app/src/main/res/raw/csengo.mp3";
  static const menybol =
      "https://raw.githubusercontent.com/megamegax/christmas-app/master/app/src/main/res/raw/mennybol.mp3";

  @override
  _CastSampleState createState() => _CastSampleState();
}

class _CastSampleState extends State<CastSample> {
  ChromeCastController _controller;
  AppState _state = AppState.idle;
  bool _playing = false;

  var currentMp3 = CastSample.csengo;
  @override
  void initState() {
    super.initState();

    currentMp3 = CastSample.csengo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plugin example app'),
        actions: <Widget>[
          ChromeCastButton(
            size: CastSample._iconSize,
            color: Colors.white,
            onButtonCreated: _onButtonCreated,
            onSessionStarted: _onSessionStarted,
            onSessionEnded: () => setState(() => _state = AppState.idle),
            onRequestCompleted: _onRequestCompleted,
            onRequestFailed: _onRequestFailed,
          ),
        ],
      ),
      body: Center(child: _handleState()),
    );
  }

  Widget _handleState() {
    switch (_state) {
      case AppState.idle:
        return Text('ChromeCast not connected');
      case AppState.connected:
        return Text('No media loaded');
      case AppState.mediaLoaded:
        return _mediaControls();
      case AppState.error:
        return Text('An error has occurred');
      default:
        return Container();
    }
  }

  Widget _mediaControls() {
    return Column(
      children: [
        RadioListTile(
          title: Text("Csengő"),
          value: CastSample.csengo,
          groupValue: currentMp3,
          onChanged: (value) async {
            _controller.stop();
            await _controller.loadMedia(CastSample.csengo);
            setState(() {
              currentMp3 = CastSample.csengo;
            });
            _playPauseMenybol();
          },
        ),
        RadioListTile(
          title: Text("Menyből az angyal"),
          value: CastSample.menybol,
          groupValue: currentMp3,
          onChanged: (value) async {
            _controller.stop();
            await _controller.loadMedia(CastSample.menybol);
            setState(() {
              currentMp3 = CastSample.menybol;
            });
            _playPauseMenybol();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _RoundIconButton(
              icon: Icons.replay_10,
              onPressed: () =>
                  _controller.seek(relative: true, interval: -10.0),
            ),
            _RoundIconButton(
                icon: _playing ? Icons.pause : Icons.play_arrow,
                onPressed: _playPauseMenybol),
            _RoundIconButton(
              icon: Icons.forward_10,
              onPressed: () => _controller.seek(relative: true, interval: 10.0),
            )
          ],
        ),
      ],
    );
  }

  Future<void> _playPauseMenybol() async {
    final playing = await _controller.isPlaying();
    if (playing) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    setState(() => _playing = !playing);
  }

  Future<void> _onButtonCreated(ChromeCastController controller) async {
    _controller = controller;
    await _controller.addSessionListener();
  }

  Future<void> _onSessionStarted() async {
    setState(() => _state = AppState.connected);
    await _controller.loadMedia(CastSample.csengo);
  }

  Future<void> _onRequestCompleted() async {
    final playing = await _controller.isPlaying();
    setState(() {
      _state = AppState.mediaLoaded;
      _playing = playing;
    });
  }

  Future<void> _onRequestFailed(String error) async {
    setState(() => _state = AppState.error);
    print(error);
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  _RoundIconButton({@required this.icon, @required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        child: Icon(icon, color: Colors.white), onPressed: onPressed);
  }
}

enum AppState { idle, connected, mediaLoaded, error }
