pragma Singleton
import QtQuick

// Upstream plays UI sounds; here every call is a no-op.
QtObject { function playSfx(name, volume) {}

    // added by port_anserin.py
    function playUntilStopped(name, volume, loop) { return -1 }
    function stopSfx(handle) {}
}
