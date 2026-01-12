import 'dart:async';
import 'package:cast/cast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFB91C1C),
          secondary: Color(0xFF065F46),
          tertiary: Color(0xFFF59E0B),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFB91C1C),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.mountainsOfChristmasTextTheme().headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: Size(200, 70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            textStyle: GoogleFonts.poppinsTextTheme().labelLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Karácsonyi Varázslat'),
        ),
        body: CastSample(),
      ),
    );
  }
}

/// Karácsonyi háttér gradienssel
class ChristmasBackground extends StatelessWidget {
  final Widget child;

  const ChristmasBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A8A), // Éjszakai kék
            Color(0xFF3B82F6), // Világosabb kék
            Color(0xFFF0F9FF), // Hófeher
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class CastSample extends StatefulWidget {
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
  StreamSubscription<CastSessionState>? _sessionStateSubscription;

  @override
  void initState() {
    super.initState();
    _startSearch();
    _tryAutoConnect();
  }

  void _startSearch() {
    _future = CastDiscoveryService().search();
  }

  /// Automatikus csatlakozás az utoljára használt eszközhöz
  Future<void> _tryAutoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDeviceName = prefs.getString('last_device_name');
      final lastDeviceHost = prefs.getString('last_device_host');

      if (lastDeviceName != null && lastDeviceHost != null) {
        // Várjuk meg az eszközkeresés eredményét
        final devices = await _future;

        if (devices != null && devices.isNotEmpty) {
          // Keressük meg az utolsó eszközt
          final lastDevice = devices.firstWhere(
            (d) => d.name == lastDeviceName || d.host == lastDeviceHost,
            orElse: () => devices.first,
          );

          // Kis késleltetés, hogy a UI megjelenjen
          await Future.delayed(Duration(milliseconds: 500));

          setState(() {
            _isConnecting = true;
          });

          await _connectToDevice(lastDevice);

          setState(() {
            _isConnecting = false;
          });
        }
      }
    } catch (e) {
      print('Auto-connect sikertelen: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// Hibaüzenet megjelenítése barátságos formátumban
  void _showChristmasError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _sessionStateSubscription?.cancel();
    _session?.close();
    super.dispose();
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
    return ChristmasBackground(
      child: FutureBuilder<List<CastDevice>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Color(0xFFB91C1C)),
                  SizedBox(height: 16),
                  Text(
                    'Hiba történt!',
                    style: GoogleFonts.mountainsOfChristmas(
                      fontSize: 24,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      snapshot.error.toString(),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text('Újra'),
                    onPressed: () => setState(() => _startSearch()),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 6,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Varázslat keresése...',
                    style: GoogleFonts.mountainsOfChristmas(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          final devices = snapshot.data ?? [];
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cast_connected, size: 64, color: Colors.white70),
                  SizedBox(height: 16),
                  Text(
                    'Nincs Chromecast',
                    style: GoogleFonts.mountainsOfChristmas(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Győződj meg róla, hogy be van kapcsolva és ugyanazon a WiFi-n van!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text('Keresés újra'),
                    onPressed: () => setState(() => _startSearch()),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                elevation: 8,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFB91C1C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.cast,
                      size: 32,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                  title: Text(
                    device.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Koppints a csatlakozáshoz',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  trailing: _isConnecting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFFB91C1C),
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFFB91C1C),
                        ),
                  onTap: () async {
                    if (_isConnecting) return;

                    setState(() {
                      _isConnecting = true;
                    });

                    await _connectToDevice(device);

                    setState(() {
                      _isConnecting = false;
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Két gomb (csengő, mennyből az angyal) megjelenítése, ha már csatlakoztunk
  Widget _buildControlButtons() {
    return ChristmasBackground(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Connection banner
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Color(0xFF065F46),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Csatlakozva: ${_selectedDevice?.name ?? "Chromecast"}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 48),

            // Bell button
            _buildChristmasButton(
              icon: Icons.notifications_active,
              label: "Csengő",
              color: Color(0xFFF59E0B), // Gold
              onPressed: () => _playMedia(CastSample.csengo, "Csengő"),
            ),
            SizedBox(height: 24),

            // Angel song button
            _buildChristmasButton(
              icon: Icons.cloud,
              label: "Mennyből az angyal",
              color: Color(0xFF3B82F6), // Sky blue
              onPressed: () => _playMedia(CastSample.menybol, "Mennyből az angyal"),
            ),
            SizedBox(height: 24),

            // Stop button
            _buildChristmasButton(
              icon: Icons.stop_circle,
              label: "Leállítás",
              color: Color(0xFF6B7280), // Gray
              onPressed: _stopPlayback,
            ),
            SizedBox(height: 32),

            // Disconnect button
            TextButton.icon(
              icon: Icon(Icons.logout, color: Colors.white70),
              label: Text(
                'Lecsatlakozás',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
              onPressed: () {
                _session?.close();
                setState(() {
                  _session = null;
                  _selectedDevice = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Karácsonyi témájú gomb widget
  Widget _buildChristmasButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 90,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36),
              SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.mountainsOfChristmas(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Utolsó eszköz mentése a későbbi automatikus csatlakozáshoz
  Future<void> _saveLastDevice(CastDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_name', device.name);
      await prefs.setString('last_device_host', device.host);
    } catch (e) {
      print('Hiba az eszköz mentésekor: $e');
    }
  }

  /// Csatlakozás a kiválasztott eszközhöz
  Future<void> _connectToDevice(CastDevice device) async {
    try {
      final session = await CastSessionManager()
          .startSession(device)
          .timeout(Duration(seconds: 15));

      // Cancel previous subscription if exists
      await _sessionStateSubscription?.cancel();

      _sessionStateSubscription = session.stateStream.listen(
        (state) {
          if (state == CastSessionState.connected) {
            setState(() {
              _selectedDevice = device;
            });

            // Mentjük az eszközt a későbbi automatikus csatlakozáshoz
            _saveLastDevice(device);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.celebration, color: Color(0xFFF59E0B)),
                    SizedBox(width: 12),
                    Text('Sikeres csatlakozás: ${device.name}'),
                  ],
                ),
                backgroundColor: Color(0xFF065F46),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } else if (state == CastSessionState.closed) {
            // Ha bontja a kapcsolatot, akkor térjünk vissza az eszközlistához
            setState(() {
              _selectedDevice = null;
              _session = null;
            });

            _showChristmasError('Kapcsolat lezárva: ${device.name}');
          }
        },
        onError: (error) {
          _showChristmasError('Kapcsolódási hiba: $error');
        },
      );

      // Ha minden rendben, eltároljuk a session-t
      setState(() {
        _session = session;
      });

      // Indítjuk a "receiver" appot (pl. a default media receiver: CC1AD845)
      session.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'LAUNCH',
        'appId': 'CC1AD845', // Alapértelmezett media receiver
      });
    } on TimeoutException {
      _showChristmasError('Időtúllépés. Kérlek próbáld újra!');
    } catch (e) {
      _showChristmasError('Nem sikerült csatlakozni: ${device.name}');
    }
  }

  /// Leállít bármilyen aktív lejátszást
  void _stopPlayback() {
    if (_session == null) return;

    try {
      _session!.sendMessage(
        CastSession.kNamespaceMedia,
        {
          "type": "STOP",
          "sessionId": _session!.sessionId,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lejátszás leállítva'),
          backgroundColor: Color(0xFF6B7280),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showChristmasError('Nem sikerült leállítani a lejátszást');
    }
  }

  /// Egy általános függvény, ami lejátszik valamilyen médiaállományt
  void _playMedia(String contentId, String title) {
    if (_session == null) return;

    try {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lejátszás indul: $title'),
          backgroundColor: Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showChristmasError('Nem sikerült elindítani a zenét');
    }
  }
}
