import 'package:equatable/equatable.dart';

class StepDayModel extends Equatable {
  final String date;
  final int stepCount;
  final int sensorBaseline;
  final int lastSensorValue;
  final DateTime lastUpdated;

  const StepDayModel({
    required this.date,
    required this.stepCount,
    this.sensorBaseline = 0,
    this.lastSensorValue = 0,
    required this.lastUpdated,
  });

  factory StepDayModel.fromJson(Map<String, dynamic> json) => StepDayModel(
    date: json['date'] as String,
    stepCount: json['stepCount'] as int? ?? 0,
    sensorBaseline: json['sensorBaseline'] as int? ?? 0,
    lastSensorValue: json['lastSensorValue'] as int? ?? 0,
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'stepCount': stepCount,
    'sensorBaseline': sensorBaseline,
    'lastSensorValue': lastSensorValue,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  StepDayModel copyWith({
    String? date,
    int? stepCount,
    int? sensorBaseline,
    int? lastSensorValue,
    DateTime? lastUpdated,
  }) => StepDayModel(
    date: date ?? this.date,
    stepCount: stepCount ?? this.stepCount,
    sensorBaseline: sensorBaseline ?? this.sensorBaseline,
    lastSensorValue: lastSensorValue ?? this.lastSensorValue,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  @override
  List<Object?> get props => [date, stepCount, sensorBaseline, lastSensorValue];
}
