"""
The Bookalope module contains a simple object model to make Bookalope's REST API
more accessible. See http://bookalope.net/
"""

import base64
import json
import re
import datetime
import requests
import babel

def _is_token(token_s):
    """
    Given a string, returns True if the string contains a Bookalope token, or
    False otherwise. A Bookalope token contains 32 lower-case hex characters,
    i.e. must match the regular expression [0-9a-f]{32}.

    :param str token_s: The string to be checked.

    :returns bool: True if the string is a valid Bookalope token, False otherwise.
    """
    return re.match(r"^[0-9a-f]{32}$", token_s or "") is not None


class TokenError(Exception):
    """
    A TokenError is raised whenever a Bookalope ID or auth token is expected but
    not provided. See the _is_token() function.
    """
    def __init__(self, token=""):
        message = "Invalid Bookalope token: " + (token or "<not set>")
        super(TokenError, self).__init__(message)


class BookalopeClient(object):
    """
    The Bookalope client provides direct access to the Bookalope server and its
    services.
    """

    def __init__(self, token=None, beta_host=False, version="v1"):
        """
        Initializes a Bookalope client instance.

        :param str token: The user's authentication token provided by Bookalope.
        :param bool beta_host: True to use Bookalope's beta services, False for production.
        :param int version: Use the given version of the API.

        :raises TokenError: If the given token is an invalid Bookalope token.
        """
        self.__token = None
        if token is not None:
            self.__token = token
        if beta_host:
            self.__host = "https://beta.bookalope.net"
        else:
            self.__host = "https://bookflow.bookalope.net"
        self.__version = version

    def __repr__(self):
        """Return a printable representation of this instance."""
        repr_s = "<{}.{} object at {}> JSON: {}".format(
            self.__class__.__module__,
            self.__class__.__name__,
            hex(id(self)),
            json.dumps({
                "token": self.__token,
                "server": self.__host,
                }))
        return repr_s

    def http_get(self, url, params=None):
        """
        Perform an HTTP GET request to the Bookalope server. If the response
        content type is JSON then this function returns whatever object was
        encoded in JSON; if the response contains an attachment then this
        function returns that attachment as a byte array.

        :param str url: The URL string of the service endpoint.
        :param dict params: An optional dictionary of param/value pairs that
                            is URL encoded and passed as part of the URL string.

        :returns: Depending on the response, either a dictionary or file download.

        :raises: An HTTP exception if the server responded with anything but
                 OK (200) or if the response contained unexpected header/body
                 data.
        """
        response = requests.get(self.__host + url, params=params, auth=(self.__token, ""))
        if response.status_code == requests.codes.ok:
            if response.headers["Content-Type"] == "application/json; charset=UTF-8":
                return response.json()
            if response.headers["Content-Disposition"].startswith("attachment"):
                return response.content
        response.raise_for_status()
        assert not "Implement: missed a success code"

    def http_post(self, url, params):
        """
        Perform an HTTP POST request to the Bookalope server. A response may or
        may not contain a body, so this function returns either whatever object
        was encoded in JSON; or None.

        :param str url: The URL string of the service endpoint.
        :param dict params: An optional dictionary of param/value pairs that will
                            be JSON encoded and passed in the request body.

        :returns: Depending on the response, either a dictionary or None.

        :raises: An HTTP exception if the server responded with anything but
                 OK (200) or CREATED (201).
        """
        response = requests.post(self.__host + url, json=params, auth=(self.__token, ""))
        if response.status_code in [requests.codes.ok, requests.codes.created]:
            if int(response.headers["Content-Length"]):
                # TODO: Check that Content-Type is JSON?
                return response.json()
            else:
                return None
        response.raise_for_status()
        assert not "Implement: missed a success code"

    def http_delete(self, url):
        """
        Perform an HTTP DELETE request to the Bookalope server.

        :param str url: The URL of the service endpoint.

        :returns: None

        :raises: An HTTP exception if the server responded with anything but
                 NO CONTENT (204).
        """
        response = requests.delete(self.__host + url, auth=(self.__token, ""))
        if response.status_code == requests.codes.no_content:
            return None
        response.raise_for_status()
        assert not "Implement: missed a success code"

    @property
    def token(self):
        """Return the Bookalope auth token of this client instance, or None."""
        return self.__token

    @token.setter
    def token(self, token):
        """
        Set the Bookalope auth token for this client instance.

        :param str token: The auth token as provided by the website.
        :raises: TokenError if the token is invalid.
        """
        if _is_token(token):
            self.__token = token
        else:
            raise TokenError(token)

    def get_profile(self):
        """
        Query the Bookalope server for the user profile data associated with the
        auth token. Return a new Profile instance that represents a Bookalope
        user profile.
        """
        return Profile(self)

    def get_styles(self, format_):
        """
        Query the Bookalope server for all available design styles for the given
        target file format.

        :param str format: The target file format, one of 'epub', 'epub3',
                           'mobi', 'pdf', 'icml', 'docx'.
        :returns list: Returns a list of Style instances, each of which describes
                       an available design style.
        """
        params = {
            "format": format_,
            }
        styles = self.http_get("/api/styles", params)["styles"]
        return [Style(format_, _) for _ in styles]

    def get_export_formats(self):
        """
        Query the Bookalope server for all available export file formats.

        :returns list: Returns a list of Format instances, each of which describes
                       a supported export file format.
        """
        formats = self.http_get("/api/formats")["formats"]
        return [Format(format_) for format_ in formats["export"]]

    def get_import_formats(self):
        """
        Query the Bookalope server for all available import file formats.

        :returns list: Returns a list of Format instances, each of which describes
                       a supported import file format.
        """
        formats = self.http_get("/api/formats")["formats"]
        return [Format(format_) for format_ in formats["import"]]

    def get_books(self):
        """
        Queries the Bookalope server for all books associated with the user.

        :returns list: Returns a list of Book instances for this user.
        """
        books = self.http_get("/api/books")
        return [Book(self, _) for _ in books["books"]]

    def create_book(self):
        """
        Create a new Book instance with the given name. Note that the books has
        not been saved to the Bookalope server yet, and needs to be saved. The
        new book has a default name '<none>' which should be changed. Note that
        the new book will also have a single empty Bookflow instance.

        :returns: A Book instance for the new book.
        """
        return Book(self)


