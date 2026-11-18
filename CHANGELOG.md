# Changelog

All notable changes to Alchemist's Cookbook are listed here.

## 1.0.2

- New recipe filters, as small checkboxes next to the search box and on the settings page:
  - **Skill-ups only** shows only recipes that can still raise your skill (orange, yellow or green) and hides grey ones.
  - **Have materials** shows only recipes you can make at least one of right now from your bags. Tick **+ bank** to count your bank too (as of your last bank visit); it only appears once Have materials is ticked.
- The filters combine with each other and with search. Headers with nothing left under them are hidden, and if nothing matches you get a short message saying which filters are on.
- Slash commands: `/acook skillup`, `/acook have` and `/acook bank` toggle them (add `on` or `off` to set them directly).
- Filters are saved per account. "Defaults" on the settings page turns them off.
- Fixed: a scan that ran while the game was still loading a profession could save it as an extra "Unknown 0/0" tab. Placeholder names (Unknown, in any language) and skill 0/0 are now never saved; the Cookbook works the name out from the skill line or the recipes, or waits and scans again. Any "Unknown" list saved earlier is removed when you log in (chat says so), so just open that profession again.

## 1.0.1

- Fixed the live crafting line. "Done so far" stayed at 0 during a repeat craft, because each finished craft refreshes the open profession's recipe list and the Cookbook treated the next cast as a new batch. Batches are now matched by their spell, so a refresh no longer resets the count.
- Each finished craft is counted once: from the cast finishing, or from the "You create: [item]" chat line if the cast event doesn't arrive. The two are never added together.
- The batch size is read once, when the first cast starts (remaining crafts + 1, the same way the game's own Professions window works it out). "Left" is then the batch size minus what's done, so it can't jump around if the game's own count updates late. Pressing Create or Create All again with a bigger queue starts a new batch.
- The line now reads like `Crafting [Tin Bar]: 2 of 5 done, 3 left` ("left" includes the one being made right now). It clears when the batch finishes, when you jump or move to cancel, or about 8 seconds after crafting stops on its own (for example, out of ore).

## 1.0.0

- First release for WoW Forever (Interface 16001).
- Saves each profession's recipes (per character) whenever you open it the normal way.
- Cookbook window: one tab per saved profession, search by recipe or reagent name, collapsible headers, how many you can make right now, reagent "have / need" counts (bags, plus bank), item tooltips, and a live line while repeat-crafting.
- Minimap button, keybind, `/acook` and `/cookbook`, Esc to close, and a settings page under Esc > Options > AddOns > Alchemist's Cookbook.
- Read-only: never crafts, casts, or opens or closes a profession window.
