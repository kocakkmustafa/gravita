import 'dart:convert';

import 'program_model.dart';

/// Exact input/prescription binding for newly created schedules. This is a
/// deterministic equality token, not a security hash or an inferred identity
/// for legacy history. Existing dates and RPE never establish this binding.
String programSignature(ProgramInputs inputs, WorkoutProgram program) {
  final equipment = inputs.availableEquipment.toList()..sort();
  return jsonEncode(<String, Object?>{
    'bindingVersion': 1,
    'calendarPolicy': 'civil-week-v1',
    'equipment': equipment,
    'daysPerWeek': inputs.daysPerWeek,
    'experience': inputs.experience.name,
    'programId': program.programId,
    'days': <Object?>[
      for (final day in program.days)
        <String, Object?>{
          'week': day.weekNumber,
          'day': day.dayNumber,
          'deload': day.isDeload,
          'exercises': <Object?>[
            for (final exercise in day.exercises)
              <String, Object?>{
                'movementId': exercise.movementId,
                'sets': exercise.sets,
                'hold': exercise.isHold,
                'reps': exercise.targetReps,
                'seconds': exercise.targetHoldSeconds,
                'restSeconds': exercise.restSeconds,
                'live': exercise.isLiveMeasured,
              },
          ],
        },
    ],
  });
}