class Profile(object):
    """
    The Profile class implements the Bookalope user profile, and provides access
    to the profile's first and last name.
    """

    def __init__(self, bookalope):
        """
        Initialize this Profile instance from the current Bookalope profile data.

        :param bookalope: A Bookalope instance.
        """
        assert isinstance(bookalope, BookalopeClient)
        self.__bookalope = bookalope
        self.__firstname = None
        self.__lastname = None
        self.update()

    def __repr__(self):
        """Return a printable representation of this instance."""
        repr_s = "<{}.{} object at {}> JSON: {}".format(
            self.__class__.__module__,
            self.__class__.__name__,
            hex(id(self)),
            json.dumps(self.pack()))
        return repr_s

    def update(self):
        """
        Queries the Bookalope server for the current profile data, and updates
        this instance with that data.

        :raises: HTTP related exceptions.
        """
        result = self.__bookalope.http_get("/api/profile")
        self.__firstname = result["user"]["firstname"]
        self.__lastname = result["user"]["lastname"]
        return None

    def save(self):
        """
        Posts this Profile's instance data to the Bookalope server, i.e. save
        first and last name.

        :raises: HTTP related exceptions.
        """
        params = self.pack()
        return self.__bookalope.http_post("/api/profile", params)

    def pack(self):
        """
        Pack this instance data into a dictionary that can be encoded as a JSON
        string and is compatible to the Bookalope profile data.

        :returns dict: First and last name packed into a dictionary.
        """
        packed = {
            "firstname": self.__firstname,
            "lastname": self.__lastname,
            }
        return packed

    @property
    def firstname(self):
        """Return the first name string of this instance."""
        return self.__firstname

    @firstname.setter
    def firstname(self, name):
        """
        Change the first name of this instance to the new value.

        :param str name: The new first name.
        """
        self.__firstname = name

    @property
    def lastname(self):
        """Return the last name string of this instance."""
        return self.__lastname

    @lastname.setter
    def lastname(self, name):
        """
        Change the last name of this instance to the new value.

        :param str name: The new last name.
        """
        self.__lastname = name


