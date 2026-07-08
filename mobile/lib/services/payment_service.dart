// SETUP REQUIRED (do this before testing real payments):
// 1. Create a free account at https://razorpay.com
// 2. Go to Settings → API Keys → Generate Test Key
// 3. Paste the Key ID below (it is a *public* identifier, safe to ship in
//    the app — never put your Key SECRET in client code).
// 4. In Razorpay Dashboard → Payment Methods, make sure UPI is enabled.
// 5. For production, generate a Live key and swap it in before release.
//
// Test payments: use UPI id `success@razorpay` to simulate a successful
// payment, or `failure@razorpay` to simulate a failure, without needing a
// real bank account.
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  // TODO: replace with your real Razorpay Test/Live Key ID.
  static const String keyId = 'rzp_test_YOUR_KEY_HERE';

  static Razorpay? _razorpay;
  static void Function(String paymentId)? _onSuccess;
  static void Function(String error)? _onFailure;

  static bool get isConfigured =>
      keyId.isNotEmpty && !keyId.contains('YOUR_KEY_HERE');

  /// Must be called right before [openCheckout] and disposed with [dispose]
  /// once the screen using it is done (or on the next open).
  static void init({
    required void Function(String paymentId) onSuccess,
    required void Function(String error) onFailure,
  }) {
    dispose();
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  static void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Opens the real Razorpay checkout sheet. Razorpay itself detects which
  /// UPI apps (GPay, PhonePe, Paytm, etc.) are installed and lets the rider
  /// pick one via UPI intent — this is real money movement, not a fake
  /// deep-link. [method] only nudges Razorpay's default selection/branding.
  static void openCheckout({
    required double amountInRupees,
    required String rideId,
    required String customerName,
    required String customerPhone,
    required String method, // 'gpay' | 'phonepe' | 'paytm' | 'upi'
  }) {
    if (!isConfigured) {
      _onFailure?.call(
          'Payments are not configured yet. Add a Razorpay key in payment_service.dart.');
      return;
    }

    final amountPaise = (amountInRupees * 100).round();

    final options = <String, dynamic>{
      'key': keyId,
      'amount': amountPaise,
      'name': 'GaamRide',
      'description': 'Ride payment · $rideId',
      'currency': 'INR',
      'prefill': {
        'contact': customerPhone,
        'name': customerName,
        'method': 'upi',
      },
      'theme': {'color': '#f97316'},
      'method': {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
      },
      // Shows real installed UPI apps (GPay/PhonePe/Paytm/etc.) via intent.
      'upi': {'flow': 'intent'},
      'notes': {'ride_id': rideId, 'requested_method': method},
      'modal': {'confirm_close': true},
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      _onFailure?.call('Could not open payment: $e');
    }
  }

  static void _handleSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(response.paymentId ?? '');
  }

  static void _handleError(PaymentFailureResponse response) {
    _onFailure?.call(response.message ?? 'Payment failed');
  }

  static void _handleWallet(ExternalWalletResponse response) {
    _onFailure?.call('Selected wallet (${response.walletName}) is not supported yet.');
  }
}
