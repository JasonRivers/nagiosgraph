// nagiosgraph javascript bits and pieces
//
// $Id$
// License: OSI Artistic License
//          http://www.opensource.org/licenses/artistic-license-2.0.php
// Author:  (c) 2005 Soren Dossing
// Author:  (c) 2008 Alan Brenner, Ithaka Harbors
// Author:  (c) 2010 Matthew Wall

var PNAME = [ 'day', 'week', 'month', 'quarter', 'year' ];

// return the value (if any) for the indicated CGI key.  if we find the arg
// but it has no value, return empty string.  if no arg, then return undefined.
function getCGIValue(key) {
  var rval;
  var query = this.location.search.substring(1);
  if (query && query.length) {
    var params = query.split("&");
    for (var ii = 0; ii < params.length ; ii++) {
      var pos = params[ii].indexOf("=");
      if (params[ii].substring(0, pos) == key) {
        rval = unescape(params[ii].substring(pos+1));
        break;
      }
    }
  }
  return rval;
}

// return true if the key shows up as a CGI argument.
function getCGIBoolean(key) {
  var query = this.location.search.substring(1);
  if (query && query.length > 0) {
    var params = query.split("&");
    for (var ii = 0; ii < params.length ; ii++) {
      if (params[ii] == key) {
        return true;
      }
    }
  }
  return false;
}

function setDisplay(elem, state) {
  if (elem) {
    if (state) {
      elem.style.display = 'inline';
    } else {
      elem.style.display = 'none';
    }
  }
}

function toggleDisplay(elem) {
  if (elem) {
    if (elem.style.display == 'none') {
      elem.style.display = 'inline';
    } else {
      elem.style.display = 'none';
    }
  }
}

function setCheckBoxGUIState(expanded, panel, chkbox) {
  if (expanded) {
    if (panel) panel.style.display = 'inline';
    if (chkbox) chkbox.checked = true;
  } else {
    if (panel) panel.style.display = 'none';
    if (chkbox) chkbox.checked = false;
  }
}

function setButtonGUIState(expanded, panel, button) {
  if (expanded) {
    if (panel) panel.style.display = 'inline';
    if (button) button.value = '-';
  } else {
    if (panel) panel.style.display = 'none';
    if (button) button.value = '+';
  }
}

// FIXME: this does not work.  i tried making a table row have this id, and
// that resulted in messed up table layout.  so i wrapped the row in a div.
// now the layout is ok, but the visibility changes do not work.  sigh.
function showDBControls(flag) {
  setDisplay(document.getElementById('db_controls'), flag);
}

// show/hide the secondary controls panel
function toggleControlsDisplay() {
  toggleDisplay(document.getElementById('secondary_controls_box'));
}

// toggle display of the indicated period
function togglePeriodDisplay(period, button) {
  var elem = document.getElementById(period);
  toggleDisplay(elem);
  if (elem.style.display == 'inline') {
    button.value = '-';
  } else {
    button.value = '+';
  }
}

function clearDBSelection() {
  var elem = window.document.menuform.db;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      elem.options[ii].selected = false;
    }
  }
}

function clearPeriodSelection() {
  var elem = window.document.menuform.period;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      elem.options[ii].selected = false;
    }
  }
}

