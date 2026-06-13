import 'dart:math';

class OTPGenerator {
  OTPGenerator._();

  static String generate() {
    return (1000 + Random().nextInt(9000)).toString();
  }
}
