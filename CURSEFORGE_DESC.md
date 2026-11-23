# Alchemist's Cookbook
*Browse every profession you know without stopping the craft you're in the middle of.*

You've queued up 200 Tin Bars and settled in. Halfway through, you want to check how many Coarse Sharpening Stones you could make, or what that Blacksmithing recipe needs. Open the Blacksmithing window and your smelting stops cold, because the game only lets one profession window be open at a time.

Alchemist's Cookbook fixes that. Every time you open a profession, it quietly saves your recipes. After that you can browse any of them in the Cookbook window while your repeat craft keeps going. Nothing gets cancelled until you jump or stop it yourself.

Alchemist's Cookbook is complete on its own. It has no required dependencies.

## Features
- One tab for each profession you've opened, all in one movable window
- Search by recipe name or reagent (type "tin" to find everything that uses it)
- How many of each recipe you can make right now, shown next to its name
- Filters for "Skill-ups only" (hide grey recipes) and "Have materials" (only what you can make right now, optionally counting your bank)
- Reagent counts as "have / need", colored green, yellow (counting your bank) or red
- Item tooltips on hover, plus a live line showing what you're crafting and how many are left (for example "Crafting [Tin Bar]: 2 of 5 done, 3 left")
- Minimap button, keybind, `/acook` or `/cookbook`, and a settings page under Options > AddOns

## Optional Auctionator support

If you also have Auctionator installed, the two get even better together. The Cookbook notices it automatically — there's nothing to configure, and no setting to turn on:

- **To Craft** and **Profit** appear under the reagents, using Auctionator's last scanned prices. Profit is the product's auction price, minus the 5% auction house cut, minus the craft cost. A loss is shown in red. If a reagent hasn't been priced, the cost is marked `(incomplete)`.
- Hovering a recipe output or reagent shows the same **Vendor** and **Auction** prices you see on bag tooltips.

Without Auctionator, those extra lines simply aren't shown, and the rest of the Cookbook works the same.

## Getting started
1. Install it and restart the game.
2. Open each of your professions once the normal way, so the Cookbook can save it.
3. Start a long craft, open the Cookbook, and browse to your heart's content.

**Grows with you:** every time you open a profession, the Cookbook re-saves it, so new recipes and skill-ups are picked up automatically. Perfect for low-level characters too. Start with a handful of recipes and the Cookbook fills in as you level.


## Safe by design
The Cookbook only reads. It never crafts, casts, or opens or closes a profession window, so it can't interrupt what you're making. It's built for WoW Forever, and it's free and MIT licensed.

*The name is a safe-for-work nod to a certain infamous cookbook from back in the day.* 😉

**AI Disclaimer:** I used an AI assistant to help write the Lua code and draft this text. 1.0.5 has been tested in-game on WoW Forever 1.60.1. No AI-generated art or assets are included; the icons are Blizzard's built-in textures, and the screenshots are from the game.


Source and license: https://github.com/xclickitx/AlchemistsCookbook
