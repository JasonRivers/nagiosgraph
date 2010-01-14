function setDBControlsVisibility(state) {
    elem = document.getElementById('db_controls')
    if (state == 'visible') {
        elem.style.display = "inline";
    } else {
        elem.style.display = "none";
    }
}

// show/hide the secondary controls panel
function toggleControlsDisplay() {
    var elem = document.getElementById('secondary_controls_box')
    if (elem.style.display == 'none') {
        elem.style.display = "inline";
    } else {
        elem.style.display = "none";
    }
}

function setControlsGUIState() {
    var elem = document.getElementById('secondary_controls_box')
    if (elem.style.display == 'none') {
        document.menuform.showhidecontrols.checked = false;
    } else {
        document.menuform.showhidecontrols.checked = true;
    }
}

//Converts -, etc in input to _ for matching array name
function findName(entry) {
    for (var ii = 0; ii < menudata.length; ii++) {
        if (menudata[ii][0] == entry) {
            return ii;
        }
    }
    throw entry + " not found in the configured systems"
}

//Swaps the secondary (services) menu content after a server is selected
function setService(element, service) {
    var opts;
    try {
        opts = menudata[findName(element.options[element.selectedIndex].text)];
    }
    catch (e) {
        alert(e);
        return;
    }
    var elem = window.document.menuform.services;
    if (typeof(service) == 'undefined') {
        var query = this.location.search.substring(1);
        if (query.length > 0) {
            var params = query.split("&");
            for (var ii = 0; ii < params.length ; ii++) {
                var pos = params[ii].indexOf("=");
                var name = params[ii].substring(0, pos);
                if (name == "service") {
                    service = params[ii].substring(pos + 1);
                    break;
                }
            }
        }
    }
    elem.length = opts.length - 1;
    for (var ii = 1; ii < opts.length; ii++) {
        elem.options[ii - 1].text = opts[ii][0];
        if (opts[ii][0] == service)
            elem.options[ii - 1].selected = true;
    }
    setDB(window.document.menuform.services, 1);
}

// Once a service is selected this function updates the database list
// first try using whatever host is selected.    if there is no selected host,
// just use the first service we find.
function setDB(element) {
    var service = element.options[element.selectedIndex].text;
    var opts;
    var hosts = window.document.menuform.servidors;
    if (hosts) {
        try {
            opts = menudata[window.document.menuform.servidors.selectedIndex];
        } catch (e) {
            alert(e);
            return;
        }
    } else {
        for (var ii = 0; ii < menudata.length; ii++) {
            for (var jj = 0; jj < menudata[ii].length; jj++) {
                if (menudata[ii][jj][0] == service) {
                    opts = menudata[ii];
                    break;
                }
            }
        }
    }
    var count = 0
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
    var elem = window.document.menuform.db;
    elem.length = count;
    count = 0;
    for (var ii = 1; ii < opts.length; ii++) {
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
        setDBControlsVisibility('hidden');
        if (arguments.length == 1)
            jumpto();
    } else {
        if (elem.length > 5) {
            elem.size = 5;
        } else {
            elem.size = elem.length;
        }
        setDBControlsVisibility('visible');
    }
}

function clearDBMenuItems() {
    var elem = window.document.menuform.db;
    if (elem) {
        for (var ii = 0; ii < elem.length; ii++) {
            elem.options[ii].selected = false;
        }
    }
}

function clearPeriodItems() {
    var elem = window.document.menuform.period;
    if (elem) {
        for (var ii = 0; ii < elem.length; ii++) {
            elem.options[ii].selected = false;
        }
    }
}

//Once a line is selected this function loads the new page
function jumpto() {
    var db = new Array();
    var server;
    var service;
    var elem = window.document.menuform.servidors;
    if (elem) {
        server = escape(elem.options[elem.selectedIndex].text);
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
    var qstr = "";
    if (server) {
        if (qstr.length > 0)
            qstr += "&";
        qstr += "host=" + server;
    }
    if (service) {
        if (qstr.length > 0)
            qstr += "&";
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
        for (var ii = 0; ii < elem.length; ii++) {
            if (elem.options[ii].selected) {
                qstr += "&period=" + elem.options[ii].text;
                havetime = true;
            }
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
    if (document.menuform.FixedScale.checked)
                qstr += "&fixedscale";
        var newURL = location.pathname + "?" + qstr;
    window.location.assign(newURL);
}

// function to change host/service
function jumptohost(element) {
    var item = escape(document.menuform.servidors.value);
    window.location.assign(location.pathname + "?host=" + item);
}

function jumptoservice(element) {
    var item = escape(document.menuform.services.value);
    window.location.assign(location.pathname + "?service=" + item);
}

// Fill the host and service menus with the correct entries
function preloadMenus(server, service) {
    setControlsGUIState();
    var ii, jj, kk, pos, items;
    var elem = document.menuform.servidors;
    if (elem) {
        elem.length = menudata.length;
        for (ii = 0; ii < menudata.length; ii++) {
            elem.options[ii].text = menudata[ii][0];
            if (menudata[ii][0] == server) elem.options[ii].selected = true;
        }
        setService(elem, service);
        clearDBMenuItems();
    }
    setDBMenuItems();
}

// Fill the service menu with the correct entries
// loop through all of the menudata and create a list of all the services
// that we encounter.
// FIXME: this is inefficient and will suck on large number of services
function preloadServiceMenu(service) {
    setControlsGUIState();
    var n = 0;
    var items = new Array();
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
    var elem = window.document.menuform.services;
    elem.length = items.length;
    for (var ii = 0; ii < items.length; ii++) {
        elem.options[ii].text = items[ii];
        if (items[ii] == service) {
            elem.options[ii].selected = true;
        }
    }
    setDB(window.document.menuform.services, 1);
    clearDBMenuItems();
    setDBMenuItems();
}

// highlight the db menu items based on the url query string
function setDBMenuItems() {
    elem = window.document.menuform.db;
        if (elem) {
                var params = this.location.search.substring(1).split("&");
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
                        setDBControlsVisibility('hidden');
                } else {
                        setDBControlsVisibility('visible');
                }
        }
}

//Resize the graphs, developed from ironwolve's patch
function setresize(size) {
    button = document.getElementById(size);
    if (window.location.href.indexOf('geom') > -1) {
        window.location.href = window.location.href.replace(/geom=[^&]+/, 'geom=' + button.value);
    } else {
        window.location.href += '&geom=' + button.value;
    }
}
