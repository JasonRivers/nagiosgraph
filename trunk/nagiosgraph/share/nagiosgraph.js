// nagiosgraph javascript bits and pieces
//
// $Id$
// License: OSI Artistic License
//          http://www.opensource.org/licenses/artistic-license-2.0.php
// Author:  (c) 2005 Soren Dossing
// Author:  (c) 2008 Alan Brenner, Ithaka Harbors
// Author:  (c) 2010 Matthew Wall

var PNAME = [ 'day', 'week', 'month', 'quarter', 'year' ];
var VERSION = 1.6;

// dead simple i18n
// based on http://24ways.org/2007/javascript-internationalisation
function _(s) {
  if (typeof(i18n) != 'undefined' && i18n[s]) {
    return i18n[s];
  }
  return s;
}

// do in-place graph zooming
var ngzMouse;
var ngzZoom;
var ngzZoomBox;
var ngzZoomInfo;
var ngzZoomPanel;
var ngzGraphImg = null;
var ngzZoomID = 'ngzZoom';
var ngzZoomInCursor = 'crosshair';

function ngzInit(elem) {
  ngzGraphImg = elem;
  var orig = ngzGraphImg.getAttribute('srcorig');
  if(orig == null || orig == '') {
    ngzGraphImg.setAttribute('srcorig', ngzGraphImg.src);
  }
  ngzZoomInfo = getZoomInfo();
  ngzZoomBox = getZoomBox();
  ngzZoomPanel = getZoomPanel();
  if(!ngzMouse) ngzMouse = new Mouse();
  if(!ngzZoom) ngzZoom = new Zoom();
  ngzZoom.configure();
}

function ngzClear() {
  ngzGraphImg = null;
  ngzZoomInfo.style.visibility = 'hidden';
  ngzZoomBox.style.visibility = 'hidden';
  ngzZoomPanel.style.visibility = 'hidden';  
}

function getZoomInfo() {
  if(!ngzZoomInfo) {
    ngzZoomInfo = document.getElementById(ngzZoomID + 'Info');
  }
  if(!ngzZoomInfo) {
    ngzZoomInfo = document.createElement('div');
    ngzZoomInfo.setAttribute('id', ngzZoomID + 'Info');
    ngzZoomInfo.style.position = 'absolute';
    ngzZoomInfo.style.overflow = '';
    document.body.appendChild(ngzZoomInfo);
  }
  if(!ngzZoomInfo) {
    throw "Cannot create Zoom Info";
  }
  return ngzZoomInfo;
}

function getZoomBox() {
  if(!ngzZoomBox) {
    ngzZoomBox = document.getElementById(ngzZoomID + 'Box');
  }
  if(!ngzZoomBox) {
    ngzZoomBox = document.createElement('div');
    ngzZoomBox.setAttribute('id', ngzZoomID + 'Box');
    ngzZoomBox.style.position = 'absolute';
    ngzZoomBox.style.overflow = '';
    ngzZoomBox.style.filter = 'alpha(opacity=10)';
    ngzZoomBox.style.opacity = 0.1;
    document.body.appendChild(ngzZoomBox);
  }
  if(!ngzZoomBox) {
    throw "Cannot create Zoom Box";
  }
  return ngzZoomBox;
}

function getZoomPanel() {
  if(!ngzZoomPanel) {
    ngzZoomPanel = document.getElementById(ngzZoomID + 'Panel');
  }
  if(!ngzZoomPanel) {
    ngzZoomPanel = document.createElement('div');
    ngzZoomPanel.setAttribute('id', ngzZoomID + 'Panel');
    ngzZoomPanel.setAttribute('onmousedown', 'if(event.preventDefault) { event.preventDefault(); } ngzMouseDown(event)');
    ngzZoomPanel.setAttribute('onmouseMove', 'ngzMouseMove(event)');
    ngzZoomPanel.setAttribute('onmouseup', 'ngzMouseUp(event)');
    ngzZoomPanel.setAttribute('onmouseover', 'ngzMouseOver(event)');
    ngzZoomPanel.setAttribute('onmouseout', 'ngzMouseOut(event)');
    ngzZoomPanel.style.position = 'absolute';
    ngzZoomPanel.style.overflow = '';
    ngzZoomPanel.style.filter = 'alpha(opacity=0)';
    ngzZoomPanel.style.opacity = 0;
    ngzZoomPanel.style.cursor = ngzZoomInCursor;
    document.body.appendChild(ngzZoomPanel);
  }
  if(!ngzZoomPanel) {
    throw "Cannot create Zoom Panel";
  }
  return ngzZoomPanel;
}

