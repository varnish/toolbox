#!/bin/bash

set -e

UNIVERSE=
PKGMGR=
LOGFMT=
DIEFMT=
WARNFMT=
CLEARFMT=
GPGKEY=/tmp/varnish-plus-6.0.gpg

DIST=${DIST=}
REL=${REL=}
REPO=${REPO=60}
OVERWRITE=${OVERWRITE=y}

declare -A INSTALL_TBL
INSTALL_TBL[41]="varnish-plus varnish-plus-vmods-extra varnish-plus-addon-ssl varnish-agent varnish-plus-ha varnish-broadcaster"
INSTALL_TBL[60]="varnish-plus varnish-plus-vmods-extra varnish-plus-addon-ssl varnish-agent varnish-plus-ha varnish-broadcaster"
INSTALL_TBL[60-akamai-connector]="varnish-plus-akamai-connector"
INSTALL_TBL[60-deviceatlas]="vmod-deviceatlas"
INSTALL_TBL[60-waf]="varnish-plus-waf"

INSTALL=${INSTALL=${INSTALL_TBL[$REPO]}}

# thou shall ask no question
export DEBIAN_FRONTEND=noninteractive

usage() {
	cat << EOF
usage: VAR1=VALUE1 VAR2=VALUE2 $0

This help script aims to provide a smooth way to setup varnish-plus repositories
as well as installing software contained in them.

It takes no arguments but instead reads environment variables to adapt its
behavior:
	TOKEN		The token to acess the repository (varnish-plus/6.0 by
			default)
	DIST		Force the Linux distribution to use (ubuntu, debian, centos).
			Setting this variable disables the OS autodection, so you will
			need to set REL too
			If set to "ask", display a menu instead of trying to guess it.
	REL		The release of the current distribution (eg. xenial for ubuntu,
			7 for centos). This is only needed if you forced DIST
	OVERWRITE	If not empty, asks before removing files (repos and gpg keys)
	INSTALL		Override the list of varnish-plus packages to install
	REPO		What repository to use (60, 60-akamai-connector,
			60-deviceatlas or 60-waf). It'll impact the default
			INSTALL value.
	VERBOSE		If not empty, run the package managers in quiet mode
	GPGKEY		Where the gpg key authenticating the repository can be
			stored (default: /tmp/varnish-plus-6.0.gpg)
EOF
	exit 1
}

log() {
	echo -e $LOGFMT"$1"$CLEARFMT
}

die() {
	echo -e $DIEFMT"$1", exiting$CLEARFMT
	exit 1
}

ask() {
	echo -ne $ASKFMT"$1"$CLEARFMT
}

set_logging() {
	if [ -t 1 ]; then
		LOGFMT="\\e[1;32m"
		DIEFMT="\\e[1;31m"
		ASKFMT="\\e[1;33m"
		CLEARFMT="\\e[0m"
	fi
}
get_universe() {
	if command -v apt-get > /dev/null; then
		UNIVERSE=deb
		if [ -z "$VERBOSE" ]; then
			PKGMGR="apt-get -qq"
		else
			PKGMGR="apt-get"
		fi
		if [ -z "`ls -A /var/lib/apt/lists`" ]; then
			log "Updating apt cache"
			$PKGMGR update
		fi
	elif command -v yum > /dev/null; then
		UNIVERSE=rpm
		if [ -z "$VERBOSE" ]; then
			PKGMGR="yum -q -e 0"
		else
			PKGMGR="yum"
		fi
	else
		die "This system appears to be neither Debian nor RHEL based"
	fi
}

ensure_pkg() {
	pkg=$1
	[ -n "$PKGMGR" ] || die "No package manager specified"
	if ! command -v $pkg > /dev/null; then
		log "Installing: $pkg"
		$PKGMGR install -y $pkg
	fi
}

check_http() {
	if ! curl -qs -o /dev/null https://packagecloud.io/; then
		echo "Can't contact packagecloud.io, please make sure you have internet connectivity"
		exit 1
	fi
}

get_token() {
	if [ -z "$TOKEN" ]; then
		ask "Please enter your TOKEN: "
		read TOKEN < /dev/tty
	else
		log "Using TOKEN value from environment"
	fi

	rm_nicely $GPGKEY
	STATUSCODE=$(curl -Ls -o $GPGKEY --write-out "%{http_code}" "https://$TOKEN:@packagecloud.io/varnishplus/$REPO/gpgkey")
	if [ "$STATUSCODE" != 200 ] ; then
		die "Curl returned a \"$STATUSCODE\", either the token is wrong, or there's a network issue to packagecloud.io"
	fi
}

