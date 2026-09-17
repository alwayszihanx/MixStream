const double _bytesPerKilobyte = 1000;
const double _bytesPerMegabyte = 1000 * _bytesPerKilobyte;
const double _bytesPerGigabyte = 1000 * _bytesPerMegabyte;

/// Formats file sizes using decimal units, matching iOS' `.file`
/// `ByteCountFormatter` and the values shown by the system download task.
String formatFileSize(num bytes, {int fractionDigits = 2}) {
  final normalizedBytes = bytes < 0 ? 0 : bytes.toDouble();

  if (normalizedBytes >= _bytesPerGigabyte) {
    final value = normalizedBytes / _bytesPerGigabyte;
    return '${value.toStringAsFixed(fractionDigits)} GB';
  }
  if (normalizedBytes >= _bytesPerMegabyte) {
    final value = normalizedBytes / _bytesPerMegabyte;
    return '${value.toStringAsFixed(fractionDigits)} MB';
  }
  if (normalizedBytes >= _bytesPerKilobyte) {
    final value = normalizedBytes / _bytesPerKilobyte;
    return '${value.toStringAsFixed(fractionDigits)} KB';
  }
  return '${normalizedBytes.toStringAsFixed(0)} B';
}

/// Formats downloaded and total bytes with a shared decimal unit so the
/// compact progress label remains easy to scan.
String formatDownloadSizePair({
  required int totalBytes,
  required double progress,
  int fractionDigits = 1,
}) {
  if (totalBytes <= 0) return '-- / -- MB';

  final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
  final double divisor;
  final String unit;

  if (totalBytes >= _bytesPerGigabyte) {
    divisor = _bytesPerGigabyte;
    unit = 'GB';
  } else if (totalBytes >= _bytesPerMegabyte) {
    divisor = _bytesPerMegabyte;
    unit = 'MB';
  } else if (totalBytes >= _bytesPerKilobyte) {
    divisor = _bytesPerKilobyte;
    unit = 'KB';
  } else {
    divisor = 1;
    unit = 'B';
  }

  final total = totalBytes / divisor;
  final downloaded = total * normalizedProgress;
  final digits = unit == 'B' ? 0 : fractionDigits;

  return '${downloaded.toStringAsFixed(digits)} / '
      '${total.toStringAsFixed(digits)} $unit';
}
