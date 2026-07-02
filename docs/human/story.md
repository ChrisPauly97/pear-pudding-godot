# The Tale of Saimtar — Story Bible

> **This file is human-owned.** Claude reads this to implement maps, dialogue, and story flags — but will never edit it.
>
> **Provenance note:** The Chapter 1 Victory Condition, Flag-Gated Dialogue States table,
> Scripted Tutorial Battles notes, and the Chapter 2 section were drafted by the agent as the
> GID-108 story pack and **approved by the human on 2026-07-02**, who explicitly authorized
> writing them into this file ("document the story even if its in the human subdir, i approve").

---

## Contents

| Section | Description |
|---|---|
| [Characters](#characters) | Protagonist, companions, lords, royalty |
| [The Prophecy](#the-prophecy) | Background lore driving the plot |
| [Introduction](#introduction) | Saimtar in Madrian, meeting Maiteln |
| [Chapter 1: Into the Wild World](#chapter-1-into-the-wild-world) | Journey to Maykalene and Blancogov |
| [Chapter 2: The Road to Larik](#chapter-2-the-road-to-larik) | Council's charge, Larik, the siege of Marsax hold, the traitor |
| [NPC Dialogue by Map](#npc-dialogue-by-map) | All NPC lines, positions, and flag conditions |
| [Map Specifications](#map-specifications) | Named map layouts and entity placements |

---

## Characters

### Saimtar (Player)
- **Age:** 11, orphan, working as a household servant in Madrian
- **Appearance:** short black hair, small eyes, moderately tall with long legs and long gangly arms
- **Motivation:** escape from boring servitude, seek adventure
- **Skills learned in Chapter 1:** hunting (rabbit), fire-starting with flint and tinder

### Maiteln (Companion / Guide)
- Old wizard of unspecified age
- **Abilities:** conjures horses, smooths bumpy roads (magic), tidies rooms (magic), cooks with magic
- Has a brother named Isfig
- **Personality:** gruff, direct, impatient; uses a tone of voice where you know not to argue with him
- Calls Saimtar "wee" and uses Scottish-ish turns of phrase ("get us a wee rabbit for tea will ye")

### Isfig
- Maiteln's brother
- About 6 foot, stocky build, not overly smart
- Delivers an urgent message from Scargroth between Maykalene and Blancogov

### Lord Farsyth
- Lord of Maykalene, occupies the mansion at the end of the cobbled stone street
- Friendly relationship with Maiteln — guard admits them without fuss on news of prophecy
- Connected to lords Marsax, Ramtorous, and Temlar (to be warned)

### Scargroth
- Member of the temple's council in Blancogov
- Wears a simple white linen shirt with jet black trousers
- Sends the urgent summons letter carried by Isfig

### King Eldar
- King at Blancogov, occupies one of two thrones in the great temple
- The other throne (for his wife) is empty when Maiteln and Saimtar first enter

### Lord Marsax
- Lord of Marsax hold, west of Blancogov beyond Larik
- One of the three lords Farsyth sends word to (with Ramtorous and Temlar)
- Blunt soldier-lord; his hold is the first to feel the Martarquas raids in Chapter 2
- Grateful ally once the siege is broken — pledges his banners to the alliance

### The Traitor (identity unrevealed)
- A member of King Eldar's own council whose seal is found on Martarquas muster orders
- The same hand struck the names from the old Larik register — connected to the
  disappearance of Saimtar's parents
- Identity is the driving mystery left open at the Chapter 2 cliffhanger

### Queen (name not yet given)
- **Appearance:** shining blue eyes, pointy ears, lovely soft face
- Wears a beautiful silk gown embroidered with gems and patterns
- Azure necklace, glimpse of a solid gold bracelet
- Voice described as "the gurgling of a stream, soft and smooth"
- Arrives after Maiteln and Saimtar and sweeps her cloak away before sitting

---

## The Prophecy

The Martarquas tribe was once the deadliest tribe in the land. The other tribes banded together to
form an alliance against them and eventually crushed them — but they were never fully destroyed.
If the Martarquas reformed and launched another attack while the alliance was unprepared, the
consequences would be catastrophic. The prophecy foretells their rising again, which is why Maiteln
must warn every lord and the king before it is too late.

---

## Introduction

**Location:** Larik (Saimtar's home village), then Madrian

Saimtar had just turned 11 years old, not an occasion he wished to celebrate anymore. He is moderately tall with long legs and gangly arms that seemingly grew further out of proportion with his body each passing day.

He grew up in Larik, his entire life spent in what could only be classed as a collection of houses with aspirations of township. The kind of place where everyone knows everyone a little too well and nothing goes unnoticed. It certainly had not been missed when Saimtar's parents disappeared without a trace, on the morning of his 10th birthday.

It was a morning in Larik like any other, the sun threatening to shine from behind brooding clouds; the quiet storm before the calm. It rarely rained in Larik and this day was no different. For Saimtar, this day started as most days usually do, early to head to the stables to muck and feed the horses before occupying himself with whatever young boys do in a place like Larik, mostly nothing.

He returned from the stables to the house, pushed open the unlocked front door and called out "Mum! What's for lunch?". No answer. "Mum?" rang out. No answer. "Dad?" No answer. This was unusual, his mother never left the house, and she always answered him. His dad? Well, he would answer too if he's not at work. He wandered through the house, peering behind doors, under the beds, inside cupboards. Nothing.

---

## Chapter 1: Into the Wild World

**Goal:** Travel from Madrian to Blancogov, warning Lord Farsyth in Maykalene along the way,
then race to reach King Eldar's temple within three days.

### Story Beats

| # | Beat | Location | Notes |
|---|---|---|---|
| 1 | **Escape from Madrian** | madrian | Maiteln conjures two horses; leave before master notices |
| 2 | **Night in the wilderness** | open world | First camp; Saimtar hunts rabbit; rain prevents fire; eat raw |
| 3 | **Learning to make fire** | open world | Next morning; Maiteln teaches flint-and-tinder |
| 4 | **Arrive in Maykalene** | maykalene | White-washed town; inn stay; broth and cocoa; room tidied by magic |
| 5 | **Visit Lord Farsyth** | farsyth_mansion | Guard greets Maiteln; deliver prophecy news; Farsyth alarmed |
| 6 | **Isfig delivers letter** | open world (road) | Scripted encounter; Scargroth summons all to temple in 3 days |
| 7 | **Hard ride to Blancogov** | open world | Travel all day, overnight camp, arrive at dawn |
| 8 | **Gates of Blancogov** | blancogov | Guards suspicious; letter proves right of entry |
| 9 | **Enter the temple** | blancogov_temple | Jewelled gates; King Eldar; Queen arrives; council assembles |

### Wilderness Encounters (Between Named Maps)

- **Rabbit hunting (Night 1) — the tutorial battle:** First night camp after leaving Madrian.
  Saimtar hunts a rabbit, played as the game's first battle using the scripted battle framework
  (see below). Enemy: **Wild Rabbit** — 8 hero HP, a 2-card token deck that plays one weak minion
  per turn; impossible to lose without trying. Victory sets `chapter1_camp_night`.
- **Morning fire tutorial (Day 2):** Second day camp. Maiteln teaches fire-making — a simple
  interaction dialogue with no combat. Sets `chapter1_learned_fire`.
- **Isfig on horseback (Road to Blancogov):** Scripted NPC encounter after leaving Maykalene.
  Isfig rides up with the letter from Scargroth. Triggers `chapter1_received_letter` flag.

### Scripted Tutorial Battles

Story battles that teach mechanics use a fixed deck and a **deterministic, 1-by-1 draw order**
so every player gets the same introduction:

- **Rabbit hunt (Chapter 1, beat 2):** fixed 6-card deck — 2× ghost, 2× skeleton, 1× zombie,
  1× ghoul. Opening hand is 1 card (a ghost). Each turn draws the next card in scripted order:
  ghost → skeleton → ghost → zombie → skeleton → ghoul — cheapest first, matching the growing
  mana curve. Maiteln narrates each step via tutorial popups: turn 1 "That wee ghost costs
  1 mana — drag it to a slot"; turn 2 "Minions cannae strike the turn they're summoned —
  patience"; turn 3 "Now attack! Drag your ghost onto the beast."
- **Scouts ambush (Chapter 2, beat 3):** the same framework introduces spell cards the same way.

### Chapter 1 Victory Condition

*(Approved via GID-108, 2026-07-02 — fills the former TID-066 / TID-067 TODO.)*

- **Trigger:** Speaking to King Eldar in blancogov_temple **after** `chapter1_temple_council`
  is set **and** the Queen and Scargroth have each been spoken to (sub-flags
  `chapter1_spoke_queen`, `chapter1_spoke_scargroth`).
- **Story flag set:** `chapter1_complete`
- **Ending presentation:** Narration overlay (reuses the scroll narration UI), three short pages:
  1. The council resolves — the old alliance is re-sworn, riders will carry the warning to every lord.
  2. Maiteln, quietly proud, tells Saimtar he has earned his place at his side.
  3. Scargroth pulls Saimtar aside: *"There is a name from Larik in the old registers you should see."*
- **After the ending:** Return to the world (not the menu) as a playable epilogue — towns shift
  to war-preparation dialogue via the `chapter1_complete` flag-gated lines. All sandbox systems
  remain available; Chapter 2 begins from this epilogue state.

---

## Chapter 2: The Road to Larik

*(Approved via GID-108, 2026-07-02.)*

**Goal:** Carry the council's warning west to Lord Marsax — a road that passes through Larik,
Saimtar's home village — and uncover why the Martarquas always seem one step ahead.

The parents' mystery is the connective spine of the chapter: hinted in the Chapter 1 epilogue
(Scargroth's register), opened in Larik, entangled with the traitor at Marsax hold, and left
unresolved at the cliffhanger — fuel for Chapter 3.

### Story Beats

| # | Beat | Location | Notes |
|---|---|---|---|
| 1 | **The council's charge** | blancogov_temple | King Eldar sends riders in pairs to the three lords; Maiteln and Saimtar draw the western road — which passes Larik. Sets `chapter2_charged` |
| 2 | **Return to Larik** | larik | Saimtar's village, cold and frightened; his old house stands empty. A hidden letter reveals his parents didn't flee — they were **taken**. Sets `chapter2_reached_larik`, then `chapter2_found_letter` |
| 3 | **Scouts in the grass** | open world (west road) | First Martarquas contact — a scripted ambush battle that introduces spell cards 1-by-1 (scripted battle framework). New enemy: Martarquas scout. Sets `chapter2_ambush_survived` |
| 4 | **Marsax hold besieged** | marsax_hold | The hold is already under attack on arrival — the town-siege system plays as a story beat. Victory sets `chapter2_siege_won` |
| 5 | **The traitor's seal** | marsax_hold | Among the raiders' effects: muster orders sealed by someone on the king's own council — the same hand that struck the Larik register. Scroll sets `chapter2_traitor_seal` |
| 6 | **The war-camp** | dungeon (hills west of the hold) | Infiltrate a Martarquas war-camp (procedural dungeon reskin) to steal the muster plans; boss battle vs the warband leader. Sets `chapter2_warcamp_cleared` |
| 7 | **Cliffhanger** | narration overlay | The plans reveal the tribe marches not on Blancogov but on the lords one by one — and the traitor knows the alliance's every move. Sets `chapter2_complete` |

### Chapter 2 Flags (progression order)

`chapter2_charged` → `chapter2_reached_larik` → `chapter2_found_letter` →
`chapter2_ambush_survived` → `chapter2_siege_won` → `chapter2_traitor_seal` →
`chapter2_warcamp_cleared` → `chapter2_complete`

### Chapter 2 Scrolls

| Scroll ID | Placement | Text |
|---|---|---|
| `scroll_larik_letter` | larik — hidden in Saimtar's empty house | *"If you read this, we could not stay. They came in the night with the tribe's mark — and a councilman's seal. Do not follow us, Saimtar. Grow strong, and forgive us. — Father"* |
| `scroll_traitor_seal` | marsax_hold — among the raiders' effects after the siege | *"Orders of muster, sealed in wax. The sigil is not Martarquas — it is a chair on the king's own council."* |

### Chapter 2 Cliffhanger Narration (three pages)

1. By firelight, Maiteln reads the stolen muster plans: the tribe will not strike Blancogov.
   They march on the lords, one by one, before the alliance can gather.
2. Maiteln, grim: every route, every garrison, every weakness — written in a steady court hand.
   The traitor knows the alliance's every move.
3. And beneath the last page, in a script Saimtar knew like his own name — a list of the taken.
   His parents' names were not struck through.

### New Enemy Types (Chapter 2)

| ID | Display Name | Role | Notes |
|---|---|---|---|
| `martarquas_scout` | Martarquas Scout | Beat 3 scripted ambush | Introduces spell cards; modest deck, aggressive |
| `martarquas_warleader` | Martarquas War-Leader | Beat 6 dungeon boss | Boss-tier deck using the GID-021 boss framework |

---

## NPC Dialogue by Map

### madrian

| NPC | Position | Dialogue |
|---|---|---|
| Maiteln | x=45, z=36 | I am a wizard of old. If you come with me you will never have to worry about your master again and I will take you on an adventure. My name is Maiteln. Will you come with me? |
| Master | x=11, z=14 | Boy! Get back to your chores this instant or you will be punished! |

### maykalene

| NPC | Position | Dialogue |
|---|---|---|
| Townsperson | x=50, z=65 | Welcome to Maykalene! Fine white-washed houses and a warm inn await you. |
| Innkeeper | x=62, z=51 | Best broth and cocoa in all the land! A warm meal and soft bed within! |
| Mansion guard | x=50, z=94 | Ah, Maiteln! Lord Farsyth is not busy at the moment. Go straight in if you have news of the prophecy. |

### farsyth_mansion

| NPC | Position | Dialogue |
|---|---|---|
| Reception guard | x=49, z=78 | Welcome, Maiteln. The lord will receive you directly — he awaits word of the prophecy. |
| Lord Farsyth | x=49, z=20 | The Martarquas tribe rising again? By the gods, this is dire news. I shall send word to Lords Marsax, Ramtorous and Temlar at once. You must warn King Eldar in Blancogov! |

### blancogov

| NPC | Position | Dialogue |
|---|---|---|
| Gate guard | x=49, z=9 | Halt! State your business at the gates of Blancogov. No entry without authorisation! |
| City dweller | x=49, z=72 | The great temple of King Eldar lies at the road's end. The council has been summoned — something stirs. |

### blancogov_temple

| NPC | Position | Dialogue |
|---|---|---|
| King Eldar | x=42, z=15 | Maiteln! We are glad you came so swiftly. The council is assembling. The Martarquas threat must be answered together. |
| Queen | x=58, z=15 | Welcome, Maiteln, and your young companion. You are most welcome here. Please take a seat in one of the red satin oak chairs. |
| Scargroth | x=50, z=30 | The letter was urgent for good reason. The prophecy cannot be ignored. All lords must be present before we act. |

### larik *(Chapter 2 — GID-108)*

| NPC | Position | Dialogue |
|---|---|---|
| Villager | (set in TID-406) | Saimtar? You shouldn't have come back. Nothing good lingers here since the night the fires went out. |
| Old neighbour | (set in TID-406) | Your mother and father — we heard nothing, saw nothing. Doors were barred that night, and we kept them barred. |

### marsax_hold *(Chapter 2 — GID-108)*

| NPC | Position | Dialogue |
|---|---|---|
| Garrison sergeant | (set in TID-406) | To arms! The hold stands while its walls do — who in blazes are you two? |
| Lord Marsax | (set in TID-406) | Maiteln! Blancogov's warning came late — the tribe is already at my gates. Help us hold, and my banners ride with the alliance. |

### Flag-Gated Dialogue States

*(Table authored via GID-108, 2026-07-02 — fills the former TID-063 TODO. Format: text shown
BEFORE flag is set | text shown AFTER flag is set. Before-Flag text is the static line above
unless it differs here.)*

| NPC | Map | Flag Key | Before-Flag Text | After-Flag Text |
|---|---|---|---|---|
| Master | madrian | story_intro_complete | Boy! Get back to your chores this instant or you will be punished! | Running off with that old trickster? Good riddance — but your bed will be gone when you crawl back. |
| Maiteln | madrian | story_intro_complete | I am a wizard of old. If you come with me you will never have to worry about your master again and I will take you on an adventure. My name is Maiteln. Will you come with me? | The road waits, wee Saimtar. South, past the wilds — Maykalene first. |
| Townsperson | maykalene | chapter1_warned_farsyth | Welcome to Maykalene! Fine white-washed houses and a warm inn await you. | Word from the mansion is grim — riders left for Marsax and Temlar at first light. |
| Innkeeper | maykalene | chapter1_warned_farsyth | Best broth and cocoa in all the land! A warm meal and soft bed within! | You're the lad who came with Maiteln? Broth's on the house — dark times make short bills. |
| Mansion guard | maykalene | chapter1_warned_farsyth | Ah, Maiteln! Lord Farsyth is not busy at the moment. Go straight in if you have news of the prophecy. | The lord is with his war-scribes. He said you're to pass unannounced, always. |
| Lord Farsyth | farsyth_mansion | chapter1_warned_farsyth | The Martarquas tribe rising again? By the gods, this is dire news. I shall send word to Lords Marsax, Ramtorous and Temlar at once. You must warn King Eldar in Blancogov! | Ride hard for Blancogov. Every hour you save may save a village. |
| Gate guard | blancogov | chapter1_received_letter | Halt! State your business. No entry without authorisation! | Welcome back. The council awaits within — proceed. |
| City dweller | blancogov | chapter1_temple_council | The great temple of King Eldar lies at the road's end. The council has been summoned — something stirs. | The bells rang thrice — the alliance is called. First time in my lifetime. |
| King Eldar | blancogov_temple | chapter1_complete | Maiteln! We are glad you came so swiftly. The council is assembling. The Martarquas threat must be answered together. | The realm owes its warning to a servant boy from Larik. Remember that, all of you. |
| Queen | blancogov_temple | chapter1_complete | Welcome, Maiteln, and your young companion. You are most welcome here. Please take a seat in one of the red satin oak chairs. | Rest here whenever the road wears you thin, young Saimtar. |
| Scargroth | blancogov_temple | chapter1_complete | The letter was urgent for good reason. The prophecy cannot be ignored. All lords must be present before we act. | I've been reading the old registers. There is a name from Larik you should see. |

---

## Map Specifications

### Tile Key

| Char | Tile | Meaning |
|---|---|---|
| `0` | TILE_GRASS | Walkable floor / open ground |
| `1` | TILE_WALL | Impassable wall (building or boundary) |
| `2` | TILE_HILL | Raised terrain |

### Entity Syntax

```
SPAWN x z                     — player start position
NPC x z dialogue text here    — townsperson NPC (rest of line is dialogue)
ENEMY x z [type]              — enemy (optional type, default: undead_basic)
CHEST x z card1,card2,...     — loot chest with card rewards
DOOR x z target_map [door_id] — door linking to another map (__exit__ returns to parent)
```

### Named Map Index

| File | Chapter | Key Buildings / Areas |
|---|---|---|
| `assets/maps/madrian.txt` | Intro | Master's house, stable, inn |
| `assets/maps/maykalene.txt` | Chapter 1 | 8 town houses, inn, Farsyth mansion |
| `assets/maps/farsyth_mansion.txt` | Chapter 1 | Long hall, Lord Farsyth's audience chamber |
| `assets/maps/blancogov.txt` | Chapter 1 | Golden gate, three tower pairs, temple entrance |
| `assets/maps/blancogov_temple.txt` | Chapter 1 | Throne hall, council seating |
| `assets/maps/larik.tres` | Chapter 2 | Saimtar's empty house (hidden letter scroll), stables, ~6 village houses — "a collection of houses with aspirations of township" |
| `assets/maps/marsax_hold.tres` | Chapter 2 | Gatehouse, keep, courtyard; siege plays on arrival; war-camp dungeon lies in the hills west of the hold |

---

## New Enemy Types

> **TODO for TID-068:** Define 6 new enemy types (aiming for 2 per biome).
> For each, provide the fields below. The agent will create .tres files from this table.
> Deck and drop_pool values use card IDs (e.g. ghost, skeleton, spark, ash).

| ID | Display Name | Biome | Coin Reward | Deck (card IDs, quantities) | Drop Pool |
|---|---|---|---|---|---|
| wraith | Wraith | grasslands | 8 | (fill in) | (fill in) |
| forest_shade | Forest Shade | forest | 10 | (fill in) | (fill in) |
| sand_stalker | Sand Stalker | desert | 9 | (fill in) | (fill in) |
| scorched_revenant | Scorched Revenant | scorched | 12 | (fill in) | (fill in) |
| mountain_troll | Mountain Troll | mountains | 15 | (fill in) | (fill in) |
| stone_golem | Stone Golem | mountains | 18 | (fill in — boss tier) | (fill in) |

### Boss Enemy Types

> **TODO for TID-071:** Define the 2 boss encounters.
> A boss is an enemy placed in a specific named map location that uses the boss framework from TID-070.

| ID | Display Name | Map Placement | Special Mechanic | Deck | Drop Pool |
|---|---|---|---|---|---|
| (mid_boss) | (name) | blancogov_temple or farsyth_mansion | (e.g. phase 2 deck swap at 50% HP) | (fill in) | (fill in) |
| (chapter1_boss) | (name) | blancogov_temple | (e.g. hero gains armor each turn) | (fill in) | (fill in) |
