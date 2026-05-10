import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1v1 Score Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScoreTrackerPage(),
    );
  }
}

class ScoreTrackerPage extends StatefulWidget {
  const ScoreTrackerPage({super.key});

  @override
  State<ScoreTrackerPage> createState() => _ScoreTrackerPageState();
}

class _ScoreTrackerPageState extends State<ScoreTrackerPage> {
  String player1Name = '';
  String player2Name = '';
  int player1Total = 0;
  int player2Total = 0;
  int? winningGoal;
  String? winnerName;

  final TextEditingController _player1NameController = TextEditingController();
  final TextEditingController _player2NameController = TextEditingController();
  final TextEditingController _player1ScoreController = TextEditingController();
  final TextEditingController _player2ScoreController = TextEditingController();

  @override
  void dispose() {
    _player1NameController.dispose();
    _player2NameController.dispose();
    _player1ScoreController.dispose();
    _player2ScoreController.dispose();
    super.dispose();
  }

  void _showRulesDialog() {
    final TextEditingController goalController = TextEditingController(
      text: winningGoal?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Winning Goal'),
          content: TextField(
            controller: goalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Winning Goal',
              hintText: 'Enter a number',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (goalController.text.isNotEmpty) {
                    winningGoal = int.tryParse(goalController.text);
                  } else {
                    winningGoal = null;
                  }
                  _checkWinCondition();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _checkWinCondition() {
    if (winningGoal == null) {
      winnerName = null;
      return;
    }

    if (player1Total >= winningGoal!) {
      winnerName = player1Name.trim().isNotEmpty ? player1Name : 'Player 1';
    } else if (player2Total >= winningGoal!) {
      winnerName = player2Name.trim().isNotEmpty ? player2Name : 'Player 2';
    } else {
      winnerName = null;
    }
  }

  void _resetGame() {
    setState(() {
      player1Name = '';
      player2Name = '';
      player1Total = 0;
      player2Total = 0;
      winningGoal = null;
      winnerName = null;

      _player1NameController.clear();
      _player2NameController.clear();
      _player1ScoreController.clear();
      _player2ScoreController.clear();
    });
  }

  void _addScore(int playerIndex) {
    if (winnerName != null) return;

    setState(() {
      if (playerIndex == 1) {
        int scoreToAdd = int.tryParse(_player1ScoreController.text) ?? 0;
        player1Total += scoreToAdd;
        _player1ScoreController.clear();
      } else {
        int scoreToAdd = int.tryParse(_player2ScoreController.text) ?? 0;
        player2Total += scoreToAdd;
        _player2ScoreController.clear();
      }
      _checkWinCondition();
    });
  }

  Widget _buildPlayerColumn(int playerIndex) {
    final isPlayer1 = playerIndex == 1;
    final nameController = isPlayer1
        ? _player1NameController
        : _player2NameController;
    final scoreController = isPlayer1
        ? _player1ScoreController
        : _player2ScoreController;
    final totalScore = isPlayer1 ? player1Total : player2Total;

    return Column(
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: isPlayer1 ? 'Player 1 Name' : 'Player 2 Name',
          ),
          onChanged: (val) {
            setState(() {
              if (isPlayer1) {
                player1Name = val;
              } else {
                player2Name = val;
              }
              // If there's already a winner, update the winner's name dynamically if they change it
              if (winnerName != null) {
                _checkWinCondition();
              }
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: scoreController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Score to add'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: winnerName == null ? () => _addScore(playerIndex) : null,
          child: const Text('Add'),
        ),
        const Spacer(),
        Text('Total', style: Theme.of(context).textTheme.titleLarge),
        Text(
          '$totalScore',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1v1 Score Tracker'),
        actions: [
          TextButton(
            onPressed: _showRulesDialog,
            child: const Text('Rules', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: _resetGame,
            child: const Text('Reset', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPlayerColumn(1),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildPlayerColumn(2),
                ),
              ),
            ],
          ),
          if (winnerName != null)
            Center(
              child: Card(
                elevation: 12,
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48.0,
                    vertical: 32.0,
                  ),
                  child: Text(
                    '$winnerName Wins!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
