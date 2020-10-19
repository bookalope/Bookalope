#!/usr/bin/env bash
#
# Upgrade and/or fix an EPUB file using the Bookalope cloud service. Read the code for details 🤓

# Talk to the production server by default, or use -b/--beta to switch servers.
APIHOST="https://bookflow.bookalope.net"
APITOKEN=""

# Associate a credit with the conversion if one is available from the user's account. The credit
# is required for a full ebook conversion (i.e. no scrambled text content). Note that this script
# uses Bookalope's REST API, and that requires a 'pro' credit.
EBOOKCREDIT=""

# Create a temporary work directory.
TMPDIR=$(mktemp -d)

# Make sure that we remove the temporary directory upon exit.
trap "rm --recursive --force $TMPDIR" exit

# Parse the options and arguments of this script. We need to support the old version of
# `getopt` as well as the updated one. More info: https://github.com/jenstroeger/Bookalope/issues/6
getopt -T > /dev/null
GETOPT=$?
if [ $GETOPT -eq 4 ]; then
    OPTIONS=`getopt --quiet --options hbo:kt:a:i:p:c: --longoptions help,beta,token:,keep,title:,author:,isbn:,publisher:,credit: -- "$@"`
    if [ $? -ne 0 ]; then
        echo "Error parsing command line options, exiting"
        exit 1
    fi
    eval set -- "$OPTIONS"
else
    OPTIONS=`getopt hbo:kt:a:i:p:c: $* 2> /dev/null`
    if [ $? -ne 0 ]; then
        echo "Error parsing command line options, exiting"
        exit 1
    fi
    set -- $OPTIONS
fi
while true; do
    case "$1" in
    -h | --help)
        echo "Usage: $(basename $0) [OPTIONS] epub"
        echo -e "Upgrade and/or fix an EPUB file using the Bookalope cloud service.\n"
        echo "Options are:"
        if [ $GETOPT -eq 4 ]; then
            echo "  -h, --help             Print this help and exit."
            echo "  -b, --beta             Use Bookalope's Beta server, not its production server."
            echo "  -o, --token token      Use this authentication token."
            echo "  -k, --keep             Keep the Bookflow on the server, do not delete."
            echo "  -t, --title title      Set the ebook's metadata: title."
            echo "  -a, --author author    Set the ebook's metadata: author."
            echo "  -i, --isbn isbn        Set the ebook's metadata: ISBN number."
            echo "  -p, --publisher pub    Set the ebook's metadata: publisher."
            echo "  -c, --credit credit    Add a credit of type 'basic' or 'pro' to the Bookflow."
        else
            echo "  -h            Print this help and exit."
            echo "  -b            Use Bookalope's Beta server, not its production server."
            echo "  -o token      Use this authentication token."
            echo "  -k            Keep the Bookflow on the server, do not delete."
            echo "  -t title      Set the ebook's metadata: title."
            echo "  -a author     Set the ebook's metadata: author."
            echo "  -i isbn       Set the ebook's metadata: ISBN number."
            echo "  -p publisher  Set the ebook's metadata: publisher."
            echo "  -c credit     Add a credit of type 'basic' or 'pro' to the Bookflow."
        fi
        echo -e "\nNote that the metadata of the original EPUB file overrides the command line options."
        exit 0
        ;;
    -b | --beta)
        APIHOST="https://beta.bookalope.net"
        shift
        ;;
    -o | --token)
        APITOKEN="$2"
        if [[ ! "$APITOKEN" =~ ^[0-9a-fA-F]{32}$ ]]; then
            echo "Malformed Bookalope API token, exiting"
            exit 1
        fi
        shift 2
        ;;
    -k | --keep)
        KEEPBOOKFLOW=true
        shift
        ;;
    -t | --title)
        METATITLE="$2"
        shift 2
        ;;
    -a | --author)
        METAAUTHOR="$2"
        shift 2
        ;;
    -i | --isbn)
        METAISBN="$2"
        shift 2
        ;;
    -p | --publisher)
        METAPUBLISHER="$2"
        shift 2
        ;;
    -c | --credit)
        EBOOKCREDIT="$2"
        if [[ ! "$EBOOKCREDIT" =~ ^(basic|pro)$ ]]; then
            echo "Conversion credit must be either 'basic' or 'pro'."
            exit 1
        fi
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Error parsing command line options, exiting"
        exit 1
        ;;
    esac
