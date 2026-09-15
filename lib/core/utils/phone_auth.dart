/// Firebase Auth still needs an email address even when the person never
/// gave one. Phone-only accounts use this reserved domain so they can sign
/// in with their mobile number. The value is never shown in the UI.
const phoneAuthDomain = 'phone.nearkart.app';

final _emailPattern = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

bool isPhoneAuthEmail(String? email) {
  final value = email?.trim() ?? '';
  return value.endsWith('@$phoneAuthDomain');
}

/// Email stored on the Auth record for a phone-only account.
String phoneAuthEmail(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return '$digits@$phoneAuthDomain';
}

/// What the UI should show. Synthetic Auth emails stay hidden.
String displayEmail(String? email) {
  final value = email?.trim() ?? '';
  if (value.isEmpty || isPhoneAuthEmail(value)) return '';
  return value;
}

/// Turns a login field into the email Firebase Auth expects.
///
/// A 10-digit mobile number maps to the phone-only Auth account. Anything
/// with an `@` is used as typed.
String authEmailFromIdentifier(String raw) {
  final value = raw.trim();
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (!value.contains('@') && digits.length == 10) {
    return phoneAuthEmail(digits);
  }
  return value;
}

/// Login field: email or a 10-digit mobile number.
String? loginIdentifier(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return 'Enter your email or 10-digit mobile number';
  }
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (!text.contains('@') && digits.length == 10) return null;
  return optionalEmail(text);
}

/// Empty is allowed. A non-empty value must look like an email.
String? optionalEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!_emailPattern.hasMatch(text) || isPhoneAuthEmail(text)) {
    return 'Enter a valid email address';
  }
  return null;
}
