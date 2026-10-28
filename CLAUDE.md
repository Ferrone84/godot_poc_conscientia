# Conscientia : Apostoli — POC Godot

Proof of concept du jeu **Conscientia : Apostoli** : un combat 3D au tour par tour avec QTE,
inspiré de *Clair Obscur: Expedition 33*. Tout est construit procéduralement en GDScript
(aucun asset importé) : la scène principale `scenes/battle.tscn` n'est qu'un `Node3D` portant `battle.gd`.

Langue du projet : **français** (textes du jeu, commentaires, messages de commit).

## Environnement

- Godot **4.7.2** : `C:\Godot\Godot_v4.7.2-stable_win64.exe` (Forward+, D3D12, Jolt). Pas de MCP ni d'éditeur nécessaire : tout se pilote en ligne de commande.
- Écran de l'utilisateur : ultrawide **3440×1440**.
- ffmpeg est installé (winget) pour convertir les captures vidéo.
- Dépôt : https://github.com/Ferrone84/godot_poc_conscientia, branche `main`.

```bash
# Jouer
C:\Godot\Godot_v4.7.2-stable_win64.exe --path .
# Après l'ajout d'une nouvelle `class_name` : régénérer le cache des classes globales,
# sinon "Could not find type ... in the current scope"
C:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . --import
```

## Lore et canon

Le dossier `Lore/` (.docx) décrit l'univers : le **Credo Sum** (CS) est l'énergie issue de la croyance
humaine ; les Foyers de CS sont les **Ascendants**, **Émergents** et **Médians** ; factions : Empire
Estrédien, Vaurédie/Hexagonia, l'Athée, l'Omnideus. Les .docx se lisent en extrayant le XML du zip.

- La frise `Lore/Frise du Script.drawio` est la source la plus récente ; `99. Archives/Script.docx` est
  plus ancien mais contient les kits de combat. En cas de contradiction : privilégier la frise et demander.
- **Arbitrages de l'utilisateur** (à respecter partout) :
  - **Fradiel** (pas « Lionel »), **Laurent** (pas « Franck ») ; les autres noms sont corrects.
  - **Céran** : pouvoir CS = l'**Espace**, **16 ans** au début du jeu.
  - Carte blanche sur l'apparence des personnages.
- Table des émotions du CS (utilisée par les VFX, `scripts/data/emotions.gd`) :
  colère = éclairs orange, haine = flamme rouge, peur = vapeur verte, amour = fumée rose,
  crainte = plasma violet, joie = étincelles dorées, tristesse = liquide bleu.

## Architecture

