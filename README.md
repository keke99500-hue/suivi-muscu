# Suivi Muscu 💪

App de suivi muscu : séances, programmes, XP et niveaux, rangs, nutrition et classements entre potes.

- `index.html` : l'app
- `config.js` : URL et clé publique Supabase
- `supabase.sql` : création de la base (à lancer une fois dans Supabase › SQL Editor)
- `sw.js` + `manifest.webmanifest` + icônes : app installable sur l'écran d'accueil
- `.github/workflows/backup.yml` : sauvegarde automatique chaque lundi dans `backups/` (garde les 8 dernières)

**Mettre à jour l'app** : remplacer `index.html`, c'est tout. Les données sont dans Supabase et ne bougent pas.
