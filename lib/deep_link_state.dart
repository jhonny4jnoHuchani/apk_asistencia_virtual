// dee_link_state.dart
class DeepLinkState {
  static Uri? pendingUri;
  static Map<String, String>? pendingArgs;
  static bool deepLinkHandled = false;

  static void clear() {
    pendingUri = null;
    pendingArgs = null;
    deepLinkHandled = false;
  }
}