get_dist_auto(){
	if [[ ( -z "${DIST}" ) && ( -z "${REL}" ) ]]; then
		if [ -e /etc/lsb-release ]; then
			. /etc/lsb-release

			if [ "${ID}" = "raspbian" ]; then
				DIST=${ID}
				REL=`cut --delimiter='.' -f1 /etc/debian_version`
			else
				DIST=${DISTRIB_ID}
				REL=${DISTRIB_CODENAME}

				if [ -z "$dist" ]; then
					REL=${DISTRIB_RELEASE}
				fi
			fi

		elif [ -e /etc/debian_version ]; then
			# some Debians have jessie/sid in their /etc/debian_version
			# while others have '6.0.7'
			DIST=`cat /etc/issue | head -1 | awk '{ print tolower($1) }'`
			if grep -q '/' /etc/debian_version; then
				REL=`cut --delimiter='/' -f1 /etc/debian_version`
			else
				REL=`cut --delimiter='.' -f1 /etc/debian_version`
			fi

		elif [ -e /etc/os-release ]; then
			. /etc/os-release
			DIST=${ID}
			if [ "${DIST}" = "poky" ]; then
				REL=`echo ${VERSION_ID}`
			elif [ "${DIST}" = "sles" ]; then
				REL=`echo ${VERSION_ID}`
			elif [ "${DIST}" = "opensuse" ]; then
				REL=`echo ${VERSION_ID}`
			elif [ "${DIST}" = "opensuse-leap" ]; then
				DIST=opensuse
				REL=`echo ${VERSION_ID}`
			else
				REL=`echo ${VERSION_ID} | awk -F '.' '{ print $1 }'`
			fi

		elif [ `which lsb_release 2>/dev/null` ]; then
			# get major version (e.g. '5' or '6')
			REL=`lsb_release -r | cut -f2 | awk -F '.' '{ print $1 }'`

			# get DIST (e.g. 'centos', 'redhatenterpriseserver', etc)
			DIST=`lsb_release -i | cut -f2 | awk '{ print tolower($1) }'`

		elif [ -e /etc/oracle-release ]; then
			REL=`cut -f5 --delimiter=' ' /etc/oracle-release | awk -F '.' '{ print $1 }'`
			DIST='ol'

		elif [ -e /etc/fedora-release ]; then
			REL=`cut -f3 --delimiter=' ' /etc/fedora-release`
			DIST='fedora'

		elif [ -e /etc/redhat-release ]; then
			os_hint=`cat /etc/redhat-release  | awk '{ print tolower($1) }'`
			if [ "${os_hint}" = "centos" ]; then
				REL=`cat /etc/redhat-release | awk '{ print $3 }' | awk -F '.' '{ print $1 }'`
				DIST='centos'
			elif [ "${os_hint}" = "scientific" ]; then
				REL=`cat /etc/redhat-release | awk '{ print $4 }' | awk -F '.' '{ print $1 }'`
				DIST='scientific'
			else
				REL=`cat /etc/redhat-release  | awk '{ print tolower($7) }' | cut -f1 --delimiter='.'`
				DIST='redhatenterpriseserver'
			fi

		else
			aws=`grep -q Amazon /etc/issue`
			if [ "$?" = "0" ]; then
				REL='6'
				DIST='aws'
			else
				die "Couldn't figure the distribution/release pair (found: $DIST/$REL)"
			fi
		fi
	fi
}

