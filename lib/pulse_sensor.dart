import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import 'language.dart';

const _heartRateService = '180d';
const _heartRateMeasurement = '2a37';

int? heartRateFromMeasurement(List<int> data) {
  if (data.length < 2) return null;
  final flags = data.first;
  // A sensor which reports contact explicitly must detect skin contact.
  if (flags & 0x06 == 0x04) return null;
  final wide = flags & 1 != 0;
  if (wide && data.length < 3) return null;
  final bpm = data[1] | (wide ? data[2] << 8 : 0);
  return bpm > 0 ? bpm : null;
}

ScanFilter _sensorFilter() => ScanFilter(
  withServices: [_heartRateService],
  withNamePrefix: ['Helio', 'Amazfit Helio'],
);

Future<BleDevice?> pickPulseSensor(BuildContext context) {
  if (kIsWeb) {
    // The browser chooser must open directly from the user's tap.
    return UniversalBle.requestDevice(
      scanFilter: _sensorFilter(),
      platformConfig: PickerPlatformConfig(
        web: WebOptions(optionalServices: [_heartRateService]),
      ),
    );
  }
  return showModalBottomSheet<BleDevice>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _PulseSensorPicker(),
  );
}

class _PulseSensorPicker extends StatefulWidget {
  const _PulseSensorPicker();

  @override
  State<_PulseSensorPicker> createState() => _PulseSensorPickerState();
}

class _PulseSensorPickerState extends State<_PulseSensorPicker> {
  final devices = <String, BleDevice>{};
  late final StreamSubscription<BleDevice> scan;
  late final Future<void> started;
  Future<void>? stopping;
  Timer? timeout;
  bool searching = true;
  bool failed = false;
  bool selecting = false;

  @override
  void initState() {
    super.initState();
    scan = UniversalBle.scanStream.listen((device) {
      if (mounted) setState(() => devices[device.deviceId] = device);
    });
    started = UniversalBle.startScan(
      scanFilter: _sensorFilter(),
      platformConfig: PlatformConfig(
        android: AndroidOptions(requestLocationPermission: false),
      ),
    );
    unawaited(watchScan());
  }

  Future<void> watchScan() async {
    try {
      await started;
      if (!mounted) return;
      timeout = Timer(const Duration(seconds: 12), () async {
        await stop();
        if (mounted) setState(() => searching = false);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          searching = false;
          failed = true;
        });
      }
    }
  }

  Future<void> stop() => stopping ??= stopScan();

  Future<void> stopScan() async {
    try {
      await started;
      await UniversalBle.stopScan();
    } catch (_) {
      // Permission may have been denied or the adapter may have turned off.
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    unawaited(scan.cancel());
    unawaited(stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(tr.pulseSensor),
          subtitle: Text(
            failed
                ? tr.pulseScanFailed
                : searching
                ? tr.pulseSearching
                : devices.isEmpty
                ? tr.pulseNoDevices
                : tr.pulseChooseSensor,
          ),
        ),
        if (searching) const LinearProgressIndicator(),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final device in devices.values)
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text(device.name ?? tr.pulseSensor),
                  onTap: selecting
                      ? null
                      : () async {
                          setState(() => selecting = true);
                          timeout?.cancel();
                          await stop();
                          if (context.mounted &&
                              ModalRoute.of(context)?.isCurrent == true) {
                            Navigator.pop(context, device);
                          }
                        },
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One connection scoped to the training screen. Heart-rate notifications time
/// out independently of the Bluetooth connection (e.g. strap removed).
class PulseMonitor extends ChangeNotifier {
  static const _sampleTimeout = Duration(seconds: 5);
  BleDevice? device;
  StreamSubscription<bool>? _connection;
  StreamSubscription<Uint8List>? _measurements;
  Timer? _expires;
  final Stopwatch _sampleAge = Stopwatch();
  int? _bpm;
  bool _closed = false;
  bool busy = false;

  int? get bpm => _sampleAge.elapsed < _sampleTimeout ? _bpm : null;

  Future<bool> connect(BleDevice selected) async {
    if (_closed || busy || device != null) return false;
    busy = true;
    device = selected;
    notifyListeners();
    final id = selected.deviceId;
    try {
      await UniversalBle.connect(id, timeout: const Duration(seconds: 12));
      if (_closed) return false;
      await UniversalBle.discoverServices(id);
      if (_closed) return false;
      _connection = UniversalBle.connectionStream(id).listen((connected) {
        if (!connected) unawaited(disconnect());
      });
      _measurements = UniversalBle.characteristicValueStream(
        id,
        _heartRateMeasurement,
        serviceId: _heartRateService,
      ).listen(_receive);
      await UniversalBle.subscribeNotifications(
        id,
        _heartRateService,
        _heartRateMeasurement,
      );
      if (_closed || device != selected) return false;
      busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      await disconnect();
      return false;
    } finally {
      if (_closed) await _disconnectDevice(id);
    }
  }

  void _receive(Uint8List data) {
    _expires?.cancel();
    _sampleAge
      ..reset()
      ..start();
    _bpm = heartRateFromMeasurement(data);
    if (_bpm != null) {
      _expires = Timer(_sampleTimeout, () {
        _bpm = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    final id = device?.deviceId;
    if (id == null) return;
    device = null;
    busy = true;
    _bpm = null;
    _expires?.cancel();
    final connection = _connection;
    final measurements = _measurements;
    _connection = null;
    _measurements = null;
    if (!_closed) notifyListeners();
    await connection?.cancel();
    await measurements?.cancel();
    await _disconnectDevice(id);
    busy = false;
    if (!_closed) notifyListeners();
  }

  Future<void> _disconnectDevice(String id) async {
    try {
      await UniversalBle.disconnect(id);
    } catch (_) {
      // Already disconnected or Bluetooth was turned off.
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