| Fichier | Rôle |
|---|---|
| `scripts/battle/battle.gd` | Boucle de combat, exécution des compétences, tours ennemis, mise en scène (caméra, blink, textes flottants) |
| `scripts/battle/combatant.gd` | `Combatant` : stats, statuts, jauges, dégâts/soins, modèles placeholder des ennemis |
| `scripts/battle/hero_model.gd` | `HeroModel` : héros articulés en cel-shading (pivots + animations par tweens) |
| `scripts/battle/arena.gd` | `Arena.build()` : décor, lumières, environnement, caméra |
| `scripts/battle/demo_director.gd` | `DemoDirector` : combat scénarisé pour la vidéo (`--demo`) |
| `scripts/data/roster.gd` | Stats des personnages et patterns d'attaque ennemis |
| `scripts/data/skill_db.gd` | Compétences (`SKILLS`), kits (`KITS`), règles de ciblage |
| `scripts/data/emotions.gd` | Couleurs et styles par émotion |
| `scripts/ui/battle_ui.gd` | `BattleUI` : frise des tours, cartes, menu d'actions, bannière, sous-titres, écran de fin |
| `scripts/ui/qte_overlay.gd` | `QteOverlay` : QTE d'attaque et de défense, popups |
| `scripts/ui/gauge_widget.gd` | Jauges dessinées (Distorsion, Empathie, Horloge) |
| `scripts/ui/options_menu.gd` | Menu Options (Échap), met le jeu en pause |
| `scripts/core/game_settings.gd` | Autoload `GameSettings` : réglages d'affichage |
| `scripts/vfx/cs_flux.gd`, `cs_lightning.gd`, `shaders/cs_distortion.gdshader` | Effets de CS (particules, ondes, distorsion d'écran, éclairs) |
| `tests/` | Scènes de vérification visuelle (voir plus bas) |

## Règles du combat

- **Ordre des tours** par la vitesse, avec une chronologie prédictive : `next_time += 100 / vitesse`.
- **PA** : +1 par tour, +1 par attaque de base et par parade réussie, maximum 9.
- **QTE d'attaque** : un anneau se resserre, appuyer sur [Espace] (parfait ±0,07 s, réussi ±0,16 s).
- **QTE de défense** : [E] parer (±0,11 s), [Espace] esquiver (−0,22/+0,09 s). Parer tous les coups d'une attaque déclenche une **contre-attaque**. Une parade sur une attaque de zone protège toute l'équipe.
- **Héros** :
  - **Céran** (Inquisiteur, l'Espace) : jauge de **Distorsion** 0–100, consommée par les QTE réussis ; se déplace en « blink ». Kit : Faille, Ancrage spatial, Effondrement (ultime).
  - **Lucie** (Médecin du temple, la Chair) : **Empathie** −100..100 (multiplicateur dégâts ↔ soins). Passif « Dernier souffle » : le premier allié qui devrait mourir reste à 1 PV. Kit : Suture, Hyperplasie, Greffe, Appel des morts, Retour au départ, Excès de vie (ultime).
  - **Nicolas** (Disciple de Fradiel, le Temps) : **horloge** 0–11h. Heure paire : les compétences avancent l'aiguille ; impaire : elles la reculent. À 3/6/9h certaines touchent tous les ennemis. Un tour complet donne un jeton. Kit : Onde, Ralentissement, Hâte, Dégâts futurs, Retour vers le futur, Arrêt du temps (ultime, 1 jeton).
- **Ennemis** : 2 Altérés (colère) et le Veilleur de Gavillon (Médian de la Peur, 600 PV) ; les ennemis gardent volontairement des modèles placeholder.

## Rendu

- **Héros** : cel-shading (`DIFFUSE_TOON`/`SPECULAR_TOON` + rim), contour par coque inversée (`next_pass`, grow + `CULL_FRONT`), rig de pivots animé par tweens (`play("charge"|"attack"|"cast"|"hit"|"parry")`).
- `DEFAULT_LOOK` dans `battle.gd` doit rester cohérent avec le cadrage de la caméra dans `arena.gd`.

## Affichage et options

- Base 1280×720, stretch `canvas_items` / `expand` : l'UI s'adapte, la 3D est rendue à la taille réelle de la fenêtre.
- `GameSettings` (sauvegardé dans `user://settings.cfg`) : mode de fenêtre, résolution, échelle de rendu 3D + FSR/FSR2, MSAA, VSync, taille d'interface. F11 bascule le plein écran. En plein écran, la « résolution » fixe la définition de la 3D (l'UI reste nette).
- Lancé avec F5 depuis l'éditeur, le jeu est **intégré à l'onglet « Jeu »** : il ne peut changer ni sa taille ni son mode. Le menu le détecte (`Engine.is_embedded_in_editor()`) et grise ces options.
- `_window_locked()` : pas de gestion de fenêtre en headless, en jeu intégré, ni pendant un enregistrement `--write-movie`.
- Les réglages réels du joueur sont dans `%APPDATA%\Godot\app_userdata\Poc_conscientia\settings.cfg`. **Ne jamais les écraser dans un test** (ou les restaurer après).

## Tests et validation

Pas de framework de test : on valide par des combats automatiques en headless et des captures d'images.

```bash
# Combat joué automatiquement (affiche une ligne AUTOTEST: VICTOIRE/DEFAITE + contrôle d'anomalies)
C:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . -- --autotest --fast
# Variante qui rate tous les QTE (doit perdre souvent : vérifie la difficulté et les KO)
C:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . -- --autotest --fast --qte-miss
```

- `--fast` : `Engine.time_scale = 3`.
- `tests/display_test.tscn` : essaie plusieurs résolutions et le plein écran, enregistre des captures (ne sauvegarde pas les réglages).
- `tests/hero_showcase.tscn` : les trois héros de face et de dos qui enchaînent leurs animations (à enregistrer avec `--write-movie`).
- Vérification visuelle : capturer des images avec `--write-movie <dossier>/f.png --fixed-fps N --quit-after N` puis les regarder.
- Un process Godot lancé en arrière-plan qui plante au parsing ne quitte jamais : vérifier qu'il n'en reste pas (et ne tuer que ceux qu'on a lancés, l'utilisateur peut avoir l'éditeur ouvert).

## Mode démo et vidéo

`-- --demo` joue un combat scénarisé (`DemoDirector`, graine fixe) : navigation simulée dans les menus,
chaque compétence montrée au moins une fois (sauf Appel des morts, personne ne tombe), QTE réussis,
défense alternant parades/esquives/coups encaissés, sous-titres explicatifs, écran-titre et conclusion.
Nicolas commence avec 1 jeton pour pouvoir montrer l'Arrêt du temps. Durée ≈ 2 min 20.

Enregistrer en 1080p : **`--resolution` est ignoré par `--write-movie`** (sortie bloquée en 1280×720).
Créer temporairement un `override.cfg` à la racine, puis le supprimer :

```ini
[display]

window/size/window_width_override=1920
window/size/window_height_override=1080
```

```bash
C:\Godot\Godot_v4.7.2-stable_win64.exe --path . --write-movie <scratch>/demo.avi --fixed-fps 30 -- --demo
ffmpeg -i <scratch>/demo.avi -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart -an video/conscientia_poc_demo.mp4
```

La qualité MJPEG de l'AVI est réglée dans `project.godot` (`editor/movie_writer/mjpeg_quality=0.95`).
Le dossier `video/` est ignoré par git.

## Pièges connus

- `BILLBOARD_PARTICLES` ignore l'échelle des particules sans `billboard_keep_scale = true`.
- Tween : `set_parallel(true)` annule un `chain()` en attente ; enchaîner explicitement avec `chain()`/`parallel()` (voir `HeroModel._rest`).
- Ne pas nommer une méthode `_set` (collision avec le virtuel d'`Object`) : d'où `OptionsMenu._apply_setting`.
- Dégâts et soins sont arrondis (`roundf`) : sinon des PV fractionnaires s'affichent « 0 » sur un personnage vivant.
- Panneaux centrés (Options, fin de combat) : `reset_size()` puis `set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)` à l'ouverture ; un `Label` en autowrap a besoin d'un `custom_minimum_size.x`, sinon il gonfle en hauteur.
- `_wait()` utilise `create_timer(s, false)` : les attentes se figent quand le menu Options met l'arbre en pause (le menu est `PROCESS_MODE_ALWAYS`).
- `OS.get_cmdline_args()` ne voit pas `--write-movie` : utiliser `Engine.get_write_movie_path()`.
- Les noms 3D des ennemis utilisent `no_depth_test` pour rester lisibles.

## Git

- Commits en français, sur une branche de travail puis fusion en avance rapide sur `main` et push quand l'utilisateur le demande (ou directement sur `main` s'il le demande explicitement).
- Commiter les fichiers `.uid` générés par Godot avec leurs scripts.

## Pistes à venir

- **Piste B** : vrais modèles de personnages via **VRoid Studio + Mixamo** (l'utilisateur l'évalue), en commençant par Céran. La piste A (héros procéduraux en cel-shading) est faite.
- Les ennemis restent en placeholders tant que l'utilisateur ne demande pas autre chose.
