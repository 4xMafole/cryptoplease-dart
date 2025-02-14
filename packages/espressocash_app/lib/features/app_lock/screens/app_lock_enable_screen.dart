import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../routes.gr.dart';
import '../../../ui/back_button.dart';
import '../../../ui/decorated_window/decorated_window.dart';
import '../widgets/pin_input_display_widget.dart';

@RoutePage()
class AppLockEnableScreen extends StatefulWidget {
  const AppLockEnableScreen({
    super.key,
    required this.onFinished,
    required this.onCanceled,
  });

  final ValueSetter<String> onFinished;
  final VoidCallback onCanceled;

  static const route = AppLockEnableRoute.new;

  @override
  State<AppLockEnableScreen> createState() => _AppLockEnableScreenState();
}

class _AppLockEnableScreenState extends State<AppLockEnableScreen> {
  String? _firstPass;
  String? _secondPass;

  void _onComplete(String value) {
    if (_firstPass == null) {
      setState(() => _firstPass = value);
    } else {
      setState(() => _secondPass = value);
      if (_firstPass == _secondPass) {
        // ignore: avoid-non-null-assertion, cannot be null here
        widget.onFinished(_firstPass!);
      }
    }
  }

  String get _instructions => _firstPass == null
      ? context.l10n.enterPasscode
      : context.l10n.reEnterPasscode;

  @override
  Widget build(BuildContext context) => DecoratedWindow(
        backButton: CpBackButton(onPressed: widget.onCanceled),
        hasLogo: true,
        backgroundStyle: BackgroundStyle.dark,
        child: PinInputDisplayWidget(
          message: _instructions,
          onCompleted: _onComplete,
        ),
      );
}