function Mouse() {
  this.posXStart = 0;
  this.posYStart = 0;
  this.posX = 0;
  this.posY = 0;
  this.drawInfo = 0;
  this.drawBox = 0;
  this.mouseButtonLeft = ngzMouseButtonLeftFunc;
  this.mouseButtonRight = ngzMouseButtonRightFunc;
  this.mouseButtonMiddle = ngzMouseButtonMiddleFunc;
  this.mouseGetPos = ngzMouseGetPosFunc;
  this.setEvent = ngzMouseSetEvent;
}

function Zoom() {
  this.startTime = 0;
  this.endTime = 0;
  this.imgTop = 0;
  this.imgLeft = 0;
  this.imgWidth = 0;
  this.imgHeight = 0;
  this.boxTop = 0;
  this.boxLeft = 0;
  this.boxWidth = 0;
  this.boxHeight = 0;
  this.drawInfo = ngzZoomBoxDrawInfoFunc;
  this.drawBox = ngzZoomBoxDrawBoxFunc;
  this.configure = ngzZoomBoxConfigure;
}

function ngzZoomBoxDrawInfoFunc(x1, y1, x2, y2) {
  if(ngzMouse.drawInfo) {
    var sec = ngzPix2Sec(x2);
    var date = new Date();
    date.setTime(sec*1000);
    var txt = dtpFormatDate(date);
    if(ngzMouse.drawBox) {
      sec = ngzPix2Sec(x1);
      date.setTime(sec*1000);
      txt = dtpFormatDate(date) + '<br>' + txt;
    }
    ngzZoomInfo.innerHTML = txt;
    ngzZoomInfo.style.visibility = 'visible';
  } else {
    ngzZoomInfo.style.visibility = 'hidden';
  }
}

function ngzZoomBoxDrawBoxFunc(x1, y1, x2, y2) {
  if(ngzMouse.drawBox) {
    if(x2 < x1) { var tmp = x2; x2 = x1; x1 = tmp; }
    if(y2 < y1) { var tmp = y2; y2 = y1; y1 = tmp; }
    var top = ngzZoom.boxTop;
    var bw = ngzGetStyle(ngzZoomBox,'border-left-width');
    bw = parseInt(bw);
    var left = x1;
    var width = x2 - x1;
    if(width >= bw) width -= bw;
    var height = ngzZoom.boxHeight;
    ngzZoomBox.style.top = top + 'px';
    ngzZoomBox.style.left = left + 'px';
    ngzZoomBox.style.width = width + 'px';
    ngzZoomBox.style.height = height + 'px';
    ngzZoomBox.style.visibility = 'visible';
  } else {
    ngzZoomBox.style.visibility = 'hidden';
  }
}

function ngzGetStyle(obj, prop) {
  var val;
  if(obj.currentStyle) {
    val = obj.currentStyle[prop];
  } else if(window.getComputedStyle) {
    val = document.defaultView.getComputedStyle(obj,null).getPropertyValue(prop);
  }
  return val;
}

function ngzZoomBoxConfigure() {
  ngzParseURL(ngzGraphImg.src);
  ngzResizeZoomBox(ngzGraphImg);
  ngzZoomPanel.style.visibility = 'visible';
  ngzZoomInfo.style.visibility = 'hidden';
  ngzZoomBox.style.visibility = 'hidden';
}

function ngzResizeZoomBox(img) {
  ngzZoom.imgTop = img.offsetTop;
  ngzZoom.imgLeft = img.offsetLeft;
  ngzZoom.imgWidth = img.width;
  ngzZoom.imgHeight = img.height;
  var top = parseInt(img.getAttribute('graphtop'));
  if (! top) top = 20;
  var left = parseInt(img.getAttribute('graphleft'));
  if (! left) left = 50;
  var width = img.getAttribute('graphwidth');
  if (! width) width = img.width - left - 30;
  var height = img.getAttribute('graphheight');
  if (! height) height = img.height - top - 40;
  var imgObj = img;
  while(imgObj) {
    top += imgObj.offsetTop;
    left += imgObj.offsetLeft;
    imgObj = imgObj.offsetParent;
  }
  ngzZoom.boxTop = top;
  ngzZoom.boxLeft = left;
  ngzZoom.boxWidth = width;
  ngzZoom.boxHeight = height;
  ngzZoomPanel.style.top = top + 'px';
  ngzZoomPanel.style.left = left + 'px';
  ngzZoomPanel.style.width = width + 'px';
  ngzZoomPanel.style.height = height + 'px';
  ngzZoomInfo.style.top = (top+2) + 'px';
  ngzZoomInfo.style.left = (left+2) + 'px';
}

