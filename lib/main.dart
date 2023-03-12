import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox<String>('myBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Hive Multi-threading Example',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _receivePort = ReceivePort();
  late SendPort _sendPort;
  late Box<String> _box;
  String _value = '';

  @override
  void initState() {
    super.initState();
    _initializeIsolate();
    _box = Hive.box<String>('myBox');
  }

  Future<void> _initializeIsolate() async {
    final isolate = await Isolate.spawn(runInIsolate, _receivePort.sendPort);
    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
      }
    });
    _sendPort = await _receivePort.first;
  }

  @override
  void dispose() {
    _receivePort.close();
    super.dispose();
  }

  // Future<void> _getValueFromIsolate() async {
  //   final result = await _sendPort.call(['get', 'myKey']);
  //   setState(() {
  //     _value = result ?? '';
  //   });
  // }

  Future<void> _getValueFromIsolate() async {
    final response = ReceivePort();
    _sendPort.send(['get', 'myKey', response.sendPort]);
    final result = await response.first;

    setState(() {
      _value = result ?? '';
    });
  }

  // Future<void> _putValueInIsolate() async {
  //   final value = DateTime.now().toString();
  //   _box.put('myKey', value);
  //   await _sendPort.call(['put', 'myKey', value]);
  //   setState(() {
  //     _value = value;
  //   });
  // }

  Future<void> _putValueInIsolate() async {
    final value = DateTime.now().toString();
    _box.put('myKey', value);

    final response = ReceivePort();
    _sendPort.send(['put', 'myKey', value, response.sendPort]);
    await response.first;

    setState(() {
      _value = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hive Multi-threading Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Value in Hive Box: $_value',
              style: const TextStyle(fontSize: 20.0),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed:
                  // () {},
                  _getValueFromIsolate,
              child: const Text('Get Value from Isolate'),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed:
                  // () {},
                  _putValueInIsolate,
              child: const Text('Put Value in Isolate'),
            ),
          ],
        ),
      ),
    );
  }
}

void runInIsolate(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final box = await Hive.openBox<String>('myBox');

  await for (final message in receivePort) {
    final command = message[0];
    final key = message[1];
    final value = message[2];

    switch (command) {
      case 'get':
        final result = box.get(key);
        sendPort.send(result);
        break;
      case 'put':
        await box.put(key, value);
        break;
    }
  }

  await box.close();
}
