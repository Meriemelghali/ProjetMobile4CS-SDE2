# HôpitalConnect

Application Flutter de coordination du personnel hospitalier, avec une API
Express 5 et MongoDB. L’inscription publique crée un compte patient à accès
limité ; seul un administrateur peut changer son rôle. Les transmissions sont
réservées aux consignes opérationnelles : ne saisissez aucune donnée réelle
de patient.

## Prérequis

- Flutter et Dart (voir `flutter doctor`)
- Node.js 20 ou plus récent
- MongoDB local ou une base MongoDB Atlas
- Pour Android : Android Studio et un émulateur démarré

## 1. Configurer et démarrer le backend

Dans un premier terminal PowerShell, à la racine du dépôt :

```powershell
cd "C:\Users\windows 10\Desktop\4CS-SDE2\Mobile2\ProjetMobile4CS-SDE2\backend"
npm install
Copy-Item .env.example .env
```

Ouvrez `backend\.env` et définissez `MONGODB_URI` et `JWT_SECRET`. Le secret
JWT doit contenir au moins 32 caractères et ne doit pas être publié. Démarrez
MongoDB, puis lancez l’API :

```powershell
npm run dev
```

L’API écoute par défaut sur `http://localhost:3000`. Vous pouvez vérifier
qu’elle fonctionne en ouvrant `http://localhost:3000/health`.
Pour la procédure détaillée d’initialisation, consultez
[backend/README.md](backend/README.md).

### Travail en groupe avec MongoDB Atlas

Chaque membre clone le dépôt et crée son propre fichier local avec
`Copy-Item .env.example .env` dans `backend`, puis ajoute l’URI Atlas dans ce
fichier. Vous pouvez partager la configuration uniquement par un canal privé
de gestion de secrets ; ne partagez jamais `.env` sur Git ni dans des captures
d’écran. Dans Atlas, accordez à l’utilisateur de base de données le rôle
`readWrite` sur `hopital_connect`, puis ajoutez l’adresse IP publique de chaque
membre à **Network Access**. Le bootstrap du premier administrateur ne se fait
qu’une seule fois pour cette base commune.

### Créer le premier compte administrateur

Dans un deuxième terminal PowerShell, configurez le mot de passe initial sans
le mettre dans l’historique des commandes :

```powershell
cd "C:\Users\windows 10\Desktop\4CS-SDE2\Mobile2\ProjetMobile4CS-SDE2\backend"
$secure = Read-Host "Mot de passe initial (10 caractères minimum)" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $env:BOOTSTRAP_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  npm run bootstrap:admin -- admin admin@example.test
} finally {
  Remove-Item Env:BOOTSTRAP_ADMIN_PASSWORD -ErrorAction SilentlyContinue
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}
```

Connectez-vous ensuite dans l’application avec `admin@example.test` et le
mot de passe choisi. Depuis l’onglet **Admin**, créez les services et les
comptes du personnel.

## 2. Démarrer l’application Flutter

Dans un autre terminal :

```powershell
cd "C:\Users\windows 10\Desktop\4CS-SDE2\Mobile2\ProjetMobile4CS-SDE2\hopital_connect"
flutter pub get
flutter run
```

L’URL par défaut est `http://10.0.2.2:3000`, qui permet à l’émulateur Android
d’accéder au backend de l’ordinateur. Pour Chrome, utilisez :

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

Pour un téléphone physique, remplacez `localhost` par l’adresse IP locale de
l’ordinateur, par exemple :

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Le téléphone et l’ordinateur doivent être sur le même réseau. La session est
conservée localement ; **Se déconnecter** l’efface. Les rôles et les
autorisations sont vérifiés par l’API, pas par un choix sur l’écran de
connexion.

## Vérification

```powershell
cd "C:\Users\windows 10\Desktop\4CS-SDE2\Mobile2\ProjetMobile4CS-SDE2\backend"
npm test

cd "C:\Users\windows 10\Desktop\4CS-SDE2\Mobile2\ProjetMobile4CS-SDE2\hopital_connect"
flutter analyze
flutter test
```

## Documentation

- [Architecture Flutter](docs/architecture.md)
- [Modules et fonctionnalités](docs/modules-et-fonctionnalites.md)
- [Cadrage fonctionnel](docs/cadrage.md)
- [Documentation du backend et API](backend/README.md)
