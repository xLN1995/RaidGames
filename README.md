# RaidGames

WoW-Retail-Addon (Midnight 12.x) für Raid-Spiele. Nur der Spielleiter braucht das Addon.
Spiele: **Gold-Roll**, **Deathroll**, **Jackpot**, **Blackjack**. Anmeldung immer mit `!roll` im Raid- oder Gruppenchat.

## Installation
Über die CurseForge-App oder den Download auf CurseForge. Für die Entwicklung verlinkt `tools/link-dev.sh`
dieses Repo als `RaidGames` in den Retail-AddOns-Ordner (Pfad mit `WOW_ADDONS=...` überschreibbar).
Die `## Interface:`-Nummer in `RaidGames.toc` prüfst du im Spiel mit `/dump select(4, GetBuildInfo())`.

## Entwicklung
```bash
tools/lint.sh       # luacheck (Docker, Lua 5.1)
tools/package.sh    # Release-Zip nach release/ bauen, ohne Upload
tools/link-dev.sh   # Dev-Symlink in den AddOns-Ordner
```
Releases: Tag `vX.Y.Z` (bzw. `-beta`/`-alpha`) einzeln pushen, nie `--tags`. Forgejo spiegelt nach GitHub,
dort baut der BigWigs-Packager und lädt zu CurseForge hoch.

## Gold-Roll
1. `/rg` öffnet das Fenster. Einsatz eintragen und **Neues Spiel** klicken.
2. Alle (auch der Spielleiter) schreiben `!roll` in den Raid- oder Gruppenchat. Nochmal `!roll` = austreten.
3. **Starte Roll**: Die Anmeldung ist geschlossen, alle machen `/roll <Einsatz>`.
4. Der höchste Wurf gewinnt, der niedrigste zahlt die Differenz. Bei Gleichstand würfeln nur die Betroffenen neu.
5. Wer noch nicht gewürfelt hat: **Erinnern** oder in der Liste mit `x` entfernen.

## Deathroll
Reihenfolge = Anmeldereihenfolge. Wer dran ist, würfelt `/roll <letztes Ergebnis>` (Start: Einsatz).
Wer die 1 würfelt, zahlt den Einsatz an den Spieler vor ihm.

## Jackpot
Alle `/roll <Einsatz>`. Der Höchste bekommt von jedem anderen den Einsatz.
Optional geht ein Gildenanteil (% vom Gewinn, im Fenster einstellbar) an die Gildenbank.

## Blackjack (ohne Bank)
Karten per `/roll 13` (1 = Ass 1/11, 11–13 = Bube/Dame/König = 10). Die ersten 2 Würfe sind die Starthand,
jeder weitere `/roll 13` zieht eine Karte, `!stand` bleibt stehen. Über 21 = bust.
Wer am nächsten an 21 ist, bekommt von jedem anderen den Einsatz; Blackjack schlägt 21 mit mehr Karten.
Gleichstand wird mit `/roll 100` entschieden.

## Chat-Befehle (für alle)
- `!roll`: an- bzw. abmelden (nur während der Anmeldung)
- `!stand`: bei Blackjack stehen bleiben
- `!top x` / `!bottom x`: beste bzw. schlechteste x Spieler nach Gesamtbilanz (max. 10)

## Slash-Befehle
`/rg`, `/rg reset`, `/rg joins` (Raid-Ansage bei Anmeldung), `/rg lang de|en|auto` (Sprache), `/rg minimap` (Minimap-Button), `/rg debug on|off`, `/rg test`, `/rg fake <n>`, `/rg fakeroll [wert]`

## Sprache und Minimap
Deutsch und Englisch. Standard ist die Client-Sprache, umstellbar mit `/rg lang de|en|auto`; das gilt für Fenster und Raid-Ansagen.
Übersetzungen liegen in `Locales/` (Schlüssel = englischer Text im Code). Minimap-Button: Linksklick öffnet das Fenster,
Rechtsklick die Statistik. Derselbe Eintrag steht im Addon-Menü an der Minimap.
Das Original des Logos liegt in `assets/`; die Icons in `Media/` sind daraus erzeugt (TGA, 64/128 px).

## Weitere Spiele
Neue Datei in `Games/` mit `RaidGames:RegisterGame({...})` anlegen (siehe `Games/GoldRoll.lua`) und in der TOC eintragen.
