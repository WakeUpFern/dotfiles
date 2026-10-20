pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Reproductor "activo" entre todos los MPRIS de la sesion (Spotify, navegador, mpv...).
// Si hay uno elegido a mano se usa ese; si no, el que esta sonando; si no, el primero con pista.
Singleton {
    id: root

    property string preferred: ""                 // identity elegido a mano ("" = automatico)
    readonly property var players: Mpris.players.values

    readonly property var active: {
        const list = players;
        if (list.length === 0) return null;
        if (preferred !== "") {
            const p = list.find(x => x.identity === preferred);
            if (p) return p;
        }
        const playing = list.filter(x => x.isPlaying);
        if (playing.length > 0) return playing[0];
        const withTrack = list.filter(x => x.trackTitle !== "");
        return withTrack.length > 0 ? withTrack[0] : list[0];
    }

    readonly property bool hasMedia: active !== null && active.trackTitle !== ""
    readonly property bool playing: active !== null && active.isPlaying

    readonly property string line: hasMedia
        ? active.trackTitle + (active.trackArtist !== "" ? " — " + active.trackArtist : "")
        : ""

    function togglePlaying() {
        const p = active;
        if (!p) return;
        if (p.isPlaying) { if (p.canPause) p.pause(); }
        else if (p.canPlay) p.play();
    }
    function next()     { const p = active; if (p && p.canGoNext) p.next(); }
    function previous() { const p = active; if (p && p.canGoPrevious) p.previous(); }
    function select(name) {
        const p = players.find(x => x.identity.toLowerCase().includes(name.toLowerCase()));
        preferred = p ? p.identity : "";
        return p ? p.identity : "";
    }
}
