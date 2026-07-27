![vpsinfo_logo.png](images/vpsinfo_logo.png)


(updated: 2026-07-27)
##### Table of Contents
* [Introduction](#intro)
* [General Requirements](#require)
* [Quick Install](#quick_install)
* [Docker](#docker)
* [Caddy Reverse Proxy](#caddy-reverse-proxy)
* [GitHub Actions Container Build](#actions-container-build)
* [Installation](#installation)
* [Requirements for Specific Blocs](#require_bloc)
* [Configuration](#config)
* [Screenshots](#screens)
* [Acknowledgements](#acknowledgements)
* [License](#license)



<a name="intro"/>
# Introduction

VPSinfo is a Linux server monitoring script, written in PHP, that provides web access to system status information. It gathers the output from several common Linux commands into one web page, providing a quick overview of the system's current state.

While designed for use on a Linux Virtual Private Server (Virtuozzo or OpenVZ), VPSinfo also works fine on a dedicated server. When installed on a dedicated machine VPS-specific information is automatically excluded.

Please note that, on Virtuozzo and OpenVZ servers, the small beanc helper app may be required to access VPS status information.

VPSinfo shows the following outputs:
- `top`
- `/proc/user_beancounters` (VPS resources)
- `netstat -nt` (current TCP connections)
- `netstat -ntl` (listening TCP ports)
- `pstree` (tree view of running processes)
- `ls -a /tmp` (and ls -al /tmp )
- `vnstat` (network traffic at the interface)
- `mytop` (MySQL stats)
- `mysqlreport` (perl script, MySQL stats)
- Status of daemon processes
- Top summary section:
	- Values for oomguarpages and privvmpages (free RAM and swap usage)
	- Data transfer today through the network interface (from vnstat)
	- Current number of TCP connections
	- Web server threads, MySQL threads and queries (from mytop or mysqlreport)
	- Disk usage


#### Optional Third-party Software
These applications are not required to run VPSinfo, but if installed they are used to gather additional information
- vnstat (data transfert monitoring at the network interface) Highly recommended!
- mytop  (MySql monitoring)
- mysqlreport  (perl script, MySql monitoring).

<a name="require"/>
# General Requirements
- Linux operating system
- webserver ([Nginx](http://nginx.org/), [Apache](http://httpd.apache.org/) ...)
- PHP v8.3+
- Perl
- Gcc compiler (for beanc)


<a name="quick_install"/>
# Quick Install
For the anxious ones:
- Copy VPSinfo's folder in your web server directory, with proper user/permission.
- Configure and reload your webserver.
- Test it!

From there you should see what's missing to complete your installation.

<a name="docker"/>
# Docker

Build and run with Docker:

```bash
docker build -t vpsinfo:latest .
docker run --rm -p 8080:80 vpsinfo:latest
```

Then open: <http://localhost:8080>

## Docker Compose (host statistics enabled)

Use Docker Compose when you want the container to read host-level monitoring data:

```bash
docker compose up -d --build
```

This starts `vpsinfo` with host PID and network namespaces and bind mounts required paths from the host:

- `/tmp` -> `/tmp` (temp file listing)
- `/var/lib/vnstat` -> `/var/lib/vnstat` (vnstat database used by `vnstat`)
- `/proc/user_beancounters` -> `/proc/user_beancounters` (Virtuozzo/OpenVZ bean counters)

### GPU monitoring with Compose

The compose file includes a `vpsinfo-gpu` profile with GPU-facing device/path mappings for NVIDIA, AMD, and Intel telemetry collection.

Start GPU-enabled mode:

```bash
docker compose --profile gpu up -d --build vpsinfo-gpu
```

GPU-related paths/devices included by `vpsinfo-gpu`:

- `/dev/dri` -> `/dev/dri`
- `/dev/kfd` -> `/dev/kfd` (AMD ROCm)
- `/sys/class/drm` -> `/sys/class/drm` (DRM telemetry)
- `/proc/driver/nvidia` -> `/proc/driver/nvidia` (NVIDIA driver stats)

And runtime:

- `gpus: all` for NVIDIA container runtime integration

Open: <http://localhost>

To stop:

```bash
docker compose down
```

Notes:
- Host namespace mode is intended for Linux hosts where you need host process/network visibility.
- If your host does not provide `/proc/user_beancounters`, vpsinfo automatically falls back to standard RAM/swap stats.
- If your host does not expose one of the GPU device paths, remove that mapping or use the non-GPU `vpsinfo` service.

<a name="caddy-reverse-proxy"/>
# Caddy Reverse Proxy

## Caddy in front of a local vpsinfo container

1. Run vpsinfo on a local port:
```bash
docker run -d --name vpsinfo -p 8080:80 vpsinfo:latest
```
2. Create a `Caddyfile`:
```caddy
vpsinfo.example.com {
    reverse_proxy 127.0.0.1:8080
}
```
3. Start or reload Caddy:
```bash
caddy reload --config /etc/caddy/Caddyfile
```

## Caddy + Compose example

You can run Caddy and vpsinfo together with Compose:

```yaml
services:
  vpsinfo:
    image: vpsinfo:latest
    expose:
      - "80"

  caddy:
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - vpsinfo

volumes:
  caddy_data:
  caddy_config:
```

Use this `Caddyfile` in the same folder:
```caddy
vpsinfo.example.com {
    reverse_proxy vpsinfo:80
}
```

For GPU or host-stat collection, keep using the existing `vpsinfo` or `vpsinfo-gpu` service settings from this repository and place Caddy in front of that service.

<a name="actions-container-build"/>
# GitHub Actions Container Build

This repository now includes `.github/workflows/docker-build.yml`.

- On every push to `master`, the workflow builds and pushes a container image to GitHub Container Registry (`ghcr.io/<owner>/<repo>`).
- On version tags (for example `v2.4.0`), it publishes tagged images.
- The default branch also publishes `latest`.

<a name="installation"/>
# Installation
For the time being, installation documentation is limited to CentOS. Please share any relevant information you may have that may complete this documentation, and I will include it.

## Perl
Intallation on CentOS 6.x:
```bash
yum install \
perl-DBI \
perl-DBD-mysql --enablerepo=rpmforge-extras
```
*[rpmforge http://repoforge.org/](http://repoforge.org/)
(other perl modules may be needed)

## Gcc
Intallation on CentOS 6.x:
```bash
yum install \
gcc \
glibc-devel \
glibc-headers
```
(may be incomplete)

## Web Server
### Nginx
Server configuration bloc example:
```nginx
server {
	listen       	123.45.67.89:443 ssl;
    server_name  	VPSINFO.MYSERVER.COM;
	root 			/var/www/VPSINFO;

	### RESTRICTION ###
	# your restrictions

	### HEADERS ###
	add_header  	Cache-Control 					"public";

	### SSL - TLS ###
	add_header 		Strict-Transport-Security 		max-age=31536000;
	ssl_session_cache           shared:SSL:1m;
	ssl_certificate 			/etc/pki/https/PUBLIC_CERTIFICATE.crt;
	ssl_certificate_key 		/etc/pki/https/PRIVATE_KEY.pem;
    ssl_client_certificate      /etc/pki/CA/SELF_SIGNED_CA_CERTIFICATE.crt;
    ssl_verify_client           on;

	ssl_protocols               TLSv1.2 TLSv1.1 TLSv1;
	ssl_session_timeout         15m;

	ssl_ciphers  				HIGH:!MD5:!aNULL:!eNULL:!NULL:!DH:!EDH:!kEDH:!AESGCM;
	ssl_prefer_server_ciphers	on;

	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	### FAST CGI CONFIGURATION
	location 	~* 		\.php$ {
		try_files 		$uri 		=404;

		fastcgi_pass   					unix:/var/run/php-fpm-www.sock;
		fastcgi_split_path_info 		^(.+\.php)(/.+)$;
		fastcgi_intercept_errors 		off;
		fastcgi_index 					index.php;
		fastcgi_param SCRIPT_FILENAME 	$document_root$fastcgi_script_name;

		include 						fastcgi.conf;

		fastcgi_cache_valid  			60m;
	}


	### LOGGING ###
}
```
Note the `ssl_client_certificate`. This is actually a public certificate, and the private key is installed in my desktop/browser. I use one self-signed certificate for access, and another one for https protocol.

The `ssl_verify_client = on` prevents access without a verified key.

Using a key/certificate verification (vs password) blocs attempts of brute-force password and filename/directory attack.

<a name="require_bloc"/>
# Requirements for Specific Blocs

## [vnstat](http://humdi.net/vnstat/)

Installation on CentOS 6.x:
```bash
$ yum install vnstat --enablerepo=rpmforge
```

Configuring vnstat:
- get the name of the network interface:
```bash
$ ifconfig
```
you should see a `venet0` or a `eth0` for KVM's (do not use `venet0:x`).

- update `/etc/sysconfig/vnstat`:<br/>
`VNSTAT_OPTIONS="-i venet0"`

- you may also need to update `/etc/vnstat.conf`:<br/>
`interface "venet0"`

- make sure `/etc/cron.d/vnstat` exists and contains:<br/>
`*/5 * * * * vnstat /usr/sbin/vnstat.cron`

- you can test with:<br/>
```bash
$ vnstat -tr
```

## MySQL Report
The report should use the included `mysqlreport_a.pl`. For MySql earlier to v5.0, `mytop` seems to be the other option.

### mysqlreport A
The included mysqlreport_a.pl is a modified version of mysqlreport (2008) compatible with MySQL/Percona v5+.

### mysqlreport B
The included mysqlreport_b.pl is a modified version of [mysqlreport (2015)](https://github.com/jb-boin/mariadb/blob/5.5.30/debian/additions/mysqlreport) compatible with MySQL/Percona v5+ & MariaDB (according to the [author](https://mariadb.atlassian.net/browse/MDEV-573)).

### [mytop](http://jeremy.zawodny.com/mysql/mytop/)
Installation on CentOS 6.x:
```bash
$ yum install mytop --enablerepo=epel
```
Note: this option is untested. Mytop was built for MySQL 3.22.x, 3.23.x, and 4.x., but is said to [work](https://www.howtoforge.com/tutorial/mytop-mysql-database-monitoring/#about-mytop) with v5.0 .

## beanc
beanc is a 10 lines C program that fetches the old, but still valid, [/proc/user_beancounters](https://wiki.openvz.org/Proc/user_beancounters) data on a Linux [Virtuozzo](http://www.odin.com/products/virtuozzo/) v.3 or [OpenVZ](http://openvz.org/) VPS (Virtual Private Server).

Installation on CentOS 6.x:
```bash
$ cd VPSINFO-FOLDER-PATH/beanc/
$ sh install.sh
```


<a name="config"/>
# Configuration
This is a partial list of configuration entries. For the complete list and description, please refer to `config.php`.

**$vnstat**<br/>
`0 = disabled`<br/>
`1 = enabled`<br/>

**$mysql_mon**<br/>
`0 = none`<br/>
`1 = mytop`<br/>
`2 = mysqlreport_a   (mysql/percona)`<br/>
`3 = mysqlreport_b   (mysql/percona, MariaDB)`<br/>

**$gpu_mon**<br/>
`0 = disabled`<br/>
`1 = enabled`<br/>

**$gpu_refresh**<br/>
Popup refresh interval in minutes for the GPU window.<br/>

**Database Access**<br/>
Not needed if `$mysql_mon = 0`.<br/>

Socket has priority if defined.<br/>
`$my_socket = '/var/lib/mysql/mysql.sock';`<br/>

Then host IP if no socket. Avoid 'localhost', save a dns lookup.<br/>
`$my_host   = '127.0.0.1';`<br/>
`$my_port   = '3306';`<br/>

Only required by mytop<br/>
`$my_db     = 'mysql';`<br/>

And authentication.<br/>
`$my_user   = 'USERNAME';`<br/>
`$my_pass   = 'PASSWORD';`<br/>
`$userhome = '/USERNAME';`<br/>

**$processes**<br/>
`crond dovecot nginx master memcached monitorix mysqld php-fpm rsyslogd sshd vsftpd miniserv`<br/>
Process names that appear in a `ps -e` command output are shown as 'up'.<br/>




<a name="screens"/>
# Screenshots
## Main page<br/>
![main.png](images/main.png)

## Pop-ups
### Top

![top_ps-aux_a.png](images/top_ps-aux_a.png)<br/>
Popup:<br/>
![top_ps-aux_b.png](images/top_ps-aux_b.png)

![top_ps-aux_mem_a.png](images/top_ps-aux_mem_a.png)<br/>
Popup:<br/>
![top_ps-aux_mem_b.png](images/top_ps-aux_mem_b.png)

![top_logged_in_user_a.png](images/top_logged_in_user_a.png)<br/>
Popup:<br/>
![top_logged_in_user_b.png](images/top_logged_in_user_b.png)

### Netstat

![netstat_listening_a.png](images/netstat_listening_a.png)<br/>
Popup:<br/>
![netstat_listening_b.png](images/netstat_listening_b.png)

![netstat_portlist_a.png](images/netstat_portlist_a.png)<br/>
Popup:<br/>
![netstat_portlist_b.png](images/netstat_portlist_b.png)

### Whois
In the netstat list:<br/>
![netstat_whois_a_foreign_a.png](images/netstat_whois_a_foreign_a.png)<br/>
In the footer of the netstat bloc:<br/>
![netstat_whois_a_lookup_a.png](images/netstat_whois_a_lookup_a.png)<br/>
Popup:<br/>
![netstat_whois_b.png](images/netstat_whois_b.png)

### Vnstat
Clic any one:<br/>
![vnstat_a_days.png](images/vnstat_a_days.png) ![vnstat_a_month.png](images/vnstat_a_month.png) ![vnstat_a_sample.png](images/vnstat_a_sample.png)<br/>
Popup:<br/>
![vnstat_b_month.png](images/vnstat_b_month.png)

### MySQL Report
![mysql_full_report_a.png](images/mysql_full_report_a.png)<br/>
Popup:<br/>
![mysql_full_report_b.png](images/mysql_full_report_b.png)

### Temp files<br/>
![ls-al~tmp_a.png](images/ls-al~tmp_a.png)<br/>
Popup:<br/>
![ls-al~tmp_b.png](images/ls-al~tmp_b.png)

<a name="acknowledgements"/>
# Acknowledgements
Original VPSinfo was developped by Douglas T. Robbins at [labradordata.ca](http://www.labradordata.ca)

This script may utilize third party software:

* MyTop by Jeremy D. Zawodny,<br/>
    <http://jeremy.zawodny.com/mysql/mytop>

* mysqlreport (a) by Daniel Nichter,<br/>
    <http://hackmysql.com/mysqlreport>

* mysqlreport (b) by Jean Weisbuch,<br/>
    <http://github.com/jb-boin/mariadb/blob/5.5.30/debian/additions/mysqlreport>

* vnstat by Teemu Toivola,<br/>
    <http://humdi.net/vnstat>

<a name="license"/>
# License
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

The GNU General Public License is available at:
[http://www.gnu.org/copyleft/gpl.html]()
