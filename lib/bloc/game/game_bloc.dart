import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/game_state.dart';
import '../../models/domino.dart';
import '../../models/player.dart';
import '../../engine/game_engine.dart';
import '../../engine/ai_opponent.dart';
import '../../services/firestore_service.dart';

abstract class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class InitializeLocalAIGame extends GameEvent {
  final GameMode mode;
  final Player player;
  const InitializeLocalAIGame(this.mode, this.player);
  @override
  List<Object?> get props => [mode, player];
}

class JoinOnlineGame extends GameEvent {
  final String gameId;
  final String currentUserId;
  const JoinOnlineGame(this.gameId, this.currentUserId);
  @override
  List<Object?> get props => [gameId, currentUserId];
}

class GameStateUpdated extends GameEvent {
  final GameState state;
  const GameStateUpdated(this.state);
  @override
  List<Object?> get props => [state];
}

class PlayDomino extends GameEvent {
  final Domino domino;
  final bool onHead;
  const PlayDomino(this.domino, {this.onHead = true});
  @override
  List<Object?> get props => [domino, onHead];
}

class DrawDomino extends GameEvent {}

class PassTurn extends GameEvent {}

class GameBlocState extends Equatable {
  final GameState? gameState;
  final bool isLoading;
  final bool isLocalAI;
  final String? currentUserId;
  final String? errorMessage;

  const GameBlocState({
    this.gameState,
    this.isLoading = false,
    this.isLocalAI = false,
    this.currentUserId,
    this.errorMessage,
  });

  GameBlocState copyWith({
    GameState? gameState,
    bool? isLoading,
    bool? isLocalAI,
    String? currentUserId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GameBlocState(
      gameState: gameState ?? this.gameState,
      isLoading: isLoading ?? this.isLoading,
      isLocalAI: isLocalAI ?? this.isLocalAI,
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [gameState, isLoading, isLocalAI, currentUserId, errorMessage];
}

class GameBloc extends Bloc<GameEvent, GameBlocState> {
  final FirestoreService _firestoreService;
  StreamSubscription? _gameSub;

  GameBloc({required FirestoreService firestoreService})
      : _firestoreService = firestoreService,
        super(const GameBlocState()) {
    on<InitializeLocalAIGame>(_onInitializeLocalAIGame);
    on<JoinOnlineGame>(_onJoinOnlineGame);
    on<GameStateUpdated>(_onGameStateUpdated);
    on<PlayDomino>(_onPlayDomino);
    on<DrawDomino>(_onDrawDomino);
    on<PassTurn>(_onPassTurn);
  }

  void _onInitializeLocalAIGame(InitializeLocalAIGame event, Emitter<GameBlocState> emit) {
    emit(state.copyWith(isLoading: true, isLocalAI: true, currentUserId: event.player.id));

    final initialState = DominoGameEngine.startNewGame(
      gameId: 'local_ai',
      mode: event.mode,
      host: event.player,
      opponent: AIOpponent.aiPlayer,
    );

    add(GameStateUpdated(initialState));
  }

  void _onJoinOnlineGame(JoinOnlineGame event, Emitter<GameBlocState> emit) {
    emit(state.copyWith(isLoading: true, isLocalAI: false, currentUserId: event.currentUserId));

    _gameSub?.cancel();
    _gameSub = _firestoreService.streamGameState(event.gameId).listen((gameState) {
      // If the game just transitioned to playing and we are the host, initialize the board
      if (gameState.status == GameStatus.playing && gameState.board.isEmpty && gameState.players[0].id == event.currentUserId) {
        if (gameState.players.length == 2 && gameState.players[0].hand.isEmpty) {
             final initializedState = DominoGameEngine.startNewGame(
              gameId: gameState.id,
              mode: gameState.mode,
              host: gameState.players[0],
              opponent: gameState.players[1],
            );
            _firestoreService.updateGameState(initializedState);
            return;
        }
      }
      add(GameStateUpdated(gameState));
    }, onError: (error) {
       emit(state.copyWith(errorMessage: error.toString(), isLoading: false));
    });
  }

  void _onGameStateUpdated(GameStateUpdated event, Emitter<GameBlocState> emit) async {
    emit(state.copyWith(gameState: event.state, isLoading: false));

    // Handle AI Turn if it's AI's turn and game is local
    if (state.isLocalAI && event.state.currentPlayerId == AIOpponent.aiId && event.state.status == GameStatus.playing) {
      final bestMove = await AIOpponent.calculateBestMove(event.state);

      if (bestMove != null) {
        // AI plays domino
        // AI logic doesn't explicitly choose head/tail yet, just pick whichever fits
        bool onHead = true;
        if (event.state.board.isNotEmpty) {
           if (!bestMove.contains(event.state.headValue!)) {
             onHead = false;
           }
        }
        final newState = DominoGameEngine.playDomino(event.state, bestMove, onHead: onHead);
        add(GameStateUpdated(newState));
      } else {
        // AI must draw or pass
        if (event.state.mode == GameMode.draw && event.state.boneyard.isNotEmpty) {
           GameState tempState = event.state;
           bool foundMove = false;
           while(tempState.boneyard.isNotEmpty && !foundMove) {
              tempState = DominoGameEngine.drawDomino(tempState);
              // Wait a bit to simulate drawing
              await Future.delayed(const Duration(milliseconds: 500));
              emit(state.copyWith(gameState: tempState));
              if (DominoGameEngine.hasValidMove(tempState, AIOpponent.aiId)) {
                foundMove = true;
                // Re-evaluate to play
                add(GameStateUpdated(tempState));
                return;
              }
           }
           if (!foundMove) {
             final newState = DominoGameEngine.passTurn(tempState);
             add(GameStateUpdated(newState));
           }
        } else {
           final newState = DominoGameEngine.passTurn(event.state);
           add(GameStateUpdated(newState));
        }
      }
    }
  }

  void _onPlayDomino(PlayDomino event, Emitter<GameBlocState> emit) {
    if (state.gameState == null || state.gameState!.currentPlayerId != state.currentUserId) return;

    try {
      final newState = DominoGameEngine.playDomino(state.gameState!, event.domino, onHead: event.onHead);
      _updateState(newState);
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Invalid move: \${e.toString()}'));
      emit(state.copyWith(clearError: true));
    }
  }

  void _onDrawDomino(DrawDomino event, Emitter<GameBlocState> emit) {
    if (state.gameState == null || state.gameState!.currentPlayerId != state.currentUserId) return;

    try {
      final newState = DominoGameEngine.drawDomino(state.gameState!);
      _updateState(newState);
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Cannot draw: \${e.toString()}'));
      emit(state.copyWith(clearError: true));
    }
  }

  void _onPassTurn(PassTurn event, Emitter<GameBlocState> emit) {
     if (state.gameState == null || state.gameState!.currentPlayerId != state.currentUserId) return;

     try {
       final newState = DominoGameEngine.passTurn(state.gameState!);
       _updateState(newState);
     } catch (e) {
        emit(state.copyWith(errorMessage: 'Cannot pass: \${e.toString()}'));
        emit(state.copyWith(clearError: true));
     }
  }

  void _updateState(GameState newState) {
    if (state.isLocalAI) {
      add(GameStateUpdated(newState));
    } else {
      _firestoreService.updateGameState(newState);
    }
  }

  @override
  Future<void> close() {
    _gameSub?.cancel();
    return super.close();
  }
}
