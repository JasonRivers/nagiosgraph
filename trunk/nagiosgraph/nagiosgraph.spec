%define name nagiosgraph
%define version 1.4.4
%define release 1
%define nlib /usr/lib/nagios
%define nshare /usr/share/nagios
%define ng_bin_dir %{nlib}
%define ng_etc_dir /etc/nagiosgraph
%define ng_cgi_dir %{nlib}/cgi
%define ng_doc_dir /usr/share/nagiosgraph
%define ng_css_dir %{nshare}
%define ng_js_dir %{nshare}
%define ng_util_dir /usr/share/nagiosgraph/util
%define ng_rrd_dir /var/nagios/rrd
%define ng_log_file /var/nagios/nagiosgraph.log
%define ng_cgilog_file /var/nagios/nagiosgraph-cgi.log

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
Nagiosgraph is an add-on to Nagios. It collects service performance data into
RRD format and displays the resulting graphs via cgi.

%prep

%setup

%build
make test

%install
rm -rf ${RPM_BUILD_ROOT}
NG_DEST_DIR=/
NG_LAYOUT=overlay
NG_BIN_DIR=%{ng_bin_dir}
NG_ETC_DIR=%{ng_etc_dir}
NG_CGI_DIR=%{ng_cgi_dir}
NG_DOC_DIR=%{ng_doc_dir}
NG_CSS_DIR=%{ng_css_dir}
NG_JS_DIR=%{ng_js_dir}
NG_UTIL_DIR=%{ng_util_dir}
NG_RRD_DIR=%{ng_rrd_dir}
NG_LOG_FILE=%{ng_log_file}
NG_CGILOG_FILE=%{ng_cgilog_file}
NG_CGI_URL=/nagios/cgi-bin
NG_CSS_URL=/nagios/nagiosgraph.css
NG_JS_URL=/nagios/nagiosgraph.js
export NG_DEST_DIR NG_BIN_DIR NG_ETC_DIR NG_CGI_DIR NG_DOC_DIR NG_CSS_DIR NG_JS_DIR NG_UTIL_DIR NG_RRD_DIR NG_LOG_FILE NG_CGILOG_FILE NG_CGI_URL NG_CSS_URL NG_JS_URL
install.pl

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%config %{ng_etc_dir}
%{ng_bin_dir}/*
%{ng_cgi_dir}/*
%{ng_doc_dir}/*
%{ng_css_dir}/*
%{ng_js_dir}/*
%{ng_util_dir}/*
%attr(755,nagios,nagios) %{ng_rrd_dir}
%attr(755,nagios,nagios) %{ng_log_file}
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
