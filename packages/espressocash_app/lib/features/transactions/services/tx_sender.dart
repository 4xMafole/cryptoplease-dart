import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../../../config.dart';
import '../models/tx_sender.dart';

@injectable
class TxSender {
  TxSender({
    required SolanaClient client,
  }) : _client = client;

  final SolanaClient _client;

  Future<TxSendResult> send(
    SignedTx tx, {
    required BigInt minContextSlot,
  }) async {
    Future<TxSendResult> checkSubmittedTx(String txId) => _client.rpcClient
            .getSignatureStatuses([txId], searchTransactionHistory: true).then(
          (statuses) => statuses.value.first == null
              ? (statuses.context.slot >= minContextSlot
                  ? const TxSendResult.invalidBlockhash()
                  : const TxSendResult.networkError())
              : const TxSendResult.sent(),
          onError: (_) => const TxSendResult.networkError(),
        );

    try {
      await _client.rpcClient.sendTransaction(
        tx.encode(),
        preflightCommitment: Commitment.confirmed,
        minContextSlot: minContextSlot.toInt(),
      );

      return const TxSendResult.sent();
    } on JsonRpcException catch (e) {
      if (e.code == JsonRpcErrorCode.minContextSlotNotReached) {
        return const TxSendResult.networkError();
      }

      if (e.isInsufficientFunds) {
        return const TxSendResult.failure(
          reason: TxFailureReason.insufficientFunds,
        );
      }
      switch (e.transactionError) {
        case TransactionError.alreadyProcessed:
          return const TxSendResult.sent();
        case TransactionError.blockhashNotFound:
          // ignore: prefer-return-await, not needed here
          return checkSubmittedTx(tx.id);
        // ignore: no_default_cases, not interested in other options
        default:
          return const TxSendResult.failure(reason: TxFailureReason.txError);
      }
    } on Exception {
      return const TxSendResult.networkError();
    }
  }

  Future<TxWaitResult> wait(
    SignedTx tx, {
    required BigInt minContextSlot,
  }) async {
    const commitment = Commitment.confirmed;

    Future<TxWaitResult?> getSignatureStatus() async {
      final statuses = await _client.rpcClient
          .getSignatureStatuses([tx.id], searchTransactionHistory: true);
      final t = statuses.value.first;

      if (t == null) {
        final bh = tx.blockhash;
        final isValidBlockhash = await _client.rpcClient
            .isBlockhashValid(
              bh,
              commitment: commitment,
              minContextSlot: minContextSlot.toInt(),
            )
            .value;
        if (!isValidBlockhash && statuses.context.slot >= minContextSlot) {
          return const TxWaitResult.failure(
            reason: TxFailureReason.invalidBlockhashWaiting,
          );
        }
      } else {
        if (t.err != null) {
          return const TxWaitResult.failure(reason: TxFailureReason.txError);
        }

        if (t.confirmationStatus.index >= ConfirmationStatus.confirmed.index) {
          return const TxWaitResult.success();
        }
      }
    }

    Future<TxWaitResult> waitForSignatureStatus() async {
      try {
        await _client.waitForSignatureStatus(
          tx.id,
          status: commitment,
          pingInterval: pingDefaultInterval,
          timeout: waitForSignatureDefaultTimeout,
        );

        return const TxWaitResult.success();
      } on SubscriptionClientException {
        return const TxWaitResult.failure(reason: TxFailureReason.txError);
      } on Exception {
        return const TxWaitResult.networkError();
      }
    }

    final polling = _createPolling<TxWaitResult?>(
      createSource: () => getSignatureStatus().asStream(),
    );

    return Future.any([
      polling.whereNotNull().first,
      waitForSignatureStatus(),
    ]);
  }
}

extension on JsonRpcException {
  // TODO(KB): Think about some better error handling
  bool get isInsufficientFunds {
    final data = this.data;
    if (data is! Map<String, dynamic>) return false;

    final error = data['err'];
    if (error is! Map<String, dynamic>) return false;

    final instructionError = error['InstructionError'];
    if (instructionError is! List<dynamic>) return false;
    if (instructionError.length < 2) return false;

    final instructionErrorData = instructionError[1];
    if (instructionErrorData is! Map<String, dynamic>) return false;

    return instructionErrorData['Custom'] == 1;
  }
}

Stream<T> _createPolling<T>({required Stream<T> Function() createSource}) {
  Duration backoff = const Duration(seconds: 1);

  Stream<void> retryWhen(void _, void __) async* {
    await Future<void>.delayed(backoff);
    if (backoff < const Duration(seconds: 30)) backoff *= 2;

    yield null;
  }

  return RetryWhenStream(
    () => Stream<void>.periodic(const Duration(seconds: 10))
        .startWith(null)
        .flatMap((_) => createSource()),
    retryWhen,
  );
}
