function clearitems() {
  var elem = window.document.menuform.db;
  for (var ii = 0; ii < elem.length; ii++) {
    elem.options[ii].selected = false;
  }
}
function setvis(state) {
  elem = document.getElementById('subnav')
  if (state == 'visible') {
    elem.style.display = "inline"; 
  } else {
    elem.style.display = "none";
  }
}
//Converts -, etc in input to _ for matching array name
function fixName(entry) {
  entry = entry.replace(/-/g,"_").replace(/\\./g,"_");
  if (entry.match("^[0-9]"))
    entry = "_" + entry;
  return entry;
}
//Swaps the secondary (services) menu content after a server is selected
function setService(element, service) {
  var opts = menudata[fixName(element.options[element.selectedIndex].text)];
  var elem = window.document.menuform.services;
  if (typeof(service) == 'undefined') {
    var query = this.location.search.substring(1);
    if (query.length > 0) {
      var params = query.split("&");
      for (var ii = 0; ii < params.length ; ii++) {
        var pos = params[ii].indexOf("=");
        var name = params[ii].substring(0, pos);
        //Append "safe" params (geom, rrdopts)
        if (name == "service") {
          service = params[ii].substring(pos + 1);
          break;
        }
      }
    }
  }
  elem.length = opts.length;
  for (var ii = 0; ii < opts.length; ii++) {
    elem.options[ii].text = opts[ii][0];
    if (opts[ii][0] == service)
      elem.options[ii].selected = true;
  }
  setDb(window.document.menuform.services, 1);
}
//Once a service is selected this function updates the lines list
function setDb(element) {
  var opts = menudata[fixName(window.document.menuform.servidors.value)];
  var elem = window.document.menuform.db;
  var service = element.options[element.selectedIndex].text;
  var count = 0
  for (var ii = 0; ii < opts.length; ii++) {
    if (opts[ii][0] == service) {
      for (var jj = 1; jj < opts[ii].length; jj++) {
        for (var kk = 1; kk < opts[ii][jj].length; kk++) {
          count++;
        }
      }
      break;
    }
  }
  elem.length = count;
  count = 0;
  for (var ii = 0; ii < opts.length; ii++) {
    if (opts[ii][0] == service) {
      for (var jj = 1; jj < opts[ii].length; jj++) {
        for (var kk = 1; kk < opts[ii][jj].length; kk++) {
          elem.options[count].text = opts[ii][jj][0] + ',' + opts[ii][jj][kk];
          count++;
        }
      }
      break;
    }
  }
  if (elem.length == 1) {
    setvis('hidden');
    if (arguments.length == 1)
      jumpto();
  } else {
    if (elem.length > 5) {
      elem.size = 5;
    } else {
      elem.size = elem.length;
    }
    setvis('visible');
  }
}
//Once a line is selected this function loads the new page
function jumpto() {
  var elem = window.document.menuform.servidors;
  var server = escape(elem.options[elem.selectedIndex].text);
  elem = window.document.menuform.services;
  var service = escape(elem.options[elem.selectedIndex].text);
  elem = window.document.menuform.db;
  var db = new Array();
  for (var ii = 0; ii < elem.length; ii++) {
    if (elem.options[ii].selected)
      db.push(escape(elem.options[ii].text));
  }
  var newURL = location.pathname + "?host=" + server + "&service=" + service;
  if (db) {
    var source, entry;
    for (var ii = 0; ii < db.length; ii++) {
      entry = db[ii].split(',');
      if (entry[0] == source) {
        newURL += "," + entry[1];
      } else {
        newURL += "&db=" + db[ii];
        source = entry[0];
      }
    }
  }
  var query = this.location.search.substring(1);
  if (query.length > 0) {
    var params = query.split("&");
    for (var ii = 0; ii < params.length ; ii++) {
      var name = params[ii].substring(0, params[ii].indexOf("="));
      //Append "safe" params (geom, rrdopts)
      if (name == "geom" || name == "rrdopts")
        newURL += "&" + params[ii];
    }
  }
  if (document.menuform.FixedScale.checked)
    newURL += "&" + "fixedscale";
  window.location.assign(newURL);
}
//Forces the service menu to be filled with the correct entries at page load
function preloadSVC(server, service) {
  var elem = document.menuform.servidors;
  var params = this.location.search.substring(1).split("&");
  var ii, jj, kk, pos, items;
  pos = 0;
  for (ii in menudata) {
    pos++;
  }
  elem.length = pos;
  pos = 0;
  for (ii in menudata) {
    elem.options[pos].text = ii;
    if (ii == server)
      elem.options[pos].selected = true;
    pos++;
  }
  setService(elem, service);
  clearitems();
  elem = window.document.menuform.db;
  for (ii = 0; ii < params.length ; ii++) {
    pos = params[ii].indexOf("=");
    if (params[ii].substring(0, pos) == "db") {
      items = unescape(params[ii].substring(pos + 1)).split(',');
      for (jj = 1; jj < items.length; jj++) {
        for (kk = 0; kk < elem.length; kk++) {
          if (items[0] + ',' + items[jj] == elem.options[kk].value) { 
            elem.options[kk].selected = true;
            break;
          }
        }
      }
    }
  }
  if (elem.length == 1) {
    setvis('hidden');
  } else {
    setvis('visible');
  }
}