function ngzMouseButtonLeftFunc(e) {
  var x = false;
  if(this.e.button) x = (this.e.button == 1); // IE
  else if(this.e.which) x = (this.e.which == 1);
  return x;
}

function ngzMouseButtonRightFunc(e) {
  var x = false;
  if(this.e.button) x = (this.e.button == 2); // IE
  else if(this.e.which) x = (this.e.which == 3);
  return x;
}

function ngzMouseButtonMiddleFunc(e) {
  var x = false;
  if(this.e.button) x = (this.e.button == 4); // IE
  else if(this.e.which) x = (this.e.which == 2);
  return x;
}

function ngzMouseGetPosFunc() {
  if(this.e.pageX || this.e.pageY) {
    this.posX = this.e.pageX;
    this.posY = this.e.pageY;
  } else if(this.e.clientX || this.e.clientY) {
    this.posX = this.e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
    this.posY = this.e.clientY + document.body.scrollTop + document.documentElement.scrollTop;
  }
}

function ngzMouseSetEvent(e) {
  if(!e) this.e = window.event;
  else this.e = e;
}

function ngzMouseDown(e) {
  ngzMouse.setEvent(e);
  if(ngzMouse.mouseButtonLeft()) {
    if(ngzMouse.posX > ngzZoom.boxLeft &&
       ngzMouse.posX < ngzZoom.boxLeft + ngzZoom.boxWidth &&
       ngzMouse.posY > ngzZoom.boxTop &&
       ngzMouse.posY < ngzZoom.boxTop + ngzZoom.boxHeight) {
      ngzMouse.drawBox = 1;
      ngzMouse.posXStart = ngzMouse.posX;
      ngzMouse.posYStart = ngzMouse.posY;
      ngzZoom.drawBox(ngzMouse.posX, ngzMouse.posY,
                      ngzMouse.posX, ngzMouse.posY);
    }
  }
}

function ngzMouseUp(e) {
  ngzMouse.setEvent(e);
  if(ngzMouse.mouseButtonLeft()) {
    if(ngzMouse.drawBox) {
      var s = Math.min(ngzMouse.posXStart, ngzMouse.posX);
      var e = Math.max(ngzMouse.posXStart, ngzMouse.posX);
      var w = e - s;
      ngzMouse.drawBox = 0;
      ngzZoom.drawBox(0,0,0,0);
      if(w > 0) {
        ngzLoadGraph(ngzGraphImg, s, e);
      }
    }
    ngzZoom.drawInfo(ngzMouse.posXStart, ngzMouse.posYStart,
                     ngzMouse.posX, ngzMouse.posY);
  } else if(ngzMouse.mouseButtonRight()) {
    ngzRevertGraph(ngzGraphImg);
  }
}

function ngzMouseMove(e) {
  ngzMouse.setEvent(e);
  ngzMouse.mouseGetPos();
  ngzZoom.drawBox(ngzMouse.posXStart, ngzMouse.posYStart,
                  ngzMouse.posX, ngzMouse.posY);
  ngzZoom.drawInfo(ngzMouse.posXStart, ngzMouse.posYStart,
                   ngzMouse.posX, ngzMouse.posY);
}

function ngzMouseOver(e) {
  if(ngzGraphImg == null ||
     ngzGraphImg.offsetParent == null ||
     ngzGetStyle(ngzGraphImg, 'visibility') == 'hidden' ||
     ngzGetStyle(ngzGraphImg, 'display') == 'none') {
    ngzClear();
    return;
  }
  if(ngzGraphImg.offsetTop != ngzZoom.imgTop ||
     ngzGraphImg.offsetLeft != ngzZoom.imgLeft ||
     ngzGraphImg.width != ngzZoom.imgWidth ||
     ngzGraphImg.height != ngzZoom.imgHeight) {
    ngzResizeZoomBox(ngzGraphImg);
  }
  ngzMouse.setEvent(e);
  ngzMouse.mouseGetPos();
  ngzMouse.drawInfo = 1;
  ngzZoom.drawInfo(ngzMouse.posXStart, ngzMouse.posYStart,
                   ngzMouse.posX, ngzMouse.posY);
}

function ngzMouseOut(e) {
  ngzMouse.setEvent(e);
  ngzMouse.drawBox = 0;
  ngzZoom.drawBox(0,0,0,0);
  ngzMouse.drawInfo = 0;
  ngzZoom.drawInfo(0,0,0,0);
}

function ngzRevertGraph(graph) {
  var orig = graph.getAttribute('srcorig');
  if(orig != 'undefined' && orig != '') {
    graph.src = orig;
    ngzParseURL(graph.src);
  }
}