// Construct a CGI query based on current state.
// FIXME: do we need this?  why not regular CGI?
function mkCGIArgs() {
  var host;
  var service;
  var db = new Array();

  var elem = window.document.menuform.servidors;
  if (elem) {
    host = escape(elem.options[elem.selectedIndex].text);
  }
  elem = window.document.menuform.services;
  if (elem) {
    service = escape(elem.options[elem.selectedIndex].text);
  }
  elem = window.document.menuform.db;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      if (elem.options[ii].selected)
        db.push(escape(elem.options[ii].text));
    }
  }

  var qstr = '';
  if (host && host != '' && host != '-') {
    if (qstr != '') qstr += "&";
    qstr += "host=" + host;
  }
  if (service && service != '' && service != '-') {
    if (qstr != '') qstr += "&";
    qstr += "service=" + service;
  }
  var source, entry;
  for (var ii = 0; ii < db.length; ii++) {
    entry = db[ii].split(',');
    if (entry[0] == source) {
      qstr += "," + entry[1];
    } else {
      qstr += "&db=" + db[ii];
      source = entry[0];
    }
  }
  var havegeom = false;
  elem = window.document.menuform.geom;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      if (elem.options[ii].selected) {
        qstr += "&geom=" + elem.options[ii].text;
        havegeom = true;
      }
    }
  }
  var havetime = false;
  elem = window.document.menuform.period;
  if (elem) {
    var str = "";
    for (var ii = 0; ii < elem.length; ii++) {
      if (elem.options[ii].selected) {
        if (str != "") str += ",";
        str += elem.options[ii].text;
        havetime = true;
      }
    }
    if (str != "") {
      qstr += "&period=" + str;
    }
  }
  var oldqstr = this.location.search.substring(1);
  if (oldqstr.length > 0) {
    var params = oldqstr.split("&");
    for (var ii = 0; ii < params.length ; ii++) {
      var name = params[ii].substring(0, params[ii].indexOf("="));
      //Append "safe" params (geom, rrdopts)
      if (name == "rrdopts") {
        qstr += "&" + params[ii];
      } else if (name == "geom" && havegeom == false) {
        qstr += "&" + params[ii];
      } else if (name == "period" && havetime == false) {
        qstr += "&" + params[ii];
      }
    }
  }
  if (document.menuform.FixedScale.checked) {
    qstr += "&fixedscale";
  }
  if (document.menuform.showhidecontrols.checked) {
    qstr += "&expand_controls";
  }

  // no expanded periods means they are all collapsed
  var ep = '';
  for (var ii = 0; ii < PNAME.length; ii++) {
    elem = document.getElementById('period_data_' + PNAME[ii]);
    if (elem && elem.style.display == 'inline') {
      if (ep != '') ep += ',';
      ep += PNAME[ii];
    }
  }
  qstr += "&expand_period=" + ep;

  return qstr;
}

// Populate menus and make the GUI state match the CGI query string.
// This should be invoked at the bottom of a web page, after all of the DOM
// elements have been instantiated.
//
// expanded_controls is a boolean that indicates the default expanded/collapsed
// controls state.  this is overridden by any CGI arguments.
//
// expanded_periods is a comma-separate list of periods that indicates the
// periods that should be expanded.  these are overridden by any CGI arguments.
//
// if nothing specified, see if there is anything in the CGI query string.
function cfgMenus(host, service, expanded_periods) {
  cfgHostMenu(host);
  cfgServiceMenu(host, service);
  cfgDBMenu(host, service);

  setControlsGUIState();
  setPeriodGUIStates(expanded_periods);
  selectPeriodItems();
  selectDBItems(this.location.search.substring(1));
}

// Populate the host menu and select the indicated host.
function cfgHostMenu(host) {
  var menu = document.menuform.servidors;
  if(!menu) return;

  menu.length = menudata.length+1;
  menu.options[0].text = '-';
  for (var ii=0; ii<menudata.length; ii++) {
    menu.options[ii+1].text = menudata[ii][0];
    if (menudata[ii][0] == host) {
      menu.options[ii+1].selected = true;
    }
  }
}

//Converts -, etc in input to _ for matching array name
function findName(entry) {
  for (var ii = 0; ii < menudata.length; ii++) {
    if (menudata[ii][0] == entry) {
      return ii;
    }
  }
  throw entry + " not found in the configured hosts and services"
}

