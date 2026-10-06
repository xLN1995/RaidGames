# RaidGames

**Gold Roll, Deathroll, Jackpot and Blackjack for your raid. Only the host needs the addon.**

RaidGames turns the wait between pulls into a game. You pick a game and a bet, everyone else joins by typing `!roll` in raid chat and plays with the normal `/roll`. Nobody else has to install anything. RaidGames collects the sign-ups, checks every roll, announces who pays whom in raid chat and keeps a leaderboard of who is up and who is down.


## The games

**Gold Roll** – everyone rolls `/roll <bet>`. The lowest roll pays the highest roll the difference. The classic.

**Deathroll** – players take turns, each rolling up to the previous result (the first roll goes up to the bet). Whoever rolls the 1 pays the bet to the player before them. Works with any number of players.

**Jackpot** – everyone rolls `/roll <bet>`, the highest roll collects the bet from every other player. Optionally a percentage of the winnings goes to the guild bank.

**Blackjack** – no dealer, everyone plays at once. Each `/roll 13` is a card (A = 1 or 11, J/Q/K = 10), `!stand` to stand. Whoever is closest to 21 collects the bet from everyone else. A two-card Blackjack beats a 21 with more cards.

In every game a tie is settled by a reroll among the tied players only.


## How a round works

1. Open the window with `/rg` or the minimap button, pick a game, enter the bet and click **New game**.
2. Players (you too) type `!roll` in raid or party chat to join. Typing it again leaves the game.
3. Click **Start roll**: sign-up closes and everyone rolls.
4. When the last roll is in, RaidGames announces the result in raid chat, for example *"Winner: Thrall (9,512) – loser: Jaina (1,204). Jaina pays Thrall 8,308g!"*. The window shows the same.

Someone isn't rolling? **Remind** them in raid chat, remove them from the round, or cancel the game.


## What else it does

- **Checks every roll.** Only rolls with the right range count, and only the first one. Players with the wrong range get a hint in raid chat.
- **Leaderboard.** Every player's balance over all games is kept between sessions. Anyone in the raid can type `!top 5` or `!bottom 5` to see the best and worst players.
- **Connected realms.** Players from other realms are matched correctly, even though the roll message shows their name without the realm.
- **English and German.** Follows your client language, or switch with `/rg lang en` / `/rg lang de`. Announcements in raid chat use the same language.
- **Test mode.** Try every game alone with fake players before you run it in the raid.


## Commands

| Command | What it does |
| --- | --- |
| `/rg` | open or close the window |
| `/rg lang de`, `en` or `auto` | language |
| `/rg minimap` | show or hide the minimap button |
| `/rg joins` | also announce every sign-up in raid chat |
| `/rg reset` | reset the leaderboard |
| `/rg test`, `/rg fake 3`, `/rg fakeroll` | test mode with fake players |

Chat commands for everyone: `!roll` (join or leave), `!stand` (Blackjack), `!top x` and `!bottom x`.


## Good to know

- RaidGames only does the bookkeeping. Players hand over the gold themselves.
- During a boss encounter WoW Midnight hides chat and roll messages from addons. Play between pulls. Announcements that can't be sent during combat are sent afterwards.


## Feedback

Found a bug or have an idea for a new game? Leave a comment. The Lua error (BugSack makes that easy) and the output of `/rg debug on` while rolling help a lot.

---

# Deutsch

**Gold-Roll, Deathroll, Jackpot und Blackjack für deinen Raid. Nur der Spielleiter braucht das Addon.**

RaidGames macht aus der Wartezeit zwischen den Pulls ein Spiel. Du wählst Spiel und Einsatz, alle anderen melden sich mit `!roll` im Raid-Chat an und würfeln ganz normal mit `/roll`. Niemand sonst muss etwas installieren. RaidGames sammelt die Anmeldungen, prüft jeden Wurf, sagt im Raid-Chat an, wer wem zahlt, und führt eine Rangliste, wer im Plus und wer im Minus ist.

## Die Spiele

- **Gold-Roll** – alle `/roll <Einsatz>`. Der Niedrigste zahlt dem Höchsten die Differenz.
- **Deathroll** – reihum würfelt jeder bis zum vorherigen Ergebnis. Wer die 1 würfelt, zahlt dem Spieler vor ihm den Einsatz.
- **Jackpot** – der höchste Wurf bekommt von jedem anderen den Einsatz. Optional geht ein Anteil an die Gildenbank.
- **Blackjack** – ohne Bank. Jeder `/roll 13` ist eine Karte, `!stand` zum Stehenbleiben. Wer am nächsten an 21 ist, bekommt von allen den Einsatz.

Bei Gleichstand würfeln nur die Betroffenen neu.

## So läuft eine Runde

1. `/rg` oder Minimap-Button, Spiel und Einsatz wählen, **Neues Spiel**.
2. Alle (auch du) schreiben `!roll` in den Raid- oder Gruppenchat. Nochmal `!roll` = austreten.
3. **Starte Roll**: Anmeldung zu, alle würfeln.
4. Nach dem letzten Wurf steht im Raid-Chat und im Fenster, wer wem was zahlt.

Nachzügler kannst du **erinnern**, aus der Runde nehmen oder das Spiel abbrechen.

## Außerdem

- Nur Würfe mit dem richtigen Bereich zählen, und nur der erste. Bei falschem Bereich kommt ein Hinweis im Raid.
- Die Bilanz jedes Spielers bleibt gespeichert. Jeder im Raid kann `!top 5` oder `!bottom 5` abfragen.
- Spieler von verbundenen Realms werden richtig erkannt.
- Deutsch und Englisch, je nach Client oder mit `/rg lang de|en`.
- Testmodus mit Fake-Spielern zum Ausprobieren.

## Gut zu wissen

- RaidGames rechnet nur. Das Gold handeln die Spieler selbst.
- Während eines Bosskampfs versteckt WoW Midnight Chat und Würfelergebnisse vor Addons. Spielt zwischen den Pulls.