get_distro() {
	if [ "$DIST" = "ask" ]; then
		cat << EOF
What OS are we currently using?
 1. Ubuntu xenial (16.04)
 2. Ubuntu bionic (18.04)
 3. Ubuntu focal (20.04)
 4. Debian stretch (9.x)
 5. Debian buster (10.x)
 6. CentOS/RedHat 7
 7. CentOS/RedHat 8
 8. Something else
EOF
		read -n 1 opt < /dev/tty
		case "$opt" in
			1)
				DIST=ubuntu
				REL=xenial
				;;
			2)
				DIST=ubuntu
				REL=bionic
				;;
			3)
				DIST=ubuntu
				REL=focal
				;;
			4)
				DIST=debian
				REL=stretch
				;;
			5)
				DIST=debian
				REL=buster
				;;
			6)
				DIST=centos
				REL=7
				;;
			7)
				DIST=centos
				REL=8
				;;
			8)
				die "\nSorry, this script in interactive mode only supports the above options"
				;;
			*)
				die "\n\"$opt\" is not a valid option"
				;;
		esac
		return
	else
		get_dist_auto
	fi

	# remove whitespace from OS and REL name
	DIST="${DIST// /}"
	REL="${REL// /}"

	if [[ ( -z "${DIST}" ) || ( -z "${REL}" ) ]]; then
		die "Couldn't figure the distribution/release pair (found: $DIST/$REL)"
	else
		log "Detected operating system as ${DIST}/${REL}."
	fi

	case "$DIST-$REL" in
		Ubuntu-16.04)
			DIST=ubuntu
			REL=xenial
		;;
		Ubuntu-18.04)
			DIST=ubuntu
			REL=bionic
		;;
		Ubuntu-20.04)
			DIST=ubuntu
			REL=focal
		;;
		debian-9)
			REL=stretch
		;;
		debian-10)
			REL=buster
		;;
		centos-7)
		;;
		redhat-7)
		;;
		centos-8)
		;;
		redhat-8)
		;;
		*)
			die "Unsupported platform ($DIST/$REL)"
	esac
}

rm_nicely() {
	if [ -e "$1" ]; then
		if [ "$OVERWRITE" = "y" ]; then
			log "Replacing $1"
			rm "$1"
			return
		fi
		ask "$1 already exist, okay to overwrite? [y/n]"
		read -n 1 opt < /dev/tty
		echo ""
		case "$opt" in
		y|Y)
			log "Replacing $1"
			rm "$1"
			;;
		*)
			die "Didn't get a \"y\", aborting"
			;;
		esac
	fi
}

prepare_repos() {
	if [ "$DIST" = ubuntu -o "$DIST" = debian ]; then
		SRCL=/etc/apt/sources.list.d/varnish-plus-$REPO.list

		ensure_pkg apt-transport-https
		ensure_pkg gnupg

		log "Adding GPG key"
		apt-key add $GPGKEY

		rm_nicely "$SRCL"
		echo "deb https://$TOKEN:@packagecloud.io/varnishplus/$REPO/$DIST/ $REL main" > $SRCL

		if [ "$REPO" = 60 -a "$DIST" = debian -a "$REL" = stretch ]; then
			SRCL=/etc/apt/sources.list.d/varnish-plus-backports.list
			rm_nicely $SRCL
			echo "deb http://deb.debian.org/debian stretch-backports main" > $SRCL
		fi

		log "Updating apt's database"
		$PKGMGR update
	elif [ $DIST = centos ]; then
		if ! rpm -q epel-release > /dev/null; then
			log "Installing epel-release to have access to jemalloc"
			yum install -y epel-release
		fi

		SRCL=/etc/yum.repos.d/varnish-plus-$REPO.repo
		rm_nicely "$SRCL"

		cat << EOF > "$SRCL"
[varnish-plus-$REPO]
name=varnish-plus-$REPO
baseurl=https://$TOKEN:@packagecloud.io/varnishplus/$REPO/el/\$releasever/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://$TOKEN:@packagecloud.io/varnishplus/$REPO/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF

		if [ "$REL" -ge 8 ]; then
			log "Disabling the varnish dnf module"
			dnf -y module disable varnish
		fi
		SRCL=/etc/yum.repos.d/mongodb-org-4.0.repo
		rm_nicely "$SRCL"

		cat << EOF > "$SRCL"
[mongodb-org-4.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.0.asc
EOF

	else
		die "What are you doing here? You shouldn't be here! $DIST isn't a valid distribution"
	fi
}

install_targets() {
	if [ -z "$INSTALL" ]; then
		log "No package to install (INSTALL variable is empty)"
	else
		log "Installing: $INSTALL"
		$PKGMGR install -y $INSTALL
	fi
}

main() {
	if [ "$1" -ne 0 ]; then
		usage
	fi
	set_logging
	get_universe
	ensure_pkg curl
	check_http
	get_token
	get_distro
	prepare_repos
	install_targets

	log "Done"
}

main $#
