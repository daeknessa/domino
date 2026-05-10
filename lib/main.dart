import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/auth/auth_bloc.dart';
import 'bloc/lobby/lobby_bloc.dart';
import 'bloc/game/game_bloc.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Assuming correct options are provided or it's a stub)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase not configured. Stubs will fail unless setup properly. \$e");
  }

  final authService = AuthService();
  final firestoreService = FirestoreService();

  runApp(MyApp(authService: authService, firestoreService: firestoreService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final FirestoreService firestoreService;

  const MyApp({
    Key? key,
    required this.authService,
    required this.firestoreService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(authService: authService)..add(AppStarted()),
        ),
        BlocProvider(
          create: (_) => LobbyBloc(firestoreService: firestoreService),
        ),
        BlocProvider(
          create: (_) => GameBloc(firestoreService: firestoreService),
        ),
      ],
      child: MaterialApp(
        title: 'Dominoes Multiplayer',
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Colors.grey[200],
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
