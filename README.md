# Projet Flutter — App connectée avec backend réel

[![Vérifications](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml/badge.svg)](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml)

Application mobile Android/iOS en français : authentification JWT, trois rubriques alimentées par une API HTTP persistante et consultation hors ligne avec Hive.

**Nom de l’application : Carnet.** Le client est développé avec Flutter ; le backend réel utilise Python et une base SQLite persistante.

## Exigences du projet : fichiers et lignes de code

Le tableau relie les exigences fonctionnelles et techniques décrites dans ce README à leur implémentation. Les numéros de ligne correspondent à la version actuelle des sources ; ils peuvent changer après une modification du code. Les chemins sont relatifs au dossier contenant ce README et `pubspec.yaml`.

| Exigence | Fichiers et lignes de code | Réalisation |
| --- | --- | --- |
| Application Flutter connectée à un backend réel | [`lib/main.dart`, lignes 10–38](lib/main.dart#L10-L38) ; [`backend/server.py`, lignes 162–169](backend/server.py#L162-L169) | Initialisation du client et démarrage d’un serveur HTTP Python. |
| Persistance des données côté serveur | [`backend/server.py`, lignes 20–38](backend/server.py#L20-L38) ; [`backend/seed.json`](backend/seed.json) | Tables SQLite pour les utilisateurs, les sessions et les ressources ; insertion des données initiales. |
| Inscription et connexion réelles | [`lib/data/repositories.dart`, lignes 61–86](lib/data/repositories.dart#L61-L86) ; [`backend/server.py`, lignes 126–144](backend/server.py#L126-L144) | Envoi des formulaires à l’API, création du compte et vérification des identifiants. |
| Validation des formulaires | [`lib/presentation/app.dart`, lignes 180–233](lib/presentation/app.dart#L180-L233) ; [`backend/server.py`, lignes 127–135](backend/server.py#L127-L135) | Contrôles du nom, de l’email et du mot de passe côté client et serveur. |
| Authentification JWT et renouvellement de session | [`lib/core/api_client.dart`, lignes 45–115](lib/core/api_client.dart#L45-L115) ; [`backend/server.py`, lignes 145–151](backend/server.py#L145-L151) | Injection du Bearer token, refresh partagé entre requêtes concurrentes et nouvelle tentative limitée. |
| Protection des identifiants et des routes | [`lib/data/storage.dart`, lignes 6–23](lib/data/storage.dart#L6-L23) ; [`backend/server.py`, lignes 43–59](backend/server.py#L43-L59) et [78–94](backend/server.py#L78-L94) | Stockage sécurisé des tokens, hachage scrypt des mots de passe et contrôle de la session serveur. |
| Trois rubriques alimentées par l’API | [`lib/presentation/app.dart`, lignes 349–391](lib/presentation/app.dart#L349-L391) ; [`lib/data/repositories.dart`, lignes 11–23](lib/data/repositories.dart#L11-L23) ; [`backend/server.py`, lignes 158–159](backend/server.py#L158-L159) | Explorer, Catalogue et Tâches chargent respectivement `/articles`, `/products` et `/tasks`. |
| Écran de détail | [`lib/presentation/app.dart`, à partir de la ligne 594](lib/presentation/app.dart#L594) | Affichage du contenu sélectionné, également disponible depuis le cache. |
| Cache local persistant et consultation hors ligne | [`lib/data/storage.dart`, lignes 25–39](lib/data/storage.dart#L25-L39) ; [`lib/data/repositories.dart`, lignes 11–37](lib/data/repositories.dart#L11-L37) | Écriture dans Hive après chargement ; lecture du cache en cas de panne réseau ou d’erreur serveur 5xx. |
| Isolation du cache et restauration de session | [`lib/main.dart`, lignes 19–36](lib/main.dart#L19-L36) ; [`lib/data/repositories.dart`, ligne 12](lib/data/repositories.dart#L12) et [59](lib/data/repositories.dart#L59) | Stockage séparé par URL d’API et identifiant utilisateur ; restauration de la session locale au démarrage. |
| États de chargement, erreurs et actualisation | [`lib/presentation/app.dart`, lignes 411–505](lib/presentation/app.dart#L411-L505) ; [`lib/core/api_client.dart`, lignes 4–29](lib/core/api_client.dart#L4-L29) | Indicateur de chargement, messages en français, bouton Réessayer, glissement pour actualiser et date des données. |
| Déconnexion et nettoyage local | [`lib/data/repositories.dart`, lignes 91–102](lib/data/repositories.dart#L91-L102) ; [`backend/server.py`, lignes 153–155](backend/server.py#L153-L155) | Révocation serveur lorsque le réseau est disponible ; suppression locale de la session et du cache. |
| Séparation des responsabilités | [`lib/domain/models.dart`, lignes 38–62](lib/domain/models.dart#L38-L62) ; [`lib/main.dart`, lignes 27–38](lib/main.dart#L27-L38) | Contrats du domaine, repositories de données et injection des dépendances dans la présentation. |
| Tests automatisés et intégration réelle | [`test/repository_test.dart`, à partir de la ligne 69](test/repository_test.dart#L69) ; [`test/auth_widget_test.dart`, à partir de la ligne 52](test/auth_widget_test.dart#L52) ; [`test/cache_persistence_test.dart`, à partir de la ligne 11](test/cache_persistence_test.dart#L11) ; [`test/python_api_integration_test.dart`, à partir de la ligne 12](test/python_api_integration_test.dart#L12) ; [`backend/test_api.py`, à partir de la ligne 47](backend/test_api.py#L47) | Vérification des repositories, des formulaires, de Hive sur disque et du parcours HTTP avec Python et SQLite. |

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

## Architecture

```text
lib/
  core/api_client.dart      Configuration Dio, injection JWT, refresh et erreurs
  domain/models.dart        Entités Entry/Feed, erreurs et contrats abstraits
  data/storage.dart         Adaptateurs Hive et stockage sécurisé
  data/repositories.dart    Repositories d’authentification et de contenu
  presentation/app.dart     Formulaires, navigation, listes et détail
  main.dart                 Initialisation et injection des dépendances
backend/
  server.py                 API HTTP, JWT HS256, sessions et SQLite
  seed.json                 Données initiales des trois ressources
  test_api.py               Tests de bout en bout HTTP
```

Séparation `data / domain / presentation`. Les écrans de contenu dépendent du contrat `ContentRepository` ; `main.dart` injecte `RestContentRepository`. Les repositories portent l’accès réseau et les règles de cache, sans dépendre des widgets. `SessionStore` et `FeedCache` sont substituables dans les tests. L’état de présentation utilise `StatefulWidget` pour limiter les dépendances.

Le chargement suit **réseau → stockage local → affichage**. En cas d’indisponibilité réseau ou de serveur 5xx, le repository lit la dernière copie Hive. Le cache ne masque jamais une réponse 401/403 ni un format de données invalide. Les trois rubriques sont préchargées à l’ouverture de l’espace connecté. Le détail réutilise l’entité reçue et fonctionne donc aussi hors ligne.

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

### Vérifications complètes, couverture et compilation Android

Après `flutter pub get`, exécutez les commandes suivantes. La dernière commande nécessite l’environnement Android indiqué dans les prérequis ; l’APK obtenu se trouve dans `build/app/outputs/flutter-apk/app-debug.apk`.

```bash
dart format --output=none --set-exit-if-changed lib test scripts
flutter analyze
flutter test --coverage --concurrency=2
python3 scripts/check_coverage.py
python3 -m unittest discover -s backend -v
flutter build apk --debug
```

| Fichier | Ce qu’il vérifie |
| --- | --- |
| [`repository_test.dart`](test/repository_test.dart) | 10 tests : accès REST, écriture/lecture du cache, panne sans cache, isolation entre comptes, 401 non masqué, repli 503, inscription, logout hors ligne, refresh concurrent et arrêt après refresh refusé |
| [`cache_persistence_test.dart`](test/cache_persistence_test.dart) | 2 tests utilisant de **vraies boîtes Hive sur disque** : réouverture hors ligne, conservation de la date, isolation et effacement après logout |
| [`auth_widget_test.dart`](test/auth_widget_test.dart) | 4 tests de widgets : validation des formulaires, erreur de connexion puis réussite, inscription/navigation/logout, bouton Réessayer après une panne |
| [`widget_test.dart`](test/widget_test.dart) | Navigation entre les trois rubriques, bandeau hors ligne et détail au format téléphone |
| [`python_api_integration_test.dart`](test/python_api_integration_test.dart) | Parcours de bout en bout : Dio → serveur Python réel → SQLite, inscription/login, refresh JWT, trois ressources, arrêt du serveur, fermeture/réouverture Hive puis lecture hors ligne et logout |
| [`backend/test_api.py`](backend/test_api.py) | 3 tests HTTP : validation, doublons, identifiants invalides, routes protégées, tokens altérés/expirés, rotation et révocation |

Le test de bout en bout utilise l’adaptateur de test officiel pour Keychain/Keystore ; **HTTP, Python, SQLite et Hive sont réels**. Il ne remplace pas une vérification sur téléphone des autorisations et du stockage sécurisé natif.

### Couverture mesurée et CI

Résultats exécutés le 13 septembre 2026 : **18 tests Flutter réussis**, **3 tests HTTP Python réussis**, analyse Flutter sans problème.

| Couche | Lignes couvertes / instrumentées | Couverture |
| --- | --- | --- |
| `core` | 36 / 43 | 83,7 % |
| `data` | 52 / 62 | 83,9 % |
| `domain` | 12 / 15 | 80,0 % |
| `presentation` | 225 / 231 | 97,4 % |
| **Total instrumenté** | **325 / 351** | **92,6 %** |

Le bootstrap natif `main.dart` n’est pas inclus dans ce total. Ces chiffres proviennent de LCOV et sont reproductibles avec les commandes ci-dessus ; la CI publie son propre rapport pour chaque commit.

`flutter test --coverage` produit `coverage/lcov.info`. `scripts/check_coverage.py` affiche les lignes couvertes par couche et le total des fichiers instrumentés ; ce pourcentage mesure la couverture des lignes, pas toutes les branches ni une garantie d’absence de bugs. Le démarrage natif et la signature iOS restent à vérifier sur appareil.

[GitHub Actions](https://github.com/jkatems/nextflutter_connected_app/actions/workflows/ci.yml) exécute le formatage, l’analyse, les tests Flutter avec couverture et les tests HTTP Python à chaque push/PR. Le rapport LCOV est téléchargeable dans l’artefact **flutter-coverage** du run. Les résultats doivent correspondre au commit évalué : consulter uniquement des extraits de `lib/` ne montre pas les tests présents dans `test/`.

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
