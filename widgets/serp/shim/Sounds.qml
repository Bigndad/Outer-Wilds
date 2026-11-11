pragma Singleton
import QtQuick

// Upstream plays UI sounds; here every call is a no-op.
QtObject { function playSfx(name, volume) {} }
