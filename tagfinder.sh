#!/bin/sh

# Evaluate kernel dir validity
if [ ! -d $1/.git ] || [ ! -d $2 ]; then
	echo Usage: ./tagfinder.sh [common kernel dir] [vendor kernel dir]
	echo Find the most similar tag to the provided vendor kernel, in the common kernel.
	exit
fi

# Handle relative vendor kernel paths
case $2 in
	/*) VENDOR=$2 ;;
	*) VENDOR=$PWD/$2 ;;
esac

# Get vendor kernel version
getVersion () {
. /dev/stdin <<EOF
$(grep "^$1 = [0-9]" $VENDOR/Makefile | tr -d [:space:])
EOF
}
getVersion VERSION
getVersion PATCHLEVEL
getVersion SUBLEVEL
echo Kernel version: $VERSION.$PATCHLEVEL.$SUBLEVEL

# Create temporary list of tags with the same kernel version
# and corresponding line counts of differences for further culling
cd $1
for TAG in $(git tag | grep -F $VERSION.$PATCHLEVEL); do
	git checkout -f tags/$TAG -- Makefile
	if [ $(grep "^SUBLEVEL =" Makefile | tr -d -c 0-9) -eq $SUBLEVEL ]; then
		echo Found match: $TAG
		git checkout -f tags/$TAG 2>/dev/null
		ELIGIBLE="$ELIGIBLE $TAG"
		DIFFS="$DIFFS $(diff -r -x .git ./ $VENDOR | wc -l)"
	fi
done

# Get line of smallest line count to get the correct tag
CURRENT=1
LINE=1
SMALLEST=$(echo $DIFFS | cut -d ' ' -f 1)
for COUNT in $(echo $DIFFS | cut -d ' ' -f 2-); do
	CURRENT=$(($CURRENT + 1))
	if [ $COUNT -le $SMALLEST ]; then
		LINE=$CURRENT
		SMALLEST=$COUNT
	fi
done

# Output
echo
echo Most similar: $(echo $ELIGIBLE | cut -d ' ' -f $LINE)
