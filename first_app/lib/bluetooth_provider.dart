import 'dart:convert';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/foundation.dart';

class BluetoothProvider with ChangeNotifier {
  BluetoothConnection? _connection;
  bool _isConnecting = false;
  String? _connectingDeviceId;
  String? _connectedDeviceName;

  BluetoothConnection? get connection => _connection;
  bool get isConnecting => _isConnecting;
  String? get connectingDeviceId => _connectingDeviceId;
  String? get connectedDeviceName => _connectedDeviceName;

  Future<void> connectToDevice(BluetoothDevice device, {int retryCount = 0}) async {
    if (_isConnecting || _connection != null) {
      if (kDebugMode) {
        print('Connection attempt skipped: already connecting or connected.');
      }
      return;
    }

    _isConnecting = true;
    _connectingDeviceId = device.address;
    _connectedDeviceName = device.name;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('Attempting to connect to ${device.address}');
      }
      _connection = await BluetoothConnection.toAddress(device.address);
      _connection?.input?.listen((Uint8List data) {
        if (kDebugMode) {
          print('Data incoming: ${ascii.decode(data)}');
        }
        _connection?.output.add(data); // Echo the data back

        if (ascii.decode(data).contains('!')) {
          disconnect(); // Handle disconnection
        }
      }).onDone(() {
        if (kDebugMode) {
          print('Disconnected by remote request');
        }
        disconnect(); // Handle disconnection when completed
      });
      if (kDebugMode) {
        print('Connection successful to ${device.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error on attempt $retryCount: $e');
      }
      if (retryCount < 3) {
        if (kDebugMode) {
          print('Connection attempt failed, retrying...');
        }
        await Future.delayed(const Duration(seconds: 2));
        connectToDevice(device, retryCount: retryCount + 1);  // Recursive retry
      } else {
        if (kDebugMode) {
          print('Error connecting to device after 3 attempts: $e');
        }
        if (kDebugMode) {
          print('Final error connecting to device: $e');
        }
        rethrow;
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void disconnect() {
    if (_connection != null) {
      _connection!.dispose();
      _connection = null;
      _connectedDeviceName = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
