extends Node

const SCROLL_COUNT: int = 11

const _SCROLLS: Array = [
	{
		"id": "scroll_larik_origins",
		"title": "The Village of Larik",
		"lore_text": "Larik was a village of aspirations rather than achievements. It sat at the edge of the open grasslands, far from any road worth naming. The people there knew each other too well and nothing went unnoticed — least of all the morning Saimtar's parents vanished without a trace.",
		"audio_path": "res://assets/audio/narration/scroll_larik_origins.ogg",
	},
	{
		"id": "scroll_martarquas_first_war",
		"title": "The First War of Martarquas",
		"lore_text": "The Martarquas were once the most feared tribe in all the known lands. They burned villages without warning and took no prisoners. It was only when the other tribes united — for the first and only time in memory — that the Martarquas were finally broken. But broken is not destroyed.",
		"audio_path": "res://assets/audio/narration/scroll_martarquas_first_war.ogg",
	},
	{
		"id": "scroll_maiteln_order",
		"title": "The Order of Wizards",
		"lore_text": "Wizards of the old order kept no towers and sought no students. They moved through the world quietly, doing what needed doing and expecting no thanks for it. Maiteln was one of the last. He had watched kings rise and fall and kept his own counsel on most of it.",
		"audio_path": "res://assets/audio/narration/scroll_maiteln_order.ogg",
	},
	{
		"id": "scroll_prophecy_text",
		"title": "The Prophecy of Renewal",
		"lore_text": "The prophecy was not written in a grand tome but scratched into a flat river stone found in a shepherd's field. It read simply: when the scattered embers find each other, the flame will rise again. The temple scholars spent thirty years arguing about what it meant. Maiteln said he had known since the moment he read it.",
		"audio_path": "res://assets/audio/narration/scroll_prophecy_text.ogg",
	},
	{
		"id": "scroll_farsyth_lineage",
		"title": "Lords of the Western Reaches",
		"lore_text": "The Farsyth family had governed Maykalene for six generations. Each lord had added something — a road, a market, a wall. The current lord had added nothing yet, but he had only been in the seat three years, and some said caution was its own kind of wisdom.",
		"audio_path": "res://assets/audio/narration/scroll_farsyth_lineage.ogg",
	},
	{
		"id": "scroll_blancogov_founding",
		"title": "The Founding of Blancogov",
		"lore_text": "Blancogov did not grow so much as it was placed. The first king chose the site for its rivers and its sight lines, then set stonemasons to work for a decade. When it was finished it was the finest city in the land and has remained so, though no one can quite agree on what fine means.",
		"audio_path": "res://assets/audio/narration/scroll_blancogov_founding.ogg",
	},
	{
		"id": "scroll_king_eldar_coronation",
		"title": "The Coronation of King Eldar",
		"lore_text": "Eldar was crowned at twenty-two, younger than any king before him. His first act was to send letters to every lord in the realm. Not orders — letters. He wrote that he wished to know their lands, their troubles, and their names. Most lords had never received a letter from a king that was not a demand. Some wept.",
		"audio_path": "res://assets/audio/narration/scroll_king_eldar_coronation.ogg",
	},
	{
		"id": "scroll_martarquas_survivors",
		"title": "The Surviving Tribes",
		"lore_text": "After the war, the surviving Martarquas scattered into the deep wilderness. Generations passed. The alliance relaxed. It is the nature of alliances to relax when the threat they were built against has not been seen for a long time. This is not wisdom. It is forgetting dressed up as peace.",
		"audio_path": "res://assets/audio/narration/scroll_martarquas_survivors.ogg",
	},
	{
		"id": "scroll_isfig_shadow",
		"title": "Isfig's Shadow",
		"lore_text": "Maiteln's shadow stood against you three times, and three times you prevailed. When the final blow was struck, Isfig smiled — not in defeat, but in recognition. He had seen something in you that even Maiteln had missed. Without a word, he walked east. No one saw him again. But some say the shadow he left behind fights on — in you.",
		"audio_path": "res://assets/audio/narration/scroll_isfig_shadow.ogg",
	},
	{
		"id": "scroll_larik_letter",
		"title": "The Larik Letter",
		"lore_text": "If you read this, we could not stay. They came in the night with the tribe's mark — and a councilman's seal. Do not follow us, Saimtar. Grow strong, and forgive us. — Father",
		"audio_path": "res://assets/audio/narration/scroll_larik_letter.ogg",
	},
	{
		"id": "scroll_traitor_seal",
		"title": "The Traitor's Seal",
		"lore_text": "Orders of muster, sealed in wax. The sigil is not Martarquas — it is a chair on the king's own council.",
		"audio_path": "res://assets/audio/narration/scroll_traitor_seal.ogg",
	},
]

func get_scroll(id: String) -> Dictionary:
	for scroll: Dictionary in _SCROLLS:
		if scroll["id"] == id:
			return scroll
	return {}

func get_all_scrolls() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_SCROLLS)
	return result
