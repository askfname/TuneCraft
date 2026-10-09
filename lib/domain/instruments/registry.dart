import 'guitar.dart';
import 'instrument.dart';

/// 乐器注册表：后期加乐器只需在此追加
class InstrumentRegistry {
  static List<Instrument> all() => [
        GuitarStandardInstrument(),
        // BassStandardInstrument(),
        // UkuleleStandardInstrument(),
      ];

  static Instrument byId(String id) =>
      all().firstWhere((e) => e.id == id, orElse: () => all().first);
}
