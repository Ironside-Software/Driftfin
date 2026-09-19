import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/providers/arguments_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/shared/fladder_logo.dart';
import 'package:driftfin/screens/shared/route_wrapper.dart';
import 'package:driftfin/services/local_network_permission.dart';

@RoutePage()
class SplashScreen extends ConsumerStatefulWidget {
  final Function(bool loggedIn)? loggedIn;
  const SplashScreen({this.loggedIn, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((value) async {
      await Future.delayed(const Duration(milliseconds: 500));
      final AccountModel? lastUsedAccount = ref.read(sharedUtilityProvider).getActiveAccount();
      ref.read(userProvider.notifier).updateUser(lastUsedAccount);

      if (context.mounted) {
        if (lastUsedAccount == null || ref.read(argumentsStateProvider).newWindow == true) {
          callBackOrNavigate(false);
        } else {
          !await ensureLocalNetworkPermissions(
            [lastUsedAccount.credentials.url, lastUsedAccount.credentials.localUrl],
            context,
          );

          switch (lastUsedAccount.authMethod) {
            case Authentication.autoLogin:
              callBackOrNavigate(true);
              break;
            case Authentication.biometrics:
            case Authentication.none:
            case Authentication.passcode:
              callBackOrNavigate(false);
              break;
          }
        }
      }
    });
  }

  void callBackOrNavigate(bool loggedIn) {
    if (widget.loggedIn == null) {
      if (loggedIn) {
        context.router.replace(const DashboardRoute());
      } else {
        context.router.replace(LoginRoute());
      }
    } else {
      widget.loggedIn?.call(loggedIn);
      context.router.maybePop(loggedIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const RouteWrapper(
      child: Scaffold(
        body: Center(
          child: FractionallySizedBox(
            heightFactor: 0.4,
            child: FladderLogo(),
          ),
        ),
      ),
    );
  }
}
