import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance_history.freezed.dart';

@freezed
class BalanceHistory with _$BalanceHistory {
  const factory BalanceHistory({
    required String token,
    required int amount,
    required DateTime created,
  }) = _BalanceHistory;
}
