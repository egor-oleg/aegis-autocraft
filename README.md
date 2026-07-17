# A.E.G.I.S. autocraft for CC:Tweaked

Monitor-driven autocrafting for Minecraft — ComputerCraft / CC:Tweaked. Craft something once — the system records the recipe and automates it from then on.

Supports most modded machines. Stress-tested on endgame Modern Industrialization chains — fluid and hybrid recipes, probabilistic outputs, 170+ stage crafts.

---

## Highlights

- **Teach by example** — the system watches one craft and records the recipe.
- **Parallel crafting engine** — independent branches run simultaneously on different machine groups.
- **Machine pooling** — teach a recipe on one machine, run it on the whole bank (auto or hand-picked groups).
- **Fluid crafting** — fluid and fluid+item recipes, multiblock support.
- **KEEP (auto-stock)** — "always keep 200 plates" with threshold/target hysteresis.
- **Tool recipes** — supports crafts that use durability tools.
- **Storage management** — everything in connected storages on one screen, with search and filters.
- **Logistics** — rule-based transfers for both items and fluids.
- **GitHub sync** — export/import the recipe library.

---

## Requirements

| What | Notes |
|------|-------|
| Advanced Computer + Advanced Monitor wall | 6x3 monitor or larger |
| Wired modems everywhere | One wired network; every modem right-clicked ("peripheral attached") |
| Storage inventories | Vaults, chests, drawers |
| 1 barrel/chest as "train box" | Staging area for recipe learning |
| Advanced Crafty Turtles | For crafting-table recipes |

---

## Installation

**Drag & drop:** download ZIP → open the computer's terminal in-game → drag `computer/startup.lua` onto the Minecraft window → `reboot`. Same for turtles with `turtle/startup.lua`.

**Setup:** NETWORK tab → mark storages [VAULT], one barrel [T.BOX], turtles [TURTLE]. Done.

---

## Teaching recipes

| Type | How |
|------|-----|
| Turtle (grid) | +RECIPES → TURTLE: lay ingredients in the train box exactly as in a 3x3 crafting grid — they are placed into the turtle's central 3x3 slots, SCAN |
| Machine | +RECIPES → MACHINES: pick machine, ingredients into train box, SCAN |
| Fluid / hybrid | +RECIPES → FLUID: same + fluid amounts in mB |
| Alternatives | Extra recipes for the same item become alts with a priority order |

Result screen: `-> NEW` new recipe, `-> +ALT` added as alternative, red `DUB` — duplicate.

---

## Features

| Crafting | |
|---|---|
| Deep crafting | Order the final item — the whole ingredient tree is planned and crafted |
| Parallel execution | Independent branches run at once, each on its own machine group |
| Multi-machine batches | Work splits across all machines of a group (`pm3` = 3 machines) |
| Auto top-up | If a step comes up short, the missing part is re-crafted automatically |
| Craft queue | Build a list, reorder, run top-to-bottom |
| Durability tools | One hammer/file per recipe, reused until broken, then re-crafted |

| Machines | |
|---|---|
| Auto-grouping | Same-name machines pool automatically |
| Custom groups | Hand-pick machines into named groups; highest priority |
| Exclusions | Detach a machine from name-based pooling |
| Split I/O | Input into one block, collect from another (multiblock hatches) |
| Output cleanup | Before every craft the output slots of the machines involved are emptied to storage |
| Labels | Give machines your own custom names |

| Fluids | |
|---|---|
| Fluid & hybrid recipes | mB amounts, fluid+item inputs, item outputs |
| Sequential pour | One fluid at a time for multiblocks |
| Fluid KEEP | Auto-stock in mB |

| KEEP (auto-stock) | |
|---|---|
| Threshold → target | Crafts when stock drops below threshold, fills to target |
| Priority + pause | Ordered list, per-entry and global pause |
| Idle gate | Runs only after 3 min of inactivity |

| Logistics | |
|---|---|
| Transfer groups | Rule-based item/fluid moving with filters and conditions |
| Provider sources | Pull-only inventories: counted as stock, never filled |

| Interface & remote | |
|---|---|
| RECIPES | Search, quantity picker, max-craftable, machine reassign, alternatives |
| Live progress | Sub-task counter, per-branch bars |
| CANCEL | Stops the whole craft. Most modded machines block automated extraction from their input slots, so after cancelling check the input slots of machines that were running |
| STOCK / History | Storage view with filters; one-tap repeat of recent crafts |
| ntfy push | Phone notification on completion/failure; `/status`, `/queue`, `/cancel` from the phone |
| GitHub sync | Export/import the recipe library. Setup: create a private repo, generate a token, enter the repo and token in the GIT tab — after that import/export becomes available |

Data safety is built in: atomic saves, automatic backups with restore on boot, protection against config wipes.

---

## Tips

- Machine "disappeared"? Right-click its modem — the red ring must be lit.
- A machine inside a custom group always works with its group; EXCLUDE only affects name-based pooling.
- Keep free space in storage — collection needs somewhere to put results.
