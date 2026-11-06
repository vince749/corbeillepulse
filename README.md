# CorbeillePulse

Petite app macOS native (Swift, macOS 14+) : l'état de la Corbeille dans la barre de menus, et un tas de débris par-dessus le Dock quand elle dépasse le seuil choisi.

**Télécharger :** le DMG est dans les [Releases](https://gitlab.com/northerntech1/mac-apps/corbeillepulse/-/releases). Les instructions d'installation sont dans `Lisez-moi.txt`, à l'intérieur du DMG.

- `swift test` : tests (`CP_LIVE=1 swift test` lit aussi la vraie Corbeille, sans la modifier)
- `scripts/build-app.sh` : construit `dist/CorbeillePulse.app` (universelle, signature ad hoc)
- `scripts/make-dmg.sh` : construit le DMG à partir de l'app

Sans accès complet au disque, l'app lit la Corbeille via le Finder, qui ne donne pas la taille des dossiers.
