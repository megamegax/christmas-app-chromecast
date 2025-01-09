import 'package:cast/cast.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Egyszerű karácsonyi színek használata
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.green.shade100,
        appBarTheme: AppBarTheme(color: Colors.redAccent),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Karácsonyi Chromecast'),
          centerTitle: true,
        ),
        body: CastSample(),
      ),
    );
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
  Future<List<CastDevice>>? _future;
  CastSession? _session; // A kiválasztott eszközzel létrehozott session.
  bool _isConnecting = false; // Hogy tudjuk, éppen történik-e csatlakozás.
  CastDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  void _startSearch() {
    _future = CastDiscoveryService().search();
  }

  @override
  Widget build(BuildContext context) {
    // Ha már van session, jelenítsük meg a gombokat a lejátszáshoz.
    if (_session != null) {
      return _buildControlButtons();
    }

    // Különben listázzuk az eszközöket (vagy azt, hogy épp csatlakozás folyik).
    return _buildDeviceList();
  }

  /// Eszközlista megjelenítése, ha még nincs csatlakozva
  Widget _buildDeviceList() {
    return FutureBuilder<List<CastDevice>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Hiba történt: ${snapshot.error.toString()}',
              style: TextStyle(color: Colors.red),
            ),
          );
        } else if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return Center(child: Text('Nem található Chromecast eszköz.'));
        }

        return ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return ListTile(
              title: Text(device.name),
              trailing: _isConnecting
                  ? SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator())
                  : Icon(Icons.cast),
              onTap: () async {
                // Ne lehessen többször rákattintani, amíg folyik a csatlakozás
                if (_isConnecting) return;

                setState(() {
                  _isConnecting = true;
                });

                await _connectToDevice(device);

                setState(() {
                  _isConnecting = false;
                });
              },
            );
          },
        );
      },
    );
  }

  /// Két gomb (csengő, mennyből az angyal) megjelenítése, ha már csatlakoztunk
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Csatlakozva: ${_selectedDevice?.name ?? "Ismeretlen eszköz"}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.music_note),
            label: Text("Csengő lejátszása"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            onPressed: () => _playMedia(CastSample.csengo, "Csengő"),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.music_video),
            label: Text("Mennyből az angyal lejátszása"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            onPressed: () =>
                _playMedia(CastSample.menybol, "Mennyből az angyal"),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.stop),
            label: Text("Lejátszás leállítása"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            onPressed: _stopPlayback,
          ),
        ],
      ),
    );
  }

  /// Csatlakozás a kiválasztott eszközhöz
  Future<void> _connectToDevice(CastDevice device) async {
    try {
      final session = await CastSessionManager().startSession(device);

      session.stateStream.listen((state) {
        if (state == CastSessionState.connected) {
          setState(() {
            _selectedDevice = device;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sikeres csatlakozás: ${device.name}')),
          );
        } else if (state == CastSessionState.closed ||
            state == CastSessionState.closed) {
          // Ha bontja a kapcsolatot, akkor térjünk vissza az eszközlistához
          setState(() {
            _selectedDevice = null;
            _session = null;
          });
        }
      });

      // Ha minden rendben, eltároljuk a session-t
      setState(() {
        _session = session;
      });

      // Indítjuk a "receiver" appot (pl. a default media receiver: CC1AD845)
      session.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'LAUNCH',
        'appId': 'CC1AD845', // Alapértelmezett media receiver
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a csatlakozás során: $e')),
      );
    }
  }

  /// Leállít bármilyen aktív lejátszást
  void _stopPlayback() {
    if (_session == null) return;
    _session!.sendMessage(
      CastSession.kNamespaceMedia,
      {
        "type": "STOPg",
        "sessionId": _session!.sessionId,
      },
    );
    _session?.close();
    print("Leállítás");
  }

  /// Egy általános függvény, ami lejátszik valamilyen médiaállományt
  void _playMedia(String contentId, String title) {
    if (_session == null) return;

    final message = {
      'contentId': contentId,
      'contentType': 'audio/mp3', // Mindkét esetben mp3
      'streamType': 'BUFFERED',
      'metadata': {
        'type': 0,
        'metadataType': 0,
        'title': title,
        'images': [
          {'url': contentId}
        ],
      }
    };

    _session!.sendMessage(
      CastSession.kNamespaceMedia,
      {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': 0,
        'media': message,
      },
    );
  }
}