function ngzLoadGraph(graph, start, end) {
  var newst = ngzPix2Sec(start);
  var newet = ngzPix2Sec(end);
  var rrdopts = ngzZoom.urlRRDOpts;
  if(rrdopts != '') { rrdopts += ' '; }
  rrdopts += '-s ' + newst + ' -e ' + newet;
  rrdopts = rrdopts.replace(/ /g, '+');
  var args = ngzZoom.urlArgs;
  if(args != '') { args += '&'; }
  args += 'rrdopts=' + rrdopts;
  graph.src = ngzZoom.urlBase + '?' + args;
  ngzParseURL(graph.src);
}

// FIXME: no way to do this exactly unless we know what 'now' is (i.e. when
// the graphs were first drawn), only in the case where s/e uses 'now'
// FIXME: there is an undefined state when rrdopts, period, and offset are
// all specified.  which to use?
function ngzParseURL(url) {
  var parts = url.split('?');
  var base = parts[0];
  var qs = parts[1];
  parts = qs.split('&');
  var args = '';
  var rrdopts = '';
  var now = new Date();
  now.setSeconds(0);
  var nows = now.getTime() / 1000;
  nows = parseInt(nows);
  var oldst = nows;
  var oldet = nows;
  for(var i=0; i<parts.length; i++)  {
    var pos = 0;
    if((pos=parts[i].indexOf('rrdopts')) >= 0) {
      var optstr = parts[i].substring(parts[i].indexOf('=')+1);
      optstr = optstr.replace(/\+/g, ' ');
      var opts = optstr.split(' ');
      for(var j=0; j<opts.length; j++) {
        if(opts[j].indexOf('-s') >= 0) {
          var str = '';
          if(opts[j].length == 2) { j++; str = opts[j]; }
          else { str = opts[j].substring(2); }
          oldst = ngzStr2Sec(str, nows);
        } else if(opts[j].indexOf('--start') >= 0) {
          var str = '';
          if(opts[j].length == 7) { j++; str = opts[j]; }
          else { str = opts[j].substring(7); }
          oldst = ngzStr2Sec(str, nows);
        } else if(opts[j].indexOf('-e') >= 0) {
          var str = '';
          if(opts[j].length == 2) { j++; str = opts[j]; }
          else { str = opts[j].substring(2); }
          oldet = ngzStr2Sec(str, nows);
        } else if(opts[j].indexOf('--end') >= 0) {
          var str = '';
          if(opts[j].length == 5) { j++; str = opts[j]; }
          else { str = opts[j].substring(5); }
          oldet = ngzStr2Sec(str, nows);
        } else if(opts[j] != '') {
          if(rrdopts != '') rrdopts += ' ';
          rrdopts += opts[j];
        }
      }
    } else if((pos=parts[i].indexOf('period')) >= 0) {
      var pstr = parts[i].substring(parts[i].indexOf('=')+1);
      if(pstr == 'day') {
        oldst -= 118800;
      } else if(pstr == 'week') {
        oldst -= 777600;
      } else if(pstr == 'month') {
        oldst -= 3024000;
      } else if(pstr == 'quarter') {
        oldst -= 8467200;
      } else if(pstr == 'year') {
        oldst -= 34560000;
      } else {
// FIXME: complain about unknown period
      }
    } else if((pos=parts[i].indexOf('offset')) >= 0) {
      var ostr = parts[i].substring(parts[i].indexOf('=')+1);
      var offset = parseInt(ostr);
      oldst -= offset;
      oldet -= offset;
    } else {
      if(args != '') { args += '&'; }
      args += parts[i];
    }
  }
  ngzZoom.startTime = oldst;
  ngzZoom.endTime = oldet;
  ngzZoom.urlBase = base;
  ngzZoom.urlArgs = args;
  ngzZoom.urlRRDOpts = rrdopts;
}

function ngzPix2Sec(p) {
  var x = p - ngzZoom.boxLeft;
  x /= ngzZoom.boxWidth;
  x *= ngzZoom.endTime - ngzZoom.startTime;
  x += ngzZoom.startTime;
  x = parseInt(x);
  return x;
}

function ngzStr2Sec(str, now) {
  var x = 0;
  var pos = 0;
  if(str == 'now') {
    x = now;
  } else if((pos=str.indexOf('now')) >= 0) {
    str = str.replace('now', '');
    x = now;
    x += parseInt(str);
  } else {
    x = parseInt(str);
  }
  return x;
}

var ngzStatus;
function ngzShowStatus(s) {
  if(!ngzStatus) {
    ngzStatus = document.createElement('div');
    ngzStatus.setAttribute('id', 'zoomStatus');
    document.body.appendChild(ngzStatus);
  }
  ngzStatus.innerHTML = s;
}

