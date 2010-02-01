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
  var query = location.search.substring(1);
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
  var query = location.search.substring(1);
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

function setExpansionStateCB(expanded, panel, chkbox) {
  if (expanded) {
    if (panel) panel.style.display = 'inline';
    if (chkbox) chkbox.checked = true;
  } else {
    if (panel) panel.style.display = 'none';
    if (chkbox) chkbox.checked = false;
  }
}

function setExpansionStateB(expanded, panel, button) {
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
  var elem = document.menuform.db;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      elem.options[ii].selected = false;
    }
  }
}

function clearPeriodSelection() {
  var elem = document.menuform.period;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      elem.options[ii].selected = false;
    }
  }
}

// Construct a CGI query based on current state.  We start with the existing
// URL then modify it based on the current state.
//
// Why not just use CGI, you ask?  We need this since we maintain the GUI
// state, e.g. expanded/collapsed state of time periods and controls.
function mkCGIArgs() {
  var args = new Array();

  var elem = document.menuform.servidors;
  if (elem) {
    var host = elem.options[elem.selectedIndex].text;
    if (host && host != '' && host != '-') {
      args.push('host=' + escape(host));
    }
  }
  elem = document.menuform.services;
  if (elem) {
    service = elem.options[elem.selectedIndex].text;
    if (service && service != '' && service != '-') {
       args.push('service=' + escape(service));
    }
  }
  elem = document.menuform.groups;
  if (elem) {
    group = elem.options[elem.selectedIndex].text;
    if (group && group != '' && group != '-') {
       args.push('group=' + escape(group));
    }
  }
  elem = document.menuform.db;
  if (elem) {
    for (var ii=0; ii<elem.length; ii++) {
      if (elem.options[ii].selected) {
        args.push('db=' + escape(elem.options[ii].text));
      }
    }
  }

  var geom = '';
  elem = document.menuform.geom;
  if (elem) {
    for (var ii = 0; ii < elem.length; ii++) {
      if (elem.options[ii].selected) {
        if (elem.options[ii].text == 'default') {
          geom = 'default';
        } else {
          geom = 'geom=' + escape(elem.options[ii].text);
        }
        break;
      }
    }
  }

  elem = document.menuform.fixedscale;
  if (elem && elem.checked) {
    args.push('fixedscale');
  }

  elem = document.menuform.showhidecontrols;
  if (elem && elem.checked) {
    args.push('expand_controls');
  }

  elem = document.menuform.period;
  if (elem) {
    var str = '';
    for (var ii = 0; ii < elem.length; ii++) {
      if (elem.options[ii].selected) {
        if (str != '') str += ',';
        str += elem.options[ii].text;
      }
    }
    if (str != '') {
      args.push('period=' + str);
    }
  }

  // an empty string for expand_period means they are all collapsed.
  // no expand_period variable means use the defaults/config.
  var ep = '';
  for (var ii = 0; ii < PNAME.length; ii++) {
    elem = document.getElementById('period_data_' + PNAME[ii]);
    if (elem && elem.style.display == 'inline') {
      if (ep != '') ep += ',';
      ep += PNAME[ii];
    }
  }
  args.push('expand_period=' + ep);

  // remove parameters from previous query string
  var oldq = location.search.substring(1);
  var params = oldq.split("&");
  for (var ii=0; ii<params.length; ii++) {
    var name = '';
    var value = '';
    var pos = params[ii].indexOf("=");
    if (pos >= 0) {
      name = params[ii].substring(0, pos);
      value = params[ii].substring(pos+1);
    } else {
      name = params[ii];
    }
    if (name == 'host'
        || name == 'service'
        || name == 'group'
        || name == 'db'
        || name == 'fixedscale'
        || name == 'expand_controls'
        || name == 'period'
        || name == 'expand_period') {
      // skip it
    } else if (name == 'geom') {
      if (geom == '' && value != '' && value != 'default') {
        geom = params[ii];
      }
    } else {
      args.push(params[ii]);
    }
  }

  if (geom != '' && geom != 'default') {
    args.push(geom);
  }

  var newq = '';
  for (var ii=0; ii<args.length; ii++) {
    if (args[ii] != '') {
      if (newq != '') newq += '&';
      newq += args[ii];
    }
  }
  return newq;
}

// Populate menus and make the GUI state match the CGI query string.
// This should be invoked at the bottom of a web page, after all of the DOM
// elements have been instantiated.
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
  selectDBItems(location.search.substring(1));
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
  var menu = document.menuform.services;
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
  var menu = document.menuform.db;
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
  elem = document.menuform.period;
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
  elem = document.menuform.db;
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
  elem = document.menuform.db;
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
// not, then collapse them.  make the other gui controls match the state as
// well.
function setControlsGUIState() {
  setExpansionStateCB(getCGIBoolean('expand_controls'),
                      document.getElementById('secondary_controls_box'),
                      document.menuform.showhidecontrols);
  var elem = document.menuform.fixedscale;
  if (elem) {
    elem.checked = getCGIBoolean('fixedscale');
  }
  elem = document.menuform.geom;
  if (elem) {
    var geom = getCGIValue('geom');
    for (var ii=0; ii<elem.length; ii++) {
      if (elem.options[ii].text == geom) {
        elem.options[ii].selected = true;
        break;
      }
    }
  }
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
    setExpansionStateB(pflag[ii],
                       document.getElementById('period_data_' + PNAME[ii]),
                       document.getElementById('toggle_' + PNAME[ii]));
  }
}

// reload the page with CGI arguments constructed from current state.
function jumpto() {
  var qstr = mkCGIArgs();
  location.assign(location.pathname + "?" + qstr);
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
