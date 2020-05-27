#!/bin/sh

set -e

TOKEN=`cat token`

if [ -z "$TOKEN" ]; then
    echo "token is empty"
    exit 1
fi

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

OPAMF=packages/$PROJ/$PROJ.$REV/opam

if [ ! -f $OPAMF ]; then
    echo "$OPAMF: not found"
    exit 2
fi

if [ ! -f $OPAMF.bak ]; then
    cp $OPAMF $OPAMF.bak
fi

URL_orig=`grep src: $OPAMF.bak | sed -e 's/.*: "//' -e 's/"//'`

if [ -z "$URL_orig" ]; then
    echo "original URL not found"
    exit 2
fi

SRC=$HOME/.share/projects/$PROJ

if [ ! -d $SRC ]; then
    echo "$SRC: not found"
    exit 2
fi

rm -rf $PROJ
git clone https://gitlab.com/camlspotter/$PROJ
(cd $PROJ;
 git checkout -f origin/hg-b$REV;
 mkdir .bak; mv * .[A-z]* .bak || echo ok; mv .bak/.git .;
 mkdir .orig; (cd .orig; (curl $URL_orig | tar xvf -); mv */* */.[A-z]* ..);
 git checkout -b b$REV;
 git commit -m "recover $REV" . --allow-empty;
 git tag -f $REV;
 git push -u -f origin b$REV;
 git push -f --tags
)

echo TAGGED $REV

curl -L "https://gitlab.com/api/v4/projects/camlspotter%2F$PROJ?access_token=$TOKEN&visibility=public" -X PUT | jq | grep visibility

sed -E -e 's|homepage: "https?://bitbucket.org/camlspotter/(.*)"|homepage: "https://gitlab.com/camlspotter/\1"|' \
    -e 's|https?://bitbucket.org/camlspotter/(.*)/issues\?status=new&status=open|https://gitlab.com/camlspotter/\1/-/issues|' \
    -e 's|dev-repo: "hg\+https://bitbucket.org/camlspotter/(.*)"|dev-repo: "git+https://gitlab.com/camlspotter/\1"|' \
    -e 's|dev-repo: "hg\+https://bitbucket.org/camlspotter/(.*)"|dev-repo: "git+https://gitlab.com/camlspotter/\1"|' \
    -e 's|src: "https://bitbucket.org/camlspotter/(.*)/get/(.*).tar.gz"|src: "https://gitlab.com/camlspotter/\1/-/archive/\2/\1-\2.tar.bz2"|' < $OPAMF > ./tmp

URL=`grep src: tmp | sed -e 's/.*src: "//' -e 's/".*//'`
echo Getting $URL
curl -L $URL > /tmp/archive
tar tvf /tmp/archive
CHKSM=`md5sum /tmp/archive | awk '{ print $1 }'`

sed -e "s/checksum: \"md5=.*\"/checksum: \"md5=$CHKSM\"/" < ./tmp > $OPAMF

rm -f ./tmp

git checkout origin/master
git checkout -b $PROJ.$REV
git commit -m "fix for $PROJ.$REV" packages/$PROJ/$PROJ.$REV
git push -u private $PROJ.$REV

opam lint $OPAMF
