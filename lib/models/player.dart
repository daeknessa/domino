import 'package:equatable/equatable.dart';
import 'domino.dart';

class Player extends Equatable {
  final String id;
  final String name;
  final List<Domino> hand;

  const Player({
    required this.id,
    required this.name,
    this.hand = const [],
  });

  Player copyWith({
    String? id,
    String? name,
    List<Domino>? hand,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? this.hand,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hand': hand.map((x) => x.toJson()).toList(),
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      hand: (json['hand'] as List<dynamic>?)
              ?.map((x) => Domino.fromJson(x as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [id, name, hand];
}
