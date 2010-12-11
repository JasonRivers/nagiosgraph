%define name nagiosgraph
%define version VERSION
%define release 1

%define ng_bin_dir /usr/libexec/nagiosgraph
%define ng_cgi_dir /usr/lib/nagiosgraph/cgi-bin
%define ng_doc_dir /usr/share/nagiosgraph/doc
%define ng_etc_dir /etc/nagiosgraph
%define ng_examples_dir /usr/share/nagiosgraph/examples
%define ng_www_dir /usr/share/nagiosgraph/htdocs
%define ng_util_dir /usr/share/nagiosgraph/util
%define ng_rrd_dir /var/spool/nagiosgraph/rrd
%define ng_log_file /var/log/nagiosgraph.log
%define ng_cgilog_file /var/log/nagiosgraph-cgi.log

Summary: A Nagios data archiver and grapher.
Name: %{name}
Version: %{version}
Release: %{release}
Group: Applications/System
Source: %{name}-%{version}.tar.gz
URL: http://nagiosgraph.sourceforge.net/
License: Artistic
BuildRoot: %{_tmppath}/%{name}-root

%description
Nagiosgraph is an add-on to Nagios. It collects performance data
into RRD files and displays graphs via cgi.

%prep
%setup

%build

%install
export NG_LAYOUT=redhat; perl install.pl

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%doc AUTHORS
%doc CHANGELOG
%doc INSTALL
%doc README
%doc TODO
%defattr(-,root,root)
%{ng_bin_dir}/insert.pl
%attr(755,root,root) %{ng_bin_dir}/*
%{ng_cgi_dir}/show.cgi
%{ng_cgi_dir}/showconfig.cgi
%{ng_cgi_dir}/showgraph.cgi
%{ng_cgi_dir}/showgroup.cgi
%{ng_cgi_dir}/showhost.cgi
%{ng_cgi_dir}/showservice.cgi
%{ng_cgi_dir}/testcolor.cgi
%attr(755,root,root) %{ng_cgi_dir}/*
%doc %{ng_doc_dir}/AUTHORS
%doc %{ng_doc_dir}/CHANGELOG
%doc %{ng_doc_dir}/INSTALL
%doc %{ng_doc_dir}/README
%doc %{ng_doc_dir}/TODO
%config %{ng_etc_dir}/access.conf
%config %{ng_etc_dir}/datasetdb.conf
%config %{ng_etc_dir}/groupdb.conf
%config %{ng_etc_dir}/hostdb.conf
%config %{ng_etc_dir}/labels.conf
%config %{ng_etc_dir}/map
%config %{ng_etc_dir}/nagiosgraph.conf
%config %{ng_etc_dir}/nagiosgraph_fr.conf
%config %{ng_etc_dir}/nagiosgraph_de.conf
%config %{ng_etc_dir}/nagiosgraph_es.conf
%config %{ng_etc_dir}/ngshared.pm
%config %{ng_etc_dir}/rrdopts.conf
%config %{ng_etc_dir}/servdb.conf
%{ng_examples_dir}/nagiosgraph.1.css
%{ng_examples_dir}/nagiosgraph.2.css
%{ng_examples_dir}/map_minimal
%{ng_examples_dir}/map_examples
%{ng_examples_dir}/map_mwall
%{ng_examples_dir}/nagiosgraph-nagios.cfg
%{ng_examples_dir}/map_1_4_4
%{ng_examples_dir}/map_1_3
%{ng_examples_dir}/map_1_4_3
%{ng_examples_dir}/action.gif
%{ng_examples_dir}/nagiosgraph.ssi
%{ng_www_dir}/nagiosgraph.css
%{ng_www_dir}/nagiosgraph.js
%{ng_util_dir}/testentry.pl
%{ng_util_dir}/upgrade.pl
%attr(755,root,root) %{ng_util_dir}/*
%{ng_rrd_dir}
%attr(775,nagios,www-data) %{ng_rrd_dir}
%{ng_log_file}
%attr(755,nagios,nagios) %{ng_log_file}
%{ng_cgilog_file}
%attr(755,www-data,www-data) %{ng_cgilog_file}

%changelog
* Fri Nov 5 2010 Matthew Wall
- refactor for use with new install script

* Wed Nov 11 2009 Craig Dunn <craig@craigdunn.org>
- action.gif renamed to nagiosgraph_action.gif to avoid package conflict with nagios

* Fri Nov 6 2009 Craig Dunn <craig@craigdunn.org>
- Fixed build root, paths and install command

* Tue Sep 23 2008 Alan Brenner <alan.brenner@ithaka.org>
- Initial spec.
