class_name SkillDB
extends RefCounted
## Compétences des personnages jouables.
## target : enemy | ally | other_ally | ally_ko | self | all_allies | all_enemies
## qte    : true si la compétence déclenche un QTE de timing à l'attaque
## clock  : décalage d'horloge de Nicolas (heure paire = avance, impaire = recule)

const SKILLS := {
	# --- Céran : l'Espace -------------------------------------------------
	"ceran_frappe": {
		"name": "Frappe", "cost": 0, "target": "enemy", "qte": false,
		"desc": "Coup d'épée.\n+1 PA, +10 Distorsion.",
	},
	"ceran_faille": {
		"name": "Faille", "cost": 2, "target": "enemy", "qte": true,
		"desc": "Déchire l'espace sous la cible (160 %). +20 Distorsion.\nQTE réussi : consomme 30 Distorsion pour doubler les dégâts.",
	},
	"ceran_ancrage": {
		"name": "Ancrage spatial", "cost": 1, "target": "enemy", "qte": true,
		"desc": "Fige la cible dans l'espace : Ancrée (+30 % dégâts subis, 2 tours). +15 Distorsion.\nQTE réussi : consomme 20 Distorsion, l'ancrage dure 3 tours et repousse la cible dans l'ordre des tours.",
	},
	"ceran_effondrement": {
		"name": "Effondrement", "cost": 4, "target": "enemy", "qte": true, "ultimate": true,
		"desc": "Replie l'espace sur la cible (250 %).\nQTE réussi : consomme toute la Distorsion, +1 % de dégâts par point consommé.",
	},
	# --- Lucie : la Chair -------------------------------------------------
	"lucie_frappe": {
		"name": "Frappe", "cost": 0, "target": "enemy", "qte": false,
		"desc": "Coup de scalpel.\n+1 PA. Empathie vers Frappe (−10).",
	},
	"lucie_suture": {
		"name": "Suture offensive", "cost": 2, "target": "enemy", "qte": true,
		"desc": "Referme brutalement les plaies internes de la cible (140 %, ×1,5 si elle est sous 50 % PV).\nEmpathie −20.",
	},
	"lucie_hyperplasie": {
		"name": "Hyperplasie contrôlée", "cost": 2, "target": "ally", "qte": true,
		"desc": "Stimule la croissance cellulaire : soigne 9 % des PV max à chaque tour de la cible, pendant 3 tours.\nEmpathie +15.",
	},
	"lucie_greffe": {
		"name": "Greffe d'urgence", "cost": 1, "target": "ally", "qte": false,
		"desc": "Prélève 25 % des PV actuels de l'allié le plus en forme pour les transférer à la cible.\nEmpathie +10.",
	},
	"lucie_appel": {
		"name": "Appel des morts", "cost": 3, "target": "ally_ko", "qte": false,
		"desc": "Ramène un allié tombé avec 35 % de ses PV (modifié par l'Empathie).\nEmpathie +20.",
	},
	"lucie_retour": {
		"name": "Retour au départ", "cost": 1, "target": "self", "qte": false,
		"desc": "Lucie recentre son curseur d'Empathie.",
	},
	"lucie_exces": {
		"name": "Excès de vie", "cost": 5, "target": "all_allies", "qte": true, "ultimate": true,
		"desc": "Surcharge ses capacités : soigne 60 % des PV max de toute l'équipe et donne un bouclier de 25 % des PV max.\nEmpathie +30.",
	},
	# --- Nicolas : le Temps -----------------------------------------------
	"nicolas_frappe": {
		"name": "Frappe", "cost": 0, "target": "enemy", "qte": false, "clock": 0,
		"desc": "Coup de canne.\n+1 PA.",
	},
	"nicolas_onde": {
		"name": "Onde temporelle", "cost": 2, "target": "enemy", "qte": true, "clock": 2,
		"desc": "Dégâts (130 %).\nSur 3, 6 ou 9 heures : touche tous les ennemis.",
	},
	"nicolas_ralenti": {
		"name": "Ralentissement", "cost": 2, "target": "enemy", "qte": false, "clock": 1,
		"desc": "Ralentit la cible (−40 % vitesse, 2 tours) et la repousse dans l'ordre des tours.\nSur 3, 6 ou 9 heures : tous les ennemis.",
	},
	"nicolas_hate": {
		"name": "Hâte", "cost": 2, "target": "ally", "qte": false, "clock": 1,
		"desc": "Accélère un allié (+50 % vitesse, 2 tours) et le rapproche de son tour.",
	},
	"nicolas_futur": {
		"name": "Dégâts futurs", "cost": 2, "target": "enemy", "qte": true, "clock": 3,
		"desc": "Programme 180 % de dégâts qui frappent au bout de 3 tours de la cible.\nRelancé avant l'impact : dégâts doublés.",
	},
	"nicolas_retour": {
		"name": "Retour vers le futur", "cost": 3, "target": "other_ally", "qte": false, "clock": 2,
		"desc": "Donne immédiatement le tour à un autre allié.\nSur 6 heures : retire aussi ses altérations.",
	},
	"nicolas_arret": {
		"name": "Arrêt du temps", "cost": 3, "tokens": 1, "target": "all_enemies", "qte": false, "clock": 0, "ultimate": true,
		"desc": "Coûte 1 jeton. Fige le temps : tous les ennemis perdent leur prochain tour et l'aiguille se fige pendant 2 tours.",
	},
}

const KITS := {
	"ceran": ["ceran_faille", "ceran_ancrage", "ceran_effondrement"],
	"lucie": ["lucie_suture", "lucie_hyperplasie", "lucie_greffe", "lucie_appel", "lucie_retour", "lucie_exces"],
	"nicolas": ["nicolas_onde", "nicolas_ralenti", "nicolas_hate", "nicolas_futur", "nicolas_retour", "nicolas_arret"],
}


static func get_skill(id: String) -> Dictionary:
	return SKILLS[id]


static func basic_attack(char_id: String) -> String:
	return char_id + "_frappe"


## Cibles possibles d'une compétence (tableau vide = pas de choix de cible).
static func valid_targets(skill_id: String, actor: Combatant, allies: Array, enemies: Array) -> Array:
	var out: Array = []
	match SKILLS[skill_id]["target"]:
		"enemy":
			out = enemies.filter(func(c: Combatant) -> bool: return not c.dead)
		"ally":
			out = allies.filter(func(c: Combatant) -> bool: return not c.dead)
		"other_ally":
			out = allies.filter(func(c: Combatant) -> bool: return not c.dead and c != actor)
		"ally_ko":
			out = allies.filter(func(c: Combatant) -> bool: return c.dead)
	return out


static func needs_target(skill_id: String) -> bool:
	return SKILLS[skill_id]["target"] in ["enemy", "ally", "other_ally", "ally_ko"]


static func can_use(skill_id: String, actor: Combatant, allies: Array, enemies: Array) -> bool:
	var sk: Dictionary = SKILLS[skill_id]
	if actor.pa < int(sk["cost"]):
		return false
	if actor.tokens < int(sk.get("tokens", 0)):
		return false
	if needs_target(skill_id) and valid_targets(skill_id, actor, allies, enemies).is_empty():
		return false
	return true
