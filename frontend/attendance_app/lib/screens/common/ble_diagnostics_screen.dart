import 'package:flutter/material.dart';
import '../../services/ble_mesh_service.dart';

class BleDiagnosticsScreen extends StatefulWidget {
  const BleDiagnosticsScreen({super.key});

  @override
  State<BleDiagnosticsScreen> createState() => _BleDiagnosticsScreenState();
}

class _BleDiagnosticsScreenState extends State<BleDiagnosticsScreen> {
  final _testSessionId = '11111111-1111-1111-1111-111111111111';
  String _status = 'Idle';
  int? _lastHopCount;
  int? _lastRssi;

  @override
  void dispose() {
    BleMeshService().stopAll();
    super.dispose();
  }

  Future<void> _startTeacher() async {
    setState(() => _status = 'Starting Teacher Broadcast (Hop 0)...');
    try {
      await BleMeshService().startTeacherBroadcast(_testSessionId);
      setState(() => _status = 'Broadcasting as Teacher (Hop 0)');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _startStudent() async {
    setState(() {
      _status = 'Scanning for Mesh Network...';
      _lastHopCount = null;
      _lastRssi = null;
    });
    try {
      final result = await BleMeshService().startStudentScanAndRelay(
        _testSessionId,
        timeout: const Duration(seconds: 30),
      );
      setState(() {
        _lastHopCount = result['hop_count'];
        _lastRssi = result['rssi'];
        _status = 'Received & Relaying (My Hop: ${_lastHopCount! + 1})';
      });
    } catch (e) {
      setState(() => _status = 'Error/Timeout: $e');
    }
  }

  Future<void> _stopAll() async {
    await BleMeshService().stopAll();
    setState(() {
      _status = 'Idle';
      _lastHopCount = null;
      _lastRssi = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Mesh Diagnostics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $_status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_lastHopCount != null)
              Text('Received Hop: $_lastHopCount'),
            if (_lastRssi != null)
              Text('Received RSSI: $_lastRssi dBm'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _startTeacher,
              child: const Text('Simulate Teacher (Start Broadcast)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _startStudent,
              child: const Text('Simulate Student (Scan & Relay)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _stopAll,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Stop All BLE Activity'),
            ),
          ],
        ),
      ),
    );
  }
}