done
if [ $# -ne 1 ]; then
    echo "No EPUB file specified, exiting"
    exit 1
fi

# Last entry in the command line must be the ebook file's path.
EBOOKFILE=$1

# Make sure that the ebook file actually exists, and that it's an EPUB file.
if [ ! -f "$EBOOKFILE" ]; then
    echo "Specified file $EBOOKFILE does not exist, exiting"
    exit 1
fi
if [ `builtin type -p file` ] && [ `file --mime-type --brief $EBOOKFILE` != "application/epub+zip" ]; then
    echo "Specified file $EBOOKFILE is not an EPUB file, exiting"
    exit 1
fi

# Check that Python 3 is available.
if [ ! `builtin type -p python3` ]; then
    echo "This script requires Python 3 to be installed, exiting"
    exit 1
fi

# Confirm which Bookalope server is being used.
echo "Talking to Bookalope server $APIHOST"

# Separate path, filename, and extension of the document.
EBOOKPATH=$(dirname "$EBOOKFILE")
EBOOKNAME=$(basename "$EBOOKFILE")
EBOOKBASE="${EBOOKNAME%.*}"

# Wait for a given number of seconds while showing a spinner.
function wait() {
    local COUNT=$1
    while ((COUNT--)); do
        for SPIN in '-' '\' '|' '/'; do
            echo -en "Waiting for Bookflow to finish $SPIN \r"
            sleep 0.25
        done
    done
}

# Use httpie to talk to the Bookalope server.
if [ `builtin type -p http` ]; then

    # Check if the server is alive and responding, make sure that the Bookalope token authenticates
    # correctly with the server, and that the API version is correct.
    APITEST=`http --headers --auth $APITOKEN: HEAD $APIHOST/api/profile`
    if [ $? != 0 ]; then
        echo "Unable to connect to server $APIHOST, existing"
        exit 1
    fi
    if [ ! `echo "$APITEST" | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
        echo "Wrong Bookalope API token, exiting"
        exit 1
    fi
    APIVER=`echo "$APITEST" | grep X-Bookalope-Api-Version | cut -d ' ' -f 2`
    if [ ! "${APIVER//[$'\t\r\n ']}" == "1.2.0" ]; then
        echo "Invalid API server version, please update this client; exiting"
        exit 1
    fi

    # Create a new book, and use the book's initial bookflow.
    echo "Creating new Book..."
    read -r BOOKID BOOKFLOWID <<< `http --ignore-stdin --json --print=b --auth $APITOKEN: POST $APIHOST/api/books name="$EBOOKBASE" title="$METATITLE" author="$METAAUTHOR" isbn="$METAISBN" publisher="$METAPUBLISHER" | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id'], obj['book']['bookflows'][0]['id']);"`
    echo "Done, Book id=$BOOKID, Bookflow id=$BOOKFLOWID"

    # If we've purchased a plan through the Bookalope website, then we can now credit this
    # Bookflow, thus getting access to the full version of the book.
    if [ ! -z "$EBOOKCREDIT" ]; then
        http --ignore-stdin --json --print= --auth $TOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/credit type="$EBOOKCREDIT"
    fi

    # Upload the ebook file which automatically ingests its content and styling. Passing the `skip_analysis`
    # argument here tells Bookalope to ignore the AI-assisted semantic structuring of the ebook, and instead
    # carry through the ebook's visual styles (AKA WYSIWYG conversion). The result is a flat and unstructured
    # ebook, but it is at least a valid EPUB3 file. So make sure you know what you're doing here.
    echo "Uploading and ingesting ebook file: $EBOOKNAME"
    base64 "$EBOOKFILE" > "$TMPDIR/$EBOOKNAME.base64"
    http --ignore-stdin --json --print= --auth $APITOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document file=@"$TMPDIR/$EBOOKNAME.base64" filename="$EBOOKNAME" filetype=epub skip_analysis=true

    # Wait until the bookflow's step changes from 'processing' to 'convert', thus indicating that Bookalope
    # has finished noodling through the ebook.
    while true; do
        wait 5
        STEP=`http --ignore-stdin --json --print=b --auth $APITOKEN: GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
        if [ "$STEP" = "convert" ]; then
            echo "Waiting for Bookflow to finish, done!"
            break
        fi
        if [ "$STEP" = "processing_failed" ]; then
            echo "Bookalope failed to ingest the ebook, exiting"
            exit 1
        fi
    done

    # Convert the ingested ebook file to EPUB3 and download it.
    # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
    echo "Converting to EPUB3 format and downloading ebook file..."
    DOWNLOAD_URL=`http --auth $APITOKEN: POST $APIHOST/api/bookflows/$BOOKFLOWID/convert format=epub3 style=default < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
    while true; do
        wait 5
        STATUS=`http --auth $APITOKEN: GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
        case "$STATUS" in
        "processing")
            ;;
        "failed")
            echo "Bookalope failed to convert the ebook, exiting"
            exit 1
            ;;
        "available")
            echo "Waiting for Bookflow to finish, done!"
            break
            ;;
        esac
    done
    http --download --output "${EBOOKFILE%.*}-$BOOKFLOWID.epub" --ignore-stdin --print= --auth $APITOKEN: GET $DOWNLOAD_URL > /dev/tty
    echo "Saved converted ebook to file ${EBOOKFILE%.*}-$BOOKFLOWID.epub"

    # Either delete the Bookflow and its files or keep them.
    if [ "$KEEPBOOKFLOW" = true ]; then
        echo "You can continue working with your Bookflow by clicking: $APIHOST/bookflows/$BOOKFLOWID/convert"
    else
        echo "Deleting Book and Bookflow..."
        http --ignore-stdin --print= --auth $APITOKEN: DELETE $APIHOST/api/books/$BOOKID
    fi
    echo "Done"

else

    # Use curl to talk to the Bookalope server.
    if [ `builtin type -p curl` ]; then

        # Check if the server is alive and responding, make sure that the Bookalope token authenticates
        # correctly with the server, and that the API version is correct.
        APITEST=`curl --silent --show-error --user $APITOKEN: --head -s -D - -o /dev/null $APIHOST/api/profile`
        if [ $? != 0 ]; then
            echo "Unable to connect to server $APIHOST, existing"
            exit 1
        fi
        if [ ! `echo "$APITEST" | grep HTTP | cut -d ' ' -f 2` == "200" ]; then
            echo "Wrong Bookalope API token, exiting"
            exit 1
        fi
        APIVER=`echo "$APITEST" | grep X-Bookalope-Api-Version | cut -d ' ' -f 2`
        if [ ! "${APIVER//[$'\t\r\n ']}" == "1.2.0" ]; then
            echo "Invalid API server version, please update this client; exiting"
            exit 1
        fi

        # Create a new book, and use the book's initial bookflow.
        echo "Creating new Book..."
        read -r BOOKID BOOKFLOWID <<< `curl --silent --show-error --user $APITOKEN: --header "Content-Type: application/json" --data "{\"name\":\"$EBOOKBASE\",\"title\":\"$METATITLE\",\"author\":\"$METAAUTHOR\",\"isbn\":\"$METAISBN\",\"publisher\":\"$METAPUBLISHER\"}" --request POST $APIHOST/api/books | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['book']['id'], obj['book']['bookflows'][0]['id']);"`
        echo "Done, Book id=$BOOKID, Bookflow id=$BOOKFLOWID"

        # If we've purchased a plan through the Bookalope website, then we can now credit this
        # Bookflow, thus getting access to the full version of the book.
        if [ ! -z "$EBOOKCREDIT" ]; then
            echo '{"type":"'$EBOOKCREDIT'"}' > "$TMPDIR/$DOCNAME.json"
            curl --silent --show-error -output /dev/null --user $TOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$DOCNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/credit
        fi

        # Upload the ebook file which automatically ingests its content and styling. Passing the `skip_analysis`
        # argument here tells Bookalope to ignore the AI-assisted semantic structuring of the ebook, and instead
        # carry through the ebook's visual styles (AKA WYSIWYG conversion). The result is a flat and unstructured
        # ebook, but it is at least a valid EPUB3 file. So make sure you know what you're doing here.
        echo "Uploading and ingesting ebook file: $EBOOKNAME"
        echo '{"filetype":"epub", "filename":"'$EBOOKNAME'", "skip_analysis":"true", "file":"' > "$TMPDIR/$EBOOKNAME.json"
        base64 "$EBOOKFILE" >> "$TMPDIR/$EBOOKNAME.json"
        echo '"}' >> "$TMPDIR/$EBOOKNAME.json"
        curl --silent --show-error --user $APITOKEN: --header "Content-Type: application/json" --data @"$TMPDIR/$EBOOKNAME.json" --request POST $APIHOST/api/bookflows/$BOOKFLOWID/files/document

        # Wait until the bookflow's step changes from 'processing' to 'convert', thus indicating that Bookalope
        # has finished noodling through the ebook.
        while true; do
            wait 5
            STEP=`curl --silent --show-error --user $APITOKEN: --header "Content-Type: application/json" --request GET $APIHOST/api/bookflows/$BOOKFLOWID | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['bookflow']['step']);"`
            if [ "$STEP" = "convert" ]; then
                echo "Waiting for Bookflow to finish, done!"
                break
            fi
            if [ "$STEP" = "processing_failed" ]; then
                echo "Bookalope failed to ingest the ebook, exiting"
                exit 1
            fi
        done

        # Convert the ingested ebook file to EPUB3 and download it.
        # Regarding < /dev/tty see: https://github.com/jakubroztocil/httpie/issues/150#issuecomment-21419373
        echo "Converting to EPUB3 format and downloading ebook file..."
        DOWNLOAD_URL=`curl --silent --show-error --user $APITOKEN: --header "Content-Type: application/json" --data '{"format":"epub3","style":"default"}' --request POST $APIHOST/api/bookflows/$BOOKFLOWID/convert < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['download_url'])"`
        while true; do
            wait 5
            STATUS=`curl --silent --show-error --user $APITOKEN: --header "Content-Type: application/json" --request GET $DOWNLOAD_URL/status < /dev/tty | python3 -c "import json,sys;obj=json.load(sys.stdin);print(obj['status']);"`
            case "$STATUS" in
            "processing")
                ;;
            "failed")
                echo "Bookalope failed to convert the ebook, exiting"
                exit 1
                ;;
            "available")
                echo "Waiting for Bookflow to finish, done!"
                break
                ;;
            esac
        done
        curl --silent --show-error --user $APITOKEN: --output "${EBOOKFILE%.*}-$BOOKFLOWID.epub" --request GET $DOWNLOAD_URL > /dev/tty
        echo "Saved converted ebook to file ${EBOOKFILE%.*}-$BOOKFLOWID.epub"

        # Either delete the Bookflow and its files or keep them.
        if [ "$KEEPBOOKFLOW" = true ]; then
            echo "You can continue working with your Bookflow by clicking: $APIHOST/bookflows/$BOOKFLOWID/convert"
        else
            echo "Deleting Book and Bookflow..."
            curl --silent --show-error --user $APITOKEN: --request DELETE $APIHOST/api/books/$BOOKID
        fi
        echo "Done"

    else
        echo "Unable to find http or curl command, exiting"
        exit 1
    fi
fi
exit 0
