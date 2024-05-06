import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

 void main() {
  runApp(MyApp());
}
class BluetoothManager {
  void runBluetoothApp() {
    runApp(MyApp());
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          Provider(create: (_) => BluetoothService()),
          Provider(create: (_) => SharedPrefService()),
        ],
        child: HomePage(),
      ),
    );
  }
}


class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _value;
  bool _connected = false;
  bool _connecting = true;

  _autoConnect(BuildContext context) async {
    final SharedPref sharedPref =
        Provider.of<SharedPrefService>(context, listen: false);
    String address = await sharedPref.getAddress();
    if (address == 'nothing') {
      _connecting = false;
      return;
    } else {
      setState(() {
        _value = address;
      });
      _connect(context);
    }
  }

  @override
  void initState() {
    Future.delayed(Duration.zero, () {
      _autoConnect(context);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Bluetooth bluetooth = Provider.of<BluetoothService>(context);
    final SharedPref sharedPref = Provider.of<SharedPrefService>(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: Icon(Icons.bluetooth),
        title: Text("Bluetooth Control"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await sharedPref.getTurnOffFan();
          setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            color: Colors.white,
          ),
          child: ListView(
            children: <Widget>[
              FutureBuilder<List<BluetoothDevice>>(
                future: bluetooth.getDevices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: <Widget>[
                            DropdownButtonFormField(
                              items: snapshot.data!
                                  .map((e) => DropdownMenuItem(
                                        child: Text(e.name!),
                                        value: e.address,
                                      ))
                                  .toList(),
                              onChanged: _connected
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _value = value.toString();
                                      });
                                    },
                              value: _value,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              disabledHint: Text(
                                "Disconnect to change device",
                              ),
                            ),
                            MaterialButton(
                              child: Text(
                                _connected ? "Disconnect" : "Connect",
                                style: TextStyle(color: Colors.black),
                              ),
                              onPressed: _connecting
                                  ? null
                                  : () {
                                      if (_connected) {
                                        _disconnect(context);
                                      } else {
                                        _connect(context);
                                      }
                                    },
                              color: _connected ? Colors.red : Colors.green,
                              textColor: Colors.white,
                            )
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text("Turn on bluetooth"),
                    );
                  }
                  return CircularProgressIndicator();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  _connect(BuildContext context) async {
    final Bluetooth bluetooth =
        Provider.of<BluetoothService>(context, listen: false);
    final SharedPref sharedPref =
        Provider.of<SharedPrefService>(context, listen: false);
    bool status = await bluetooth.connectTo(_value!);
    await sharedPref.setAddress(_value!);
    if (status) {
      sharedPref.getStatus('light').then((value) {
        value ? bluetooth.write('L') : bluetooth.write('7');
      });
      sharedPref.getStatus('fan').then((value) {
        value ? bluetooth.write('F') : bluetooth.write('3');
      });
    }
    setState(() {
      _connected = status;
      _connecting = false;
    });
  }

  _disconnect(BuildContext context) async {
    final Bluetooth bluetooth =
        Provider.of<BluetoothService>(context, listen: false);
    bluetooth.disconnect();
    setState(() {
      _connected = false;
    });
  }
}

abstract class Bluetooth {
  Future<List<BluetoothDevice>> getDevices();
  Future<bool> connectTo(String address);
  Stream<BluetoothState> connectionState();
  void write(String message);
  Future<bool> disconnect();
}

class BluetoothService implements Bluetooth {
  final flutterBluetoothSerial = FlutterBluetoothSerial.instance;
  BluetoothConnection? bluetoothConnection;

  @override
  Future<List<BluetoothDevice>> getDevices() async {
    List<BluetoothDevice> devices =
        await flutterBluetoothSerial.getBondedDevices();
    try {
      if (devices.isNotEmpty) {
        return devices;
      }
    } on PlatformException {
      print("PlatformException");
    }
    return devices;
  }

  @override
  Future<bool> connectTo(String address) async {
    try {
      bluetoothConnection = await BluetoothConnection.toAddress(address);
      return bluetoothConnection!.isConnected;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<BluetoothState> connectionState() {
    return flutterBluetoothSerial.onStateChanged();
  }

  @override
  void write(String message) {
    if (bluetoothConnection!.isConnected) {
      bluetoothConnection!.output.add(utf8.encode(message));
    }
  }

  @override
  Future<bool> disconnect() async {
    if (bluetoothConnection!.isConnected) {
      await bluetoothConnection!.close();
      return false;
    }
    return false;
  }
}

abstract class SharedPref {
  Future<bool> setStatus(String key, bool value);
  Future<bool> getStatus(String key);
  Future<bool> setTurnOnLight();
  Future<bool> setTurnOnFan();
  Future<bool> setTurnOffLight();
  Future<bool> setTurnOffFan();
  Future<String> getTurnOnLight();
  Future<String> getTurnOnFan();
  Future<String> getTurnOffLight();
  Future<String> getTurnOffFan();
  Future<bool> setAddress(String address);
  Future<String> getAddress();
}

class SharedPrefService implements SharedPref {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  Future<bool> setAddress(String address) async {
    return await _prefs.then((pref) => pref.setString('address', address));
  }

  @override
  Future<String> getAddress() async {
    return await _prefs.then((pref) => pref.getString('address') ?? "nothing");
  }

  @override
  Future<bool> setStatus(String key, bool value) async {
    try {
      return await _prefs
          .then((pref) => pref.setBool(key, value).then((success) => value));
    } catch (e) {
      print(e.toString());
      return false;
    }
  }

  @override
  Future<bool> getStatus(String key) async {
    try {
      return await _prefs.then((pref) => pref.getBool(key) ?? false);
    } catch (e) {
      print(e);
      return false;
    }
  }

  @override
  Future<bool> setTurnOnLight() async {
    return await _prefs.then((pref) => pref
        .setString(
          'turnOnLight',
          DateTime.now().hour.toString() +
              ':' +
              DateTime.now().minute.toString() +
              ':' +
              DateTime.now().second.toString(),
        )
        .then((value) => value));
  }

  @override
  Future<String> getTurnOnLight() async {
    return await _prefs.then((pref) => pref.getString('turnOnLight')!);
  }

  @override
  Future<bool> setTurnOnFan() async {
    return await _prefs.then((pref) => pref
        .setString(
          'turnOnFan',
          DateTime.now().hour.toString() +
              ':' +
              DateTime.now().minute.toString() +
              ':' +
              DateTime.now().second.toString(),
        )
        .then((value) => value));
  }

  @override
  Future<String> getTurnOnFan() async {
    return await _prefs.then((pref) => pref.getString('turnOnFan')!);
  }

  @override
  Future<bool> setTurnOffLight() async {
    return await _prefs.then((pref) => pref
        .setString(
          'turnOffLight',
          DateTime.now().hour.toString() +
              ':' +
              DateTime.now().minute.toString() +
              ':' +
              DateTime.now().second.toString(),
        )
        .then((value) => value));
  }

  @override
  Future<String> getTurnOffLight() async {
    return await _prefs.then((pref) => pref.getString('turnOffLight')!);
  }

  @override
  Future<bool> setTurnOffFan() async {
    return await _prefs.then((pref) => pref
        .setString(
          'turnOffFan',
          DateTime.now().hour.toString() +
              ':' +
              DateTime.now().minute.toString() +
              ':' +
              DateTime.now().second.toString(),
        )
        .then((value) => value));
  }

  @override
  Future<String> getTurnOffFan() async {
    return await _prefs.then((pref) => pref.getString('turnOffFan')!);
  }
}
