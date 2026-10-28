class_name DemoDirector
extends RefCounted
## Mode démo (`-- --demo`) : un combat qui se joue tout seul, scénarisé pour
## montrer tout le POC (chaque compétence, parades, esquives, contre-attaques)
## avec des sous-titres explicatifs. Pensé pour être enregistré :
##   godot --path . --write-movie demo.avi --fixed-fps 30 --resolution 1920x1080 -- --demo

const SEED := 7

## Ordre dans lequel chaque héros montre ses compétences. Une compétence pas
## encore utilisable (PA, jeton, cible, personne à soigner) attend son tour.
const SHOWCASE := {
	"ceran": ["ceran_faille", "ceran_ancrage", "ceran_effondrement"],
	"lucie": ["lucie_suture", "lucie_hyperplasie", "lucie_greffe", "lucie_retour", "lucie_exces", "lucie_appel"],
	"nicolas": ["nicolas_futur", "nicolas_hate", "nicolas_arret", "nicolas_onde", "nicolas_ralenti", "nicolas_retour"],
}
## Jetons de départ de Nicolas : un tour d'horloge complet prend trop de temps
## pour une démo, on lui en donne un pour montrer l'Arrêt du temps.
const NICOLAS_TOKENS := 1
## Une fois la vitrine terminée : compétences offensives dès que les PA le permettent.
const FINISHERS := {
	"ceran": ["ceran_effondrement", "ceran_faille"],
	"lucie": ["lucie_suture"],
	"nicolas": ["nicolas_onde", "nicolas_futur"],
}
## Défense jouée à chaque attaque ennemie, dans l'ordre puis en boucle.
const DEFENSE := ["parry", "dodge", "hit", "parry", "hit", "dodge", "parry", "hit"]

const CAPTIONS := {
	"intro": "En haut à gauche, la frise donne l'ordre des tours, calculé d'après la vitesse de chacun.",
	"hero_ceran": "Céran, 16 ans — Credo Sum de l'Espace. Ses QTE réussis puisent dans sa jauge de Distorsion.",
	"hero_lucie": "Lucie — la Chair. Son Empathie penche vers les dégâts ou vers les soins selon ses actions.",
	"hero_nicolas": "Nicolas — le Temps. L'heure de son horloge change l'effet de ses compétences.",
	"basic": "L'attaque de base rend 1 PA ; les compétences de Credo Sum en consomment.",
	"qte_attack": "QTE d'attaque : appuyer sur [Espace] quand l'anneau recouvre le cercle.",
	"defend": "En défense : [E] pour parer (fenêtre courte), [Espace] pour esquiver (plus large).",
	"counter": "Toutes les frappes parées : contre-attaque !",
	"aoe": "Attaque de zone : une seule parade protège toute l'équipe.",
	"outro": "Conscientia : Apostoli — proof of concept réalisé sous Godot 4.7",
}

var _queues := {}
var _defense_index := 0
var _shown := {}


func _init() -> void:
	for id in SHOWCASE:
		_queues[id] = (SHOWCASE[id] as Array).duplicate()


## Texte du sous-titre la première fois que `key` se produit, "" ensuite.
func caption_once(key: String) -> String:
	if _shown.has(key):
		return ""
	_shown[key] = true
	return CAPTIONS[key]


func next_defense() -> String:
	var d: String = DEFENSE[_defense_index % DEFENSE.size()]
	_defense_index += 1
	return d


func choose(a: Combatant, allies: Array, enemies: Array) -> Dictionary:
	var queue: Array = _queues[a.id]
	for sid in queue:
		if SkillDB.can_use(sid, a, allies, enemies) and _worth(sid, a, allies):
			queue.erase(sid)
			return {"skill": sid, "target": _target(sid, a, allies, enemies)}
	if queue.is_empty():
		for sid in FINISHERS[a.id]:
			if SkillDB.can_use(sid, a, allies, enemies) and _worth(sid, a, allies):
				return {"skill": sid, "target": _target(sid, a, allies, enemies)}
	var basic := SkillDB.basic_attack(a.id)
	return {"skill": basic, "target": _target(basic, a, allies, enemies)}


func _worth(sid: String, a: Combatant, allies: Array) -> bool:
	var weakest := _weakest(allies)
	match sid:
		"lucie_hyperplasie", "lucie_greffe":
			return weakest.hp_ratio() < 0.85
		"lucie_exces":
			return weakest.hp_ratio() < 0.7
		"lucie_retour":
			return absf(a.gauge) >= 15.0
		"ceran_effondrement":
			return a.gauge >= 40.0
	return true


func _target(sid: String, a: Combatant, allies: Array, enemies: Array) -> Combatant:
	var targets := SkillDB.valid_targets(sid, a, allies, enemies)
	if targets.is_empty():
		return a
	match sid:
		"ceran_ancrage", "ceran_effondrement", "nicolas_futur":
			for t in targets:
				if (t as Combatant).id == "veilleur":
					return t
		"lucie_hyperplasie", "lucie_greffe":
			return _weakest(targets)
		"nicolas_hate", "nicolas_retour":
			for t in targets:
				if (t as Combatant).id == "ceran":
					return t
	if SkillDB.SKILLS[sid]["target"] == "enemy":
		# On achève d'abord les plus entamés : les KO arrivent plus vite à l'écran.
		targets.sort_custom(func(x: Combatant, y: Combatant) -> bool: return x.hp < y.hp)
	return targets[0]


func _weakest(list: Array) -> Combatant:
	var best: Combatant = null
	for c in list:
		var u := c as Combatant
		if not u.dead and (best == null or u.hp_ratio() < best.hp_ratio()):
			best = u
	return best