class Format(object):
    """
    A Format instance describes a file format that Bookalope supports either as
    import or export file format. It contains the mime type of the supported file
    format, and a list of file name extensions.
    """

    def __init__(self, packed):
        """
        Initialize this Format instance from a dictionary of a packed Format.

        :param dict packed: A dictionary containing packed Format information.
        """
        self.__mime = packed["mime"]
        self.__file_extensions = packed["exts"]

    def __repr__(self):
        """Return a printable representation of this instance."""
        repr_s = "<{}.{} object at {}> JSON: {}".format(
            self.__class__.__module__,
            self.__class__.__name__,
            hex(id(self)),
            json.dumps(self.pack()))
        return repr_s

    def pack(self):
        """
        Pack this instance data into a dictionary that can be encoded as a JSON
        string and is compatible to the Bookalope Format data.

        :returns dict: This Format's information as a Bookalope compatible
                       dictionary.
        """
        packed = {
            "mime": self.__mime,
            "exts": self.__file_extensions,
            }
        return packed

    @property
    def mimetype(self):
        """Return the mime type of this format."""
        return self.__mime

    @property
    def file_exts(self):
        """Return a list of file extensions for this file format."""
        return self.__file_extensions


class Style(object):
    """
    For every target file format that Bookalope generates, the user can select
    from several available design styles. This class implements a single such
    design style.
    """

    def __init__(self, format_, packed):
        """
        Initialize this Style instance from a dictionary of a packed Style.

        :param str format_: The file format this Style instance applies to.
        :param dict packed: A dictionary containing packed Style information.
        """
        self.__format = format_
        self.__short_name = packed["name"]
        self.__name = packed["info"]["name"]
        self.__description = packed["info"]["description"]
        self.__api_price = packed["info"]["price-api"]

    def __repr__(self):
        """Return a printable representation of this instance."""
        repr_s = "<{}.{} object at {}> JSON: {}".format(
            self.__class__.__module__,
            self.__class__.__name__,
            hex(id(self)),
            json.dumps(self.pack()))
        return repr_s

    def pack(self):
        """
        Pack this instance data into a dictionary that can be encoded as a JSON
        string and is compatible to the Bookalope Style data.

        :returns dict: This Style's information as a Bookalope compatible
                       dictionary.
        """
        packed = {
            "name": self.__short_name,
            "info": {
                "name": self.__name,
                "description": self.__description,
                "price-api": self.__api_price,
                },
            }
        return packed

    @property
    def format(self):
        """Return the file format this style description refers to."""
        return self.__format

    @property
    def short_name(self):
        """Return the short name of this style description."""
        return self.__short_name

    @property
    def name(self):
        """Return the descriptive name of this style description."""
        return self.__name

    @property
    def description(self):
        """Return the description string for this style."""
        return self.__description

    @property
    def api_price(self):
        """Return the price in US$ that is charged for this style by the API."""
        return self.__api_price


