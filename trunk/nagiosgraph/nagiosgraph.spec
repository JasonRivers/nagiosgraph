# $Id$
# License: OSI Artistic License
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# default configuration when OS is not known - this will fail.  when it does,
# add a vendor section with an appropriate configuration.
%define layout unknown

# suse
%if "%{_vendor}" == "suse"
%define layout suse
%define relos .suse%{suse_version}
%define apacheconfdir %{_sysconfdir}/apache2/conf.d
%define apacheuser wwwrun
%define apachegroup nagcmd
%define apachecmd apache2
%define nagiosuser nagios
%define nagiosgroup nagios
%define nagioscmd nagios
%endif

# redhat, fedora, centos
%if "%{_vendor}" == "redhat"
%define layout redhat
%define relos %{?dist:%{dist}}
%define apacheconfdir %{_sysconfdir}/httpd/conf.d
%define apacheuser apache
%define apachegroup apache
%define apachecmd httpd
%define nagiosuser nagios
%define nagiosgroup nagios
%define nagioscmd nagios
%endif

%global relnum 1
%global release %{relnum}%{?relos:%{relos}}

%global ng_bin_dir %{_libexecdir}/%{name}
%global ng_cgi_dir /usr/lib/%{name}/cgi-bin
%global ng_etc_dir %{_sysconfdir}/%{name}
%global ng_doc_dir %{_defaultdocdir}/%{name}-%{version}
%global ng_examples_dir %{_datadir}/%{name}/examples
%global ng_www_dir %{_datadir}/%{name}/htdocs
%global ng_util_dir %{_datadir}/%{name}/util
%global ng_rrd_dir %{_localstatedir}/spool/%{name}/rrd
%global ng_log_dir %{_localstatedir}/log/%{name}
%global ng_log_file %{ng_log_dir}/nagiosgraph.log
%global ng_cgilog_file %{ng_log_dir}/nagiosgraph-cgi.log
%global n_cfg_file %{_sysconfdir}/nagios/nagios.cfg
%global n_cmd_file %{_sysconfdir}/nagios/objects/commands.cfg
%global stag "# begin nagiosgraph configuration"
%global etag "# end nagiosgraph configuration"

Summary: Nagios add-on for performance data storage and graphing
Name: nagiosgraph
Version: VERSION
Release: %{release}
Group: Applications/System
Source: http://sourceforge.net/projects/nagiosgraph/files/nagiosgraph/%{version}/%{name}-%{version}.tar.gz
URL: http://nagiosgraph.sourceforge.net/
License: Artistic 2.0
Requires: nagios, httpd, perl, perl(CGI), perl(RRDs), perl(GD)
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
BuildRequires: perl

%description
nagiosgraph is an add-on to Nagios. It collects performance data
into RRD files and displays graphs in web pages.

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
DESTDIR=%{buildroot} NG_LAYOUT=%{layout} perl install.pl --no-check-prereq --no-chown --doc-dir %{ng_doc_dir}

%post
cp %{_sysconfdir}/%{name}/nagiosgraph-apache.conf %{apacheconfdir}/nagiosgraph.conf
cp -p %{n_cfg_file} %{n_cfg_file}-ngsave
echo %{stag} >> %{n_cfg_file}
cat %{_sysconfdir}/%{name}/nagiosgraph-nagios.cfg >> %{n_cfg_file}
echo %{etag} >> %{n_cfg_file}
cp -p %{n_cmd_file} %{n_cmd_file}-ngsave
echo %{stag} >> %{n_cmd_file}
cat %{_sysconfdir}/%{name}/nagiosgraph-commands.cfg >> %{n_cmd_file}
echo %{etag} >> %{n_cmd_file}
%{_initrddir}/%{apachecmd} restart
%{_initrddir}/%{nagioscmd} restart

