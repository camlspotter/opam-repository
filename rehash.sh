#!/bin/sh

set -e

PROJ=$1
REV=$2

if [ -z "$PROJ" ]; then
    echo "project is empty"
    exit 2
fi

if [ -z "$REV" ]; then
    echo "version is empty"
    exit 2
fi

USER=$3
if [ -z "$USER" ]; then
    USER=camlspotter
fi

OPAMF=packages/$PROJ/$PROJ.$REV/opam

if [ ! -f $OPAMF ]; then
    echo "$OPAMF: not found"
    exit 2
fi

if [ ! -f $OPAMF.bak ]; then
    cp $OPAMF $OPAMF.bak
fi

URL="https://gitlab.com/$USER/$PROJ/-/archive/$REV/$PROJ-$REV.tar.bz2"
echo Getting $URL
curl -L $URL > /tmp/archive
tar tvf /tmp/archive
CHKSM=`md5sum /tmp/archive | awk '{ print $1 }'`

gsed '/^url/Q' "$OPAMF" > ./tmp
cat >> ./tmp << EOF
url {
  src: "$URL"
  checksum: "md5=$CHKSM"
}
EOF

cp ./tmp $OPAMF
echo Made $OPAMF

# sed -e "s/checksum: \"md5=.*\"/checksum: \"md5=$CHKSM\"/" < ./tmp > $OPAMF
# 
# rm -f ./tmp
# 
# git checkout origin/master
# git checkout -b $PROJ.$REV
# git commit -m "fix for $PROJ.$REV" packages/$PROJ/$PROJ.$REV
# git push -u private $PROJ.$REV
# 
# opam lint $OPAMF
