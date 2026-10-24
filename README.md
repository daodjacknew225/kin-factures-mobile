# Kin Factures — application mobile

Application Android des entreprises inscrites sur Kin Factures (https://factures.kinpay.cd) :
factures, clients, produits, solde et retraits. Même API que le site (dépôt `kin-factures-api`),
connexion par jeton (`Authorization: Bearer`).

## Stack
Flutter 3.38 · GetX (état, navigation) · dio (API) · flutter_secure_storage (jeton) ·
local_auth (déverrouillage par empreinte) · intl (français).

## Lancer
```sh
# Production (par défaut)
flutter run

# API locale depuis l'émulateur Android (10.0.2.2 = le PC)
flutter run --dart-define=SITE_URL=http://10.0.2.2:5173 --dart-define=API_URL=http://10.0.2.2:3001/api

# Essai du verrouillage sans attendre 15 minutes
flutter run --dart-define=IDLE_LOCK_SECONDS=40
```

## Règles
- Couleurs et mesures : `lib/app/theme.dart` (reprend `tokens.css` du site), jamais de couleur en dur.
- Aucune clé secrète dans l'application : elle n'appelle que l'API Kin Factures.
- Les droits sont appliqués par l'API ; `Auth.to.can()` sert seulement à afficher ou masquer un bouton.
- La clé de signature Android (`*.jks`, `key.properties`) ne va jamais dans git.
