// Pure data helpers for the Reminders panel

function safeTrim(value) {
  return String(value === undefined || value === null ? "" : value).trim()
}

function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 7)
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function formatTime(date) {
  var d = new Date(date)
  if (isNaN(d.getTime())) return ""
  var hours = d.getHours()
  var minutes = pad2(d.getMinutes())
  var ampm = hours >= 12 ? "PM" : "AM"
  hours = hours % 12
  hours = hours ? hours : 12
  return hours + ":" + minutes + " " + ampm
}

function formatRelativeDate(timestamp) {
  if (!timestamp) return ""
  var d = new Date(timestamp)
  if (isNaN(d.getTime())) return ""

  var now = new Date()
  var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var targetDay = new Date(d.getFullYear(), d.getMonth(), d.getDate())

  var diffDays = Math.round((today - targetDay) / (1000 * 60 * 60 * 24))
  var timeStr = formatTime(d)

  if (diffDays === 0) {
    return "Today at " + timeStr
  } else if (diffDays === 1) {
    return "Yesterday at " + timeStr
  } else if (diffDays === -1) {
    return "Tomorrow at " + timeStr
  } else {
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return months[d.getMonth()] + " " + d.getDate() + " at " + timeStr
  }
}

function countPending(list) {
  if (!Array.isArray(list)) return 0
  var count = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i] && !list[i].completed) {
      count++
    }
  }
  return count
}

function countCompleted(list) {
  if (!Array.isArray(list)) return 0
  var count = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].completed) {
      count++
    }
  }
  return count
}

function filterReminders(list, filter) {
  if (!Array.isArray(list)) return []
  var items = list.filter(function(item) {
    return item && typeof item === "object" && typeof item.title === "string"
  })

  if (filter === "active") {
    return items.filter(function(item) { return !item.completed })
  }
  if (filter === "completed") {
    return items.filter(function(item) { return item.completed === true })
  }
  if (filter === "today") {
    var now = new Date()
    var todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    var todayEnd = todayStart + 24 * 60 * 60 * 1000
    return items.filter(function(item) {
      var t = item.createdAt || 0
      return t >= todayStart && t < todayEnd
    })
  }

  // "all" filter
  return items.sort(function(a, b) {
    var aDone = a && a.completed ? 1 : 0
    var bDone = b && b.completed ? 1 : 0
    if (aDone !== bDone) return aDone - bDone
    var aTime = (a && a.createdAt) ? a.createdAt : 0
    var bTime = (b && b.createdAt) ? b.createdAt : 0
    return bTime - aTime
  })
}

function parseRemindersJson(jsonText) {
  if (!jsonText || String(jsonText).trim() === "") return []
  try {
    var data = JSON.parse(jsonText)
    if (Array.isArray(data)) return data
    if (data && Array.isArray(data.reminders)) return data.reminders
    return []
  } catch (e) {
    return []
  }
}
