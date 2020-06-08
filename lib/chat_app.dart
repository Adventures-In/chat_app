import 'package:adventures_in_chat_app/auth_page.dart';
import 'package:adventures_in_chat_app/chat_page.dart';
import 'package:adventures_in_chat_app/home_page.dart';
import 'package:adventures_in_chat_app/link_accounts_page.dart';
import 'package:adventures_in_chat_app/profile_page.dart';
import 'package:adventures_in_chat_app/services/database_service.dart';
import 'package:adventures_in_chat_app/splash_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatApp extends StatelessWidget {
  final DatabaseService db = DatabaseService(Firestore.instance);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(
          value: db,
        )
      ],
      child: MaterialApp(
        title: 'Adventures In',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        onGenerateRoute: (settings) {
          // If we push the ChatPage route
          if (settings.name == ChatPage.routeName) {
            // Cast the arguments to the correct type: ChatPageArgs.
            final args = settings.arguments as ChatPageArgs;

            // Then, extract the required data from the arguments and
            // pass the data to the correct screen.
            return MaterialPageRoute<dynamic>(
              builder: (context) {
                return ChatPage(
                  conversationItem: args.conversationItem,
                  currentUserId: args.currentUserId,
                  db: db,
                );
              },
            );
          }
          return MaterialPageRoute<dynamic>(builder: (context) {
            return Container();
          });
        },
        home: StreamBuilder<FirebaseUser>(
          stream: FirebaseAuth.instance.onAuthStateChanged,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData) {
                // set the database service to use the current user
                Provider.of<DatabaseService>(context, listen: false)
                    .currentUserId = snapshot.data.uid;
                return HomePage();
              } else {
                Provider.of<DatabaseService>(context, listen: false)
                    .currentUserId = null;
                return AuthPage();
              }
            }

            return SplashPage();
          },
        ),
        routes: {
          ProfilePage.routeName: (context) => ProfilePage(),
          LinkAccountsPage.routeName: (context) => LinkAccountsPage(),
        },
      ),
    );
  }
}