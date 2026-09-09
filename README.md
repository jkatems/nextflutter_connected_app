# Carnet — Flutter + API REST

Application mobile Android/iOS en français : authentification JWT, trois rubriques alimentées par une API HTTP persistante et consultation hors ligne avec Hive.

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

## Démarrage rapide

Prérequis : Flutter **3.41.9** / Dart **3.11**, Python **3.11+** avec SQLite, Android SDK et Java 17 pour Android. La compilation iOS nécessite macOS, Xcode et la configuration de signature Apple.

Depuis le dossier du dépôt, lancez l’API dans un premier terminal :

```bash
export JWT_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
python3 backend/server.py
```

Gardez la même valeur `JWT_SECRET` entre les redémarrages pour conserver les sessions. N’incluez jamais cette valeur dans Git. Le serveur refuse une clé de moins de 32 caractères. Par défaut, il écoute sur le port 8000 et stocke ses données dans `carnet.sqlite3` du répertoire courant. Aucune dépendance Python à installer.

Dans un second terminal :

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Créez un compte depuis **Nouveau ici ? Créer un compte**, avec un nom de 2 à 80 caractères, un email valide et un mot de passe de 8 à 128 caractères. Aucun compte ou mot de passe prédéfini.

| Environnement | API_BASE_URL |
| --- | --- |
| Émulateur Android | `http://10.0.2.2:8000` (valeur Android par défaut) |
| Simulateur iOS | `http://127.0.0.1:8000` (valeur iOS par défaut) |
| Téléphone physique | `http://ADRESSE_IP_LOCALE_DU_PC:8000` en debug, même réseau Wi-Fi |
| API hébergée | `https://votre-domaine-api.example` |

Sur un téléphone physique, autorisez le port 8000 dans le pare-feu du PC. Android autorise HTTP dans la variante **debug seulement** ; les builds release doivent cibler HTTPS. iOS déclare l’accès réseau local ; utilisez un nom local ou HTTPS si la politique ATS du système refuse une adresse IP HTTP. L’application cible Android/iOS, pas Flutter Web.

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

## Vérification

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python3 -m unittest discover -s backend -v
flutter build apk --debug
```

`test/repository_test.dart` vérifie les succès réseau, l’écriture du cache, le repli hors ligne, l’absence de cache, l’isolation entre comptes, le refus de masquer un 401, le repli 503, l’inscription persistée, la déconnexion hors ligne, le refresh concurrent et l’absence de boucle après refus du refresh. `test/widget_test.dart` vérifie la navigation entre les trois rubriques et le détail. Les tests HTTP utilisent une base temporaire et un véritable serveur local pour couvrir inscription, login, lecture, rotation, expiration et révocation.

GitHub Actions exécute formatage, analyse, tests Flutter et tests HTTP à chaque push/PR.

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

## Publier sur GitHub

Depuis ce dossier, avec GitHub CLI connecté :

```bash
gh repo create carnet-flutter --public --source=. --remote=origin --push
```

Si le dépôt existe déjà, ajoutez son URL avec `git remote add origin URL_DU_DEPOT`, puis `git push -u origin main`.

## Références

- [Networking Flutter](https://docs.flutter.dev/data-and-backend/networking)
- [Dio](https://pub.dev/packages/dio)
- [Hive Flutter](https://pub.dev/packages/hive_flutter)
- [Stockage sécurisé Flutter](https://pub.dev/packages/flutter_secure_storage)
