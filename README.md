# Pingo

![Locked modded joker](assets/preview/joker.png)

An unofficial add-on of the [Balatro Archipelago Randomizer](https://github.com/BurndiL/BalatroAP) that adds basic logic for modded items.

It works by grouping modded items with the existing vanilla ones, a lot like the bundles feature in the original mod. The mod groups checks first by category (joker, tarot card, spectral, etc.), and then prioritizes on minimizing the number of modded checks within each vanilla check, while also trying to match the rarities of the jokers with each other if it doesn't compromise on the afforementioned priorities. 

When the game is launched with the mod installed, a `logic.lua` file will show up in the mod directory. This contains the mapping of modded items which are tied to their respective vanilla check. A new one can always be generated simply by deleting the file, and then reloading the profile.

You are free to modify the file to move specific checks behind specific unlocks. Specifying the same modded check across multiple vanilla checks means that the modded check is unlocked when *any* of the vanilla checks are found. Removing a modded check from the list makes it fallback to the "Modded Items" setting under the Archipelago save file's config tab. Some modded elements (enhancements, editions, and tags) are intentionally not considered checks to remain consistent with the original mod.

Modded decks and stakes are not supported, since it interferes with the original mod. Although, this mod provides dedicated support for [Card Sleeves](https://github.com/larswijn/CardSleeves).

![Locked card sleeve](assets/preview/sleeve.png)

# Installation

Dependencies:
- [`steamodded >= 1.0.0~ALPHA-1326a`](https://github.com/Steamodded/smods)
- [`Lovely >= 0.6.0`](https://github.com/ethangreen-dev/lovely-injector)
- [`Rando >= 0.1.9d`](https://github.com/BurndiL/BalatroAP)

Press "Code" and "Download ZIP", or clone the repository if you're a nerd. Extract it inside `%appdata%/Balatro/Mods`. Verify that the path to this file is `%appdata%/Balatro/Mods/Pingo/README.md`, without any nested or missing folders.

# License

This repository is licensed under the [MPL-2 License](https://github.com/Emik03/Pingo/blob/main/LICENSE).

# Credits

Massive thank you to [larswijn](https://github.com/larswijn)'s randomizer, including everyone who helped in its creation. This mod would have been so much harder to make had I required to make everything from scratch.

Additionally, a big thank you to the wider [Archipelago](https://github.com/ArchipelagoMW/Archipelago) community for the entire backend and tooling that holds everything together.