// show/hide a graph popup window (for mouseovers)
var ngpopup;
var ngpopupT = 16;
var ngpopupL = 20;
function showGraphPopup(elem) {
  if(!elem.rel) return;
  if(ngpopup == null) {
    ngpopup = document.createElement('div');
    ngpopup.style.position = 'absolute';
    ngpopup.style.padding = '3';
    ngpopup.style.backgroundColor = '#dddddd';
    ngpopup.style.border = '1px solid #777777';
    ngpopup.style.filter='alpha(opacity=90)';
    ngpopup.style.opacity='0.90';
    document.body.appendChild(ngpopup);
  }
  var html = "<div id='graphPopup'>";
  html += "<img src='" + elem.rel + "' alt='" + _('graph data') + "'>";
  html += "</div>";
  ngpopup.innerHTML = html;
  var coord = findPos(elem);
  ngpopup.style.top = coord.top + ngpopupT;
  ngpopup.style.left = coord.left + ngpopupL;
  ngpopup.style.visibility = 'visible';
}

function hideGraphPopup() {
  if(ngpopup != null) {
    ngpopup.style.visibility = 'hidden';
  }
}

function findPos(elem) {
  var top = 0;
  var left = 0;
  if(elem.offsetParent) {
    do {
      top += elem.offsetTop;
      left += elem.offsetLeft;
    } while((elem=elem.offsetParent) != null);
  }
  var coord = new Object();
  coord.top = top;
  coord.left = left;
  return coord;
}

// yet another javascript date/time picker
var ngpicker;
var ngStartOfWeek = "mon";  // 'mon' or 'sun'
function showDateTimePicker(elem) {
  if(ngpicker == null) {
    ngpicker = document.createElement('div');
    var cb = document.getElementById('secondary_controls_box');
    cb.appendChild(ngpicker);
    var html = "<div id='pickerPopup'>";
    html += dtpCreateHTML();
    html += "</div>";
    ngpicker.innerHTML = html;
  }
  if(ngpicker.style.visibility == 'visible') {
    ngpicker.style.visibility = 'hidden';
  } else {
    var date = dtpParseDate(document.menuform.enddate.value);
    dtpConfigCalendar(date);
    ngpicker.style.visibility = 'visible';
  }
}

function hideDateTimePicker() {
  if(ngpicker != null) {
    ngpicker.style.visibility = 'hidden';
  }
}

function dtpGetSelectedDate() {
  var date = new Date();
  date.setSeconds(0);
  date.setYear(document.menuform.year.value);
  date.setMonth(document.menuform.month.value);
  date.setDate(document.menuform.day.value);
  date.setHours(document.menuform.hour.value);
  date.setMinutes(document.menuform.minute.value);
  return date;
}

// expects the format 'dd.mm.yyyy HH:SS'
// returns current time if cannot parse.
function dtpParseDate(str) {
  var date = new Date();
  var parts = str.split(' ');
  if(parts.length == 2) {
    var dstr = parts[0].split('.');
    var tstr = parts[1].split(':');
    if(dstr.length == 3 && tstr.length == 2) {
      date.setYear(dstr[2]);
      date.setMonth(dstr[1]-1);
      date.setDate(dstr[0]);
      date.setHours(tstr[0]);
      date.setMinutes(tstr[1]);
      date.setSeconds(0);
    }
  }
  return date;
}

function dtpFormatDate(date) {
  var MM = dtpPrepend(date.getMinutes());
  var HH = dtpPrepend(date.getHours());
  var dd = dtpPrepend(date.getDate());
  var mm = dtpPrepend(date.getMonth() + 1);
  var yy = date.getFullYear();
  return dd + '.' + mm + '.' + yy + ' ' + HH + ':' + MM;
}

function dtpPickDateTime(label) {
  if(!label) {
    var date = dtpGetSelectedDate();
    label = dtpFormatDate(date);
  }
  if(document.menuform.enddate) {
    document.menuform.enddate.value = label;
  }
}

function dtpPrepend(x) {
  return (x < 10 ? "0" : "") + x;
}

