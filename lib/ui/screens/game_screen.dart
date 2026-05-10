import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/game/game_bloc.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/domino.dart';
import '../../engine/game_engine.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final bool isLocalAI;
  final GameMode? localMode;
  final Player? localPlayer;

  const GameScreen({
    Key? key,
    required this.gameId,
    this.isLocalAI = false,
    this.localMode,
    this.localPlayer,
  }) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    if (widget.isLocalAI) {
      context.read<GameBloc>().add(InitializeLocalAIGame(widget.localMode!, widget.localPlayer!));
    } else {
      // For online, we assume currentUser is already known by the lobby, but we can pass localPlayer.id here
      // Ideally passed cleanly from route
      final currentUserId = widget.localPlayer?.id ?? context.read<GameBloc>().state.currentUserId ?? '';
      context.read<GameBloc>().add(JoinOnlineGame(widget.gameId, currentUserId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameBlocState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
        if (state.gameState?.status == GameStatus.finished) {
           _showGameOverDialog(context, state.gameState!);
        }
      },
      builder: (context, state) {
        if (state.isLoading || state.gameState == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E5631),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final gameState = state.gameState!;
        final currentPlayerId = state.currentUserId;

        // Find me and opponent
        final meIndex = gameState.players.indexWhere((p) => p.id == currentPlayerId);
        if (meIndex == -1) return const Scaffold(body: Center(child: Text("Error loading player")));

        final me = gameState.players[meIndex];
        final opponent = gameState.players[(meIndex + 1) % 2];

        return Scaffold(
          backgroundColor: const Color(0xFF1E5631), // Felt green
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              gameState.status == GameStatus.waiting
                  ? 'Waiting for opponent...'
                  : (gameState.currentPlayerId == me.id ? 'Your Turn' : "\${opponent.name}'s Turn"),
            ),
            actions: [
              if (gameState.mode == GameMode.draw)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(child: Text('Boneyard: \${gameState.boneyard.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                ),
            ],
          ),
          body: Column(
            children: [
              // Opponent Area
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    opponent.hand.length,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Container(
                        width: 30,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black),
                        ),
                        child: const Center(child: Icon(Icons.help_outline, size: 16)),
                      ),
                    ),
                  ),
                ),
              ),

              // Interactive Board Area
              Expanded(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.5,
                  maxScale: 2.0,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (gameState.board.isEmpty)
                          DragTarget<Domino>(
                            onAccept: (domino) {
                              context.read<GameBloc>().add(PlayDomino(domino, onHead: true));
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: Text('Play Here', style: TextStyle(color: Colors.white))),
                              );
                            },
                          )
                        else
                          // Render the board simple list for now, ideally layout algorithm
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: gameState.board.map((d) => _buildBoardDomino(d)).toList(),
                          ),

                        // Drop targets at ends
                        if (gameState.board.isNotEmpty) ...[
                           Positioned(
                             left: -60,
                             child: DragTarget<Domino>(
                               onWillAccept: (domino) => domino != null && domino.contains(gameState.headValue!),
                               onAccept: (domino) => context.read<GameBloc>().add(PlayDomino(domino, onHead: true)),
                               builder: (context, candidateData, rejectedData) => Container(
                                 width: 50, height: 50, color: candidateData.isNotEmpty ? Colors.green.withOpacity(0.5) : Colors.transparent,
                               ),
                             )
                           ),
                           Positioned(
                             right: -60,
                             child: DragTarget<Domino>(
                               onWillAccept: (domino) => domino != null && domino.contains(gameState.tailValue!),
                               onAccept: (domino) => context.read<GameBloc>().add(PlayDomino(domino, onHead: false)),
                               builder: (context, candidateData, rejectedData) => Container(
                                 width: 50, height: 50, color: candidateData.isNotEmpty ? Colors.green.withOpacity(0.5) : Colors.transparent,
                               ),
                             )
                           ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons
              if (gameState.currentPlayerId == me.id && gameState.status == GameStatus.playing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (gameState.mode == GameMode.draw && gameState.boneyard.isNotEmpty)
                        ElevatedButton(
                          onPressed: () => context.read<GameBloc>().add(DrawDomino()),
                          child: const Text('Draw'),
                        ),
                      if (!DominoGameEngine.hasValidMove(gameState, me.id) && (gameState.mode == GameMode.block || gameState.boneyard.isEmpty))
                        ElevatedButton(
                          onPressed: () => context.read<GameBloc>().add(PassTurn()),
                          child: const Text('Pass'),
                        ),
                    ],
                  ),
                ),

              // Player Hand
              Container(
                height: 120,
                padding: const EdgeInsets.all(16),
                color: Colors.black26,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: me.hand.map((domino) {
                      bool isPlayable = gameState.currentPlayerId == me.id && DominoGameEngine.canPlay(gameState, domino);
                      return Draggable<Domino>(
                        data: domino,
                        feedback: _buildDominoTile(domino, true),
                        childWhenDragging: Opacity(opacity: 0.3, child: _buildDominoTile(domino, false)),
                        maxSimultaneousDrags: isPlayable ? 1 : 0,
                        child: Opacity(
                          opacity: isPlayable ? 1.0 : 0.6,
                          child: _buildDominoTile(domino, false),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDominoTile(Domino domino, bool isDragging) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 40,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: isDragging ? [const BoxShadow(blurRadius: 10, color: Colors.black45)] : [],
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        children: [
          Expanded(child: Center(child: Text('\${domino.val1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Container(height: 2, color: Colors.black),
          Expanded(child: Center(child: Text('\${domino.val2}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildBoardDomino(Domino domino) {
    // Simple vertical or horizontal rendering based on double
    bool isVertical = domino.isDouble;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: isVertical ? 40 : 80,
      height: isVertical ? 80 : 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black),
      ),
      child: isVertical
        ? Column(
            children: [
              Expanded(child: Center(child: Text('\${domino.val1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
              Container(height: 2, color: Colors.black),
              Expanded(child: Center(child: Text('\${domino.val2}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
            ],
          )
        : Row(
            children: [
              Expanded(child: Center(child: Text('\${domino.val1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
              Container(width: 2, color: Colors.black),
              Expanded(child: Center(child: Text('\${domino.val2}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
            ],
          )
    );
  }

  void _showGameOverDialog(BuildContext context, GameState state) {
     String message = "It's a draw!";
     if (state.winnerId != null) {
       final winnerName = state.players.firstWhere((p) => p.id == state.winnerId).name;
       message = state.isBlocked ? "Game Blocked! \$winnerName wins by points." : "\$winnerName wins!";
     }

     showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
           title: const Text('Game Over'),
           content: Text(message),
           actions: [
             ElevatedButton(
               onPressed: () {
                 Navigator.of(context).popUntil((route) => route.isFirst);
               },
               child: const Text('Back to Lobby'),
             )
           ],
        ),
     );
  }
}
