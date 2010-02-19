%define ngetc /etc/nagiosgraph
%define ngshare /usr/share/nagiosgraph
%define nlib /usr/lib/nagios
%define ncgi %{nlib}/cgi
%define nshare /usr/share/nagios

Summary: A Nagios data archiver and grapher.
Name: nagiosgraph
Version: 1.4.1
Release: 1
Group: Applications/System
Source: %{name}-%{version}.tar.gz
URL: http://nagiosgraph.wiki.sourceforge.net/
License: Artistic
BuildRoot: %{_tmppath}/%{name}-root

%description
Nagiosgraph is an add-on of Nagios. It collects service performance data into
rrd format, and displays the resulting graphs via cgi.

%prep
%setup

%build
make test

%install
rm -rf ${RPM_BUILD_ROOT}
NGETC=%{ngetc}
NGSHARE=%{ngshare}
NLIB=%{nlib}
NCGI=%{ncgi}
NSHARE=%{nshare}
export NGETC NGSHARE NLIB NCGI NSHARE
%makeinstall
mv ${RPM_BUILD_ROOT}/%{nshare}/images/action.gif ${RPM_BUILD_ROOT}/%{nshare}/images/nagiosgraph_action.gif

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%config %{ngetc}
%{ncgi}/*
%{nlib}/*
%{nshare}
%{ngshare}

%changelog
* Wed Nov 11 2009 Craig Dunn <craig@craigdunn.org>
- action.gif renamed to nagiosgraph_action.gif to avoid package conflict with nagios

* Fri Nov 6 2009 Craig Dunn <craig@craigdunn.org>
- Fixed build root, paths and install command

* Tue Sep 23 2008 Alan Brenner <alan.brenner@ithaka.org>
- Initial spec.
