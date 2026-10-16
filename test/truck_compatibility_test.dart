import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorry_link/modules/loads/models/load_model.dart';
import 'package:lorry_link/modules/vehicles/widgets/truck_length_input.dart';

void main() {
  testWidgets('custom length responsive preview and controlled edits', (
    tester,
  ) async {
    if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
      await tester.runAsync(() async {
        for (final entry in {
          'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
          'MaterialIcons':
              'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final file = File(entry.value);
          if (await file.exists()) {
            await (FontLoader(entry.key)..addFont(
                  Future.value(ByteData.sublistView(await file.readAsBytes())),
                ))
                .load();
          }
        }
      });
    }
    final capture = GlobalKey();
    String? value = '17.55';
    for (final width in [390.0, 800.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: Material(
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: const TextScaler.linear(1.5),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 500,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: StatefulBuilder(
                          builder: (context, setState) => Form(
                            child: TruckLengthInput(
                              value: value,
                              allowAny: true,
                              onChanged: (next) => setState(() => value = next),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '18.25');
      await tester.pumpAndSettle();
      expect(value, '18.25');
      expect(find.text('18.25'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'artifacts/previews/custom_length_${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  LoadModel load(double tonnes, {String type = 'Pickup', double length = 10}) =>
      LoadModel(
        id: 'load',
        shipperId: 'customer',
        pickup: 'Kochi',
        destination: 'Kannur',
        cargo: 'Goods',
        vehicle: type,
        pickupDate: DateTime(2026, 10, 20),
        status: 'open',
        weightTonnes: tonnes,
        requiredVehicleLengthFt: length,
      );

  test('4-tonne general cargo truck accepts lighter compatible classes', () {
    for (final truck in ['Mini truck', 'Pickup', 'LCV', 'Open truck']) {
      final filter = LoadFilter(
        vehicle: truck,
        maxWeightTonnes: 4,
        minVehicleLengthFt: 17.55,
      );
      for (final type in ['Mini truck', 'Pickup', 'LCV', 'Open truck']) {
        for (final tonnes in [1.0, 1.5, 2.0, 3.0, 4.0]) {
          expect(filter.matchesTruckFit(load(tonnes, type: type)), isTrue);
        }
      }
      expect(filter.matchesTruckFit(load(4.01)), isFalse);
      expect(filter.matchesTruckFit(load(2, length: 17.56)), isFalse);
      for (final type in ['Container', 'Trailer', 'Refrigerated']) {
        expect(filter.matchesTruckFit(load(1, type: type)), isFalse);
      }
    }
    expect(vehicleTypeFitsLoad(' lcv ', 'LCV', ' pickup '), isTrue);
    expect(vehicleTypeFitsLoad('Container', 'Container', 'Pickup'), isFalse);
    expect(vehicleTypeFitsLoad('Container', 'Container', 'Container'), isTrue);
  });

  test('decimal lengths retain precision', () {
    expect(feetValue(20), '20');
    expect(feetValue(17.5), '17.5');
    expect(load(2, length: 17.55).vehicleLengthLabel, '17.55 ft');
  });

  testWidgets('custom length restores, validates and emits changes', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: TruckLengthInput(
              value: '17.55',
              onChanged: (value) => result = value,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Custom length'), findsOneWidget);
    expect(find.text('17.55'), findsOneWidget);
    expect(key.currentState!.validate(), isTrue);
    await tester.enterText(find.byType(TextFormField), '18.25');
    expect(result, '18.25');
    expect(key.currentState!.validate(), isTrue);
    for (final invalid in ['0', '-1', '81', 'NaN', 'Infinity', '12.123', '']) {
      await tester.enterText(find.byType(TextFormField), invalid);
      expect(key.currentState!.validate(), isFalse);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
