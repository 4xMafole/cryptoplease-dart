import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:decimal/decimal.dart';
import 'package:dfunc/dfunc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/amount.dart';
import '../../../core/currency.dart';
import '../../../core/flow.dart';
import '../../../core/presentation/extensions.dart';
import '../../../core/presentation/format_amount.dart';
import '../../../core/presentation/value_stream_builder.dart';
import '../../../core/tokens/token.dart';
import '../../../di.dart';
import '../../../l10n/device_locale.dart';
import '../../../l10n/l10n.dart';
import '../../../routes.gr.dart';
import '../../../ui/colors.dart';
import '../../../ui/content_padding.dart';
import '../../../ui/loader.dart';
import '../../../ui/navigation_bar/navigation_bar.dart';
import '../../../ui/theme.dart';
import '../../balances/data/balances_repository.dart';
import '../../conversion_rates/services/watch_user_fiat_balance.dart';
import '../../ramp/widgets/ramp_buttons.dart';
import '../../swap/services/token_ext.dart';
import '../../token_chart/module.dart';
import '../../token_chart/widgets/token_chart.dart';
import '../../token_chart/widgets/token_overview.dart';
import '../models/token_details.dart';
import '../services/token_details_bloc.dart';
import '../widgets/balance_widget.dart';
import '../widgets/exchange_buttons.dart';
import '../widgets/token_app_bar.dart';
import '../widgets/token_details_widget.dart';

@RoutePage()
class TokenDetailsScreen extends StatelessWidget {
  const TokenDetailsScreen({super.key, required this.token});

  static const route = TokenDetailsRoute.new;

  final Token token;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          BlocProvider(
            create: (context) => sl<TokenDetailsBloc>(param1: token)
              ..add(const FetchDetailsRequested()),
          ),
          TokenChartModule(token),
        ],
        child: CpTheme.dark(
          child: Scaffold(
            backgroundColor: CpColors.darkBackground,
            body: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: cpNavigationBarheight),
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    TokenAppBar(token: token),
                  ],
                  body: _NoGlowList(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Chart(token: token),
                          if (token.shouldShowExchangeButtons)
                            ExchangeButtons(token: token),
                          if (token == Token.usdc) const _RampButtons(),
                          _Balance(token: token),
                          _Content(token: token),
                          SizedBox(
                            height: max(
                              MediaQuery.paddingOf(context).bottom -
                                  cpNavigationBarheight,
                              0,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _TokenPrice extends StatelessWidget {
  const _TokenPrice();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TokenDetailsBloc, TokenDetailsState>(
        builder: (context, state) {
          final tokenRate = switch (state) {
            FlowSuccess(:final result) => result.marketPrice
                    ?.toString()
                    .let(Decimal.parse)
                    .formatDisplayablePrice(
                      locale: DeviceLocale.localeOf(context),
                      currency: defaultFiatCurrency,
                    ) ??
                '-',
            _ => '-',
          };

          return PriceWidget(
            label: context.l10n.price,
            amount: tokenRate,
          );
        },
      );
}

class _Content extends StatelessWidget {
  const _Content({required this.token});

  final Token token;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TokenDetailsBloc, TokenDetailsState>(
        builder: (context, state) {
          const loader = SizedBox(
            height: 80,
            child: LoadingIndicator(),
          );

          return switch (state) {
            FlowInitial() || FlowProcessing() => loader,
            FlowFailure() =>
              TokenDetailsWidget(data: TokenDetails(name: token.name)),
            FlowSuccess(:final result) => TokenDetailsWidget(data: result),
          };
        },
      );
}

class _Balance extends StatelessWidget {
  const _Balance({required this.token});

  final Token token;

  @override
  Widget build(BuildContext context) =>
      ValueStreamBuilder<({Amount? fiat, CryptoAmount crypto})>(
        create: () {
          final fiat = sl<WatchUserFiatBalance>().call(token);
          final crypto = sl<BalancesRepository>().watch(token);

          return (
            Rx.combineLatest2(
              fiat.$1,
              crypto.$1,
              (fiat, crypto) => (fiat: fiat, crypto: crypto),
            ),
            (fiat: fiat.$2, crypto: crypto.$2),
          );
        },
        builder: (context, value) {
          final (:crypto, :fiat) = value;

          return crypto.value != 0 && fiat != null
              ? CpContentPadding(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    width: double.infinity,
                    decoration: const ShapeDecoration(
                      shape: StadiumBorder(),
                      color: CpColors.darkBackgroundColor,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      children: [
                        PriceWidget(
                          label: context.l10n.youOwn,
                          amount: crypto.format(
                            DeviceLocale.localeOf(context),
                            roundInteger: true,
                          ),
                        ),
                        PriceWidget(
                          label: context.l10n.tokenDetails_lblBalance,
                          amount: fiat.format(
                            DeviceLocale.localeOf(context),
                            roundInteger: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink();
        },
      );
}

class _Chart extends StatefulWidget {
  const _Chart({required this.token});

  final Token token;

  @override
  State<_Chart> createState() => __ChartState();
}

class __ChartState extends State<_Chart> {
  TokenChartItem? _selected;

  @override
  Widget build(BuildContext context) {
    final price = _selected?.price.toString().let(Decimal.parse);
    final currentPrice = price.formatDisplayablePrice(
      locale: DeviceLocale.localeOf(context),
      currency: defaultFiatCurrency,
    );

    return Column(
      children: [
        if (_selected == null)
          const _TokenPrice()
        else
          Text(
            currentPrice,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        const SizedBox(height: 8),
        const ChartPriceOverview(),
        TokenChart(
          token: widget.token,
          onSelect: (item) {
            setState(() {
              _selected = item;
            });
          },
        ),
      ],
    );
  }
}

class _RampButtons extends StatelessWidget {
  const _RampButtons();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            AddCashButton(),
            SizedBox(width: 24),
            CashOutButton(),
          ],
        ),
      );
}

class _NoGlowList extends StatelessWidget {
  const _NoGlowList({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (OverscrollIndicatorNotification overscroll) {
          overscroll.disallowIndicator();

          return true;
        },
        child: child,
      );
}

extension on Token {
  /// Since buy and sell a token actually swaps it for USDC, makes no sense
  /// buying or selling USDC through this same flow as would not exist a match.
  bool get shouldShowExchangeButtons =>
      canBeSwapped && address != Token.usdc.address;
}
