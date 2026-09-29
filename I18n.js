.pragma library
// Interface text in other languages, keyed by the English text itself, so a
// string missing from a table shows in English. tr("… %1", x) fills in %1, %2…
// after the lookup. The same scheme as predmaxim.jira and predmaxim.datebook.
var TABLES = {
  ru: {
    "Clipboard": "Буфер обмена", "Entries": "Записей",
    "How many to keep": "Сколько хранить",
    "How many entries to keep (1–%1) · Enter saves": "Сколько записей хранить (1–%1) · Enter — сохранить",
    "Search": "Поиск", "Nothing found": "Ничего не найдено",
    "Files": "Файлы", "Image": "Изображение", "Delete": "Удалить"
  }
}

// Text follows LC_MESSAGES, overridden by LC_ALL and defaulting to LANG, as
// the system splits it. env is name -> value (Quickshell.env in QML).
function textLanguage(env) {
  var names = ["LC_ALL", "LC_MESSAGES", "LANG"]
  for (var i = 0; i < names.length; i++) {
    var v = String(env(names[i]) || "").split(".")[0].split("@")[0]
    if (v && v !== "C" && v !== "POSIX") {
      var l = v.slice(0, 2).toLowerCase()
      return TABLES[l] ? l : "en"
    }
  }
  return "en"
}

function translator(lang) {
  var table = TABLES[lang] || {}
  return function(text) {
    var out = Object.prototype.hasOwnProperty.call(table, text) ? table[text] : text
    for (var i = 1; i < arguments.length; i++) out = out.split("%" + i).join(String(arguments[i]))
    return out
  }
}
