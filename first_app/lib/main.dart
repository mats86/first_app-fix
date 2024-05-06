import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:first_app/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart' as flutter_blue;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as flutter_bluetooth_serial;
import 'package:collection/collection.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection',
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ObjectDetectionPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          "assets/eyeicon.png",
          height: 300,
        ),
      ),
    );
  }
}

class ObjectDetectionPage extends StatefulWidget {
  @override
  _ObjectDetectionPageState createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage>
    with SingleTickerProviderStateMixin {
  flutter_bluetooth_serial.BluetoothConnection? _connection;
  List<Color> bubbleColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple
  ];
  List<double> bubbleSizes = [20.0, 25.0, 30.0, 35.0, 40.0];
  List<Bubble> _bubbles = [];
  late AnimationController _controller;
  flutter_blue.FlutterBlue flutterBlue = flutter_blue.FlutterBlue.instance;
  StreamSubscription? scanSubscription;
  bool _processing = false;
  String _result = '';
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _connectToBluetoothServer();
    _startBubbleAnimation();
    _generateRandomBubbles();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
    flutterBlue.startScan(timeout: Duration(seconds: 4));
    scanSubscription = flutterBlue.scanResults.listen((results) {
      for (flutter_blue.ScanResult r in results) {
        print('${r.device.name} found! rssi: ${r.rssi}');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_connection != null) {
      _connection!.dispose();
    }
    flutterBlue.stopScan();
    scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _connectToBluetoothServer() async {
    List<flutter_bluetooth_serial.BluetoothDevice> devices =
        await flutter_bluetooth_serial.FlutterBluetoothSerial.instance
            .getBondedDevices();
    String raspberryPiAddress = 'D8:3A:DD:5F:AD:2F';

    flutter_bluetooth_serial.BluetoothDevice? raspberryPiDevice =
        devices.firstWhereOrNull(
      (device) => device.address == raspberryPiAddress,
    );

    if (raspberryPiDevice != null) {
      try {
        _connection =
            await flutter_bluetooth_serial.BluetoothConnection.toAddress(
                raspberryPiAddress);
      } catch (error) {
        print('Error connecting to Bluetooth server: $error');
      }
    }
  }

  Future<void> _detectObjects() async {
    setState(() {
      _processing = true;
    });

    if (_connection != null) {
      try {
        _connection!.output.add(utf8.encode('take_picture\n'));
        await _connection!.output.allSent;

        List<int> bytes =
            (await _connection!.input?.toList() ?? []) as List<int>;

        String result = utf8.decode(bytes);
        print('Received result from Raspberry Pi: $result');
        setState(() {
          _result = result;
          _processing = false;
        });
        await flutterTts.speak('Processed has started. $_result');
      } catch (error) {
        print('Error communicating with Bluetooth server: $error');
        setState(() {
          _processing = false;
        });
      }
    } else {
      print('Not connected to Bluetooth server.');
      setState(() {
        _processing = false;
      });
    }
  }

  void _startBubbleAnimation() {
    Timer.periodic(Duration(milliseconds: 50), (timer) {
      setState(() {
        for (var bubble in _bubbles) {
          bubble.move();
        }
      });
    });
  }

  void _generateRandomBubbles() {
    _bubbles = List.generate(30, (_) => Bubble.random());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Vision',
          style: TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontFamily: 'Lugrasimo',
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu, color: Colors.blue),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      body: Stack(
        children: [
          ..._bubbles.map((bubble) {
            return Positioned(
              left: bubble.x,
              top: bubble.y,
              child: Container(
                width: bubble.size,
                height: bubble.size,
                decoration: BoxDecoration(
                  color: bubble.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
          Center(
            child: _processing
                ? CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Press the button to detect objects',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20.0),
                      ),
                      SizedBox(height: 20.0),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Container(
                            width: 110 + _controller.value * 20,
                            height: 110 + _controller.value * 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.camera_alt),
                              iconSize: 30,
                              onPressed: _detectObjects,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Text(
                'About Us',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: Text('Number of Objects to be Detected'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NumberOfObjectsSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              title: Text('Bluetooth Settings'),
              onTap: () {
                Navigator.pop(context);

                // var bluetoothManager = BluetoothManagerPage();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BluetoothManagerPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class Bubble {
  double x;
  double y;
  double size;
  Color color;
  double speedX;
  double speedY;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speedX,
    required this.speedY,
  });

  Bubble.random()
      : x = Random().nextDouble() * 400,
        y = Random().nextDouble() * 800,
        size = Random().nextDouble() * 20 + 10,
        color = Color.fromRGBO(
          Random().nextInt(255),
          Random().nextInt(255),
          Random().nextInt(255),
          0.7,
        ),
        speedX = Random().nextDouble() * 2 - 1,
        speedY = Random().nextDouble() * 2 - 1;

  void move() {
    x += speedX;
    y += speedY;
    if (x < -size || x > 400 + size) {
      x = Random().nextDouble() * 400;
    }
    if (y < -size || y > 800 + size) {
      y = Random().nextDouble() * 800;
    }
  }
}

class NumberOfObjectsSettingsPage extends StatefulWidget {
  @override
  _NumberOfObjectsSettingsPageState createState() =>
      _NumberOfObjectsSettingsPageState();
}

class _NumberOfObjectsSettingsPageState
    extends State<NumberOfObjectsSettingsPage> {
  double _numberOfObjects = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Number of Objects'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              value: _numberOfObjects,
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (newValue) {
                setState(() {
                  _numberOfObjects = newValue;
                });
              },
              label: _numberOfObjects.toStringAsFixed(0),
            ),
            SizedBox(height: 20),
            Text(
              'Number of Objects: ${_numberOfObjects.toInt()}',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class BluetoothManagerPage extends StatefulWidget {
    @override
  _BluetoothManagerPageState createState() => _BluetoothManagerPageState();
}
  
   

class _BluetoothManagerPageState extends State<BluetoothManagerPage> {
  final BluetoothManager bluetoothManager = BluetoothManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      bluetoothManager.runBluetoothApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(), // or any other widget if needed
    );
  }
}
