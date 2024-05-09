import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import 'bluetooth_provider.dart';


class BluetoothDevicesPage extends StatefulWidget {
  const BluetoothDevicesPage({super.key});

  @override
  BluetoothDevicesPageState createState() => BluetoothDevicesPageState();
}

class BluetoothDevicesPageState extends State<BluetoothDevicesPage> {
  BluetoothDevice? connectingDevice;

  @override
  Widget build(BuildContext context) {
    final bluetoothProvider = Provider.of<BluetoothProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Available Bluetooth Devices")),
      body: FutureBuilder<List<BluetoothDevice>>(
        future: FlutterBluetoothSerial.instance.getBondedDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return ListView(
              children: snapshot.data!.map((device) => ListTile(
                title: Text(device.name ?? "Unknown device"),
                subtitle: Text(device.address),
                trailing: connectingDevice?.address == device.address
                    ? const CircularProgressIndicator() // Zeigt den Ladeindikator an, wenn der Verbindungsversuch läuft
                    : null,
                onTap: () async {
                  if (!bluetoothProvider.isConnecting && connectingDevice == null) {
                    setState(() {
                      connectingDevice = device; // Setzt das aktuell verbundene Gerät
                    });
                    try {
                      await bluetoothProvider.connectToDevice(device);

                      if (!context.mounted) return;
                      Navigator.pop(context); // Zurück zur Hauptseite
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to connect: $e"))
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          connectingDevice = null; // Setzt das Gerät zurück, wenn die Verbindung abgeschlossen oder fehlgeschlagen ist
                        });
                      }
                    }
                  }
                },
              )).toList(),
            );
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return const CircularProgressIndicator();
          }
        },
      ),
    );
  }
}
