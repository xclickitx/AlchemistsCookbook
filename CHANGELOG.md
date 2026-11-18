# Changelog

All notable changes to Alchemist's Cookbook are listed here.

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
