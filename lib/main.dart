import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chromecast_example/player/cast_mini_media_controls.dart';
import 'package:flutter_chromecast_example/service_discovery.dart';
import 'package:dart_chromecast/casting/cast.dart';
import 'package:flutter_chromecast_example/device_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Karácsony',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Karácsony App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _servicesFound = false;
  bool _castConnected = false;
  ServiceDiscovery _serviceDiscovery;
  CastSender _castSender;

  List _videoItems = [
    CastMedia(
      title: 'Zene',
      contentId:
          'https://raw.githubusercontent.com/megamegax/christmas-app/master/app/src/main/res/raw/mennybol.mp3',
      images: [
        'https://img.casual.hu/shops/2013/images/item/szalveta-karacsonyi-angyal-es-nyuszi-xmas-angel-and-rabbitts-581588.jpg?v=1607969862'
      ],
    ),
    CastMedia(
        title: 'Csengő',
        contentId:
            'https://raw.githubusercontent.com/megamegax/christmas-app/master/app/src/main/res/raw/csengo.mp3',
        images: [
          'https://images.minimano.hu/bolcsi_ovi_felkeszules/ovisjelek/csengo/ovodai_jelkeszlet_16_darabos_csengo_1.jpg'
        ])
  ];

  void initState() {
    super.initState();

    _reconnectOrDiscover();
  }

  _reconnectOrDiscover() async {
    bool reconnectSuccess = await reconnect();
    if (!reconnectSuccess) {
      _discover();
    }
  }

  _discover() async {
    _serviceDiscovery = ServiceDiscovery();
    _serviceDiscovery.changes.listen((_) {
      setState(
          () => _servicesFound = _serviceDiscovery.foundServices.length > 0);
    });
    _serviceDiscovery.startDiscovery();
  }

  Future<bool> reconnect() async {
    final prefs = await SharedPreferences.getInstance();
    String host = prefs.getString('cast_session_host');
    String name = prefs.getString('cast_session_device_name');
    String type = prefs.getString('cast_session_device_type');
    String sourceId = prefs.getString('cast_session_sender_id');
    String destinationId = prefs.getString('cast_session_destination_id');
    if (null == host ||
        null == name ||
        null == type ||
        null == sourceId ||
        null == destinationId) {
      return false;
    }
    CastDevice device = CastDevice(
        name: name,
        host: host,
        port: prefs.getInt('cast_session_port') ?? 8009,
        type: type);
    _castSender = CastSender(device);
    StreamSubscription subscription = _castSender.castSessionController.stream
        .listen((CastSession castSession) {
      print('CastSession update ${castSession.isConnected.toString()}');
      if (castSession.isConnected) {
        _castSessionIsConnected(castSession);
      }
    });
    bool didReconnect = await _castSender.reconnect(
      sourceId: sourceId,
      destinationId: destinationId,
    );
    if (!didReconnect) {
      subscription.cancel();
      _castSender = null;
    }
    return didReconnect;
  }

  void disconnect() async {
    if (null != _castSender) {
      await _castSender.disconnect();
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('cast_session_host');
      prefs.remove('cast_session_port');
      prefs.remove('cast_session_device_name');
      prefs.remove('cast_session_device_type');
      prefs.remove('cast_session_sender_id');
      prefs.remove('cast_session_destination_id');
      setState(() {
        _castSender = null;
        _servicesFound = false;
        _castConnected = false;
        _discover();
      });
    }
  }

  void _castSessionIsConnected(CastSession castSession) async {
    setState(() {
      _castConnected = true;
    });

    final prefs = await SharedPreferences.getInstance();
    prefs.setString('cast_session_host', _castSender.device.host);
    prefs.setInt('cast_session_port', _castSender.device.port);
    prefs.setString('cast_session_device_name', _castSender.device.name);
    prefs.setString('cast_session_device_type', _castSender.device.type);
    prefs.setString('cast_session_sender_id', castSession.sourceId);
    prefs.setString('cast_session_destination_id', castSession.destinationId);
  }

  void _connectToDevice(CastDevice device) async {
    // stop discovery, only has to be on when we're not casting already
    _serviceDiscovery.stopDiscovery();

    _castSender = CastSender(device);
    StreamSubscription subscription = _castSender.castSessionController.stream
        .listen((CastSession castSession) {
      if (castSession.isConnected) {
        _castSessionIsConnected(castSession);
      }
    });
    bool connected = await _castSender.connect();
    if (!connected) {
      // show error message...
      subscription.cancel();
      _castSender = null;
      return;
    }

    // SAVE STATE SO WE CAN TRY TO RECONNECT!
    _castSender.launch();
  }

  Widget _buildVideoListItem(BuildContext context, int index) {
    CastMedia castMedia = _videoItems[index];
    return GestureDetector(
      onTap: () => null != _castSender ? _castSender.load(castMedia) : null,
      child: Card(
        child: Column(
          children: <Widget>[
            Container(
                width: 200,
                height: 200,
                child: Image.network(castMedia.images.first)),
            Text(castMedia.title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actionButtons = [];
    if (_servicesFound || _castConnected) {
      IconData iconData = _castConnected ? Icons.cast_connected : Icons.cast;
      actionButtons.add(
        IconButton(
          icon: Icon(iconData),
          onPressed: () {
            if (_castConnected) {
              print('SHOW DISCONNECT DIALOG!');
              // for now just immediately disconnect
              disconnect();
              return;
            }
            Navigator.of(context).push(new MaterialPageRoute(
              builder: (BuildContext context) => DevicePicker(
                  serviceDiscovery: _serviceDiscovery,
                  onDevicePicked: _connectToDevice),
              fullscreenDialog: true,
            ));
          },
        ),
      );
    }
    // TODO: if connected, also show (even if there are no services found)

    List<Widget> stackChildren = [
      ListView.builder(
        itemBuilder: _buildVideoListItem,
        itemCount: _videoItems.length,
      ),
    ];

    if (null != _castSender) {
      stackChildren.add(Positioned(
        bottom: 0.0,
        right: 0.0,
        left: 0.0,
        child: Card(child: CastMiniMediaControls(_castSender, canExtend: true)),
      ));
    }

    return Builder(builder: (BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
          actions: actionButtons,
        ),
        body: Stack(children: stackChildren),
      );
    });
  }
}
