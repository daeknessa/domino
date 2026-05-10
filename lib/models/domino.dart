import 'package:equatable/equatable.dart';

class Domino extends Equatable {
  final int val1;
  final int val2;
  final String id;

  const Domino({
    required this.val1,
    required this.val2,
    required this.id,
  });

  bool get isDouble => val1 == val2;
  int get totalPips => val1 + val2;

  bool contains(int value) => val1 == value || val2 == value;

  int getOtherValue(int value) {
    if (val1 == value) return val2;
    if (val2 == value) return val1;
    throw Exception('Value $value not found on domino $this');
  }

  Domino copyWith({
    int? val1,
    int? val2,
    String? id,
  }) {
    return Domino(
      val1: val1 ?? this.val1,
      val2: val2 ?? this.val2,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'val1': val1,
      'val2': val2,
      'id': id,
    };
  }

  factory Domino.fromJson(Map<String, dynamic> json) {
    return Domino(
      val1: json['val1'] as int,
      val2: json['val2'] as int,
      id: json['id'] as String,
    );
  }

  @override
  List<Object?> get props => [val1, val2, id];

  @override
  String toString() => '[$val1|$val2]';
}
