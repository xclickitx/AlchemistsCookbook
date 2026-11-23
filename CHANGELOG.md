# Changelog

All notable changes to Alchemist's Cookbook are listed here.

## 1.0.5

- Work in progress: being tested in-game. 1.0.4 remains the current stable release.
- If Auctionator is loaded, the recipe detail now shows **To Craft** and **Profit** under the reagents, using Auctionator's last scanned prices (vendor buy price when it's the better deal, otherwise the auction price). Profit is the product's auction price, minus the 5% auction house cut, minus the craft cost. A loss is shown in red. Recipes with no item output hide the profit line. If a reagent has no price, the cost is marked `(incomplete)`.
- Hovering a recipe's output (the icon, the "Makes" item, or the recipe row) or a reagent now shows the same **Vendor** and **Auction** prices Auctionator puts on bag tooltips, including the stack/count price for reagents. The Cookbook still uses its own tooltip (so compare stays limited to the gear you're wearing); it asks Auctionator to add the lines, and won't add them twice. If Auctionator isn't loaded, the tooltip is unchanged.
- Auctionator is a soft dependency only. If it isn't loaded, the Cookbook looks exactly as it did in 1.0.4: no extra line, no empty gap, and no errors. There is no new setting.

## 1.0.4

- Code cleanup: removed a leaked global variable. The add-on name is now kept in a local (`addonName`) instead of a follow-up assignment that looked like a global write to lint tools.

## 1.0.3

- Fixed: item tooltips in the Cookbook could compare against the wrong gear. While crafting (for example smelting with the Mining window open), hovering a weapon could show "Equipped With: Mining Pick" and a "Press SHIFT-C to cycle through your main-hand items" line, because the game paired the item with the profession tool in your bags.
- Cookbook item tooltips now compare only with what you're actually wearing in that item's slot: main hand and off hand for weapons, off hand for shields and held items, both slots for rings and trinkets. Profession tools and other items in your bags are never used.
- The compare follows the default UI's rule: it shows while you hold Shift (or your compare key), or all the time if you have "always compare items" turned on. It updates when you press or release Shift or change gear.
- The Cookbook now shows item tooltips in its own tooltip window instead of the game's main one, so it never touches the game's built-in compare.

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
