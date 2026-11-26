# Player History

A mod for [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe): remembers the players you have played with.

<!-- drh:show -->
Every player you meet in a dungeon is remembered: name, hero and level (with the ascension number when they ascended), how many dungeons you played together (counted again after each dungeon you leave, for the town or for the next one), the last map, and when. In town, a round button on the home screen (under the Ultimate Records one) opens the board, as does the H key, which can be changed like the other mods' keys. Four tabs: the most recent players, the most played with, your friends, and a friends-only manager for bulk actions. A gold star marks a friend.

The board now has a clean white-and-ice-blue look, a soft green LIVE pip, and rows that keep their columns separate. The open tab refreshes twice a second, so presence and "seen" times stay current. The search box matches any part of a name, hero or map (press `/` while the board is open to focus it), and a top strip counts total players, friends, players in dungeons, repeats and players seen in the last 24 hours. Bulk buttons show how many players are selected, and the manager has SELECT PAGE and UNFRIEND (which removes the friendship, not the history entry). The manager sorts friends by Online Tracker activity, most active to least active; its LEAST ACTIVE button flips to least active first. Its ONLINE column shows the tracker's last-online date.

Escape closes the board. What is kept is in the mod's data folder, `players.json`, the last 300 players.
<!-- /drh:show -->

Each row has a JOIN button (highlighted when the player is in a dungeon; teleports your hero to them), an ADD button (sends a friend request, then shows SENT), a BLOCK button (it asks first, with the game's own popup) and a REMOVE button (press twice, SURE? the second time) that takes the player off the list. The manager's UNFRIEND button is different: it removes the friendship on the server and keeps the history entry. A blocked player shows BLOCKED. A small light beside a friend's status shows when they are online or in a dungeon.
