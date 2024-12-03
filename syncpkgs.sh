#!/usr/bin/bash

BASEDIR=/home/shrik3/a/proj/my_pkgs
LOCK='pkgs_lock.json'

PKGS=(
	'aspectc++-nightly-bin'
	'kazv/kazv-git'
	'kazv/libkazv-git'
	'kazv/vodozemac-bindings-cpp-kazv'
	'passmenu-otp'
	'rfc'
	'bilibili-magical-danmaku'
)

confirm_or_exit() {
	read -r -p "$1 [y/N] " response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo "okay, continue .."
	else
		echo "exit.."
		exit 1
	fi
}

git_check_curr() {
	# check if current working directory clean
    if [[ ! -z "$(git status --porcelain $1)" ]]; then
		echo "$1 contains uncommited changes...abort."
		git status $1
		exit 1
	fi
}

sync_pkg() {
	# echo "checking pkg $1, path $2"
	_from_root=false
	_tracked_head=$(jq -r ".[\"$1\"] // empty" $LOCK)
    # check if tracked dir has clean vcs
    git_check_curr $1
	if [ -z "$_tracked_head" ]; then
		_from_root=true
		echo $1 not tracked before
	else
		echo $1 was tracked@$_tracked_head
	fi

	if [ ! -z "$_tracked_head" ] && ! git --git-dir=$2/.git cat-file -t $_tracked_head >/dev/null; then
		echo $LOCK seems to be corrupted for package $1
		confirm_or_exit "override all?"
		_from_root=true
		# TODO ask whether override. Abort if no
	fi
	_newhead=$(git --git-dir=$2/.git rev-parse HEAD)

    if [ "$_tracked_head" = "$_newhead" ]; then
        echo "$1 already up to date, skipped"
        return 0
    fi

	if $_from_root; then
		commitmsgs_short="$1: init"
		commitmsgs=$(git --git-dir=$2/.git log --oneline)
	else
		commitmsgs_short="$1: automated update"
		commitmsgs=$(git --git-dir=$2/.git log --oneline $_tracked_head..HEAD)
	fi
	echo "updates:"
	echo "$commitmsgs"
	# now sync the files and commit
	git --git-dir=$2/.git checkout-index -f -a --prefix=./$pkgname/
	# TODO options reply the commits
	# create commit for this (bulk) update
	# git add $1
	msg="$commitmsgs_short"
	msg+=$'\n\n'
	msg+=$commitmsgs
	jq ".[\"$1\"]=\"$_newhead\"" $LOCK > jq.tmp && mv jq.tmp $LOCK
	git add $1 $LOCK
	git commit -m "$msg"
	if [ $? -ne 0 ]; then
		echo "creating commit failed, panic!"
        # if failed, reset tracked head
        jq ".[\"$1\"]=\"$_tracked_head\"" $LOCK > jq.tmp && mv jq.tmp $LOCK
        exit 1
	fi

}

_stripped=()
_me=syncpkgs.sh
sancheck() {
	# check if current git repo is clean
	if [ ! -f $_me ]; then
		echo "you must run this script in the same dir"
		exit 1
	fi

	# check if jq tool is available
	if ! command -v jq 2 >&1 >/dev/null; then
		echo "you don't have jq tool, install it pls"
		exit 1
	fi

	# check if rsync tool is available
	if ! command -v rsync 2 >&1 >/dev/null; then
		echo "you don't have rsync tool, install it pls"
		exit 1
	fi

	# check if pkgnames are unique
	for pkg in "${PKGS[@]}"; do
		pkgname=$(basename -a $pkg)
		_stripped+=($pkgname)
	done

	# this trick by https://unix.stackexchange.com/a/606263
	readarray -td '' dups < <(
		((${#_stripped[@]} == 0)) ||
			printf '%s\0' "${_stripped[@]}" |
			LC_ALL=C sort -z |
				LC_ALL=C uniq -zd
	)

	if ((${#dups[@]} > 0)); then
		echo >&2 "package name collision:"
		printf >&2 ' - "%s"\n' "${dups[@]}"
		exit 1
	fi

}

sancheck

# main

for pkg in "${PKGS[@]}"; do
	pkgpath=${BASEDIR}/${pkg}
	pkgname=$(basename -a ${pkg})
	sync_pkg $pkgname $pkgpath
done
