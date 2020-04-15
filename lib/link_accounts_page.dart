import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_auth_buttons/flutter_auth_buttons.dart';
import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum UIStatus {
  loading,
  done,
  error,
}

class LinkAccountsPage extends StatefulWidget {
  static final routeName = '/link_accounts';

  @override
  State<StatefulWidget> createState() => LinkAccountsPageState();
}

class LinkAccountsPageState extends State<LinkAccountsPage> {
  final StreamController<UIStatus> _uiController = StreamController();

  @override
  void dispose() {
    _uiController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: StreamBuilder<UIStatus>(
              initialData: UIStatus.done,
              stream: _uiController.stream,
              builder: (context, snapshot) {
                switch (snapshot.data) {
                  // Errors are already displayed as alert dialogs
                  case UIStatus.done:
                  case UIStatus.error:
                    return FutureBuilder<FirebaseUser>(
                        future: FirebaseAuth.instance.currentUser(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return LoadedUI(
                                user: snapshot.data,
                                streamController: _uiController);
                          } else {
                            return CircularProgressIndicator();
                          }
                        });
                  default:
                    return CircularProgressIndicator();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

bool _hasLinkedProvider(String id, List<UserInfo> providersInfo) {
  for (final info in providersInfo) {
    if (info.providerId == id) {
      return true;
    }
  }
  return false;
}

void _showDialog(BuildContext context, String errorMessage) {
  // flutter defined function
  showDialog<dynamic>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return AlertDialog(
        title: Text('There was a problem'),
        content: Text(errorMessage),
        actions: <Widget>[
          // usually buttons at the bottom of the dialog
          FlatButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

class LoadedUI extends StatelessWidget {
  final FirebaseUser user;
  final StreamController<UIStatus> streamController;

  const LoadedUI({Key key, this.user, this.streamController}) : super(key: key);

  Future<void> _linkGoogle(FirebaseUser user) async {
    // signal to change UI
    streamController.add(UIStatus.loading);

    try {
      final _googleSignIn = GoogleSignIn(scopes: <String>['email']);
      final _googleUser = await _googleSignIn.signIn();

      // if the user canceled signin, an error is thrown but it gets swallowed
      // by the signIn() method so we need to reset the UI and close the stream
      if (_googleUser == null) {
        streamController.add(UIStatus.done);
        return;
      }

      final googleAuth = await _googleUser.authentication;

      final credential = GoogleAuthProvider.getCredential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.linkWithCredential(credential);

      // we are linked so reload the user's data and reset the UI
      await user.reload();
      streamController.add(UIStatus.done);
    } catch (error) {
      // reset the UI and display an alert
      streamController.add(UIStatus.error);
      // errors with code kSignInCanceledError are swallowed by the
      // GoogleSignIn.signIn() method so we can assume anything caught here
      // is unexpected and for display
      rethrow;
    }
  }

  Future<void> _linkFacebook(FirebaseUser user) async {
    // signal to change UI
    streamController.add(UIStatus.loading);

    try {
      final facebookLogin = FacebookLogin();
      final result = await facebookLogin.logIn(['email']);

      switch (result.status) {
        case FacebookLoginStatus.loggedIn:

          /// the auth info will be picked up by the listener on [onAuthStateChanged]
          /// and emitted by [streamOfStateChanges]

          final credential = FacebookAuthProvider.getCredential(
              accessToken: result.accessToken.token);

          await user.linkWithCredential(credential);

          // we are signed in so reload the user's data and reset the UI
          await user.reload();
          streamController.add(UIStatus.done);
          break;
        case FacebookLoginStatus.cancelledByUser:
          streamController.add(UIStatus.done);
          break;
        case FacebookLoginStatus.error:
          streamController.add(UIStatus.error);
          throw result.errorMessage;
          break;
      }
    } catch (error) {
      // reset the UI and display an alert
      streamController.add(UIStatus.error);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    var buttons = <Widget>[];
    var theme = Theme.of(context);

    if (!_hasLinkedProvider('google.com', user.providerData)) {
      buttons.add(GoogleSignInButton(
        onPressed: () {
          _linkGoogle(user)
              .catchError((Object err) => _showDialog(context, err.toString()));
        },
      ));
    }

    if (!_hasLinkedProvider('facebook.com', user.providerData)) {
      buttons.add(FacebookSignInButton(
        onPressed: () {
          _linkFacebook(user)
              .catchError((Object err) => _showDialog(context, err.toString()));
        },
      ));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          buttons.isEmpty ? Icons.check_circle_outline : Icons.group_add,
          size: 100,
          color: theme.accentColor,
        ),
        SizedBox(height: 16),
        Text(
          buttons.isEmpty ? 'Accounts linked' : 'Link accounts',
          style: theme.textTheme.headline5,
        ),
        SizedBox(height: 16),
        Text(
          buttons.isEmpty
              ? 'You already linked all your social accounts.'
              : 'You can sign in to this app with your social accounts by linking them to your profile.',
          style: theme.textTheme.bodyText1,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 32),
        ...buttons,
      ],
    );
  }
}
