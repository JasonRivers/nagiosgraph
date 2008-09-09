#!/usr/bin/perl

# File:    $Id: testcolor.cgi,v 1.2 2005/10/08 05:55:08 sauber Stab $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;
use CGI qw/:standard/;

# Suggest some commonly used keywords
my $w = param('words') ? join ' ', param('words') : 'response rta pctfree';

# Start each page with an input field
print <<EOF;
Content-type: text/html

<html><body>
<form>
Type some space seperated nagiosgraph line names here:<br>
<input name=words size=80 value="$w">
<input type=submit>
</form><br>
EOF

# Render a table of colors of all schemes for each keyword
if ( param('words') ) {
  print "<table cellpadding=0><tr><td></td>";
  print "<th>$_</th>" for 1..8;
  print "</tr>\n";
  for my $w ( split /\s+/, param('words') ) {
    print "<tr><td>$w</td>";
    for my $c ( 1..8 ) {
      my $h = hashcolor($w, $c);
      print "<td><table bgcolor=#000000><tr><td bgcolor=#$h>&nbsp;</td></tr></table></td>";
    }
    print "</tr>\n";
  }
  print "</table>\n";
}

# End of page
print "</body></html>\n";

# Calculate a color for a keyword
#
sub hashcolor {
  my$c=$_[1];map{$c=1+(51*$c+ord)%(216)}split//,$_[0];
  my($i,$n,$m,@h);@h=(51*int$c/36,51*int$c/6%6,51*($c%6));
  for$i(0..2){$m=$i if$h[$i]<$h[$m];$n=$i if$h[$i]>$h[$n]}
  $h[$m]=102if$h[$m]>102;$h[$n]=153if$h[$n]<153;
  $c=sprintf"%06X",$h[2]+$h[1]*256+$h[0]*16**4;
  return $c;
}