function dtpConfigCalendar(ts) {
  var currD;
  var currM;
  var currY;
  if(ts) {
    currD = ts.getDate();
    currM = ts.getMonth();
    currY = ts.getFullYear();
    var MM = 15 * parseInt(ts.getMinutes() / 15);
    document.menuform.minute.value = dtpPrepend(MM);
    document.menuform.hour.value = dtpPrepend(ts.getHours());
    document.menuform.day.value = currD;
    document.menuform.month.value = currM;
    document.menuform.year.value = currY;
  } else {
    currD = parseInt(document.menuform.day.value);
    currM = parseInt(document.menuform.month.value);
    currY = parseInt(document.menuform.year.value);
  }
  var date = new Date();
  date.setFullYear(currY);
  date.setMonth(currM);
  date.setDate(1);
  date.setSeconds(0);
  var d = date.getDay();
  if(d == 0) { d = 7; }
  d -= (ngStartOfWeek == "mon" ? 1 : 0);
  if(d < 0) { d = 7; }
  var dates = new Array(42);
  var prevM = (currM > 0) ? currM - 1 : 11;
  for(var i=0; i<d; i++) {
    dates[i] = dtpDiM(prevM,currY) - d + i + 1;
  }
  var x = 1;
  for(var i=d; i<=d+dtpDiM(currM,currY)-1; i++) {
    dates[i] = x;
    x += 1;
  }
  x = 1;
  for(var i=d+dtpDiM(currM,currY); i<= 41; i++) {
    dates[i] = x;
    x += 1;
  }
  var dow = 0;
  var sat = (ngStartOfWeek == "mon" ? 5 : 6);
  var sun = (ngStartOfWeek == "mon" ? 6 : 0);
  for(var i=0; i<42; i++) {
    var cn = 'dateWeekday';
    if((i<7 && dates[i]>20) || (i>27 && dates[i]<20)) {
      cn = 'dateNonCurrent';
    } else if(dow == sat || dow == sun) {
      cn = 'dateWeekend';
    }
    var elem = document.getElementById('calCell'+i);
    elem.innerHTML = dates[i];
    elem.className = cn;
    dow += 1;
    if(dow > 6) { dow = 0; }
  }
  for(var i=0; i<42; i++) {
    if(dates[i] == currD) {
      dtpSelectDay('calCell'+i);
      break;
    }
  }
}

function dtpSelectDay(id) {
  var selem = document.getElementById(id);
  if(!selem)
    return;
  if(selem.className != 'dateWeekday' && selem.className != 'dateWeekend')
    return;
  if(isNaN(selem.innerHTML))
    return;
  var elem = document.getElementById('calUnselectedCell');
  var bg = deepCSS(elem,'background-color');
  for(var i=0; i<42; i++) {
    elem = document.getElementById('calCell'+i);
    elem.style.backgroundColor = bg;
  }
  elem = document.getElementById('calSelectedCell');
  bg = deepCSS(elem,'background-color');
  selem.style.backgroundColor = bg;
  document.menuform.day.value = selem.innerHTML;
}

// get the actual (computed) CSS value of the indicated property
// (thank you mrhoo http://codingforums.com/showthread.php?p=920175)
function deepCSS(elem, prop) {
  var val;
  var dv = document.defaultView || window;
  if(dv.getComputedStyle) {
    val = dv.getComputedStyle(elem,'').getPropertyValue(prop);
  } else if(elem.currentStyle) {
    prop = prop.replace(/\-[a-z]/g, function(w) {
      return w.charAt(1).toUpperCase() + w.substring(2);
    });
    val = elem.currentStyle[prop];
  }
  return val;
}