class Book(object):
    """
    The Book class describes a single book as used by Bookalope. A book has only
    one name, and a list of conversions: the Bookflows. Note that title, author,
    and other information is stored as part of the Bookflow, not the Book itself.
    """

    def __init__(self, bookalope, id_or_packed=None):
        """
        Create or initialize a new Book instance. The new Book instance is created
        on the Bookalope server and this instance is initialized with the new
        data. Note that the default book name is set to '<none>', and an empty
        bookflow will be created for this book as well.

        :param bookalope: A Bookalope instance.
        :param str id_or_packed: None to create a new Book instance; a valid
                                 Bookalope token string with a book id; or a
                                 dictionary containing packed book information.
        """
        assert isinstance(bookalope, BookalopeClient)
        self.__bookalope = bookalope
        if id_or_packed is None:
            params = {
                "name": "<none>",
                }
            url = "/api/books"
            book = self.__bookalope.http_post(url, params)["book"]
        elif isinstance(id_or_packed, str):
            if not _is_token(id_or_packed):
                raise TokenError(id_or_packed)
            url = "/api/books/" + id_or_packed
            book = self.__bookalope.http_get(url)["book"]
        elif isinstance(id_or_packed, dict):
            book = id_or_packed
        else:
            raise TypeError()
        self.__id = book["id"]
        self.__url = "/api/books/{}".format(self.__id)
        self.__name = book["name"]
        self.__created = datetime.datetime.strptime(book["created"], "%Y-%m-%dT%H:%M:%S")
        bookflows = book["bookflows"]
        self.__bookflows = [Bookflow(self.__bookalope, self, _) for _ in bookflows]

    def __repr__(self):
        """Return a printable representation of this instance."""
        repr_s = "<{}.{} object at {}> JSON: {}".format(
            self.__class__.__module__,
            self.__class__.__name__,
            hex(id(self)),
            json.dumps(self.pack()))
        return repr_s

    def update(self):
        """
        Queries the Bookalope server for this Book's server-side data, and updates
        this instance with that data. Note that this creates a new list with new
        Bookflow instances, that may compete with references to older Bookflow
        instances.
        """
        book = self.__bookalope.http_get(self.url)["book"]
        self.__name = book["name"]
        bookflows = book["bookflows"]
        self.__bookflows = [Bookflow(self.__bookalope, self, _) for _ in bookflows]
        return None

    def save(self):
        """
        Post this Book's instance data to the Bookalope server, i.e. stores the
        name of this book.
        """
        params = {
            "name": self.__name,
            }
        return self.__bookalope.http_post(self.url, params)

    def delete(self):
        """
        Delete this Book from the Bookalope server. Subsequent calls to save()
        will fail on the server side.
        """
        return self.__bookalope.http_delete(self.url)

    def pack(self):
        """
        Pack this instance data into a dictionary that can be encoded as a JSON
        string and is compatible to the Bookalope Book data.

        :returns dict: This Book's information as a Bookalope compatible
                       dictionary.
        """
        packed = {
            "id": self.__id,
            "name": self.__name,
            "created": self.__created.strftime("%Y-%m-%dT%H:%M:%S"),
            "bookflows": [_.pack() for _ in self.__bookflows],
            }
        return packed

    @property
    def id(self):
        """Return the Bookalope token id for this Book instance."""
        return self.__id

    @property
    def url(self):
        """Return the API endpoint URL for this Book instance."""
        return self.__url

    @property
    def name(self):
        """Return the name of this Book instance."""
        return self.__name

    @name.setter
    def name(self, name):
        """
        Change the name of this Book instance locally. Use save() to store the
        change to the Bookalope server.

        :param str name: The new book name.
        """
        self.__name = name

    @property
    def created(self):
        """
        Return a Python datetime instance that represents the date when this
        Book instance was created.
        """
        return self.__created

    @property
    def bookflows(self):
        """Return a list of Bookflow instances associated with this Book."""
        return self.__bookflows

    def create_bookflow(self):
        """
        Create a new Bookflow on the Bokalope server and return an initialized
        Bookflow instance.
        """
        bookflow = Bookflow(self.__bookalope, self)
        self.__bookflows += [bookflow]
        return bookflow


