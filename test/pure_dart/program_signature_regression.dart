import 'dart:convert';
import 'dart:io';

import 'package:gravita/app/program/program_builder.dart';
import 'package:gravita/app/program/program_model.dart';
import 'package:gravita/app/program/program_signature.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

void main() {
  final configData =
      (jsonDecode(
                File('content/programs/foundation.v1.json').readAsStringSync(),
              )
              as Map)
          .cast<String, dynamic>();
  final config = ProgramConfig.fromJson(configData);
  const catalog = <ProgramCatalogEntry>[
    ProgramCatalogEntry(
      id: 'bodyweight',
      family: 'push',
      level: 'beginner',
      equipment: {},
      isHold: false,
      isLive: false,
    ),
    ProgramCatalogEntry(
      id: 'weighted',
      family: 'carry',
      level: 'beginner',
      equipment: {'dumbbells'},
      isHold: true,
      isLive: false,
    ),
    ProgramCatalogEntry(
      id: 'pull',
      family: 'pull',
      level: 'intermediate',
      equipment: {},
      isHold: false,
      isLive: false,
    ),
  ];
  final builder = ProgramBuilder(config: config, catalog: catalog);
  ProgramInputs inputs(Set<String> equipment, {int n = 4}) => ProgramInputs(
    availableEquipment: equipment,
    daysPerWeek: n,
    experience: ExperienceLevel.beginner,
  );
  final originalInputs = inputs({});
  final original = builder.build(originalInputs);
  final originalSignature = programSignature(originalInputs, original);
  var checks = 0;
  void verify(bool ok, String label) {
    check(ok, label);
    checks++;
  }

  verify(
    originalSignature ==
        programSignature(originalInputs, builder.build(originalInputs)),
    'Unchanged plan must bind deterministically',
  );
  final first = inputs({'dumbbells', 'kettlebell'});
  final reordered = inputs({'kettlebell', 'dumbbells'});
  verify(
    programSignature(first, builder.build(first)) ==
        programSignature(reordered, builder.build(reordered)),
    'Set insertion order must not change identity',
  );
  final weighted = inputs({'dumbbells'});
  verify(
    original.totalSessions == builder.build(weighted).totalSessions,
    'Same-frequency control retains length',
  );
  verify(
    originalSignature != programSignature(weighted, builder.build(weighted)),
    'Same-length equipment recipe change must not inherit RPE',
  );
  final intermediate = ProgramInputs(
    availableEquipment: {},
    daysPerWeek: 4,
    experience: ExperienceLevel.intermediate,
  );
  verify(
    originalSignature !=
        programSignature(intermediate, builder.build(intermediate)),
    'Experience change must change binding',
  );
  final revised = ProgramBuilder(
    config: ProgramConfig.fromJson({
      ...configData,
      'baseSets': config.baseSets + 1,
    }),
    catalog: catalog,
  );
  verify(
    originalSignature !=
        programSignature(originalInputs, revised.build(originalInputs)),
    'Dose change must change binding',
  );
  final otherFrequency = inputs({}, n: 3);
  verify(
    originalSignature !=
        programSignature(otherFrequency, builder.build(otherFrequency)),
    'Frequency change must change binding',
  );
  final identity = jsonDecode(originalSignature) as Map;
  verify(
    identity['calendarPolicy'] == 'civil-week-v1',
    'New calendar policy must be explicit, never retrofitted to legacy data',
  );
  print(
    jsonEncode({
      'checks': checks,
      'result': 'PASS',
      'scope':
          'Actual production builder and binding function; no UI or legacy migration',
    }),
  );
}