// Populate the service menu and select the indicated service.
// If a host is specified, then use only the services for that host.
// If no host is specified, then loop through all of the menudata and create
// a list of all the services that we encounter.
// FIXME: this is inefficient and will suck on large number of hosts/services
function cfgServiceMenu(host, service) {
  var menu = window.document.menuform.services;
  if (!menu) return;

  var items = new Array();

  if (typeof(host) != 'undefined' && host != '') {
    var opts;
    for (var ii=0; ii<menudata.length; ii++) {
      if (menudata[ii][0] == host) {
        opts = menudata[ii];
        break;
      }
    }
    if (opts) {
      items.length = opts.length - 1;
      for (var ii=1; ii<opts.length; ii++) {
        items[ii-1] = opts[ii][0];
      }
    }
  } else {
    var n = 0;
    for (var ii = 0; ii < menudata.length; ii++) {
      var opts = menudata[ii];
      for (var jj = 1; jj < opts.length; jj++) {
        var data = opts[jj];
        var found = 0;
        for (var kk = 0; kk < items.length; kk++) {
          if (items[kk] == data[0]) {
            found = 1;
          }
        }
        if (!found) {
          items[n] = data[0]
          n++;
        }
      }
    }
  }

  menu.length = items.length + 1;
  menu.options[0].text = '-';
  for (var ii = 0; ii < items.length; ii++) {
    menu.options[ii+1].text = items[ii];
    if (items[ii] == service) {
      menu.options[ii+1].selected = true;
    }
  }
}

// Once a service is selected this function updates the list of corrsponding
// data sets.  First try using whatever host is selected.  If there is no
// selected host, just use the first matching service we find.
function cfgDBMenu(host, service) {
  var menu = window.document.menuform.db;
  if (!menu) return;

  var opts;
  if (typeof(host) != 'undefined' && host != '') {
    for (var ii=0; ii<menudata.length; ii++) {
      if (menudata[ii][0] == host) {
        opts = menudata[ii];
        break;
      }
    }
  } else if (typeof(service) != 'undefined' && service != '') {
    for (var ii = 0; ii < menudata.length; ii++) {
      for (var jj = 0; jj < menudata[ii].length; jj++) {
        if (menudata[ii][jj][0] == service) {
          opts = menudata[ii];
          break;
        }
      }
    }
  }

  menu.length = 0;
  if (opts) {
    var count = 0;
    for (var ii = 1; ii < opts.length; ii++) {
      if (opts[ii][0] == service) {
        for (var jj = 1; jj < opts[ii].length; jj++) {
          for (var kk = 1; kk < opts[ii][jj].length; kk++) {
            count++;
          }
        }
        break;
      }
    }
    menu.length = count;
    count = 0;
    for (var ii = 1; ii < opts.length; ii++) {
      if (opts[ii][0] == service) {
        for (var jj = 1; jj < opts[ii].length; jj++) {
          for (var kk = 1; kk < opts[ii][jj].length; kk++) {
            menu.options[count].text = opts[ii][jj][0] +','+ opts[ii][jj][kk];
            count++;
          }
        }
        break;
      }
    }
  }

  if (menu.length <= 1) {
    showDBControls(false);
  } else {
    menu.size = 5;
    showDBControls(true);
  }
}

// highlight the period menu items based on the elements in the page.
function selectPeriodItems() {
  elem = window.document.menuform.period;
  if(!elem) return;

  var pstr = '';
  for (var ii=0; ii<PNAME.length; ii++) {
    var x = document.getElementById('period_data_' + PNAME[ii]);
    if (x) {
      if (pstr != '') pstr += ',';
      pstr += PNAME[ii];
    }
  }

  var items = pstr.split(',');
  for (jj=0; jj<items.length; jj++) {
    for (kk=0; kk<elem.length; kk++) {
      if (items[jj] == elem.options[kk].value) {
        elem.options[kk].selected = true;
        break;
      }
    }
  }
}

