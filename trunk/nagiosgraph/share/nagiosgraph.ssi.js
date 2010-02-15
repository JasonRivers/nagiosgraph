<script type="text/javascript">
// nagiosgraph javascript to display graphs on mouseover
// $Id$
// Copyright 2010 Matthew Wall, all rights reserved
var ngpopup;
function showGraphPopup(elem) {
  if(!elem || !elem.rel) return;
  if(ngpopup == null) {
    ngpopup = document.createElement('div');
    ngpopup.style.position = 'absolute';
    ngpopup.style.padding = '3';
    ngpopup.style.background = '#dddddd';
    ngpopup.style.border = '1px solid #777777';
    ngpopup.style.filter='alpha(opacity=90)';
    ngpopup.style.opacity='0.90';
    document.body.appendChild(ngpopup);
  }
  var html = "<div class='graphPopup'>";
  html += "<img src='" + elem.rel + "' alt='graph data'>";
  html += "</div>";
  ngpopup.innerHTML = html;
  var coord = findPos(elem);
  ngpopup.style.left = coord[0] + 20;
  ngpopup.style.top = coord[1] + 16;
  ngpopup.style.visibility = 'visible';
}
function hideGraphPopup() {
  if(ngpopup != null) {
    ngpopup.style.visibility = 'hidden';
  }
}
function findPos(elem) {
  var left = top = 0;
  if(elem.offsetParent) {
    do {
      left += elem.offsetLeft;
      top += elem.offsetTop;
    } while(elem=elem.offsetParent);
  }
  return [left, top];
}
</script>
