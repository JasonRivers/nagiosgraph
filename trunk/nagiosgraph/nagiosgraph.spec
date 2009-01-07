%define ngetc /etc/nagios/nagiosgraph
%define ngshare /usr/share/nagiosgraph
%define nlib /usr/lib/nagios
%define ncgi %{nlib}/cgi
%define nshare /usr/share/nagios

Summary: A Nagios data archiver and grapher.
Name: nagiosgraph
Version: 1.2.0
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

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%config %{ngetc}/*
%{ncgi}/*
%{nlib}/*
%{nshare}/stylesheets/*
%{ngshare}

%changelog
* Tue Sep 23 2008 Alan Brenner <alan.brenner@ithaka.org>
- Initial spec.