// highlight the db menu items based on the url query string.
// specifying nothing is equivalent to selecting all.
function selectDBItems(query) {
  elem = window.document.menuform.db;
  if(!elem) return;

  var found = false;
  if (query && query.length) {
    var params = query.split("&");
    for (var ii = 0; ii < params.length ; ii++) {
      var pos = params[ii].indexOf("=");
      if (params[ii].substring(0, pos) == 'db') {
        var value = unescape(params[ii].substring(pos+1));
        var items = value.split(',');
        for (var jj = 1; jj < items.length; jj++) {
          for (var kk = 0; kk < elem.length; kk++) {
            if (items[0] + ',' + items[jj] == elem.options[kk].value) {
              elem.options[kk].selected = true;
              found = true;
              break;
            }
          }
        }
      }
    }
  }

  if (! found) {
    for (var kk=0; kk<elem.length; kk++) {
      elem.options[kk].selected = true;
    }
  }

  if (elem.length == 1) {
    showDBControls(false);
  } else {
    showDBControls(true);
  }
}

// returns a string with the selected data sets.  string is in CGI format.
function getSelectedDBItems() {
  elem = window.document.menuform.db;
  if(!elem) return '';

  var rval = '';
  for (var kk=0; kk<elem.length; kk++) {
    if (elem.options[kk].selected == true) {
      if (rval != '') rval += '&';
      rval += 'db=' + escape(elem.options[kk].value);
    }
  }
  return rval;
}

// see if there is a cgi argument to expand the controls.  if so, do it.  if
// not, then collapse them.  make the gui match the state.
function setControlsGUIState() {
  setCheckBoxGUIState(getCGIBoolean('expand_controls'),
                      document.getElementById('secondary_controls_box'),
                      document.menuform.showhidecontrols);
}

// if there is a cgi argument to expand time periods, then respect it.  an
// empty argument means collapse all of them.  if there is no argument, then
// fall back to the preferences (whatever was passed to us as an argument).
function setPeriodGUIStates(expanded_periods) {
  var pstr = getCGIValue('expand_period');
  if (typeof(pstr) == 'undefined') {
    pstr = expanded_periods;
  }
  var pflag = [ 0, 0, 0, 0, 0 ];
  if (typeof(pstr) != 'undefined' && pstr != '') {
     var periods = pstr.split(",");    
     for (var ii = 0; ii < periods.length; ii++) {
       for (var jj = 0; jj < PNAME.length; jj++) {
         if (periods[ii] == PNAME[jj]) {
           pflag[jj] = 1;
         }
       }
     }
  }
  for (var ii = 0; ii < pflag.length; ii++) {
    setButtonGUIState(pflag[ii],
                      document.getElementById('period_data_' + PNAME[ii]),
                      document.getElementById('toggle_' + PNAME[ii]));
  }
}

// reload the page with CGI arguments constructed from current state.
function jumpto() {
  var qstr = mkCGIArgs();
  window.location.assign(location.pathname + "?" + qstr);
}

// configure everything based on a change to the selected host.  a change
// to the host requires that the service menu be reconstructed to match the
// services of the selected host.
function hostChange() {
  var host = '';
  var service = '';
  var dbitems = getSelectedDBItems();

  var hostmenu = document.menuform.servidors;
  if (hostmenu) {
    host = hostmenu.options[hostmenu.selectedIndex].text;
  }
  var servmenu = document.menuform.services;
  if (servmenu) {
    service = servmenu.options[servmenu.selectedIndex].text;
  }
  cfgServiceMenu(host, service);

  // service selection may have changed, so get the new one
  if (servmenu) {
    service = servmenu.options[servmenu.selectedIndex].text;
  }
  cfgDBMenu(host, service);
  selectDBItems(dbitems);
}

// configure everything based on a change to the selected service.  a change
// to the service requires that the db menu be reconstructed to match the
// data sets of the selected service.
function serviceChange() {
  var host = '';
  var service = '';
  var dbitems = getSelectedDBItems();

  var hostmenu = document.menuform.servidors;
  if (hostmenu) {
    host = hostmenu.options[hostmenu.selectedIndex].text;
  }
  var servmenu = document.menuform.services;
  if (servmenu) {
    service = servmenu.options[servmenu.selectedIndex].text;
  }

  cfgDBMenu(host, service);
  selectDBItems(dbitems);
}
