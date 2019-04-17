#! /bin/bash

#  Copyright (C) 2019 Alexandros Theodotou <alex at zrythm dot org>
#
#  This file is part of Zrythm
#
#  Zrythm is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Zrythm is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Zrythm.  If not, see <https://www.gnu.org/licenses/>.
#

# Notes:
# 1. This script assumes you have all the dependencies
#   installed using HomeBrew.
# 2. Meant to be run from the parent dir
# 3. Uses appdmg (brew install npm, npm -g appdmg)
# 4. need to install librsvg and then reinstall gdk-pixbuf
#   in brew to get svgs upport

set -e

# script for pulling together a MacOSX app bundle.

GTKSTACK_ROOT=/usr/local
BUILD_ROOT=build

SAE=
STRIP=1
PRINT_SYSDEPS=
WITH_NLS=
PROGRAM_VERSION="0.4.003"
major_version=${PROGRAM_VERSION:0:1}

APPNAME=Zrythm
BUNDLENAME=Zrythm
lower_case_appname=zrythm;

echo "Version is $major_version"
if [ "x$commit" != "x" ] ; then
    info_string="$major_version ($commit) built on `hostname` by `whoami` on `date`"
else
    info_string="$major_version built on `hostname` by `whoami` on `date`"
fi
echo "Info string is $info_string"

if [ x$DEBUG = xT ]; then
	STRIP=
	echo "Debug build, strip disabled"
else
	if test x$STRIP != x ; then
		echo "No debug build, strip enabled"
	else
		echo "No debug build, but strip disabled."
	fi
fi

# setup directory structure

OSXDIR=$BUILD_ROOT/osx
APPDIR=$OSXDIR/${BUNDLENAME}.app
TMPDIR=$OSXDIR/tmp
mkdir -p $TMPDIR
APPROOT=$APPDIR/Contents
Resources=$APPROOT/Resources
PRODUCT_PKG_DIR=$OSXDIR/Zrythm

#
# Since this is OS X, don't try to distinguish between etc and shared
# (machine dependent and independent data) - just put everything
# into Resources.
#
Bin=$Resources/bin
Share=$Resources/share
Etc=$Resources/etc
Locale=$Resources/share/locale
Lib=$Resources/lib

if [ x$PRINT_SYSDEPS != x ] ; then
#
# print system dependencies
#

echo "system dependencies:"
for file in $BUILD_ROOT/zrythm ; do
	if ! file $file | grep -qs Mach-O ; then
	    continue
	fi
	otool -L $file | awk '{print $1}' | egrep -v "(^$BUILD_ROOT*)"
    done | sort | uniq
fi

echo "Removing old $APPDIR tree ..."

rm -rf $APPDIR

echo "Building new app directory structure ..."

# only bother to make the longest paths

mkdir -p $APPROOT/MacOS
mkdir -p $Etc
mkdir -p $Locale
mkdir -p $Lib
mkdir -p $Bin


EXECUTABLE=${BUNDLENAME}

env=""
info_string="$PROGRAM_VERSION, (C) 2018-2019 Alexandros Theodotou https://www.zrythm.org"

echo "updating plists"
# edit plist
sed -e "s?@ENV@?$env?g" \
    -e "s?@VERSION@?$PROGRAM_VERSION?g" \
    -e "s?@INFOSTRING@?$info_string?g" \
    -e "s?@IDSUFFIX@?$EXECUTABLE?g" \
    -e "s?@BUNDLENAME@?$BUNDLENAME?g" \
    -e "s?@EXECUTABLE@?$EXECUTABLE?g" < data/Info.plist.in > $TMPDIR/Info.plist
# and plist strings
mkdir -p $TMPDIR/Resources
sed -e "s?@APPNAME@?$appname?" \
    -e "s?@ENV@?$env?g" \
    -e "s?@VERSION@?$major_version?g" \
    -e "s?@INFOSTRING@?$info_string?g" < data/InfoPlist.strings.in > $TMPDIR/Resources/InfoPlist.strings || exit 1

# copy static files

echo "copying plists"
cp $TMPDIR/Info.plist $APPROOT
cp -R $TMPDIR/Resources $APPROOT

# ..and clean up
rm -f $TMPDIR/Info.plist
rm -f $TMPDIR/Resources/InfoPlist.strings

#
# if we build a bundle without jack, then
# make the Ardour executable a helper
# script that checks to see if JACK is
# installed.
#

