# Projet Flutter — App connectée avec backend réel

[![Vérifications](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml/badge.svg)](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml)

Application mobile Android/iOS en français : authentification JWT, trois rubriques alimentées par une API HTTP persistante et consultation hors ligne avec Hive.

**Nom de l’application : Carnet.** Le client est développé avec Flutter ; le backend réel utilise Python et une base SQLite persistante.

## Exigences du projet : fichiers et lignes de code

Le tableau relie les exigences fonctionnelles et techniques décrites dans ce README à leur implémentation. Les numéros de ligne correspondent à la version actuelle des sources ; ils peuvent changer après une modification du code. Les chemins sont relatifs au dossier contenant ce README et `pubspec.yaml`.

| Exigence | Fichiers et lignes de code | Réalisation |
| --- | --- | --- |
| Application Flutter et backend réel | [`lib/main.dart`, ligne 10](lib/main.dart#L10) ; [`backend/server.py`, ligne 162](backend/server.py#L162) | Initialisation du client et du serveur HTTP. |
| Persistance serveur | [`backend/server.py`, ligne 29](backend/server.py#L29) | Tables SQLite des utilisateurs, sessions et ressources ; données initiales dans `backend/seed.json`. |
| Inscription et connexion | [`lib/data/repositories.dart`, ligne 96](lib/data/repositories.dart#L96) ; [`backend/server.py`, ligne 126](backend/server.py#L126) | Création réelle du compte, vérification des identifiants et sauvegarde de session. |
| Validation des formulaires | [`lib/presentation/app.dart`, ligne 89](lib/presentation/app.dart#L89) ; [`backend/server.py`, ligne 127](backend/server.py#L127) | Contrôles du nom, de l’email et du mot de passe côté client et serveur. |
| JWT et refresh token | [`lib/core/api_client.dart`, ligne 53](lib/core/api_client.dart#L53) ; [`backend/server.py`, ligne 145](backend/server.py#L145) | Bearer token, rotation du refresh et nouvelle tentative limitée ; vérification du compte et des données de session. |
| Stockage sécurisé et routes protégées | [`lib/data/storage.dart`, ligne 6](lib/data/storage.dart#L6) ; [`backend/server.py`, ligne 43](backend/server.py#L43) ; [`backend/server.py`, ligne 79](backend/server.py#L79) | Tokens dans le stockage sécurisé ; mots de passe hachés ; session contrôlée côté serveur. |
| Trois rubriques REST | [`lib/presentation/app.dart`, ligne 301](lib/presentation/app.dart#L301) ; [`lib/data/repositories.dart`, ligne 11](lib/data/repositories.dart#L11) ; [`backend/server.py`, ligne 158](backend/server.py#L158) | Explorer, Catalogue et Tâches consultent leurs endpoints dédiés. |
| Écran de détail | [`lib/presentation/app.dart`, ligne 584](lib/presentation/app.dart#L584) | Affichage du contenu sélectionné, également disponible depuis le cache. |
| Cache persistant et mode hors ligne | [`lib/data/storage.dart`, ligne 25](lib/data/storage.dart#L25) ; [`lib/data/repositories.dart`, ligne 54](lib/data/repositories.dart#L54) | Hive sur disque ; repli en cas de panne réseau ou 5xx, jamais pour masquer un refus 401/403. |
| Isolation et restauration | [`lib/main.dart`, ligne 19](lib/main.dart#L19) ; [`lib/data/repositories.dart`, ligne 12](lib/data/repositories.dart#L12) ; [`lib/data/repositories.dart`, ligne 83](lib/data/repositories.dart#L83) | Stockage séparé par serveur et utilisateur ; validation de la session restaurée. |
| Gestion d’état dédiée | [`lib/presentation/controllers.dart`, ligne 5](lib/presentation/controllers.dart#L5) ; [`lib/presentation/controllers.dart`, ligne 82](lib/presentation/controllers.dart#L82) ; [`lib/presentation/app.dart`, ligne 20](lib/presentation/app.dart#L20) | Provider et ChangeNotifier : session, chargement, erreurs, requêtes concurrentes et cycle de vie. |
| Erreurs explicites et retry | [`lib/domain/models.dart`, ligne 31](lib/domain/models.dart#L31) ; [`lib/core/api_client.dart`, ligne 13](lib/core/api_client.dart#L13) ; [`lib/presentation/app.dart`, ligne 417](lib/presentation/app.dart#L417) | Erreurs typées ; bouton Réessayer ; actualisation par glissement et date des données. |
| Déconnexion et nettoyage | [`lib/data/repositories.dart`, ligne 134](lib/data/repositories.dart#L134) ; [`backend/server.py`, ligne 153](backend/server.py#L153) | Révocation serveur et tentative des deux nettoyages locaux, y compris après un échec du stockage sécurisé. |
| Architecture en couches | [`lib/domain/models.dart`, ligne 66](lib/domain/models.dart#L66) ; [`lib/main.dart`, ligne 30](lib/main.dart#L30) | Contrats du domaine, repositories de données et contrôleurs de présentation injectés. |
| Tests unitaires des repositories | [`test/repository_test.dart`, ligne 8](test/repository_test.dart#L8) ; [`test/repository_resilience_test.dart`, ligne 29](test/repository_resilience_test.dart#L29) | 25 tests : cas nominaux, cache, erreurs HTTP/stockage et renouvellement de session. |
| Tests de gestion d’état | [`test/controllers_test.dart`, ligne 40](test/controllers_test.dart#L40) ; [`test/auth_widget_test.dart`, ligne 54](test/auth_widget_test.dart#L54) | Contrôleurs et formulaires : erreurs, retry, double soumission, navigation et déconnexion. |
| Intégration réelle et persistance | [`test/python_api_integration_test.dart`, ligne 11](test/python_api_integration_test.dart#L11) ; [`test/cache_persistence_test.dart`, ligne 11](test/cache_persistence_test.dart#L11) ; [`backend/test_api.py`, ligne 11](backend/test_api.py#L11) | HTTP, Python, SQLite et Hive réels ; rotation, révocation et réouverture hors ligne. |
| CI et livraison Android | [`.github/workflows/ci.yml`, ligne 5](.github/workflows/ci.yml#L5) ; [`scripts/check_coverage.py`, ligne 7](scripts/check_coverage.py#L7) | Analyse, tests, seuil de couverture de 80 % et artefact APK debug après validation. |

## Fonctionnalités

- Inscription réelle, connexion, restauration de session et déconnexion.
- **Explorer** : articles ; **Catalogue** : produits ; **Tâches** : suggestions de tâches.
- Chaque rubrique appelle son endpoint REST et propose un écran de détail.
- Cache Hive persistant, isolé par compte, avec date de synchronisation.
- Repli sur le cache en cas de perte réseau, timeout ou erreur serveur 5xx.
- Messages d’erreur en français, bouton Réessayer et actualisation par glissement.
- JWT injecté par un intercepteur Dio ; refresh unique pour les requêtes simultanées ; une seule nouvelle tentative après renouvellement.
- Tokens conservés dans le stockage sécurisé de la plateforme, jamais dans Hive.

Les rubriques sont en lecture seule. Les données éditoriales initiales sont fournies dans `backend/seed.json`, insérées dans SQLite, puis servies par une véritable API REST. Aucun service tiers ni faux endpoint d’inscription n’est utilisé. Le serveur doit être lancé localement ou hébergé pour utiliser l’application en ligne.

## Comment lancer l’application

Prérequis : Flutter **3.41.9** / Dart **3.11.5**, Python **3.11+** avec SQLite, Android SDK et Java 17 ou 21 pour Android. La compilation iOS nécessite macOS, Xcode et la configuration de signature Apple.

Récupérez le dépôt public :

```bash
git clone https://github.com/jkatems/nextflutter_connected_app.git
cd nextflutter_connected_app
```

Si vous utilisez l’espace de travail `app_back` fourni, entrez plutôt dans `carnet` avec `cd carnet`. Dans les deux cas, toutes les commandes suivantes doivent être exécutées depuis le dossier contenant `pubspec.yaml`, `lib/` et `backend/`.

### 1. Lancer le backend réel

Depuis ce dossier, lancez l’API dans un premier terminal (commandes Bash, Linux/macOS) :

```bash
export JWT_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
python3 backend/server.py
```

Gardez la même valeur `JWT_SECRET` entre les redémarrages pour conserver les sessions. N’incluez jamais cette valeur dans Git. Le serveur refuse une clé de moins de 32 caractères. Par défaut, il écoute sur le port 8000 et stocke ses données dans `carnet.sqlite3` du répertoire courant. Aucune dépendance Python à installer.

### 2. Vérifier que l’API répond

Dans un second terminal, exécutez :

```bash
curl http://127.0.0.1:8000/health
```

Résultat attendu : `{"status": "ok"}`. Laissez le premier terminal ouvert pendant l’utilisation de l’application.

### 3. Lancer le client Flutter

Dans le second terminal, placez-vous dans le même dossier de projet. Démarrez un émulateur Android ou branchez un téléphone avec le débogage USB activé, puis exécutez :

```bash
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Cette commande cible l’API depuis un émulateur Android. Adaptez l’URL selon le tableau ci-dessous. Si plusieurs appareils sont disponibles, ajoutez `-d IDENTIFIANT_APPAREIL` à `flutter run`, avec l’identifiant affiché par `flutter devices`. Dans le terminal Flutter, `r` effectue un hot reload et `q` quitte l’exécution ; `Ctrl+C` arrête le backend dans son terminal.

Créez un compte depuis **Nouveau ici ? Créer un compte**, avec un nom de 2 à 80 caractères, un email valide et un mot de passe de 8 à 128 caractères. Aucun compte ou mot de passe prédéfini.

| Environnement | API_BASE_URL |
| --- | --- |
| Émulateur Android | `http://10.0.2.2:8000` (valeur Android par défaut) |
| Simulateur iOS | `http://127.0.0.1:8000` (valeur iOS par défaut) |
| Téléphone physique | `http://ADRESSE_IP_LOCALE_DU_PC:8000` en debug, même réseau Wi-Fi |
| API hébergée | `https://votre-domaine-api.example` |

Sur un téléphone physique, autorisez le port 8000 dans le pare-feu du PC. Android autorise HTTP dans la variante **debug seulement** ; les builds release doivent cibler HTTPS. iOS déclare l’accès réseau local ; utilisez un nom local ou HTTPS si la politique ATS du système refuse une adresse IP HTTP. L’application cible Android/iOS, pas Flutter Web.

### Variables de configuration

| Variable | Où ? | Valeur par défaut / usage |
| --- | --- | --- |
| `JWT_SECRET` | Environnement Python | Obligatoire, au moins 32 caractères ; conserver la même clé entre les redémarrages |
| `DATABASE_PATH` | Environnement Python | `carnet.sqlite3` ; fichier SQLite persistant, jamais versionné |
| `HOST` | Environnement Python | `0.0.0.0` ; utiliser `127.0.0.1` pour limiter l’écoute à la machine |
| `PORT` | Environnement Python | `8000` |
| `ACCESS_TTL` | Environnement Python | `900` secondes ; `5` pour tester rapidement l’expiration |
| `API_BASE_URL` | `--dart-define` Flutter | Adresse HTTP locale selon la plateforme ; HTTPS pour une API hébergée |

`API_BASE_URL` est fixé à la compilation : reconstruisez l’application après un changement. Le serveur lit les variables d’environnement du terminal ; il ne charge pas automatiquement de fichier `.env`. La publication du code sur GitHub n’héberge pas le serveur Python.

### Configuration backend réutilisable

Un modèle sans secret est fourni dans [`backend/.env.example`](backend/.env.example). Pour éviter de changer de clé à chaque ouverture du terminal :

1. Copiez le modèle avec `cp backend/.env.example backend/.env`.
2. Générez une clé avec `python3 -c 'import secrets; print(secrets.token_urlsafe(48))'` et placez le résultat après `JWT_SECRET=` dans `backend/.env`.
3. Depuis le dossier contenant `pubspec.yaml`, chargez explicitement les variables puis lancez le serveur :

```bash
set -a
source backend/.env
set +a
python3 backend/server.py
```

Ces commandes supposent Bash. Le serveur ne lit pas le fichier `.env` lui-même. `backend/.env` est ignoré par Git ; il doit rester local. `DATABASE_PATH` est relatif au dossier de lancement : conservez le même chemin pour retrouver les comptes et les sessions. Au premier démarrage, le serveur crée les tables et importe `seed.json` ; aux suivants, les lignes existantes sont conservées. Les tests utilisent une base temporaire distincte et n’effacent pas la base de développement.

## Architecture

```text
lib/
  core/api_client.dart      Configuration Dio, injection JWT, refresh et erreurs
  domain/models.dart        Entités Entry/Feed, erreurs et contrats abstraits
  data/storage.dart         Adaptateurs Hive et stockage sécurisé
  data/repositories.dart    Repositories d’authentification et de contenu
  presentation/controllers.dart  État de session et de chargement avec ChangeNotifier
  presentation/app.dart     Widgets et injection Provider : formulaires, listes et détail
  main.dart                 Initialisation et injection des dépendances
backend/
  server.py                 API HTTP, JWT HS256, sessions et SQLite
  seed.json                 Données initiales des trois ressources
  test_api.py               Tests de bout en bout HTTP
```

Séparation `data / domain / presentation`. Les écrans de contenu dépendent du contrat `ContentRepository` ; `main.dart` injecte `RestContentRepository`. Les repositories portent l’accès réseau et les règles de cache, sans dépendre des widgets. `SessionStore` et `FeedCache` sont substituables dans les tests. L’état métier de présentation utilise **Provider + ChangeNotifier** : `AuthController` porte la session, l’authentification en cours et les erreurs ; chaque rubrique possède un `FeedController` pour les données, le chargement et les erreurs. Les widgets observent ces contrôleurs via `watch`/`select` et déclenchent les actions via `read`. Les contrôleurs dépendent uniquement des contrats du domaine et sont testables sans widgets. Provider gère leur destruction ; les réponses tardives sont ignorées après destruction et les actualisations simultanées partagent une seule requête.

`StatefulWidget` reste réservé à l’état local d’interface : contrôleurs de champs, visibilité du mot de passe, sélection d’un onglet et clé du messager. Les appels d’authentification et de chargement ne sont plus pilotés par `setState`. Voir la [documentation officielle de Provider](https://pub.dev/packages/provider).

Le chargement suit **réseau → stockage local → affichage**. En cas d’indisponibilité réseau ou de serveur 5xx, le repository lit la dernière copie Hive. Le cache ne masque jamais une réponse 401/403 ni un format de données invalide. Les erreurs exposées par les repositories portent un `FailureKind` : réseau, session expirée, accès interdit, réponse invalide, stockage ou erreur non classée. Un cache corrompu ou inaccessible produit un message explicite. Une erreur d’écriture empêche d’annoncer une synchronisation réussie. Les sessions reçues sont validées avant sauvegarde ; le refresh ne peut pas remplacer le compte courant. La déconnexion tente d’effacer le cache même si l’effacement du stockage sécurisé échoue, et signale tout nettoyage incomplet.

Les trois rubriques sont préchargées à l’ouverture de l’espace connecté. Le détail réutilise l’entité reçue et fonctionne donc aussi hors ligne.

Les fichiers Hive et les clés de session sont séparés par URL d’API ; à l’intérieur d’une boîte Hive, les données sont séparées par identifiant utilisateur (`userId/category`). Changer de serveur ou utiliser cette nouvelle version impose donc une connexion propre, sans réutiliser les tokens d’une autre API.

Les données en cache n’ont pas d’expiration forcée : elles restent lisibles jusqu’à la prochaine actualisation ou déconnexion. Leur date et leur provenance sont affichées. Les changements sur le serveur sont récupérés par actualisation manuelle ou au prochain lancement.

## API utilisée

API Carnet incluse, Python standard + SQLite, encodage JSON UTF-8. Les routes de données nécessitent `Authorization: Bearer <accessToken>`.

| Méthode | Route | Corps / résultat |
| --- | --- | --- |
| GET | `/health` | `{ "status": "ok" }` |
| POST | `/auth/register` | `name`, `email`, `password` → session, HTTP 201 |
| POST | `/auth/login` | `email`, `password` → session |
| POST | `/auth/refresh` | `refreshToken` → nouvelle session, ancien refresh invalidé |
| POST | `/auth/logout` | JWT → révocation de la session serveur |
| GET | `/auth/me` | Profil de l’utilisateur connecté |
| GET | `/articles` | `{ "items": [...] }` |
| GET | `/products` | `{ "items": [...] }` |
| GET | `/tasks` | `{ "items": [...] }` |

Une session contient `accessToken`, `refreshToken` et `user: {id, name, email}`. Chaque élément contient `id`, `title`, `body`, `label`. Une erreur renvoie `{ "message": "..." }` avec son code HTTP approprié (400, 401, 404, 409, 413, 500).

Exemple :

```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com","password":"mon-mot-de-passe"}'
```

### Sessions et sécurité

Les mots de passe sont hachés par scrypt avec sel aléatoire. L’access token est un JWT HS256 valable 15 minutes (`ACCESS_TTL`, secondes). Le refresh token opaque est aléatoire, stocké haché côté serveur, valable 7 jours et remplacé atomiquement à chaque renouvellement. La vérification de l’access token contrôle aussi l’existence de la session : un logout en ligne invalide immédiatement ses tokens.

La session est restaurée depuis Keychain/Keystore sans imposer de réseau, afin de permettre une reprise hors ligne. Une session expirée côté serveur provoque le refresh lors du prochain appel en ligne. Si ce refresh est refusé, un message invite à se reconnecter. Une panne du refresh permet toujours le repli sur le cache.

La déconnexion efface la session locale et le cache. Hors ligne, la révocation serveur ne peut pas être confirmée : l’application le signale explicitement ; la session distante expirera au plus tard après 7 jours sans renouvellement. Le cache contient uniquement les ressources de lecture, sans tokens ni mots de passe, et n’est pas chiffré. Les sauvegardes Android sont désactivées.

Le serveur fourni est destiné à une démonstration et à un déploiement contrôlé. Pour une exposition publique durable, prévoir un reverse proxy HTTPS, des limites de débit sur l’authentification, des sauvegardes SQLite et une gestion durable du secret. Il n’inclut pas de récupération de mot de passe ni de vérification d’email.

## Tests et preuves de fonctionnement

Les tests sont versionnés dans [`test/`](test/) et [`backend/test_api.py`](backend/test_api.py). Python doit être installé avant de lancer la suite Flutter : un test démarre réellement le serveur en arrière-plan sur un port libre et le nettoie à la fin.

### Lancer les tests

Depuis le dossier contenant `pubspec.yaml` (`carnet/` dans cet espace de travail), lancez :

```bash
flutter pub get
flutter test --concurrency=2
python3 -m unittest discover -s backend -v
```

Les tests ne nécessitent ni émulateur ni démarrage manuel de l’API. Les tests HTTP créent leur propre serveur, leur secret de test et leur base temporaire. Une exécution réussie se termine par `All tests passed!` pour Flutter et `OK` pour Python.

Pour lancer uniquement le parcours Flutter → API Python → SQLite → cache hors ligne :

```bash
flutter test test/python_api_integration_test.dart
```

Pour tester uniquement les formulaires et leurs interactions :

```bash
flutter test test/auth_widget_test.dart
```

Pour vérifier les repositories et les contrôleurs indépendamment des écrans :

```bash
flutter test test/repository_test.dart test/repository_resilience_test.dart
flutter test test/controllers_test.dart
```

### Vérifications complètes, couverture et compilation Android

Après `flutter pub get`, exécutez les commandes suivantes. La dernière commande nécessite l’environnement Android indiqué dans les prérequis ; l’APK obtenu se trouve dans `build/app/outputs/flutter-apk/app-debug.apk`.

```bash
dart format --output=none --set-exit-if-changed lib test scripts
flutter analyze
flutter test --coverage --concurrency=2
python3 scripts/check_coverage.py --min-total 80
python3 -m unittest discover -s backend -v
flutter build apk --debug
```

| Fichier | Ce qu’il vérifie |
| --- | --- |
| [`repository_test.dart`](test/repository_test.dart) | 10 tests : accès REST, écriture/lecture du cache, panne sans cache, isolation entre comptes, 401 non masqué, repli 503, inscription, logout hors ligne, refresh concurrent et arrêt après refresh refusé |
| [`repository_resilience_test.dart`](test/repository_resilience_test.dart) | Réponses invalides, refus 403, cache corrompu, panne du stockage sécurisé, nettoyage après échec, refresh hors ligne, refresh tardif et changement de compte interdit |
| [`controllers_test.dart`](test/controllers_test.dart) | États Provider/ChangeNotifier : chargement, erreur, retry, double soumission, déconnexion hors ligne et réponses après destruction |
| [`cache_persistence_test.dart`](test/cache_persistence_test.dart) | 2 tests utilisant de **vraies boîtes Hive sur disque** : réouverture hors ligne, conservation de la date, isolation et effacement après logout |
| [`auth_widget_test.dart`](test/auth_widget_test.dart) | 4 tests de widgets : validation des formulaires, erreur de connexion puis réussite, inscription/navigation/logout, bouton Réessayer après une panne |
| [`widget_test.dart`](test/widget_test.dart) | Navigation entre les trois rubriques, bandeau hors ligne et détail au format téléphone |
| [`python_api_integration_test.dart`](test/python_api_integration_test.dart) | Parcours de bout en bout : Dio → serveur Python réel → SQLite, inscription/login, refresh JWT, trois ressources, arrêt du serveur, fermeture/réouverture Hive puis lecture hors ligne et logout |
| [`backend/test_api.py`](backend/test_api.py) | 3 tests HTTP : validation, doublons, identifiants invalides, routes protégées, tokens altérés/expirés, rotation et révocation |

Le test de bout en bout utilise l’adaptateur de test officiel pour Keychain/Keystore ; **HTTP, Python, SQLite et Hive sont réels**. Il ne remplace pas une vérification sur téléphone des autorisations et du stockage sécurisé natif.

### Couverture mesurée et CI

Résultats exécutés le 27 septembre 2026 : **40 tests Flutter réussis**, **3 tests HTTP Python réussis**, analyse Flutter sans problème.

| Couche | Lignes couvertes / instrumentées | Couverture |
| --- | --- | --- |
| `core` | 39 / 45 | 86,7 % |
| `data` | 59 / 65 | 90,8 % |
| `domain` | 22 / 24 | 91,7 % |
| `presentation` (widgets et contrôleurs) | 262 / 268 | 97,8 % |
| **Total instrumenté** | **382 / 402** | **95,0 %** |

Le bootstrap natif `main.dart` n’est pas inclus dans ce total. Ces chiffres proviennent du rapport LCOV local ; les commandes ci-dessus permettent de recalculer les valeurs sur la version évaluée ; la CI publie son propre rapport pour chaque commit.

`flutter test --coverage` produit `coverage/lcov.info`. `scripts/check_coverage.py` affiche les lignes couvertes par couche et le total des fichiers instrumentés ; ce pourcentage mesure la couverture des lignes, pas toutes les branches ni une garantie d’absence de bugs. Le démarrage natif et la signature iOS restent à vérifier sur appareil.

[GitHub Actions](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml) exécute le formatage, l’analyse, les tests Flutter avec couverture et les tests HTTP Python à chaque push/PR et sur déclenchement manuel. Le rapport LCOV est téléchargeable dans l’artefact **flutter-coverage** du run. Les résultats doivent correspondre au commit évalué : consulter uniquement des extraits de `lib/` ne montre pas les tests présents dans `test/`.

### Pipeline CI et livraison Android

Le workflow est versionné dans [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

| Étape | Contrôle ou résultat |
| --- | --- |
| Environnement | Ubuntu, Flutter 3.41.9, Python 3.14 ; Java 17 pour le job Android |
| Dépendances | `flutter pub get --enforce-lockfile` utilise les versions verrouillées dans `pubspec.lock` |
| Qualité | Formatage Dart puis analyse statique ; un échec arrête le job |
| Tests | Repositories, contrôleurs, widgets, Hive sur disque, intégration Flutter/API réelle et tests HTTP Python |
| Couverture | `python scripts/check_coverage.py --min-total 80` impose 80 % des lignes instrumentées ; rapport absent ou vide refusé |
| Rapport | Artefact `flutter-coverage` contenant `lcov.info`, téléversé même si une étape ultérieure échoue, lorsqu’il existe |
| Compilation | Le job `android` démarre uniquement après réussite du job `test` et compile un APK debug |
| Livraison | Artefact `carnet-android-debug` téléchargeable depuis le run GitHub Actions |

Aucun secret GitHub n’est nécessaire pour ces tests : ils génèrent leurs propres sessions et utilisent des serveurs locaux temporaires. L’APK CI cible `http://10.0.2.2:8000` et sert à une démonstration sur émulateur avec le backend démarré sur l’hôte. Pour un téléphone ou une API hébergée, reconstruisez avec l’URL adaptée.

La livraison est un **artefact de démonstration**, pas une publication automatique sur un store ni un déploiement de l’API. La mise en production reste manuelle : héberger le backend avec HTTPS, conserver son secret et son volume SQLite, puis compiler un client avec l’URL HTTPS et une signature de production. Aucun résultat de pipeline distant n’est présumé réussi avant son exécution sur GitHub.

### Essai du mode hors ligne

1. Lancez l’API et inscrivez-vous dans l’application.
2. Vérifiez que les trois rubriques affichent leurs données.
3. Arrêtez le serveur ou activez le mode avion sur un téléphone physique.
4. Actualisez une rubrique : après le timeout, le bandeau de données cachées apparaît.
5. Fermez puis relancez l’application : les données restent consultables sans réseau.
6. Rétablissez le réseau et actualisez : le bandeau indique « À jour ».
7. Déconnectez-vous : les informations de session et le cache sont supprimés.

Pour observer rapidement le refresh, lancez le serveur avec `ACCESS_TTL=5`, connectez-vous, attendez plus de cinq secondes puis actualisez.

## Héberger l’API

Un Dockerfile est fourni. Utilisez un volume persistant pour SQLite et configurez `JWT_SECRET` dans l’environnement de l’hébergeur :

```bash
docker build -t carnet-api backend
docker volume create carnet-data
docker run --rm -p 8000:8000 --env JWT_SECRET \
  -v carnet-data:/data carnet-api
```

Placez le service derrière HTTPS, puis compilez le client avec l’URL réelle :

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://votre-api.example
```

La configuration Android générée utilise la signature debug pour les builds release de développement. Configurez votre keystore avant toute publication sur un store. La cible iOS est incluse ; sa compilation et sa signature doivent être vérifiées sur macOS.

## Dépannage

| Symptôme | Vérification |
| --- | --- |
| Connexion impossible sur téléphone | API démarrée, même Wi-Fi, IP du PC dans `API_BASE_URL`, port 8000 autorisé par le pare-feu |
| Connexion impossible sur émulateur Android | Utiliser `10.0.2.2`, pas `localhost` qui désigne l’émulateur |
| Pas de données hors ligne | Charger d’abord les rubriques en ligne avec le même compte et la même URL ; une déconnexion efface le cache |
| Session expirée après redémarrage serveur | Conserver `JWT_SECRET` et le fichier SQLite ; se reconnecter si la clé a changé |
| Erreur 409 à l’inscription | L’email existe déjà dans la base : utiliser la connexion |
| Erreur HTTP en release | Utiliser une API HTTPS ; HTTP local est réservé au debug Android |
| Test de bout en bout impossible à démarrer | `python3` doit être accessible ; l’environnement doit autoriser un serveur HTTP sur loopback |

## Dépôt public

Sources : https://github.com/jkatems/nextflutter_connected_app

Pour publier une modification depuis le dépôt déjà configuré : `git push origin main`. Le serveur Python doit être hébergé séparément si l’APK doit fonctionner hors du réseau local.

## Références

- [Networking Flutter](https://docs.flutter.dev/data-and-backend/networking)
- [Dio](https://pub.dev/packages/dio)
- [Hive Flutter](https://pub.dev/packages/hive_flutter)
- [Stockage sécurisé Flutter](https://pub.dev/packages/flutter_secure_storage)
