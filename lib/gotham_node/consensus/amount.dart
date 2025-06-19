/// Gotham Amount Handling - Consensus Critical
/// 
/// This file implements amount handling exactly as in Gotham Core
/// to ensure consensus compatibility.

/// Amount in satoshis (Can be negative) - matches Gotham Core's CAmount
typedef GAmount = int;

/// The amount of satoshis in one GTH - matches Gotham Core exactly
const int COIN = 100000000;

/// No amount larger than this (in satoshi) is valid.
/// 
/// Note that this constant is *not* the total money supply, which in Gotham
/// currently happens to be less than 21,000,000 GTH for various reasons, but
/// rather a sanity check. As this sanity check is used by consensus-critical
/// validation code, the exact value of the MAX_MONEY constant is consensus
/// critical; in unusual circumstances like a(nother) overflow bug that allowed
/// for the creation of coins out of thin air modification could lead to a fork.
const GAmount MAX_MONEY = 21000000 * COIN;

/// Check if an amount is within the valid money range
bool moneyRange(GAmount value) {
  return value >= 0 && value <= MAX_MONEY;
}

/// Convert satoshis to GTH (as double for display purposes only)
double satoshisToGTH(GAmount satoshis) {
  return satoshis / COIN.toDouble();
}

/// Convert GTH to satoshis (for consensus operations)
GAmount gthToSatoshis(double gth) {
  final satoshis = (gth * COIN).round();
  if (!moneyRange(satoshis)) {
    throw ArgumentError('Amount out of valid range: $gth GTH');
  }
  return satoshis;
}

/// Format amount in satoshis as GTH string
String formatGTH(GAmount satoshis, {int decimals = 8}) {
  final gth = satoshisToGTH(satoshis);
  return '${gth.toStringAsFixed(decimals)} GTH';
}

/// Format amount in satoshis as GTH string with automatic precision
String formatGTHAuto(GAmount satoshis) {
  final gth = satoshisToGTH(satoshis);
  
  // Remove trailing zeros for cleaner display
  String formatted = gth.toStringAsFixed(8);
  formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
  
  // Ensure at least one decimal place for small amounts
  if (!formatted.contains('.') && gth < 1.0) {
    formatted = gth.toStringAsFixed(1);
  }
  
  return '$formatted GTH';
}

/// Parse GTH string to satoshis
GAmount parseGTH(String gthString) {
  // Remove 'GTH' suffix if present
  String cleanString = gthString.replaceAll(RegExp(r'\s*GTH\s*$', caseSensitive: false), '');
  
  final gth = double.tryParse(cleanString);
  if (gth == null) {
    throw FormatException('Invalid GTH amount: $gthString');
  }
  
  return gthToSatoshis(gth);
}

/// Validate that a string represents a valid GTH amount
bool isValidGTHAmount(String gthString) {
  try {
    parseGTH(gthString);
    return true;
  } catch (e) {
    return false;
  }
}

/// Extension methods for easier amount handling
extension GAmountExtension on GAmount {
  /// Convert to GTH as double
  double get asGTH => satoshisToGTH(this);
  
  /// Format as GTH string
  String get formatted => formatGTH(this);
  
  /// Format as GTH string with automatic precision
  String get formattedAuto => formatGTHAuto(this);
  
  /// Check if amount is valid
  bool get isValid => moneyRange(this);
  
  /// Check if amount is zero
  bool get isZero => this == 0;
  
  /// Check if amount is positive
  bool get isPositive => this > 0;
  
  /// Check if amount is negative
  bool get isNegative => this < 0;
}

extension DoubleToGAmount on double {
  /// Convert double GTH to satoshis
  GAmount get asGAmount => gthToSatoshis(this);
}

extension StringToGAmount on String {
  /// Parse string as GTH amount to satoshis
  GAmount get asGAmount => parseGTH(this);
  
  /// Check if string is valid GTH amount
  bool get isValidGTH => isValidGTHAmount(this);
}