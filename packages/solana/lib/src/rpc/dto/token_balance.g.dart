// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_balance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenBalance _$TokenBalanceFromJson(Map<String, dynamic> json) => TokenBalance(
      accountIndex: json['accountIndex'] as int,
      mint: json['mint'] as String,
      uiTokenAmount:
          TokenAmount.fromJson(json['uiTokenAmount'] as Map<String, dynamic>),
    );
