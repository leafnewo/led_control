import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Led sign Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BluetoothPage(),
    );
  }
}

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txCharacteristic;
  bool _connected = false;

  final TextEditingController _controller = TextEditingController();

  // UUIDs (must match Arduino)
  final Guid serviceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid txUuid = Guid("12345678-1234-5678-1234-56789abcdef1");

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        debugPrint('Found device: ${r.device.name} (${r.device.id})');

        if (r.device.name == "Nano33IOT") {
          debugPrint("✅ Found Arduino, stopping scan...");
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _device = device;

    try {
      await device.connect();
      setState(() => _connected = true);
      debugPrint("✅ Connected to Arduino!");

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == txUuid) {
              _txCharacteristic = characteristic;
              debugPrint("✅ TX Characteristic found!");
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Connection error: $e");
    }
  }

  Future<void> _sendMessage(String message) async {
    if (_txCharacteristic == null || !_connected) {
      debugPrint("⚠️ Not connected or TX not ready");
      return;
    }

    await _txCharacteristic!.write(
      message.codeUnits,
      withoutResponse: false,
    );
    debugPrint("📤 Sent: $message");
  }

  void _refreshConnection() {
    if (_device != null) {
      _device!.disconnect();
      setState(() => _connected = false);
    }
    _startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Happy Birthday"),
        backgroundColor: Color.fromARGB(100, 160, 32, 240),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshConnection,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.jpg"), // ✅ your JPG background
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _connected ? "✅ Connected" : "❌ Not Connected",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // TextField with solid white background
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "",
                  filled: true,               // ✅ solid fill
                  fillColor: Colors.white,    // ✅ white background
                ),
              ),
              const SizedBox(height: 10),

              // Send button
              ElevatedButton(
                onPressed: _connected
                    ? () {
                  final msg = _controller.text;
                  if (msg.isNotEmpty) _sendMessage(msg);
                }
                    : null,
                child: const Text("Send Message"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
