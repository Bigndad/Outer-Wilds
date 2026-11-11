pragma Singleton
import QtQuick

// Upstream shows running timers in its bar; here nothing reads it, FocusTimer just writes to it.
QtObject { property var entries: [] }
