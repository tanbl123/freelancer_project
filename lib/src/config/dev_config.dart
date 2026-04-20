/// Developer configuration flags.
///
/// Flip these manually before running the app.
/// Remember to set them back after the showcase!
class DevConfig {
  DevConfig._();

  /// Set to [true] before the project showcase to enable real email checking.
  /// Set to [false] during team testing to avoid using up the 100 free credits.
  // During team testing — keep OFF (saves credits):
  static const bool emailValidationEnabled = false;

  // Before showcase — switch ON:
  ///static const bool emailValidationEnabled = true;

}
