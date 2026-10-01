# A.E.G.I.S autocraft for CC:Tweaked

A.E.G.I.S. is a CC:Tweaked autocraft in plain Lua. The first version was really basic - no dependency tree, no scheduler, just pulling ready components from a chest for one-level crafts. But I got so hooked on the process itself that after half a year of endless tweaking and feature creep the project grew way bigger than I'd originally planned - kind of a *factory core in a single computer*. 12k lines in and I'm still poking at it. Ah right - the factory must grow.

<p align="center"><img src="./images/2026-08-09-20-23-25.png" width="720"></p>

When you order an item, A.E.G.I.S. reads its saved recipes, walks the dependency tree, checks what's already sitting in your vaults and tanks, and only pushes the missing ingredients out to whichever free machines can handle them.

Teaching is interactive: drop the ingredients into T.BOX (3x3 layout for turtle crafts, or just place them for a machine recipe), pick the machine, hit SCAN - recipe is saved. From then on the system walks the dependencies on its own and crafts everything through to the final product. More details in the [Teaching recipes](#teaching-recipes-recipes-tab) section.

A.E.G.I.S. covers almost every mod, but there are exceptions - a few don't expose a standard inventory API to CC:Tweaked. Those still work through a [transfer chest workaround](#known-limitations) between the machine and the network.

---

## Requirements

- **Advanced Computer** - runs `computer/startup.lua`.
- **Advanced Monitors** - 5x3 or larger is comfortable, other layouts work too.
- **Crafty Turtle** - Advanced Turtle running `turtle/startup.lua`, used for 3x3 grid recipes.
- **Storage** - connected chests, vaults, drawers or tanks.
- **T.BOX** - one barrel or chest used as staging area for teaching recipes and item delivery.
- **Wired network** - modems on every machine/chest, connected by cable, activated (red ring on).

---

## Quick setup

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-36-05.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Install & tag</b><br><br>Drop <code>computer/startup.lua</code> onto the Advanced Computer, <code>turtle/startup.lua</code> onto the turtle, then <code>reboot</code>. On the monitor, open the <b>NETWORK</b> tab and tag your peripherals: storages → <code>[VAULT]</code>, staging barrel → <code>[T.BOX]</code>, crafting turtles → <code>[TURTLE]</code>, fluid tanks → <code>[TNK]</code> (optional).</td>
</tr>
</table>

---

## Teaching recipes (+RECIPES tab)

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-26-45.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>3x3 grid recipe</b><br><br>Lay ingredients in the 3x3 center of T.BOX, then <code>+RECIPES → TURTLE → SCAN</code>.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-27-09.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Machine recipe</b><br><br>Place ingredients in T.BOX, select the machine on the computer, then <code>+RECIPES → MACHINES → SCAN</code>.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-30-35.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Fluid / hybrid recipe</b><br><br>Solid items go into T.BOX, fluid type and mB volume are typed on the computer, then <code>+RECIPES → FLUID → SCAN</code>.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-32-34.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Alternatives (+ALT)</b><br><br>If an item already has a recipe, you can add another one as <code>+ALT</code>. At craft time the alts are checked top to bottom, first one that matches the stock is picked.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-34-39.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Editing</b><br><br><code>[E]</code> in the recipes tab lets you swap the machine for a recipe, or reassign a whole machine tag across every saved recipe at once.</td>
</tr>
</table>

---

## Create Mechanical Crafters (+RECIPES → CRAFTER)

Big Create recipes (up to 9x9, e.g. 5x5) run on a Mechanical Crafter grid.

**Build:**
- **Crafters** - put a wired modem on the back of every crafter and activate it. Leave crafter inputs **unconnected** (no wrench links), otherwise every modem sees the same combined inventory.
- **Output** - point the chain's last crafter into a barrel and give that barrel its own modem. Tag it `[C.OUT]` in NETWORK. It must not be a VAULT or the T.BOX.
- **Clutch relay** - drive the grid through a Clutch, powered by a Redstone Relay on the network. Tag the relay `[CLUTCH]`, and tap again to cycle through output sides. Relay ON disengages the clutch and locks the grid. Keep the relay from powering any crafter.
- **Pulse relay (optional)** - a second relay touching any crafter. Tag it `[PULSE]`. Recipes with empty cells need it to start, unless every empty cell has a Crafter Slot Cover.

**Teach:** press `DETECT GRID` and check that the lock shows `LOCKED`. Place the recipe into the crafters by hand, then `SCAN`. A.E.G.I.S. reads every cell and unlocks the grid. The finished item comes back from `[C.OUT]` to T.BOX.

**Craft:** one craft at a time. For each craft A.E.G.I.S. locks the grid and checks it's empty. It confirms stock covers **every** cell before it pushes anything, since crafters are insert-only and a half-loaded grid can't be unloaded by the computer. Then it loads the grid, unlocks, pulses, and pulls the result from `[C.OUT]` into vaults. A recipe is tied to the exact crafter peripherals it was learned on, so re-learn it after rebuilding the grid. Crafter recipes are not exported to GitHub.

**Cancel and recovery:** once the first item is in the grid, that craft can't be interrupted. `CANCEL` takes effect after it completes, so it never leaves half a recipe behind. If the grid still ends up part-loaded (load failure, reboot, chunk unload), the next crafter craft finishes the leftover first when it matches a known recipe. You can also use `[FINISH GRID]` in `+RECIPES → CRAFTER`. To clear the grid by hand, right-click each crafter's front with an empty hand.

---

## Autocrafting

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td colspan="2" align="center" valign="top" style="border:0;background:transparent;text-align:center;"><b>Parallel execution</b><br><br>When you request an item, A.E.G.I.S. first looks at what's already in storage, then goes after the missing ingredients.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/scan.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>SCAN</b><br><br><b>1.</b> SCAN figures out how many of each item you can actually craft from what's currently in storage. <code>SCAN</code> only checks the recipes on the current page; <code>ALL</code> checks the whole library (can take a moment on a big one).<br><b>2.</b> After it finishes, every recipe shows its max craftable count. A <code>[!]</code> next to a recipe means something is missing - tap it to see the exact list of what's short.<br><b>3.</b> Pressing <code>[CRAFT]</code> runs the same pre-calc for that single item by default. Flip the toggle to manual and the craft window opens without pre-calculating.<br><br>The calculation covers everything: items and fluids in stock, every ALT recipe, hybrid and fluid sub-crafts down the chain, and PROVIDER rules from LOGICK.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-48-13.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Multi-machine batching (<code>pm3</code>)</b><br><br>Parts of the job that don't depend on each other can run at the same time if there are free machines. The header shows <code>parallel X</code> for active sub-tasks. <code>pm3</code> on a task means 3 machines are working on it together. For recipes with probabilistic outputs the system just keeps feeding ingredients until the requested count is reached.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-50-54.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Queue</b><br><br>You can queue several crafts at once. If one runs out of resources it gets a warning, stays in the queue, and the next order starts.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-21-13-50.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Tools</b><br><br>GT-style durability tools (saws, hammers, files) are supported. If a tool breaks mid-craft, A.E.G.I.S. crafts a replacement first, then resumes the parent job.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-44-09.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Cancel / cleanup</b><br><br>Output slots are cleared before a sub-task and again on finish. Pressing <code>CANCEL</code> stops the current craft and dumps output slots to vaults. It can't always pull from input slots though - some mods block that (see limitations).</td>
</tr>
</table>

---

## Machines and groups

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-37-29.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Auto-grouping</b><br><br>Machines that share a peripheral name auto-form a pool, so you don't have to configure anything for the usual case. Individual machines can be excluded from a pool.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-39-38.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Custom groups</b><br><br>You can also group machines manually - e.g. split Create Depots into <code>Depot Forge</code> vs <code>Depot Press</code>. If you add a machine to a custom group, exclude it from auto-grouping, otherwise it ends up in both.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-25-28.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Suffixes</b><br><br>A machine can be assigned a display suffix (<code>SUF</code>) in the NETWORK tab - purely cosmetic, just helps organize machine names so they're easier to scan.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-20-44.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Multiblocks</b><br><br>Multiblocks with separate input and output hatches are supported.</td>
</tr>
</table>

---

## Fluids

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-16-47.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Hybrid & sequential pouring</b><br><br>Solid + fluid recipes work - fluid volumes are tracked in mB, and multiple fluids can be poured one after another. Full walkthrough on the screenshot.<br>Multiblocks with several fluid hatches - pipe them to one transfer tank and set it as the recipe INPUT. Same trick works for OUTPUT.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-07-57.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Fluid stock & OPTIMIZE</b><br><br>The stock view shows how many tanks each fluid takes up. <code>OPTIMIZE</code> scans, merges and defrags fluid storage.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-06-57.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>KEEP-FLUID</b><br><br><code>KEEP-FLUID</code> sets an automated mB buffer for a fluid, similar to KEEP for items.</td>
</tr>
</table>

---

## KEEP (auto-stocking)

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-05-35.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Threshold >> target</b><br><br>KEEP uses two numbers per item: a threshold and a target. Crafting starts only when stock drops below the threshold and stops once it reaches the target. So the system doesn't re-trigger a craft after every single item consumed.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-51-53.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Priority order</b><br><br>KEEP entries run in the order you set them - higher entries first.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-21-00-11.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>Idle execution</b><br><br>KEEP runs automatically when the system has been idle for ~3 minutes and no manual craft is active. Can be paused at any time.</td>
</tr>
</table>

---

## Storage

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-04-36.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>STOCK & request</b><br><br><code>STOCK</code> gives one unified view of everything in the connected vaults. From there you can request items straight into free T.BOX slots.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-03-47.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>OPTIMIZE</b><br><br><code>OPTIMIZE</code> walks every vault, merges unstacked stacks of the same item, and consolidates matching items into one place.</td>
</tr>
<tr style="background:transparent;">
<td colspan="2" valign="top" style="border:0;background:transparent;"><h2>LOGICK</h2>LOGICK replaces item/fluid pipes with rule-based transfers.<br>INPUT and OUTPUT can each point at several machines or vaults, the system spreads the resource evenly across the group.<br>Fluids work too: pick a tank as INPUT and the rule switches to fluid mode.</td>
</tr>
<tr style="background:transparent;height:210px;">
<td rowspan="3" valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-20-02-54.png" width="380" /></td>
<td valign="middle" style="border:0;background:transparent;"><b>Standard</b> - keeps the resource at the set amount.</td>
</tr>
<tr style="background:transparent;height:210px;">
<td valign="middle" style="border:0;background:transparent;"><b>Provider</b> - pull-only: the system can take resources out but never puts anything back.</td>
</tr>
<tr style="background:transparent;height:210px;">
<td valign="middle" style="border:0;background:transparent;"><b>IF</b> - conditional, like *move wood if charcoal < 32*. You can stack several IF rules in one group, and pick <code>&lt;</code>, <code>&gt;</code> or <code>=</code> as the operator.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/AE2_RS.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>AE2 / RS storage</b><br><br>AE2/RS via Advanced Peripherals: AEGIS only pulls from the network, never pushes anything back. Wire the ME/RS Bridge to your AE2/RS and to the AEGIS modem, then set the LOGICK rule as on the screenshot.</td>
</tr>
</table>

---

## Remote and integrations

<table border="0" cellspacing="0" cellpadding="8" style="border-collapse:collapse;border:0;background:transparent;">
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-19-51-42.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>RedNet remote</b><br><br>Run <code>remote_control</code> on a pocket computer with an Ender Modem to order items and follow live progress from anywhere in loaded chunks.<br>Setup: install <a href="https://github.com/egor-oleg/aegis-autocraft/tree/main/remote_control"><code>remote_control</code></a> on the pocket computer, and attach an Ender Modem to the main computer.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-19-51-12.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>GitHub sync</b><br><br>Recipe library can be exported/imported via a GitHub Personal Access Token. The token is masked in the UI and dropped from RAM on reboot.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/2026-08-09-19-50-38.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>ntfy push</b><br><br>Optional push notifications when a craft finishes. If it fails, the message includes the reason and the stage where it broke.<br>Type <code>status</code> in the ntfy chat to see the current craft progress.<br>Setup: create a chat on <a href="https://ntfy.sh/app">ntfy</a>, pick a unique name, and paste it into the AEGIS <code>SERVICE</code> tab.</td>
</tr>
<tr style="background:transparent;">
<td valign="top" width="42%" style="border:0;background:transparent;"><img src="./images/log.png" width="380" /></td>
<td valign="top" style="border:0;background:transparent;"><b>dbglog</b><br><br>Debug logging is off by default - toggle it in the <code>SERVICE</code> tab. Logs are written to the computer's directory. On reboot or when a new craft starts the current log rotates: the previous one becomes <code>factory_dbg.log.old</code>. Turning logging off wipes all log files.</td>
</tr>
<tr style="background:transparent;">
<td colspan="2" valign="top" style="border:0;background:transparent;"><b><a href="./API.md">AEGIS API</a></b><br><br>Small Lua API under <code>aegis.*</code> - same internals the on-monitor UI uses, so anything you can do by tapping the screen you can also drive from code. Works locally on the A.E.G.I.S. computer, or remotely over RedNet on protocol <code>aegis_remote</code>.<br>Covers item and fluid stock, the recipe library (with ALTs and producers), craft planning and enqueue, and live job/queue status. Full reference in <a href="./API.md">API.md</a>.</td>
</tr>
</table>

---

## Known limitations

- Some mods don't expose machine input/output inventories through the CC:Tweaked peripheral API. For those you can usually put a chest between the machine and the network - [guide](https://www.reddit.com/r/ComputerCraft/comments/1uyx4td/comment/oy8femh/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button).
- Some mods let you push into an input slot but not pull out of it. `CANCEL` can't always recover items from those input slots - check them by hand after a cancel.
- Multiblocks may need transfer chests or separate input/output hatches, depending on how the mod wires them up.
- CC:Tweaked computers have a 1 MB filesystem cap. If new recipes stop saving or vanish on reboot, the computer folder is full - delete old `.BAK` files.
- Solid-fuel furnaces need a specific setup - [guide](https://www.reddit.com/r/ComputerCraft/comments/1uyx4td/comment/oyb7z51/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button).
- Machines must stay chunk-loaded for a job to keep running.
- Keep an eye on free vault and tank space at the top of the monitor. If there's nowhere to unload, collection tasks stall.

<p align="center">
  <img src="./images/2026-08-09-21-08-50.png" width="380" />
  &nbsp;&nbsp;
  <img src="./images/2026-08-09-20-57-35.png" width="380" />
</p>

Tested on Modern Industrialization, Create, Greg_th, PneumaticCraft, and a bunch of others - most machines from most mods just work. Some mods (like Mekanism) lack CC integration and need a workaround, usually a chest between the machine and the network.

---

[Community & support](https://www.reddit.com/r/ComputerCraft/comments/1uyx4td/aegis_autocraft_for_computercraft_cctweaked/)

[Setup & guide video](https://youtu.be/mhVkOqG2S1A?si=LeTGJ9jsijtcVPoM)
