import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/player.dart';
import '../../models/game_state.dart';
import '../../services/firestore_service.dart';

abstract class LobbyEvent extends Equatable {
  const LobbyEvent();
  @override
  List<Object?> get props => [];
}

class StartLobby extends LobbyEvent {
  final String currentUserId;
  final String currentUserName;
  const StartLobby(this.currentUserId, this.currentUserName);
  @override
  List<Object?> get props => [currentUserId, currentUserName];
}

class StopLobby extends LobbyEvent {
  final String currentUserId;
  final String currentUserName;
  const StopLobby(this.currentUserId, this.currentUserName);
  @override
  List<Object?> get props => [currentUserId, currentUserName];
}

class OnlineUsersUpdated extends LobbyEvent {
  final List<Player> users;
  const OnlineUsersUpdated(this.users);
  @override
  List<Object?> get props => [users];
}

class WaitingGamesUpdated extends LobbyEvent {
  final List<Map<String, dynamic>> games;
  const WaitingGamesUpdated(this.games);
  @override
  List<Object?> get props => [games];
}

class HostGameRequested extends LobbyEvent {
  final GameMode mode;
  final Player host;
  const HostGameRequested(this.mode, this.host);
  @override
  List<Object?> get props => [mode, host];
}

class JoinGameRequested extends LobbyEvent {
  final String gameId;
  final Player opponent;
  const JoinGameRequested(this.gameId, this.opponent);
  @override
  List<Object?> get props => [gameId, opponent];
}

class PlayWithAIRequested extends LobbyEvent {
  final GameMode mode;
  final Player player;
  const PlayWithAIRequested(this.mode, this.player);
  @override
  List<Object?> get props => [mode, player];
}

class LobbyState extends Equatable {
  final List<Player> onlineUsers;
  final List<Map<String, dynamic>> waitingGames;
  final String? navigatingToGameId;
  final bool isHosting;
  final bool isJoining;
  final bool isLocalAI;
  final GameMode? localMode;
  final Player? localPlayer;

  const LobbyState({
    this.onlineUsers = const [],
    this.waitingGames = const [],
    this.navigatingToGameId,
    this.isHosting = false,
    this.isJoining = false,
    this.isLocalAI = false,
    this.localMode,
    this.localPlayer,
  });

  LobbyState copyWith({
    List<Player>? onlineUsers,
    List<Map<String, dynamic>>? waitingGames,
    String? navigatingToGameId,
    bool? isHosting,
    bool? isJoining,
    bool? isLocalAI,
    GameMode? localMode,
    Player? localPlayer,
    bool clearNavigation = false,
  }) {
    return LobbyState(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      waitingGames: waitingGames ?? this.waitingGames,
      navigatingToGameId: clearNavigation ? null : (navigatingToGameId ?? this.navigatingToGameId),
      isHosting: isHosting ?? this.isHosting,
      isJoining: isJoining ?? this.isJoining,
      isLocalAI: isLocalAI ?? this.isLocalAI,
      localMode: localMode ?? this.localMode,
      localPlayer: localPlayer ?? this.localPlayer,
    );
  }

  @override
  List<Object?> get props => [onlineUsers, waitingGames, navigatingToGameId, isHosting, isJoining, isLocalAI, localMode, localPlayer];
}

class LobbyBloc extends Bloc<LobbyEvent, LobbyState> {
  final FirestoreService _firestoreService;
  StreamSubscription? _usersSub;
  StreamSubscription? _gamesSub;

  LobbyBloc({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const LobbyState()) {
    on<StartLobby>(_onStartLobby);
    on<StopLobby>(_onStopLobby);
    on<OnlineUsersUpdated>((event, emit) => emit(state.copyWith(onlineUsers: event.users)));
    on<WaitingGamesUpdated>((event, emit) => emit(state.copyWith(waitingGames: event.games)));
    on<HostGameRequested>(_onHostGameRequested);
    on<JoinGameRequested>(_onJoinGameRequested);
    on<PlayWithAIRequested>(_onPlayWithAIRequested);
  }

  void _onStartLobby(StartLobby event, Emitter<LobbyState> emit) {
    _firestoreService.updateUserStatus(event.currentUserId, event.currentUserName, true);

    _usersSub?.cancel();
    _usersSub = _firestoreService.streamOnlineUsers(event.currentUserId).listen((users) {
      add(OnlineUsersUpdated(users));
    });

    _gamesSub?.cancel();
    _gamesSub = _firestoreService.streamWaitingGames().listen((games) {
      add(WaitingGamesUpdated(games));
    });
  }

  void _onStopLobby(StopLobby event, Emitter<LobbyState> emit) {
    _firestoreService.updateUserStatus(event.currentUserId, event.currentUserName, false);
    _usersSub?.cancel();
    _gamesSub?.cancel();
  }

  void _onHostGameRequested(HostGameRequested event, Emitter<LobbyState> emit) async {
    emit(state.copyWith(isHosting: true));
    final gameId = await _firestoreService.hostGame(event.mode, event.host);
    emit(state.copyWith(isHosting: false, navigatingToGameId: gameId));
    emit(state.copyWith(clearNavigation: true)); // Reset
  }

  void _onJoinGameRequested(JoinGameRequested event, Emitter<LobbyState> emit) async {
    emit(state.copyWith(isJoining: true));
    await _firestoreService.joinGame(event.gameId, event.opponent);
    emit(state.copyWith(isJoining: false, navigatingToGameId: event.gameId));
    emit(state.copyWith(clearNavigation: true)); // Reset
  }

  void _onPlayWithAIRequested(PlayWithAIRequested event, Emitter<LobbyState> emit) {
    emit(state.copyWith(isLocalAI: true, localMode: event.mode, localPlayer: event.player));
    // Provide a dummy ID to trigger navigation
    emit(state.copyWith(navigatingToGameId: 'local_ai_game'));
    emit(state.copyWith(clearNavigation: true, isLocalAI: false));
  }

  @override
  Future<void> close() {
    _usersSub?.cancel();
    _gamesSub?.cancel();
    return super.close();
  }
}