function dtpCreateHTML() {
  var ts = new Date();
  var minute = ts.getMinutes();
  var hour = ts.getHours();
  var day = ts.getDate();
  var month = ts.getMonth();
  var year = ts.getFullYear();

  var minutes = new Array("00","15","30","45");
  var hours = new Array();
  for(var i=0; i<24; i++) {
    hours[i] = (i < 10 ? "0" + i : i);
  }
  var months = new Array(_('Jan'),_('Feb'),_('Mar'),_('Apr'),_('May'),_('Jun'),_('Jul'),_('Aug'),_('Sep'),_('Oct'),_('Nov'),_('Dec'));
  var days = new Array(_('Sun'),_('Mon'),_('Tue'),_('Wed'),_('Thu'),_('Fri'),_('Sat'),_('Sun'));
  var years = new Array();
  for(var i=0; i<5; i++) {
    years[i] = year + i - 4;
  }

  var txt = "";
  txt += "<input type='hidden' name='day' value='" + day + "'>";
  txt += "<table style='display:none'><tr><td id='calSelectedCell'></td><td id='calUnselectedCell'></td></tr></table>";
  txt += "<table class='cal'>";
  txt += "<tr><td><table width='100%'>";
  txt += "<tr><td align='left'>";
  txt += "<select name='month' onChange='dtpConfigCalendar()'>";
  for(var i=0; i<months.length; i++) {
    var selected = (i == month ? " selected" : "");
    txt += "<option value='" + i + "'" + selected + ">" + months[i] + "</option>";
  }
  txt += "</select>";
  txt += "</td><td align='right'>";
  txt += "<select name='year' onChange='dtpConfigCalendar()'>";
  for(var i=0; i<years.length; i++ ) {
    var selected = (years[i] == year ? " selected" : "");
    txt += "<option value='" + years[i] + "'" + selected + ">" + years[i] + "</option>";
  }
  txt += "</select>";
  txt += "</td></tr>";
  txt += "</table></td></tr>";
  txt += "<tr><td><table>";

  var sidx = (ngStartOfWeek == "mon" ? 1 : 0);
  var rows = 6;
  var cols = 7;
  txt += "<tr class='calHdr'>";
  for(var j=0; j<cols; j++) {
    txt += "<td class='calHdrCell'>" + days[j+sidx] + "</td>";
  }
  txt += "</tr>";
  var idx = 0;
  for(var i=0; i<rows; i++) {
    txt += "<tr class='calRow'>";
    for(var j=0; j<cols; j++) {
      txt += "<td class='calCell' align='right'"
      txt += " id='calCell" + idx + "' onClick='dtpSelectDay(this.id)'>x";
      txt += "</td>";
      idx++;
    }
    txt += "</tr>";
  }
  txt += "</table></td></tr>";
  txt += "<tr><td><table width='100%'>";
  txt += "<tr><td align='left' colspan='2'>";
  txt += "<select name='hour'>";
  for(var i=0; i<hours.length; i++) {
    var selected = (hours[i] == hour ? " selected" : "");
    txt += "<option value='" + hours[i] + "'" + selected + ">" + hours[i] + "</option>";
  }
  txt += "</select>";
  txt += " : ";
  txt += "<select name='minute'>";
  for(var i=0; i<minutes.length; i++) {
    var selected = (minutes[i] == minute ? " selected" : "");
    txt += "<option value='" + minutes[i] + "'" + selected + ">" + minutes[i] + "</option>";
  }
  txt += "</select>";
  txt += "</td></tr>";
  txt += "<tr class='calButtons'><td align='left'>";
  txt += "<input type='button' name='ok' value='" + _('OK') + "' onClick='dtpPickDateTime(); hideDateTimePicker();'/>";
  txt += "<input type='button' name='now' value='" + _('Now') + "' onClick='dtpPickDateTime(\"now\"); hideDateTimePicker();'/>";
  txt += "</td><td align='right'>";
  txt += "<input type='button' name='cancel' value='" + _('Cancel') + "' onClick='hideDateTimePicker()'/>";
  txt += "</td></tr></table>";
  txt += "</td></tr>";
  txt += "</table>";
  return txt;
}

function dtpDiM(m, y) {
  var d = 31;
  if(m == 3 || m == 5 || m == 8 || m == 10) {
    d = 30;
  } else if(m == 1) {
    if(y/4 - parseInt(y/4) != 0) {
      d = 28;
    } else {
      d = 29;
    }
  }
  return d;
}


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

function setExpansionState(expanded, panel, button) {
  if (expanded) {
    if (panel) panel.style.display = 'inline';
    if (button) button.value = '-';
  } else {
    if (panel) panel.style.display = 'none';
    if (button) button.value = '+';
  }
}

function toggleExpansionState(id, button) {
  var elem = document.getElementById(id);
  toggleDisplay(elem);
  if (elem.style.display == 'inline') {
    button.value = '-';
  } else {
    button.value = '+';
  }
}

function toggleControlsDisplay(button) {
  toggleExpansionState('secondary_controls_box', button);
}

function togglePeriodDisplay(period, button) {
  toggleExpansionState(period, button);
}

