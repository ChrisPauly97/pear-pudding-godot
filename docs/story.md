# The Tale of Saimtar — Story Bible

This document captures the narrative source for the game's story mode. Each section maps directly
to in-game content: named map files, NPC dialogue strings, encounter triggers, and story progression
flags. All future chapters should follow the same structure.

---

## Contents

| Section | Description |
|---|---|
| [Characters](#characters) | Protagonist, companions, lords, royalty |
| [The Prophecy](#the-prophecy) | Background lore driving the plot |
| [Introduction](#introduction) | Saimtar in Madrian, meeting Maiteln |
| [Chapter 1: Into the Wild World](#chapter-1-into-the-wild-world) | Journey to Maykalene and Blancogov |
| [Story Progression System](#story-progression-system) | Flags, checkpoints, dialogue triggers |
| [Map Specifications](#map-specifications) | Named map layouts and entity placements |
| [Asset Requirements](#asset-requirements) | Files needed to drive the story |

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

**Location:** Madrian (small town, Saimtar's home)

Saimtar is doing housework when an old man beckons him from outside. Maiteln offers freedom and
adventure. Saimtar agrees immediately — life in servitude is dull. They slip away before the master
notices they are gone.

### NPC Dialogue — Introduction

**Maiteln (first meeting, x=45, z=36 in madrian.txt):**
> "I am a wizard of old. If you come with me you will never have to worry about your master again
> and I will take you on an adventure. My name is Maiteln. Will you come with me?"

**Master (inside master's house, x=11, z=14):**
> "Boy! Get back to your chores this instant or you will be punished!"

### Game Map: madrian
- **File:** `assets/maps/madrian.txt`
- **Player Spawn:** x=40, z=36
- **Buildings:** master's house (x=5–17, z=8–18), stable (x=20–28, z=8–14), inn (x=35–47, z=22–32)
- **Exits:** south edge door (x=50, z=99 → `__exit__`, id=`madrian_exit`)

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

These trigger in the open infinite-world terrain between fixed named maps:

- **Rabbit hunting (Night 1):** First night camp after leaving Madrian. Saimtar hunts a rabbit —
  represented by a weak enemy encounter (undead_basic placeholder until a rabbit enemy type exists).
- **Morning fire tutorial (Day 2):** Second day camp. Maiteln teaches fire-making — a simple
  interaction dialogue with no combat.
- **Isfig on horseback (Road to Blancogov):** Scripted NPC encounter after leaving Maykalene.
  Isfig rides up with the letter from Scargroth. Triggers `chapter1_received_letter` flag.

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

---

## Story Progression System

Story progression uses flags stored in `SaveManager` under a `story_flags` dictionary
(to be added as a new saved field). Flags gate NPC dialogue so characters say different
things before and after key events.

### Planned Flags

| Flag Key | Type | Set When |
|---|---|---|
| `story_intro_complete` | bool | Player speaks to Maiteln in Madrian |
| `chapter1_left_madrian` | bool | Player exits Madrian map |
| `chapter1_warned_farsyth` | bool | Player speaks to Lord Farsyth in farsyth_mansion |
| `chapter1_received_letter` | bool | Isfig open-world encounter triggered |
| `chapter1_reached_blancogov` | bool | Player enters blancogov map |
| `chapter1_temple_council` | bool | Player speaks to King Eldar in blancogov_temple |

### Starting Map for Story Mode

To play story mode from the beginning, `SceneManager` should load `madrian` instead of `main`.
A story-mode toggle or separate save slot is the recommended approach so the sandbox infinite
world is preserved.

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

---

## Asset Requirements

- **Map files:** all five `.txt` files listed above in `assets/maps/`
- **SaveManager:** add `story_flags: Dictionary = {}` field and persist it in save/load
- **GameBus:** add `story_flag_set(flag: String)` signal for reacting to story events
- **TownspersonNPC:** extend `get_dialogue()` to accept an optional flag check so NPCs say
  different lines after story events (e.g. Farsyth says something different after being warned)
- **SceneManager:** add `start_story_mode()` that loads `madrian` as first map instead of `main`
- **Future — branching dialogue:** when the dialogue system is extended, replace single-string NPC
  lines with a dialogue tree keyed on story flags
