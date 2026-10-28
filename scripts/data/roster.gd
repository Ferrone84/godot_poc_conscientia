class_name Roster
extends RefCounted
## Statistiques de base des combattants du POC.

const CHARACTERS := {
	"ceran": {
		"name": "Céran", "max_hp": 260.0, "atk": 30.0, "speed": 12.0, "emotion": "crainte",
		"gauge_name": "Distorsion", "title": "Inquisiteur, 16 ans — l'Espace",
	},
	"lucie": {
		"name": "Lucie", "max_hp": 220.0, "atk": 20.0, "speed": 10.0, "emotion": "amour",
		"gauge_name": "Empathie", "title": "Médecin du temple — la Chair",
	},
	"nicolas": {
		"name": "Nicolas", "max_hp": 200.0, "atk": 22.0, "speed": 11.0, "emotion": "joie",
		"gauge_name": "Horloge", "title": "Disciple de Fradiel — le Temps",
	},
	"altere": {
		"name": "Altéré", "max_hp": 170.0, "atk": 24.0, "speed": 9.0, "emotion": "colere",
		"title": "Villageois altéré par le Médian",
	},
	"veilleur": {
		"name": "Veilleur de Gavillon", "max_hp": 600.0, "atk": 31.0, "speed": 7.0, "emotion": "peur",
		"title": "Médian de la Peur",
	},
}

## Attaques ennemies. "hits" = durée d'élan (s) avant chaque impact :
## c'est la fenêtre pendant laquelle le joueur doit parer ou esquiver.
const ENEMY_PATTERNS := {
	"altere": [
		{"name": "Coup de griffe", "hits": [0.95], "power": 1.1},
		{"name": "Frénésie", "hits": [0.85, 0.42, 0.65], "power": 0.6},
	],
	"veilleur": [
		{"name": "Étreinte de terreur", "hits": [1.25, 0.5], "power": 1.0},
		{"name": "Vague d'effroi", "hits": [1.05], "power": 0.8, "aoe": true, "status": "effroi"},
		{"name": "Glas de Gavillon", "hits": [0.9, 0.38, 0.38, 1.15], "power": 0.7, "below_hp": 0.5},
	],
}
