part of 'qr_scanner_bloc.dart';

@freezed
class QrScannerEvent with _$QrScannerEvent {
  const factory QrScannerEvent.received(IList<String> codes) =
      QrScannerReceivedEvent;

  const factory QrScannerEvent.initialized() = QrScannerInitializedEvent;
}
