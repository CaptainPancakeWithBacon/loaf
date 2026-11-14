// node tests/bring-back.test.js : checks Niri.qml's windowToBringBack (pulled out of the QML file).
const fs = require("fs"), assert = require("assert")
const src = fs.readFileSync(__dirname + "/../loaf/Niri.qml", "utf8")
const fn = new Function("return " + src.match(/function windowToBringBack[\s\S]*?\n    }/)[0])()
const ws = (id, output, extra = {}) => ({ id, idx: 1, output, is_active: true, is_focused: false, active_window_id: null, ...extra })

// unplug: Claude (window 4) focused on DP-9, laptop shows workspace 1
const before = [ws(1, "eDP-1"), ws(6, "DP-9", { is_focused: true, active_window_id: 4 }), ws(15, "DP-10")]
const after = [ws(1, "eDP-1"), { ...before[1], output: "eDP-1", idx: 2, is_active: false }, { ...before[2], output: "eDP-1", idx: 3 }]
assert.strictEqual(fn(before, after), 4)
// focus stayed on the laptop: leave it
assert.strictEqual(fn([ws(1, "eDP-1", { is_focused: true, active_window_id: 2 }), ws(6, "DP-9", { active_window_id: 4 })], [ws(1, "eDP-1")]), null)
// both AOCs gone, focus on DP-10: that window wins
assert.strictEqual(fn([ws(1, "eDP-1"), ws(6, "DP-9", { active_window_id: 4 }), ws(15, "DP-10", { is_focused: true, active_window_id: 9 })], [ws(1, "eDP-1")]), 9)
// lost screen showed an empty workspace, or nothing lost (start-up, replug)
assert.strictEqual(fn([ws(6, "DP-9", { is_focused: true })], [ws(1, "eDP-1")]), null)
assert.strictEqual(fn([], [ws(1, "eDP-1")]), null)
console.log("bring-back: ok")
