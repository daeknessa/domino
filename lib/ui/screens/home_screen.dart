import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/lobby/lobby_bloc.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final user = (context.read<AuthBloc>().state as Authenticated).user;
    context.read<LobbyBloc>().add(StartLobby(user.uid, 'Player_\${user.uid.substring(0, 4)}'));
  }

  @override
  void dispose() {
    // Only stop lobby if we aren't navigating to a game
    // Ideally managed better, but safe for now.
    super.dispose();
  }

  void _showGameSettingsDialog(BuildContext context, bool isAI, {Player? opponent, String? joinGameId}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(joinGameId != null ? 'Join Game' : 'Game Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (joinGameId == null)
                const Text('Select game mode:'),
            ],
          ),
          actions: [
            if (joinGameId != null)
              ElevatedButton(
                onPressed: () {
                  final user = (context.read<AuthBloc>().state as Authenticated).user;
                  final player = Player(id: user.uid, name: 'Player_\${user.uid.substring(0, 4)}');
                  context.read<LobbyBloc>().add(JoinGameRequested(joinGameId, player));
                  Navigator.pop(dialogContext);
                },
                child: const Text('Join'),
              )
            else ...[
              ElevatedButton(
                onPressed: () => _startGame(GameMode.draw, isAI, opponent, dialogContext),
                child: const Text('Draw Mode'),
              ),
              ElevatedButton(
                onPressed: () => _startGame(GameMode.block, isAI, opponent, dialogContext),
                child: const Text('Block Mode'),
              ),
            ]
          ],
        );
      },
    );
  }

  void _startGame(GameMode mode, bool isAI, Player? opponent, BuildContext dialogContext) {
    final user = (context.read<AuthBloc>().state as Authenticated).user;
    final player = Player(id: user.uid, name: 'Player_\${user.uid.substring(0, 4)}');

    if (isAI) {
      context.read<LobbyBloc>().add(PlayWithAIRequested(mode, player));
    } else {
      context.read<LobbyBloc>().add(HostGameRequested(mode, player));
    }
    Navigator.pop(dialogContext);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyBloc, LobbyState>(
      listener: (context, state) {
        if (state.navigatingToGameId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                gameId: state.navigatingToGameId!,
                isLocalAI: state.isLocalAI,
                localMode: state.localMode,
                localPlayer: state.localPlayer,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lobby'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  final user = (context.read<AuthBloc>().state as Authenticated).user;
                  context.read<LobbyBloc>().add(StopLobby(user.uid, 'Player_\${user.uid.substring(0, 4)}'));
                  context.read<AuthBloc>().add(SignOutRequested());
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              )
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.computer),
                      label: const Text('Play with AI'),
                      onPressed: () => _showGameSettingsDialog(context, true),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Host Game'),
                      onPressed: state.isHosting ? null : () => _showGameSettingsDialog(context, false),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Waiting Games (Tap to join)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 1,
                child: state.waitingGames.isEmpty
                    ? const Center(child: Text('No games available'))
                    : ListView.builder(
                        itemCount: state.waitingGames.length,
                        itemBuilder: (context, index) {
                          final game = state.waitingGames[index];
                          return ListTile(
                            leading: const Icon(Icons.gamepad),
                            title: Text('\${game["hostName"] ?? "Unknown"}\'s Game'),
                            subtitle: Text('Mode: \${GameMode.values[game["mode"] as int? ?? 0].name}'),
                            onTap: state.isJoining
                                ? null
                                : () => _showGameSettingsDialog(context, false, joinGameId: game['id']),
                          );
                        },
                      ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Online Users', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: state.onlineUsers.isEmpty
                    ? const Center(child: Text('No users online'))
                    : ListView.builder(
                        itemCount: state.onlineUsers.length,
                        itemBuilder: (context, index) {
                          final user = state.onlineUsers[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(user.name),
                            trailing: const Icon(Icons.circle, color: Colors.green, size: 12),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