# FIXME: this assumes no changes were made since we cached to -ngsave
%postun
rm %{apacheconfdir}/nagiosgraph.conf
mv %{n_cfg_file}-ngsave %{n_cfg_file}
mv %{n_cmd_file}-ngsave %{n_cmd_file}
%{_initrddir}/%{apachecmd} restart
%{_initrddir}/%{nagioscmd} restart

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%attr(755,root,root) %{ng_bin_dir}/insert.pl
%attr(755,root,root) %{ng_cgi_dir}/show.cgi
%attr(755,root,root) %{ng_cgi_dir}/showconfig.cgi
%attr(755,root,root) %{ng_cgi_dir}/showgraph.cgi
%attr(755,root,root) %{ng_cgi_dir}/showgroup.cgi
%attr(755,root,root) %{ng_cgi_dir}/showhost.cgi
%attr(755,root,root) %{ng_cgi_dir}/showservice.cgi
%attr(755,root,root) %{ng_cgi_dir}/testcolor.cgi
%doc %{ng_doc_dir}/AUTHORS
%doc %{ng_doc_dir}/CHANGELOG
%doc %{ng_doc_dir}/INSTALL
%doc %{ng_doc_dir}/README
%doc %{ng_doc_dir}/TODO
%config(noreplace) %{ng_etc_dir}/access.conf
%config(noreplace) %{ng_etc_dir}/datasetdb.conf
%config(noreplace) %{ng_etc_dir}/groupdb.conf
%config(noreplace) %{ng_etc_dir}/hostdb.conf
%config(noreplace) %{ng_etc_dir}/labels.conf
%config(noreplace) %{ng_etc_dir}/map
%config(noreplace) %{ng_etc_dir}/nagiosgraph.conf
%config(noreplace) %{ng_etc_dir}/nagiosgraph_fr.conf
%config(noreplace) %{ng_etc_dir}/nagiosgraph_de.conf
%config(noreplace) %{ng_etc_dir}/nagiosgraph_es.conf
%config(noreplace) %{ng_etc_dir}/nagiosgraph-apache.conf
%config(noreplace) %{ng_etc_dir}/nagiosgraph-nagios.cfg
%config(noreplace) %{ng_etc_dir}/nagiosgraph-commands.cfg
%config(noreplace) %{ng_etc_dir}/ngshared.pm
%config(noreplace) %{ng_etc_dir}/rrdopts.conf
%config(noreplace) %{ng_etc_dir}/servdb.conf
%{ng_examples_dir}/nagiosgraph.1.css
%{ng_examples_dir}/nagiosgraph.2.css
%{ng_examples_dir}/map_minimal
%{ng_examples_dir}/map_examples
%{ng_examples_dir}/map_mwall
%{ng_examples_dir}/nagiosgraph-apache.conf
%{ng_examples_dir}/nagiosgraph-nagios.cfg
%{ng_examples_dir}/nagiosgraph-commands.cfg
%{ng_examples_dir}/map_1_4_4
%{ng_examples_dir}/map_1_3
%{ng_examples_dir}/map_1_4_3
%{ng_examples_dir}/action.gif
%{ng_examples_dir}/nagiosgraph.ssi
%{ng_www_dir}/nagiosgraph.css
%{ng_www_dir}/nagiosgraph.js
%attr(755,root,root) %{ng_util_dir}/testentry.pl
%attr(755,root,root) %{ng_util_dir}/upgrade.pl
%attr(755,%{nagiosuser},%{apachegroup}) %{ng_rrd_dir}
%attr(775,root,%{apachegroup}) %{ng_log_dir}
%attr(644,%{nagiosuser},%{nagiosgroup}) %{ng_log_file}
%attr(644,%{apacheuser},%{apachegroup}) %{ng_cgilog_file}

%changelog
* Sat Dec 25 2010 Matthew Wall <nagiosgraph@sourceforge.net>
- added suse layout

* Fri Nov 5 2010 Matthew Wall <nagiosgraph@sourceforge.net>
- refactor for use with new install script and latest fedora/redhat

* Wed Nov 11 2009 Craig Dunn <craig@craigdunn.org>
- action.gif renamed to nagiosgraph_action.gif to avoid package conflict with nagios

* Fri Nov 6 2009 Craig Dunn <craig@craigdunn.org>
- Fixed build root, paths and install command

* Tue Sep 23 2008 Alan Brenner <alan.brenner@ithaka.org>
- Initial spec.
