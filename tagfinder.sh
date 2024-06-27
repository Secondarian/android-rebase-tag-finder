#!/bin/sh

# Check for OEM kernel
if [ -z $1 ] || [ ! -d $1 ]; then
	echo Usage: ./tagfinder.sh "[OEM kernel directory]"
	echo This will give you the most similar tag to your kernel.
	exit
fi

# Check for common kernel
if [ ! -d common  ]; then
	echo Error: Missing common kernel
	echo Clone the common kernel into a folder named "'common', in the script'"s directory.
	exit
fi

# Get OEM kernel version
getVersion () {
. /dev/stdin <<EOF
$(grep "$1 = [0-9]" $2/Makefile | tr -d [:space:])
EOF
}
getVersion VERSION $1
getVersion PATCHLEVEL $1
getVersion SUBLEVEL $1
echo Kernel version: $VERSION.$PATCHLEVEL.$SUBLEVEL

# Preliminary clean up
cd common
git clean -df >/dev/null 2>&1
git checkout . >/dev/null 2>&1

# Create temporary list of tags with the same kernel version
# and corresponding line counts of differences for further culling
for TAG in $(git tag | grep -F ${VERSION}.${PATCHLEVEL}); do
	git checkout tags/$TAG >/dev/null 2>&1
	if [ $(grep "SUBLEVEL =" Makefile | tr -d -c 0-9) -eq $SUBLEVEL ]; then
		echo Found match: $TAG
		ELIGIBLE="$ELIGIBLE $TAG"
		DIFFS="$DIFFS $(diff -r ./ ../$1 | wc -l)"
	fi
done

# Get line of smallest line count to get the correct tag
CURRENT=1
LINE=1
SMALLEST=$(echo $DIFFS | cut -d " " -f 1)
for COUNT in $(echo $DIFFS | cut -d " " -f 2-); do
	CURRENT=$(($CURRENT + 1))
	if [ $COUNT -lt $SMALLEST ]; then
		LINE=$CURRENT
		SMALLEST=$COUNT
	fi
done

# Output
echo
echo Most similar: $(echo $ELIGIBLE | cut -d " " -f $LINE)

# Restore
git checkout android-mainline >/dev/null 2>&1
