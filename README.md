# Carnet — Flutter connecté à Firebase Rentit

[![Vérifications](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml/badge.svg)](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml)

Application Flutter Android/iOS en français, connectée au projet Firebase existant **`rentit-30415`**. Authentification réelle par email/mot de passe, trois écrans REST, cache Hive et consultation hors ligne.

## Démarrer

Prérequis : Flutter **3.41.9** (Dart **3.11.5**), SDK Android, JDK 17 ou 21. Pour iOS : macOS, Xcode et signature Apple.

```bash
git clone https://github.com/jkatems/nextflutter_connected_app.git
cd nextflutter_connected_app
flutter pub get
flutter run
```

**Aucun serveur Python à démarrer et aucune URL locale à configurer.** Le client utilise les endpoints HTTPS officiels Firebase. Créez un compte depuis l’écran de connexion, puis consultez les trois rubriques.

Dans la [console Firebase Authentication](https://console.firebase.google.com/project/rentit-30415/authentication), le fournisseur **Adresse e-mail/Mot de passe** doit être activé. Les comptes de l’ancienne démonstration Python ne sont pas des comptes Firebase : ils doivent être recréés.

## Fonctionnalités

- Inscription Firebase, connexion, restauration de session et déconnexion locale.
- **Explorer** : articles ; **Catalogue** : produits ; **Tâches** : suggestions en lecture seule.
- Trois appels REST Firestore distincts et écran de détail pour chaque élément.
- Cache Hive persistant par UID, date de synchronisation et bandeau hors ligne.
- Repli sur le cache après perte réseau, timeout ou erreur serveur 5xx.
- Messages utilisateur en français, bouton Réessayer et actualisation par glissement.
- Intercepteur Dio injectant le JWT Firebase et renouvelant le token après un 401.
- Un seul renouvellement pour les requêtes simultanées, une seule nouvelle tentative.
- Tokens conservés dans Keychain/Keystore avec `flutter_secure_storage`, jamais dans Hive.

Les données de démonstration sont réellement enregistrées dans Firestore. Le catalogue et les tâches sont consultables, sans fonctionnalités d’achat ou d’édition.

## Connexion Firebase

Configuration publique dans `lib/core/firebase_config.dart` :

| Élément | Valeur |
| --- | --- |
| Projet | `rentit-30415` |
| Application Firebase réutilisée | `rentit (web)` |
| App ID de référence | `1:508838894460:web:6a36552c40c300bb3de2f9` |
| Base Firestore | `(default)`, région `europe-west1` |
| Collection | `carnetFeeds` |
| Documents | `articles`, `products`, `tasks` |

L’intégration utilise **les API REST Firebase via Dio**, plutôt que les SDK natifs `firebase_auth`/`cloud_firestore`. Elle respecte donc l’exigence REST et conserve la même gestion explicite du cache et du refresh token. Aucun `google-services.json`, `GoogleService-Info.plist` ou `Firebase.initializeApp()` n’est nécessaire avec cette approche. L’identifiant natif de Carnet reste `com.carnet.carnet` ; les applications Rentit déjà enregistrées ne sont pas modifiées.

La clé API Firebase incluse est une configuration cliente publique, pas une clé administrateur. L’autorisation d’accès repose sur Firebase Authentication et les règles Firestore. Aucune clé de compte de service n’est incluse dans le dépôt.

## Architecture

```text
lib/
  core/
    api_client.dart                 Dio, injection JWT, renouvellement, erreurs
    firebase_config.dart            Configuration Firebase publique
  domain/models.dart                Entités et contrats de repositories/stockage
  data/
    firebase_auth_repository.dart   Authentification Firebase REST
    firestore_mapper.dart           Décodage du JSON typé Firestore
    repositories.dart               Repository REST et stratégie de cache
    storage.dart                    Adaptateurs Hive et stockage sécurisé
  presentation/app.dart             Formulaires, navigation, listes et détails
  main.dart                         Initialisation et injection des dépendances
firebase/firestore.rules             Règles d’accès déployables
scripts/firebase_smoke.dart          Vérification réelle Firebase de bout en bout
```

La présentation dépend des interfaces `AuthenticationRepository` et `ContentRepository`. `main.dart` injecte `FirebaseAuthRepository` et `RestContentRepository(..., firestore: true)`. Le domaine ne dépend ni de Dio ni de Flutter. L’état de présentation utilise `StatefulWidget`.

Le repository suit **réseau → sauvegarde Hive → affichage**. Si le réseau ou le serveur est indisponible, il relit le cache. Les erreurs d’authentification/autorisation et les réponses malformées ne sont pas masquées par le cache. Les trois rubriques sont préchargées à la connexion. Le détail réutilise l’entité reçue.

## API REST utilisées

| Méthode | Endpoint | Fonction |
| --- | --- | --- |
| POST | `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=…` | Inscription et tokens |
| POST | `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=…` | Connexion et tokens |
| POST | `https://securetoken.googleapis.com/v1/token?key=…` | Renouvellement avec `grant_type=refresh_token` |
| GET | `https://firestore.googleapis.com/v1/projects/rentit-30415/databases/(default)/documents/carnetFeeds/articles` | Articles |
| GET | Même préfixe, `/products` | Catalogue |
| GET | Même préfixe, `/tasks` | Tâches |

Firestore reçoit `Authorization: Bearer <Firebase ID token>`. Chaque document contient un tableau `items` d’objets `id`, `title`, `body`, `label`. Le mapper convertit les valeurs typées de Firestore en entités métier.

## Sessions, cache et règles

Firebase gère les comptes et les JWT. L’intercepteur renouvelle un token rejeté avec le refresh token enregistré, puis rejoue l’appel une fois. Si le renouvellement est refusé, l’interface invite à se reconnecter. Si le renouvellement échoue à cause du réseau, le cache reste utilisable.

La déconnexion est **locale**, comme un sign-out client Firebase : elle supprime les deux tokens et le cache du téléphone, même sans réseau. Elle ne révoque pas les sessions des autres appareils ni un token déjà copié. Une révocation globale nécessite une action administrateur Firebase. Aucun mot de passe n’est stocké localement.

La restauration de session ne nécessite pas de réseau. Les anciennes sessions Python sont effacées lors de la migration. Le cache est isolé par UID, non chiffré, limité aux données de lecture et conservé jusqu’à actualisation/déconnexion. Son ancienneté est affichée ; pas d’expiration forcée hors ligne.

`firebase/firestore.rules` autorise seulement la lecture directe des trois documents pour un utilisateur authentifié. Les listes et toutes les écritures clientes sont refusées ; les autres chemins sont refusés par défaut. Les modifications de contenu passent par la console ou un administrateur.

Pour redéployer les règles avec Firebase CLI connecté au bon compte :

```bash
firebase deploy --only firestore:rules --project rentit-30415
```

Les données initiales sont conservées dans `backend/seed.json`. Elles peuvent être éditées dans la [console Firestore](https://console.firebase.google.com/project/rentit-30415/firestore/databases/-default-/data).

## Vérifications

```bash
dart format --output=none --set-exit-if-changed lib test scripts
flutter analyze
flutter test
dart run scripts/firebase_smoke.dart
flutter build apk --debug
```

Les tests unitaires couvrent les repositories REST et Firebase : inscription, connexion, messages d’erreur, restauration sans réseau, migration, déconnexion, décodage Firestore, cache, isolation des comptes, refus de masquer un 401, repli 503 et renouvellement JWT concurrent.

Le script `firebase_smoke.dart` appelle **le vrai projet Firebase** : il crée un compte temporaire, se reconnecte, lit les trois documents, renouvelle son token, vérifie le refus des lectures anonymes/écritures clientes et le repli hors ligne, puis supprime son propre compte. Aucun token ou mot de passe n’est affiché. Ne le lancez pas en boucle pour éviter les limites anti-abus Firebase.

GitHub Actions lance formatage, analyse, tests Flutter et les tests du backend Python historique. Les tests Firebase réels ne sont pas lancés automatiquement à chaque push.

### Essai sur téléphone

1. Installez l’APK et créez un compte Firebase avec le réseau actif.
2. Vérifiez les trois rubriques.
3. Activez le mode avion, puis actualisez : les données cachées apparaissent après le délai réseau.
4. Fermez puis relancez l’application : elles restent disponibles.
5. Rétablissez le réseau et actualisez : le bandeau indique « À jour ».
6. Déconnectez-vous : les tokens et le cache sont effacés.

L’APK est généré dans `build/app/outputs/flutter-apk/app-debug.apk`. La cible iOS est incluse mais nécessite une vérification sur macOS. La version release utilise encore la signature de développement : configurez votre keystore avant une publication sur un store.

## Ancienne API locale

Le dossier `backend/` et `AuthRepository` conservent la première démonstration Python/SQLite avec JWT, utile comme exemple et testée séparément. **Ils ne sont plus utilisés par `main.dart`.** Le backend actuel de l’application est Firebase.

## Documentation officielle

- [Firebase Authentication REST](https://firebase.google.com/docs/reference/rest/auth)
- [Firestore REST](https://firebase.google.com/docs/firestore/use-rest-api)
- [Règles Firestore](https://firebase.google.com/docs/firestore/security/get-started)
- [Dio](https://pub.dev/packages/dio), [Hive](https://pub.dev/packages/hive_flutter)