class Bookflow(object):
    """
    The Bookflow class describes a Bookalope conversion flow--the 'bookflow'. A
    bookflow also contains the book's title, author, and other related information.
    All document uploads, image handling, and conversion is handled by this
    class.
    """

    def __init__(self, bookalope, book, id_or_packed=None):
        """
        Create or initialize a new Bookflow instance. The new bookflow is created
        on the Bookalope server side, and this Bookflow instance is then initialized
        from the new bookflow data. If a valid bookflow id is given, the new
        Bookflow instance is initialized from that existing bookflow.

        Note: initialization does not update the bookflow's metadata; instead
              call update() manually. This is to prevent too many server requests.

        :param bookalope: A Bookalope instance.
        :param book: A Book instance for which this bookflow is created.
        :param str id_or_packed: None to create a new Bookflow instance; a valid
                                 Bookalope token string with a bookflow id; or
                                 a dictionary containing packed bookflow information.
        """
        assert isinstance(bookalope, BookalopeClient)
        self.__bookalope = bookalope
        if id_or_packed is None:
            params = {
                "name": "Bookflow",
                "title": "<no-title>",
                }
            url = "/api/books/{}/bookflows".format(book.id)
            bookflow = self.__bookalope.http_post(url, params)["bookflow"]
        elif isinstance(id_or_packed, str):
            if not _is_token(id_or_packed):
                raise TokenError(id_or_packed)
            url = "/api/bookflows/{}".format(id_or_packed)
            bookflow = self.__bookalope.http_get(url)["bookflow"]
        elif isinstance(id_or_packed, dict):
            bookflow = id_or_packed
        else:
            raise TypeError()
        self.__id = bookflow["id"]
        self.__name = bookflow["name"]
        self.__step = bookflow["step"]
        self.__book = book
        self.__url = "/api/bookflows/{}".format(self.__id)
        # Metadata that can be modified.
        # TODO: Consider update() here to pull in server data.
        self.__title = None
        self.__author = None
        self.__copyright = None
        self.__isbn = None
        self.__language = None
        self.__pubdate = None
        self.__publisher = None

    def __repr__(self):
        """Return a printable representation of this instance."""
        repr_s = "<{}.{} object at {}> JSON: {}".format(
            self.__class__.__module__,
            self.__class__.__name__,
            hex(id(self)),
            json.dumps(self.pack()))
        return repr_s

    def update(self):
        """
        Queries the Bookalope server for this Bookflow's server-side data, and
        updates this instance with that data.
        """
        bookflow = self.__bookalope.http_get(self.url)["bookflow"]
        self.__name = bookflow["name"]
        self.__step = bookflow["step"]
        self.__title = bookflow["title"]
        self.__author = bookflow["author"]
        self.__copyright = bookflow["copyright"]
        self.__isbn = bookflow["isbn"]
        self.__language = bookflow["language"]
        self.__pubdate = bookflow["pubdate"]
        self.__publisher = bookflow["publisher"]
        return None

    def save(self):
        """Post this Bookflow's instance data to the Bookalope server."""
        params = {
            "name": self.__name,
            }
        params.update({k:v for k, v in self.metadata().items() if v is not None})
        return self.__bookalope.http_post(self.url, params)

    def delete(self):
        """
        Delete this Bookflow from the Bookalope server. Subsequent calls to save()
        will fail on the server side.
        """
        # TODO: Remove this Bookflow from the Book's list.
        return self.__bookalope.http_delete(self.url)

    def pack(self):
        """
        Pack this instance data into a dictionary that can be encoded as a JSON
        string and is compatible to the Bookalope Book data.

        :returns dict: This Bookflow's information as a Bookalope compatible
                       dictionary.
        """
        packed = {
            "book": self.__book.id,
            "id": self.__id,
            "name": self.__name,
            "step": self.__step,
            }
        return packed

    def metadata(self):
        """Pack the bookflow metadata into a dictionary and return that dictionary."""
        metadata = {
            "title": self.__title,
            "author": self.__author,
            "copyright": self.__copyright,
            "isbn": self.__isbn,
            "language": self.__language,
            "pubdate": self.__pubdate,
            "publisher": self.__publisher,
            }
        return metadata

    @property
    def id(self):
        """Return the Bookalope token id for this Bookflow instance."""
        return self.__id

    @property
    def url(self):
        """Return the API endpoint URL for this Bookflow instance."""
        return self.__url

    @property
    def name(self):
        """Return the name of this Bookflow instance."""
        return self.__name

    @name.setter
    def name(self, name):
        """Set the name for this bookflow instance."""
        self.__name = name

    @property
    def step(self):
        """
        Return the current conversion step this Bookflow instance is currently in.
        The step changes as the bookflow itself progresses by calling methods on
        it, but it can not be modified.
        """
        return self.__step

    @property
    def book(self):
        """Return the Book instance associated with this bookflow."""
        return self.__book

    @property
    def title(self):
        """Return the title of this bookflow's book."""
        return self.__title

    @title.setter
    def title(self, title):
        """Set the title for this bookflow's book."""
        self.__title = title

    @property
    def author(self):
        """Get the author's name for this bookflow's book."""
        return self.__author

    @author.setter
    def author(self, author):
        """Set the author's name for this bookflow's book."""
        self.__author = author

    @property
    def copyright(self):
        """Get the copyright string for this bookflow's book."""
        return self.__copyright

    @copyright.setter
    def copyright(self, copyright_):
        """Set the copyright string for this bookflow's book."""
        self.__copyright = copyright_

    @property
    def isbn(self):
        """Get the ISBN number string for this bookflow's book."""
        return self.__isbn

    @isbn.setter
    def isbn(self, isbn):
        """Set the copyright string for this bookflow's book."""
        # TODO: Check if ISBN is valid ( http://bit.ly/1lV1PgI )
        self.__isbn = isbn

    @property
    def language(self):
        """Get the Babel Locale instance representing the book's language."""
        return self.__language

    @language.setter
    def language(self, language):
        """
        Given a standard language/culture name string, set this bookflow's book
        language using a Babel Locale instance.

        :param str language: A standard language/culture name, e.g. en_US that
                             specifies the book's language.
        :raises: ValueError, babel.core.UnknownLocaleError if the language string
                 is invalid.
        """
        try:
            _ = babel.core.Locale.parse(language)
            locale = babel.core.parse_locale(language)
        except (ValueError, babel.core.UnknownLocaleError):
            _ = babel.core.Locale.parse(language, sep="-")
            locale = babel.core.parse_locale(language, sep="-")
        self.__language = babel.core.get_locale_identifier(locale)

    @property
    def pubdate(self):
        """Get the publication date string of this bookflow's book."""
        return self.__pubdate

    @pubdate.setter
    def pubdate(self, pubdate):
        """Set the publication date string of this bookflow's book."""
        # TODO: Use datetime/date instance instead of string?
        self.__pubdate = pubdate

    @property
    def publisher(self):
        """Get this bookflow's book's publisher string."""
        return self.__publisher

    @publisher.setter
    def publisher(self, publisher):
        """Set this bookflow's book's publisher string."""
        self.__publisher = publisher

    def get_cover_image(self):
        """Download the cover image as a byte array from the Bookalope server."""
        return self.get_image("cover-image")

    def get_image(self, name):
        """
        Download an image with the name 'name' as a byte array from the
        Bookalope server.

        :param str name: The name of the image.
        :returns byte[]: An array of bytes of the image.
        """
        params = {
            "name": name,
            }
        # TODO: Handle file name and mime type correctly (part of the response).
        return self.__bookalope.http_get(self.url + "/files/image", params)

    def set_cover_image(self, image_filename, image_bytes):
        """
        Upload the cover image for this bookflow.

        :param str image_filename: The file name of the cover image.
        :param image_bytes: A byte array containing the image.
        """
        return self.add_image("cover-image", image_filename, image_bytes)

    def add_image(self, name, image_filename, image_bytes):
        """
        Upload an image for this bookflow using the given name.

        :param str name: A name for the image, e.g. 'cover'.
        :param str image_filename: The file name of the cover image.
        :param image_bytes: A byte array containing the image.
        """
        params = {
            "name": name,
            "filename": image_filename,
            "file": base64.b64encode(image_bytes).decode(),
        }
        return self.__bookalope.http_post(self.url + "/files/image", params)

    def get_document(self):
        """
        Download this bookflow's document. Returns a byte array of the document.
        """
        return self.__bookalope.http_get(self.url + "/files/document")

    def set_document(self, document_filename, document_bytes):
        """
        Upload a document for this bookflow. This will start the style analysis,
        and automatically extract the content and structure of the document using
        Bookalope's default heuristics. Once this call returns, the document is
        ready for conversion.

        :param str document_filename: The file name of the document.
        :param document_bytes: A byte array containing the document.
        """
        # TODO: Check that bytes are not of an unsupported format.
        params = {
            "filetype": "doc",
            "filename": document_filename,
            "file": base64.b64encode(document_bytes).decode(),
            }
        return self.__bookalope.http_post(self.url + "/files/document", params)

    def convert(self, format_, style, version="test"):
        """
        Convert and download this bookflow's document. Note that downloading a
        'test' version shuffles the letters of random words, thus making the
        document rather useless for anything but testing purposes.

        :param str format: A valid format string, one of 'epub', 'epub3', 'mobi',
                           'pdf', 'icml', 'docx'.
        :param style: A Style instance describing the styling for the converted
                      document.
        :param str version: Either a 'test' or 'final' version of the document.
        :returns: Returns the converted document.
        """
        params = {
            "format": format_,
            "styling": style.short_name,
            "version": version,
            }
        return self.__bookalope.http_get(self.url + "/convert", params)
