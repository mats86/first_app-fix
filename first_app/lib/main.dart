import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as flutter_bluetooth_serial;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import 'bluetooth_devices_page.dart';
import 'bluetooth_provider.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => ObjectDetectionSettings()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      title: 'Object Detection',
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ObjectDetectionPage()),
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
  const ObjectDetectionPage({super.key});

  @override
  ObjectDetectionPageState createState() => ObjectDetectionPageState();
}

class ObjectDetectionPageState extends State<ObjectDetectionPage>
    with TickerProviderStateMixin, RouteAware {
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
  StreamSubscription? scanSubscription;
  bool _processing = false;
  String _result = '';
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  void _initialize() {
    _connection =
        Provider.of<BluetoothProvider>(context, listen: false).connection;
    _startBubbleAnimation();
    _generateRandomBubbles();
    _controller = AnimationController(
      vsync: this, // Verwendet jetzt TickerProviderStateMixin
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    scanSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _refreshConnection();
  }

  @override
  void didPush() {
    super.didPush();
    _initialize();
  }

  void _refreshConnection() {
    _connection =
        Provider.of<BluetoothProvider>(context, listen: false).connection;
  }

  Future<void> detectObjects() async {
    setState(() {
      _processing = true;
    });

    if (_connection != null) {
      try {
        int numberOfObjects =
            Provider.of<ObjectDetectionSettings>(context, listen: false)
                .numberOfObjects;
        String command = 'take_picture,$numberOfObjects';
        _connection!.output.add(utf8.encode('$command\n'));
        await _connection!.output.allSent;

        _connection?.input?.asBroadcastStream().listen((Uint8List data) {
          String result = utf8.decode(data);
          if (kDebugMode) {
            print('Received result from Raspberry Pi: ${ascii.decode(data)}');
          }
          setState(() {
            _result = result;
            _processing = false;
          });
          flutterTts.speak('Processed has started. $_result');

        }).onDone(() {
          if (kDebugMode) {
            print('Disconnected by remote request');
          }
          // bluetooth.disconnect(); // Handle disconnection when completed
        });

      } catch (error) {
        if (kDebugMode) {
          print('Error communicating with Bluetooth server: $error');
        }
        setState(() {
          _processing = false;
        });
      }
    } else {
      if (kDebugMode) {
        print('Not connected to Bluetooth server.');
      }
      setState(() {
        _processing = false;
      });
    }
  }

  void _startBubbleAnimation() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Vision',
              style: TextStyle(
                color: Colors.black,
                fontSize: 30,
                fontFamily: 'Lugrasimo',
              ),
            ),
            Consumer<BluetoothProvider>(
              builder: (context, bluetooth, child) => Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Connected with: ${bluetooth.connectedDeviceName ?? "No device connected"}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (bluetooth.connectedDeviceName != null) ...[
                    IconButton(
                      icon: const Icon(Icons.link_off, color: Colors.red),
                      onPressed: () {
                        bluetooth.disconnect();
                      },
                      tooltip: 'Disconnect',
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.link_outlined, color: Colors.blue),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BluetoothDevicesPage(),
                          ),
                        );
                      },
                      tooltip: 'Connection',
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.blue),
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
                ));
          }),
          Center(
            child: _processing
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        'Press the button to detect objects',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20.0),
                      ),
                      const SizedBox(height: 20.0),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Container(
                            width: 110 + _controller.value * 20,
                            height: 110 + _controller.value * 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt),
                              iconSize: 30,
                              onPressed: detectObjects,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20.0),
                      Text(
                        _result.isEmpty
                            ? 'Waiting for results...'
                            : 'Result: $_result',
                        style: const TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
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
            const DrawerHeader(
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
              title: const Text('Number of Objects to be Detected'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NumberOfObjectsSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Bluetooth Settings'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const BluetoothDevicesPage()),
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
  const NumberOfObjectsSettingsPage({super.key});

  @override
  NumberOfObjectsSettingsPageState createState() =>
      NumberOfObjectsSettingsPageState();
}

class NumberOfObjectsSettingsPageState
    extends State<NumberOfObjectsSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Number of Objects'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              value:
                  Provider.of<ObjectDetectionSettings>(context, listen: false)
                      .numberOfObjects
                      .toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (newValue) {
                Provider.of<ObjectDetectionSettings>(context, listen: false)
                    .numberOfObjects = newValue.toInt();
              },
              label:
                  Provider.of<ObjectDetectionSettings>(context, listen: false)
                      .numberOfObjects
                      .toString(),
            ),
            const SizedBox(height: 20),
            Text(
              'Number of Objects: ${Provider.of<ObjectDetectionSettings>(context).numberOfObjects}',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectDetectionSettings with ChangeNotifier {
  int _numberOfObjects = 3; // Default-Wert

  int get numberOfObjects => _numberOfObjects;

  set numberOfObjects(int newValue) {
    _numberOfObjects = newValue;
    notifyListeners();
  }
}
