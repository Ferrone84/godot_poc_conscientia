class_name Emotions
extends RefCounted
## Codes visuels des flux de Credo Sum, d'après la table du Lore (0.1.4) :
## chaque émotion a une couleur et une forme de structure fractale.

const DATA := {
	"colere": {"name": "Colère", "color": Color(1.0, 0.36, 0.08), "core": Color(1.0, 0.85, 0.55), "style": "eclair"},
	"haine": {"name": "Haine", "color": Color(0.85, 0.04, 0.04), "core": Color(0.25, 0.0, 0.0), "style": "flamme"},
	"peur": {"name": "Peur et Dégoût", "color": Color(0.55, 0.9, 0.2), "core": Color(0.9, 0.85, 0.25), "style": "vapeur"},
	"amour": {"name": "Amour", "color": Color(1.0, 0.62, 0.75), "core": Color(1.0, 0.9, 0.95), "style": "fumee"},
	"crainte": {"name": "Crainte et Adoration", "color": Color(0.58, 0.3, 1.0), "core": Color(0.88, 0.75, 1.0), "style": "plasma"},
	"joie": {"name": "Joie", "color": Color(1.0, 0.75, 0.2), "core": Color(1.0, 0.96, 0.7), "style": "etincelle"},
	"tristesse": {"name": "Tristesse", "color": Color(0.25, 0.5, 1.0), "core": Color(0.75, 0.88, 1.0), "style": "liquide"},
}


static func color(emotion: String) -> Color:
	return DATA[emotion]["color"]


static func core(emotion: String) -> Color:
	return DATA[emotion]["core"]


static func style(emotion: String) -> String:
	return DATA[emotion]["style"]
