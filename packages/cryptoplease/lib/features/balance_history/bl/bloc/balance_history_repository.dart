import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../data/db/db.dart';
import '../../../../data/db/mixins.dart';
import 'balance_history.dart';

@injectable
class BalanceHistoryRepository {
  BalanceHistoryRepository(this._db);

  final MyDatabase _db;

  Future<BalanceHistory?> fetchLastTokenEntry(String token) async {
    final query = _db.select(_db.balanceHistoryRows)
      ..where((p) => p.token.equals(token))
      ..orderBy(
        [(u) => OrderingTerm(expression: u.created, mode: OrderingMode.desc)],
      );

    return query.get().then((value) => value.first.toModel());
  }

  Future<BalanceHistory?> fetchTokenEntryByDate(
    String token,
    DateTime date,
  ) async {
    final query = _db.select(_db.balanceHistoryRows)
      ..where((p) => p.token.equals(token))
      ..where((p) => p.created.equals(date));

    return query.get().then((value) => value.first.toModel());
  }

  Future<List<BalanceHistory>> fetchBalanceEntriesByDate(DateTime date) async {
    final query = _db.select(_db.balanceHistoryRows)
      ..where((p) {
        final created = p.created;

        return created.year.equals(date.year) &
            created.month.equals(date.month) &
            created.day.equals(date.day);
      });

    return query.get().then((value) => value.map((e) => e.toModel()).toList());
  }

  Future<void> save(BalanceHistory data) async =>
      _db.into(_db.balanceHistoryRows).insertOnConflictUpdate(data.toDto());

  Future<void> clear() => _db.delete(_db.balanceHistoryRows).go();
}

class BalanceHistoryRows extends Table with AmountMixin {
  IntColumn get id => integer().nullable().autoIncrement()();
  DateTimeColumn get created => dateTime()();
}

extension on BalanceHistoryRow {
  BalanceHistory toModel() => BalanceHistory(
        token: token,
        amount: amount,
        created: created,
      );
}

extension on BalanceHistory {
  BalanceHistoryRow toDto() => BalanceHistoryRow(
        token: token,
        amount: amount,
        created: created,
      );
}