cp scripts/osx_startup_script.sh $APPROOT/MacOS/$EXECUTABLE
chmod 775 $APPROOT/MacOS/$EXECUTABLE
MAIN_EXECUTABLE=zrythm  ## used in startup_script

echo "Copying zrythm executable ...."
cp $BUILD_ROOT/zrythm $Bin/
cp data/zrythm.icns $Resources/

set +e # things below are not error-free (optional files etc) :(

#
# Copy stuff that may be dynamically loaded
#

# etc gtk
cp -RL $GTKSTACK_ROOT/etc/gtk-3.0 $Etc/

# charset alias
cp -RL $GTKSTACK_ROOT/lib/charset.alias $Lib/

# GDK Pixbuf
echo "copying gdk pixbuf loaders"
GDK_PIXBUF_DIR=gdk-pixbuf-2.0/2.10.0
mkdir -p $Lib/$GDK_PIXBUF_DIR
cp -RL $GTKSTACK_ROOT/lib/$GDK_PIXBUF_DIR/loaders.cache $Lib/$GDK_PIXBUF_DIR/
cp -RL $GTKSTACK_ROOT/lib/$GDK_PIXBUF_DIR/loaders $Lib/$GDK_PIXBUF_DIR/

# localization
echo "copying languages"
languages="fr de it es ja"
for lang in $languages; do
  CUR_DIR="$Locale/$lang/LC_MESSAGES"
  mkdir -p $CUR_DIR
  cp po/$lang/zrythm.mo "$CUR_DIR/"
  cp $GTKSTACK_ROOT/share/locale/$lang/LC_MESSAGES/gtk30.mo \
    $GTKSTACK_ROOT/share/locale/$lang/LC_MESSAGES/gtk30-properties.mo \
    $CUR_DIR/
done

echo "copying Adwaita icons"
ICONS_DIR="$Share/icons"
mkdir -p "$ICONS_DIR"
cp -RL "$GTKSTACK_ROOT/share/icons/Adwaita" "$ICONS_DIR/"

echo "copying existing hicolor icons"
cp -RL "$GTKSTACK_ROOT/share/icons/hicolor" "$ICONS_DIR/"

echo "copying app icon"
APPICON_DIR1=$ICONS_DIR/hicolor/scalable/apps
APPICON_DIR2=$ICONS_DIR/hicolor/48x48/apps
cp resources/icons/zrythm/zrythm.svg $APPICON_DIR1/
cp resources/icons/zrythm/zrythm.svg $APPICON_DIR2/

echo "copying fonts"
cp -R resources/fonts "$Share/"

SCHEMAS_DIR="glib-2.0/schemas"
mkdir -p $Share/$SCHEMAS_DIR
mkdir -p $BUILD_ROOT/schemas
cp data/org.zrythm.gschema.xml $BUILD_ROOT/schemas/
cp $GTKSTACK_ROOT/share/$SCHEMAS_DIR/org.gtk.*.xml $BUILD_ROOT/schemas/
echo "building schemas"
glib-compile-schemas $BUILD_ROOT/schemas/
echo "copying schemas"
cp "$BUILD_ROOT/schemas/gschemas.compiled" \
  "$Share/$SCHEMAS_DIR/"

# copy libs
STDCPP='|libstdc\+\+'
while [ true ] ; do
    missing=false
    for file in $Bin/* $Lib/* ; do
	if ! file $file | grep -qs Mach-O ; then
	    continue
	fi
	# libffi contains "S" (other section symbols) that should not be stripped.
	if [[ $file == *"libffi"* ]] ; then
	    continue
	fi

	if test x$STRIP != x ; then
		strip -u -r -arch all $file &>/dev/null
	fi

	deps=`otool -L $file | awk '{print $1}' | egrep "($GTKSTACK_ROOT|libs/$STDCPP)" | grep -v "$(basename $file)"`
  echo "deps=$deps"
	# echo -n "."
	for dep in $deps ; do
    echo "dependency $dep"
	    base=`basename $dep`
	    if ! test -f $Lib/$base; then
		if echo $dep | grep -sq '^libs' ; then
		    cp $BUILD_ROOT/$dep $Lib
		else
		    cp -L $dep $Lib
		fi
		missing=true
	    fi
	done
    done
    if test x$missing = xfalse ; then
	# everything has been found
	break
    fi
done

# make dmg
rm -f Zrythm.dmg
appdmg data/appdmg.json Zrythm.dmg

echo "Done."
exit