# Conscientia : Apostoli — Proof of concept

Prototype de combat de **Conscientia : Apostoli**, réalisé sous **Godot 4.7**.

Dans l'univers de Conscientia, le **Credo Sum** est l'énergie née de la croyance humaine : chaque
émotion lui donne une forme différente. Ce POC met en scène un combat 3D au tour par tour avec QTE,
dans l'esprit de *Clair Obscur: Expedition 33*. Trois héros y affrontent un Médian de la Peur, le
Veilleur de Gavillon, et les villageois qu'il a altérés.

## Lancer le jeu

1. Installer [Godot 4.7](https://godotengine.org/download) (version standard, pas .NET).
2. Cloner le dépôt :
   ```bash
   git clone https://github.com/Ferrone84/godot_poc_conscientia.git
   ```
3. Ouvrir le dossier dans Godot et lancer la scène principale (F5), ou en ligne de commande :
   ```bash
   godot --path .
   ```

Lancé depuis l'éditeur, le jeu s'affiche par défaut dans l'onglet « Jeu ». Le mode d'affichage et
la résolution ne s'y changent pas : décocher « Intégrer le jeu » dans cet onglet, ou lancer le jeu
hors de l'éditeur.

## Commandes

| Action | Touche |
|---|---|
| Naviguer dans les menus | Flèches, Entrée (ou souris) |
| Revenir en arrière / Options | Échap |
| QTE d'attaque | Espace au moment où l'anneau recouvre le cercle |
| Parer une attaque ennemie | E (fenêtre courte) |
| Esquiver une attaque ennemie | Espace (fenêtre plus large) |
| Plein écran | F11 |

## Ce que montre le POC

- **Tour par tour avec ordre prédictif** : la frise en haut à gauche montre qui joue ensuite, selon la vitesse de chacun.
- **Points d'action** : l'attaque de base et les parades en rendent, les compétences de Credo Sum en consomment.
- **QTE** : en attaque, un bon timing renforce la compétence. En défense, on pare ou on esquive chaque coup ; tout parer déclenche une contre-attaque.
- **Trois héros, trois mécaniques** :
  - **Céran**, 16 ans, Inquisiteur — l'**Espace**. Il se téléporte et accumule de la *Distorsion*, que ses QTE réussis consomment pour des effets plus puissants.
  - **Lucie**, Médecin du temple — la **Chair**. Son *Empathie* penche vers les dégâts ou vers les soins selon ses actions.
  - **Nicolas**, Disciple de Fradiel — le **Temps**. L'heure de son horloge change l'effet de ses compétences ; il peut ralentir, accélérer, programmer des dégâts futurs ou arrêter le temps.
- **Effets de Credo Sum** : chaque émotion a sa signature visuelle (plasma violet de la crainte, fumée rose de l'amour, étincelles dorées de la joie, vapeur verte de la peur, éclairs orange de la colère…).
- **Options d'affichage** : plein écran, résolution, mise à l'échelle FSR, anticrénelage, VSync, taille de l'interface.

Les héros sont modélisés et animés entièrement en code (cel-shading) ; les ennemis sont encore des formes provisoires.

## Démo vidéo

Un mode démo joue un combat complet tout seul, avec des sous-titres qui expliquent les mécaniques :

```bash
godot --path . -- --demo
```

Pour en faire une vidéo, Godot peut l'enregistrer directement (`--write-movie demo.avi --fixed-fps 30`).
Les détails, dont l'astuce pour enregistrer en 1080p, sont dans [CLAUDE.md](CLAUDE.md).

## Tests automatiques

```bash
# Combat joué automatiquement, accéléré, sans fenêtre
godot --headless --path . -- --autotest --fast
# Même chose en ratant tous les QTE
godot --headless --path . -- --autotest --fast --qte-miss
```

## Organisation du projet

```
scenes/battle.tscn      scène principale
scripts/battle/         boucle de combat, combattants, héros, arène, mode démo
scripts/data/           personnages, compétences, émotions
scripts/ui/             interface, QTE, jauges, options
scripts/core/           réglages d'affichage (autoload)
scripts/vfx/, shaders/  effets de Credo Sum
tests/                  scènes de vérification visuelle
Lore/                   documents de l'univers
```

Tout est généré par le code : il n'y a ni modèle 3D ni texture importés.
