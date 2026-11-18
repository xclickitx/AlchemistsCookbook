# CurseForge listing copy

Paste these into the project form when you are ready to create the project. Nothing here has been submitted.

Suggested project name: **Alchemist's Cookbook**
Suggested slug: `alchemists-cookbook` (or `alchemistscookbook` if that is taken)
License to select: **MIT License**
Author: use your CurseForge account. In-game / TOC author is **ClickIT**, the same as Grey Dump.

## Short summary (project summary field, 157 characters)

Browse every profession's recipes and reagents without opening its window, so your repeat craft keeps going. Tabs, search, have/need counts. For WoW Forever.

## Description (plain markdown for the Description field)

This is the approved text from `DESCRIPTION.md`, with one fact updated for 1.0.1 (the live crafting line example). Add the GitHub source link at the end.

```markdown
# Alchemist's Cookbook
*Browse every profession you know without stopping the craft you're in the middle of.*

You've queued up 200 Tin Bars and settled in. Halfway through, you want to check how many Coarse Sharpening Stones you could make, or what that Blacksmithing recipe needs. Open the Blacksmithing window and your smelting stops cold, because the game only lets one profession window be open at a time.

Alchemist's Cookbook fixes that. Every time you open a profession, it quietly saves your recipes. After that you can browse any of them in the Cookbook window while your repeat craft keeps going. Nothing gets cancelled until you jump or stop it yourself.

## Features
- One tab for each profession you've opened, all in one movable window
- Search by recipe name or reagent (type "tin" to find everything that uses it)
- How many of each recipe you can make right now, shown next to its name
- Reagent counts as "have / need", colored green, yellow (counting your bank) or red
- Item tooltips on hover, plus a live line showing what you're crafting and how many are left (for example "Crafting [Tin Bar]: 2 of 5 done, 3 left")
- Minimap button, keybind, `/acook` or `/cookbook`, and a settings page under Options > AddOns

## Getting started
1. Install it and restart the game.
2. Open each of your professions once the normal way, so the Cookbook can save it.
3. Start a long craft, open the Cookbook, and browse to your heart's content.

**Grows with you:** every time you open a profession, the Cookbook re-saves it, so new recipes and skill-ups are picked up automatically. Perfect for low-level characters too. Start with a handful of recipes and the Cookbook fills in as you level.


## Safe by design
The Cookbook only reads. It never crafts, casts, or opens or closes a profession window, so it can't interrupt what you're making. It's built for WoW Forever, and it's free and MIT licensed.

*The name is a safe-for-work nod to a certain infamous cookbook from back in the day.* 😉

Source and license: https://github.com/xclickitx/AlchemistsCookbook
```

## Categories and tags

- **Primary category:** Professions
  (The add-on is about profession recipes and reagents; comparable tools like Skillet and TradeSkillMaster's crafting side sit there.)
- **Secondary:** none required. If the form asks for a second one, use **Bags & Inventory** (it counts reagents in your bags and bank). Do not use Plugins (that is for add-ons that extend other add-ons).

Suggested tags, if the form offers them: `professions`, `tradeskill`, `crafting`, `recipes`, `reagents`, `quality of life`, `cookbook`.

## Game version when you upload the file

WoW Forever is a selectable flavor on CurseForge with game version **1.60.1** (confirmed for Grey Dump on 13 November 2026: CurseForge's own launch post, [WoW Forever Launch: New Addons & Hidden Gems on CurseForge](https://blog.curseforge.com/step-into-eternity-celebrating-the-launch-of-wow-forever-on-curseforge/), and existing Forever add-ons listing Flavor: Forever, Game Versions: 1.60.1).

When you upload `AlchemistsCookbook-1.0.1.zip`:

- Game / flavor: **World of Warcraft**, flavor **Forever** (sometimes shown as "WoW Forever")
- Supported version: **1.60.1**
- Release type: **Release**
- Changelog: paste the 1.0.1 section from `CHANGELOG.md` (it's the first public upload, so you can also paste the 1.0.0 section under it)

Tag the file with the Forever 1.60.1 version only. Do not also tag Retail or Classic unless those clients are tested later.

## Upload file

Use the clean player zip, not a git checkout:

`AlchemistsCookbook-1.0.1.zip` (in this folder; ignored by git, so attach it to the GitHub release by hand)

The zip's top level must be the `AlchemistsCookbook/` folder (`AlchemistsCookbook/AlchemistsCookbook.toc`, `AlchemistsCookbook/AlchemistsCookbook.lua`, `AlchemistsCookbook/Bindings.xml`, `AlchemistsCookbook/LICENSE.txt`). No `test/`, no nested `AlchemistsCookbook/AlchemistsCookbook/` folder.

## Screenshots to upload (in this order)

All are 1920x1080 JPGs under 1 MB in `screenshots/`.

1. `12-counter-2-of-3.jpg` (main image). Caption: **"Keep crafting while you browse: 2 of 3 done, 1 left"**
2. `08-crafting-browse-first-aid.jpg`. Caption: **"Check First Aid while your smelting keeps going"**
3. `05-mining-all-tabs.jpg`. Caption: **"Every profession you know in one window"**
4. `03-blacksmithing-tooltip.jpg`. Caption: **"Item tooltips and how many you can make right now"**
5. `11-counter-1-of-3.jpg`. Caption: **"A live count of what you're crafting and how many are left"**

## Still needed from you before anything goes live

- Create the GitHub repo `xclickitx/AlchemistsCookbook`, then push this folder and attach `AlchemistsCookbook-1.0.1.zip` to a `v1.0.1` release