function toggleDisplay(elem) {
  if (elem) {
    if (elem.style.display != 'none') {
      elem.style.display = 'none';
    } else {
      elem.style.display = 'inline';
    }
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
//
// FIXME: need to make this future-proof/less-brittle
function mkCGIArgs() {
  var args = new Array();

  var elem = document.menuform.servidors;
  if (elem) {
    var host;
    if (elem.selectedIndex > 0) {
      host = elem.options[elem.selectedIndex].text;
    } else {
      host = getCGIValue('host');
    }
    if (host && host != '' && host != '-') {
      args.push('host=' + escape(host));
    }
  }
  elem = document.menuform.services;
  if (elem) {
    var service;
    if (elem.selectedIndex > 0) {
      service = elem.options[elem.selectedIndex].text;
    } else {
      service = getCGIValue('service');
    }
    if (service && service != '' && service != '-') {
      args.push('service=' + escape(service));
    }
  }
  elem = document.menuform.groups;
  if (elem) {
    var group;
    if (elem.selectedIndex > 0) {
      group = elem.options[elem.selectedIndex].text;
    } else {
      group = getCGIValue('group');
    }
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
        if (elem.options[ii].value == 'default') {
          geom = 'default';
        } else {
          geom = 'geom=' + escape(elem.options[ii].value);
        }
        break;
      }
    }
  }

  offset = '';
  elem = document.menuform.enddate;
  if (elem) {
    if (elem.value != 'now') {
      var now = new Date();
      now.setSeconds(0);
      var then = dtpParseDate(elem.value);
      then.setSeconds(0);
      var value = now.getTime() - then.getTime();
      value /= 1000;
      value = parseInt(value);
      if (value != 0) {
        offset = 'offset=' + value;
      }
    } else {
      offset = 'now';
    }
  }

  elem = document.menuform.showhidecontrols;
  if (elem && elem.value == '-') {
    args.push('expand_controls');
  }

  elem = document.menuform.period;
  if (elem) {
    var str = '';
    for (var ii = 0; ii < elem.length; ii++) {
      if (elem.options[ii].selected) {
        if (str != '') str += ',';
        str += elem.options[ii].value;
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
        || name == 'expand_controls'
        || name == 'period'
        || name == 'expand_period') {
      // skip it
    } else if (name == 'geom') {
      if (geom == '' && value != '' && value != 'default') {
        geom = params[ii];
      }
    } else if (name == 'offset') {
      if (offset == '') {
        offset = params[ii];
      }
    } else {
      args.push(params[ii]);
    }
  }

  if (geom != '' && geom != 'default') {
    args.push(geom);
  }
  if (offset != '' && offset != 'now') {
    args.push(offset);
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

  var elem = document.getElementById('secondary_controls_box');
  if (elem) { elem.style.display = 'inline'; }
  elem = document.getElementById('js_disabled');
  if (elem) { elem.style.display = 'none'; }
  elem = document.getElementById('js_version_' + VERSION);
  if (elem) { elem.style.display = 'none'; }

  setControlsGUIState();
  setPeriodGUIStates(expanded_periods);
  selectPeriodItems();
  selectDBItems(service, location.search.substring(1));
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

  items.sort();

  menu.length = items.length + 1;
  menu.options[0].text = '-';
  for (var ii = 0; ii < items.length; ii++) {
    menu.options[ii+1].text = items[ii];
    if (items[ii] == service) {
      menu.options[ii+1].selected = true;
    }
  }
}

// Once a service is selected this function updates the list of corresponding
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

  menu.size = 5;
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
// if nothing is specified, then check the default selection array.
// if still nothing specified, then select everything.
function selectDBItems(service, query) {
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
    if (defaultds) {
      for (var ii=0; ii<defaultds.length; ii++) {
        if (defaultds[ii][0] == service) {
          for (var jj=1; jj<defaultds[ii].length; jj++) {
            for (var kk=0; kk<elem.length; kk++) {
              if (defaultds[ii][jj] == elem.options[kk].value) {
                elem.options[kk].selected = true;
                found = true;
              } else if (defaultds[ii][jj].indexOf(",") > 0) {
                var ids = defaultds[ii][jj].split(',');
                for (var ll=1; ll<ids.length; ll++) {
                  var x = ids[0] + ',' + ids[ll];
                  if (x == elem.options[kk].value) {
                    elem.options[kk].selected = true;
                    found = true;
                  }                
                }
              }
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
// not, then collapse them.  make the other gui controls match the state.
function setControlsGUIState() {
  setExpansionState(getCGIBoolean('expand_controls'),
                    document.getElementById('secondary_controls_box'),
                    document.menuform.showhidecontrols);
  elem = document.menuform.geom;
  if (elem) {
    var geom = getCGIValue('geom');
    for (var ii=0; ii<elem.length; ii++) {
      if (elem.options[ii].value == geom) {
        elem.options[ii].selected = true;
        break;
      }
    }
  }
  elem = document.menuform.enddate;
  if (elem) {
    var offset = getCGIValue('offset');
    if (offset) {
      var now = new Date();
      now.setSeconds(0);
      var nows = now.getTime();
      var date = new Date();
      date.setTime(nows - offset*1000);
      elem.value = dtpFormatDate(date);
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
    setExpansionState(pflag[ii],
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
  selectDBItems(service, dbitems);
}

// configure everything based on a change to the selected service.  a change
// to the service requires that the db menu be reconstructed to match the
// data sets of the selected service.
function serviceChange() {
  var host = '';
  var service = '';

  var hostmenu = document.menuform.servidors;
  if (hostmenu) {
    host = hostmenu.options[hostmenu.selectedIndex].text;
  }
  var servmenu = document.menuform.services;
  if (servmenu) {
    service = servmenu.options[servmenu.selectedIndex].text;
  }

  cfgDBMenu(host, service);
  selectDBItems(service, '');
}
