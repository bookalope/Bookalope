#!/usr/bin/env bash

if [ $# -ne 2 ]; then
    echo -e "Missing argument(s)\nUsage: $0 token document"
    exit 1
fi

TOKEN=$1
DOCFILE=$2
TMPDIR=$(mktemp -d)

# Make sure that the document actually exists.
if [ ! -f "$DOCFILE" ]; then
    echo "Document $DOCFILE does not exist, exiting"
    exit 1
fi

# Check that Python 3 is available.
if [ ! `builtin type -p python3` ]; then
    echo "This script requires Python 3 to be installed, exiting"
    exit 1
fi

# Check that the token has the right format.
if [[ ! $TOKEN =~ ^[0-9a-fA-F]{32}$ ]]; then
    echo "Malformed Bookalope API token, exiting"
    exit 1
fi

# The Bookalope server.
APIHOST="https://bookflow.bookalope.net"
echo "Talking to server $APIHOST"

# Separate path, filename, and extension of the document.
DOCPATH=$(dirname "$DOCFILE")
DOCNAME=$(basename "$DOCFILE")
DOCBASE="${DOCNAME%.*}"

if [ `builtin type -p http` ]; then

    # Check that the token authenticates correctly.
    if [ ! `http --headers --auth $TOKEN: GET $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
        echo "Wrong Bookalope API token, exiting"
        exit 1
    fi

    # Create a new book.
    echo "Creating new Book..."
    BOOKID=`http --json --print=b --auth $TOKEN: POST $APIHOST/api/books name="$DOCBASE" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id']);"`
    echo "Done, id=$BOOKID"

    # Create a new bookflow "Bookflow 1" for the book.
    echo "Creating new Bookflow..."
    BOOKFLOWID=`http --json --print=b --auth $TOKEN: POST $APIHOST/api/books/$BOOKID/bookflows name="Bookflow 1" title="$DOCBASE" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['id']);"`
    echo "Done, id=$BOOKFLOWID"

    # Upload the manuscript which automatically converts it using defaults.
    echo "Uploading and analyzing book document..."
    base64 "$DOCFILE" > "$TMPDIR/$DOCNAME.base64"
    http --json --timeout 300 --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document file=@"$TMPDIR/$DOCNAME.base64" filename="$DOCNAME" filetype=doc
    echo "Done"

    # Download the converted results.
    echo "Converting and downloading books..."
    http --download --timeout 300 --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID/convert format==epub version==test
    http --download --timeout 300 --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID/convert format==mobi version==test
    http --download --timeout 300 --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID/convert format==pdf version==test
    http --download --timeout 300 --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID/convert format==icml version==test
    http --download --timeout 300 --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID/convert format==docx version==test
    http --download --timeout 300 --auth $TOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID/convert format==docbook version==test
    echo "Done"

    # Delete the book and all of its bookflows.
    echo "Deleting book and bookflows..."
    http --auth $TOKEN: DELETE $APIHOST/api/books/$BOOKID
    echo "Done"

else

    if [ `builtin type -p curl` ]; then

        # Check that the token authenticates correctly.
        if [ ! `curl --user $TOKEN: --request GET -s -D - -o /dev/null $APIHOST/api/profile | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
            echo "Wrong Bookalope API token, exiting"
            exit 1
        fi

        # Create a new book.
        echo "Creating new Book..."
        BOOKID=`curl --user $TOKEN: --header "Content-Type: application/json" --data '{"name":"'$DOCBASE'"}' --request POST $APIHOST/api/books | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id']);"`
        echo "Done, id=$BOOKID"

        # Create a new bookflow "Bookflow 1" for the book.
        echo "Creating new Bookflow..."
        BOOKFLOWID=`curl --user $TOKEN: --header "Content-Type: application/json" --data '{"name":"Bookflow 1", "title":"'$DOCBASE'"}' --request POST $APIHOST/api/books/$BOOKID/bookflows | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['id']);"`
        echo "Done, id=$BOOKFLOWID"

        # Upload the manuscript which automatically converts it using defaults.
        echo "Uploading and analyzing book document..."
        echo '{"filetype":"doc", "filename":"'$DOCNAME'", "file":"' > "$TMPDIR/$DOCNAME.json"
        base64 "$DOCFILE" >> "$TMPDIR/$DOCNAME.json"
        echo '"}' >> "$TMPDIR/$DOCNAME.json"
        curl --user $TOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$DOCNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document
        echo "Done"

        # Download the converted results.
        echo "Converting and downloading books..."
        curl --user $TOKEN: --output $BOOKFLOWID.epub --request GET $APIHOST/api/bookflows/$BOOKFLOWID/convert?format=epub\&version=test
        curl --user $TOKEN: --output $BOOKFLOWID.mobi --request GET $APIHOST/api/bookflows/$BOOKFLOWID/convert?format=mobi\&version=test
        curl --user $TOKEN: --output $BOOKFLOWID.pdf --request GET $APIHOST/api/bookflows/$BOOKFLOWID/convert?format=pdf\&version=test
        curl --user $TOKEN: --output $BOOKFLOWID.icml --request GET $APIHOST/api/bookflows/$BOOKFLOWID/convert?format=icml\&version=test
        curl --user $TOKEN: --output $BOOKFLOWID.docx --request GET $APIHOST/api/bookflows/$BOOKFLOWID/convert?format=docx\&version=test
        curl --user $TOKEN: --output $BOOKFLOWID.xml --request GET $APIHOST/api/bookflows/$BOOKFLOWID/convert?format=docbook\&version=test
        echo "Done"

        # Delete the book and all of its bookflows.
        echo "Deleting book and bookflows..."
        curl --user $TOKEN: --request DELETE $APIHOST/api/books/$BOOKID
        echo "Done"

    else
        echo "Unable to find http or curl command, exiting"
        exit 1
    fi
fi
rm -fr $TMPDIR
exit 0
