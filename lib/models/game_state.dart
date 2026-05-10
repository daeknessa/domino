import 'package:equatable/equatable.dart';
import 'domino.dart';
import 'player.dart';

enum GameMode { draw, block }

enum GameStatus { waiting, playing, finished }

class GameState extends Equatable {
  final String id;
  final GameMode mode;
  final GameStatus status;
  final List<Player> players;
  final List<Domino> boneyard;
  final List<Domino> board; // Simply stores the played dominoes in order for now.
  // Represents the values at the open ends of the board
  final int? headValue;
  final int? tailValue;
  final String currentPlayerId;
  final String? winnerId;
  final bool isBlocked;

  const GameState({
    required this.id,
    required this.mode,
    this.status = GameStatus.waiting,
    required this.players,
    this.boneyard = const [],
    this.board = const [],
    this.headValue,
    this.tailValue,
    required this.currentPlayerId,
    this.winnerId,
    this.isBlocked = false,
  });

  GameState copyWith({
    String? id,
    GameMode? mode,
    GameStatus? status,
    List<Player>? players,
    List<Domino>? boneyard,
    List<Domino>? board,
    int? headValue,
    int? tailValue,
    String? currentPlayerId,
    String? winnerId,
    bool? isBlocked,
    bool clearHeadValue = false,
    bool clearTailValue = false,
    bool clearWinnerId = false,
  }) {
    return GameState(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      players: players ?? this.players,
      boneyard: boneyard ?? this.boneyard,
      board: board ?? this.board,
      headValue: clearHeadValue ? null : (headValue ?? this.headValue),
      tailValue: clearTailValue ? null : (tailValue ?? this.tailValue),
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      winnerId: clearWinnerId ? null : (winnerId ?? this.winnerId),
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mode': mode.index,
      'status': status.index,
      'players': players.map((x) => x.toJson()).toList(),
      'boneyard': boneyard.map((x) => x.toJson()).toList(),
      'board': board.map((x) => x.toJson()).toList(),
      'headValue': headValue,
      'tailValue': tailValue,
      'currentPlayerId': currentPlayerId,
      'winnerId': winnerId,
      'isBlocked': isBlocked,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      id: json['id'] as String,
      mode: GameMode.values[json['mode'] as int],
      status: GameStatus.values[json['status'] as int],
      players: (json['players'] as List<dynamic>)
          .map((x) => Player.fromJson(x as Map<String, dynamic>))
          .toList(),
      boneyard: (json['boneyard'] as List<dynamic>)
          .map((x) => Domino.fromJson(x as Map<String, dynamic>))
          .toList(),
      board: (json['board'] as List<dynamic>)
          .map((x) => Domino.fromJson(x as Map<String, dynamic>))
          .toList(),
      headValue: json['headValue'] as int?,
      tailValue: json['tailValue'] as int?,
      currentPlayerId: json['currentPlayerId'] as String,
      winnerId: json['winnerId'] as String?,
      isBlocked: json['isBlocked'] as bool,
    );
  }

  @override
  List<Object?> get props => [
        id,
        mode,
        status,
        players,
        boneyard,
        board,
        headValue,
        tailValue,
        currentPlayerId,
        winnerId,
        isBlocked,
      ];
}
