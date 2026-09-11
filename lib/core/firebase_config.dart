/// Public Firebase client configuration; this is not an administrator key.
/// Existing application: rentit (web), project rentit-30415.
class FirebaseConfig {
  static const projectId = 'rentit-30415';
  static const appId = '1:508838894460:web:6a36552c40c300bb3de2f9';
  static const apiKey = 'AIzaSyB9NvsqPuoa6BBOcGXwnYMfaC5VqsuLCck';
  static const authUrl = 'https://identitytoolkit.googleapis.com/v1';
  static const refreshUrl = 'https://securetoken.googleapis.com/v1';
  static const dataUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/carnetFeeds';
}
