# Chaos Chess — Lobby

A rebuilt lobby with a clear goal: you spawn facing the arena, glowing arrows lead
through a big **PLAY** gate, and a guide line points you to an open match circle.
Stand on a **WHITE** or **BLACK** circle; when both are filled, a countdown starts the match.

```
builder/BuildLobby.lua              Run once in Studio's Command Bar to build the map
src/server/LobbyServer.server.lua   Matchmaking pads, countdown, match start, leaderboard  -> ServerScriptService
src/client/LobbyClient.client.lua   Top banner, guide line, animated arrows                -> StarterPlayerScripts
default.project.json                Rojo project (optional)
```

## Setup in Studio

1. **Build the map:** open `builder/BuildLobby.lua`, copy all of it, paste into
   *View → Command Bar*, press Enter. Your old `Workspace.Lobby` is moved to
   `ServerStorage.OldLobbyBackup` (edit `OLD_LOBBY_NAMES` at the top if it's named differently).
   Ctrl+Z undoes the whole build.
2. **Add the scripts:**
   - With Rojo: `rojo serve` and connect the Studio plugin.
   - Without Rojo: create a **Script** named `LobbyServer` in ServerScriptService and a
     **LocalScript** named `LobbyClient` in StarterPlayer → StarterPlayerScripts, and paste the files in.
3. **Hook up your match** (top of `LobbyServer`):
   - Separate match place: set `MATCH_PLACE_ID`. Both players get teleported to a reserved
     server with TeleportData `{ white = userId, black = userId }`.
   - Same place: leave it `0` and connect to the BindableEvent:
     ```lua
     game.ServerStorage.LobbyEvents.MatchFound.Event:Connect(function(white, black, padIndex)
         -- start your chess game with these two players
     end)
     ```
4. Delete or disable any old SpawnLocations (the builder warns about them in Output).

## Real chess meshes

The pieces are built from parts and stacked from the ground up, so none of them float.
To use real meshes, put Models/MeshParts named `Pawn`, `Rook`, `Knight`, `Bishop`, `Queen`,
`King` in `ServerStorage.ChessMeshes` and run the builder again. They get scaled,
recoloured and placed on the board automatically.
