// node test.js — interface language and translations.
const assert = require("assert")
const fs = require("fs")
const isrc = fs.readFileSync(__dirname + "/I18n.js", "utf8").replace(".pragma library", "")
const I = new Function(isrc + "; return { TABLES, textLanguage, translator }")()
const envOf = o => n => o[n]
assert.strictEqual(I.textLanguage(envOf({ LANG: "en_US.UTF-8" })), "en")
assert.strictEqual(I.textLanguage(envOf({ LANG: "en_US.UTF-8", LC_MESSAGES: "ru_RU.UTF-8" })), "ru")
assert.strictEqual(I.textLanguage(envOf({ LC_ALL: "de_DE.UTF-8", LC_MESSAGES: "ru_RU.UTF-8" })), "en")
assert.strictEqual(I.textLanguage(envOf({})), "en")
assert.strictEqual(I.translator("ru")("How many entries to keep (1–%1) · Enter saves", 300), "Сколько записей хранить (1–300) · Enter — сохранить")
assert.strictEqual(I.translator("en")("Search"), "Search")
// Every tr("…") in the QML has a Russian line, and no Cyrillic is left outside tr().
const qml = fs.readFileSync(__dirname + "/Panel.qml", "utf8")
const keys = [...qml.matchAll(/\btr\("((?:[^"\\]|\\.)*)"/g)].map(m => m[1])
assert.ok(keys.length >= 9, "found " + keys.length + " tr() calls")
assert.deepStrictEqual(keys.filter(k => !(k in I.TABLES.ru)), [])
assert.deepStrictEqual(qml.split("\n").filter(l => /[А-Яа-яЁё]/.test(l)), [])
console.log("ok")
