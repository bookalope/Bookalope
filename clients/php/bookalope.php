<?php

// Helper function that checks if a given string is a Bookalope token or id;
// returns TRUE if it is, FALSE otherwise.
function is_token($token) {
    return preg_match("/^[0-9a-f]{32}$/", $token) === 1;
}

// A BookalopeException is raised whenever an API call failed or returned an
// unexpeced HTTP code was returned.
class BookalopeException extends Exception { }

// A BookalopeTokenException is raised whenever an API token is expected but none
// or an ill-formatted one is given.
class BookalopeTokenException extends BookalopeException {
    public function __construct($token) {
        parent::__construct("Malformed Bookalope token: " . $token);
    }
}

// The Bookalope client provides direct access to the Bookalope server and its
// services.
class BookalopeClient {

    // Private instance variables to access the API.
    private $token;
    private $host;
    private $version;

    // Constructor.
    public function __construct($token=NULL, $beta_host=FALSE, $version="v1") {
        if ($token) {
            $this->set_token($token);
        }
        if ($beta_host) {
            $this->host = "https://beta.bookalope.net";
        }
        else {
            $this->host = "https://bookflow.bookalope.net";
        }
        $this->version = $version;
    }

    // Issue an HTTP GET request to the Bookalope server and the $url endpoint.
    // If a parameter array is given, URL encode it and append it to the given
    // $url. Returns a result object or download attachment, or raises a
    // BookalopeException in case of an error.
    public function http_get($url, $params=NULL) {
        $curl = curl_init();
        if ($params) {
            $url .= "?" . http_build_query($params);
        }
        curl_setopt($curl, CURLOPT_URL, $this->host . $url);
        curl_setopt($curl, CURLOPT_USERPWD, $this->token . ":\"\"");
        curl_setopt($curl, CURLOPT_RETURNTRANSFER, TRUE);
        curl_setopt($curl, CURLOPT_FAILONERROR, TRUE);
        curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "GET");
        $response = curl_exec($curl);
        $response_info = curl_getinfo($curl);
        curl_close($curl);
        if ($response_info["http_code"] === 200) {
            if ($response_info["content_type"] === "application/json; charset=UTF-8") {
                return json_decode($response);
            }
            if ($response_info["download_content_length"] > 0) {
                return $response;
            }
            throw new BookalopeException("Unexpected response content type: " . $response_info["content_type"]);
        }
        throw new BookalopeException("Error or unhandled return code " . $response_info["http_code"]);
    }

    // Issue an HTTP POST request to the Bookalope server and the $url endpoint.
    // If the parameter array is given, it is JSON encoded and passed in the
    // body of the request. Returns a created object or NULL, or raises a
    // BookalopeException in case of an error.
    public function http_post($url, $params=NULL) {
        $curl = curl_init();
        curl_setopt($curl, CURLOPT_URL, $this->host . $url);
        curl_setopt($curl, CURLOPT_USERPWD, $this->token . ":\"\"");
        curl_setopt($curl, CURLOPT_RETURNTRANSFER, TRUE);
        curl_setopt($curl, CURLOPT_FAILONERROR, TRUE);
        curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "POST");
        if ($params) {
            curl_setopt($curl, CURLOPT_HTTPHEADER, array("Content-Type: application/json"));
            curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($params));
        }
        $response = curl_exec($curl);
        $response_info = curl_getinfo($curl);
        curl_close($curl);
        if ($response_info["http_code"] === 200 or $response_info["http_code"] === 201) {
            if ($response_info["content_type"] === "application/json; charset=UTF-8") {
                return json_decode($response);
            }
            return NULL;
        }
        throw new BookalopeException("Error or unhandled return code " . $response_info["http_code"]);
    }

    // Issue an HTTP DELETE request to the Bookalope server and the $url endpoint.
    // Returns NULL or raises a BookalopeException in case of an error.
    public function http_delete($url) {
        $curl = curl_init();
        curl_setopt($curl, CURLOPT_URL, $this->host . $url);
        curl_setopt($curl, CURLOPT_USERPWD, $this->token . ":\"\"");
        curl_setopt($curl, CURLOPT_RETURNTRANSFER, TRUE);
        curl_setopt($curl, CURLOPT_FAILONERROR, TRUE);
        curl_setopt($curl, CURLOPT_CUSTOMREQUEST, "DELETE");
        $response = curl_exec($curl);
        $response_info = curl_getinfo($curl);
        curl_close($curl);
        if ($response_info["http_code"] === 204) {
            return NULL;
        }
        throw new BookalopeException("Error or unhandled return code " . $response_info["http_code"]);
    }

    // Set the Bookalope authentication token.
    public function set_token($token) {
        if (!is_token($token)) {
            throw new BookalopeTokenException($token);
        }
        $this->token = $token;
    }

    // Get the Bookalope token that's currently used to authenticate requests.
    public function get_token() {
        return $this->token;
    }

    // Return a list of supported export file formats.
    public function get_export_formats() {
        $formats = $this->http_get("/api/formats")->formats;
        $formats_list = array();
        foreach ($formats->export as $format) {
            $formats_list[] = new Format($format);
        }
        return $formats_list;
    }

    // Return a list of supported import file formats.
    public function get_import_formats() {
        $formats = $this->http_get("/api/formats")->formats;
        $formats_list = array();
        foreach ($formats->import as $format) {
            $formats_list[] = new Format($format);
        }
        return $formats_list;
    }

    // Return a list of available Styles for the given file format, or NULL if
    // if the $format was invalid.
    public function get_styles($format) {
        $params = array("format" => $format);
        $styles = $this->http_get("/api/styles", $params)->styles;
        $styles_list = array();
        foreach ($styles as $style) {
            $styles_list[] = new Style($format, $style);
        }
        return $styles_list;
    }

    // Return the current user Profile.
    public function get_profile() {
        $profile = new Profile($this);
        return $profile;
    }

    // Return a list of all available books.
    public function get_books() {
        $books = $this->http_get("/api/books")->books;
        $book_list = array();
        foreach ($books as $book) {
            $book_list[] = new Book($this, $book);
        }
        return $book_list;
    }

    // Create a new book and bookflow, and return an instance of the new Book.
    public function create_book() {
        $book = new Book($this);
        return $book;
    }
}

// The Profile class implements the Bookalope user profile, and provides access
// to the profile's first and last name.
class Profile {

    // Private reference to the BookalopeClient.
    private $bookalope;

    // Public attributes of the Profile.
    public $firstname;
    public $lastname;

    // Constructor. Fetches initial data from the Bookalope server to initialize
    // this instance.
    public function __construct($bookalope) {
        assert($bookalope instanceof BookalopeClient);
        $this->bookalope = $bookalope;
        $this->update();
    }

    // Query the Bookalope server for current profile data, and update the
    // attributes of this instance.
    function update() {
        $profile = $this->bookalope->http_get("/api/profile")->user;
        $this->firstname = $profile->firstname;
        $this->lastname = $profile->lastname;
        return NULL;
    }

    // Save the current instance data to the Bookalope server.
    function save() {
        $params = array(
            "firstname" => $this->firstname,
            "lastname" => $this->lastname,
            );
        return $this->bookalope->http_post("/api/profile", $params);
    }
}

// For every target file format that Bookalope can generate, the user can select
// from several available design styles. This class implements a single such
// design style.
class Style {

    // Public attributes of a Bookalope Style.
    public $format;
    public $short_name;
    public $name;
    public $description;
    public $api_price;

    // Constructor. Initialize from a packed style object.
    public function __construct($format, $packed) {
        $this->format = $format;
        $this->short_name = $packed->name;
        $this->name = $packed->info->name;
        $this->description = $packed->info->description;
        $this->api_price = $packed->info->{"price-api"};
    }
}

// A Format instance describes a file format that Bookalope supports either as
// import or export file format. It contains the mime type of the supported file
// format, and a list of file name extensions.
class Format {

    // Public attributes of a Bookalope Format.
    public $mime;
    public $file_exts;

    // Constructor. Initialize from a packed format object.
    public function __construct($packed) {
        $this->mime = $packed->mime;
        $this->file_exts = $packed->exts;
    }
}

// The Book class describes a single book as used by Bookalope. A book has only
// one name, and a list of conversions: the Bookflows. Note that title, author,
// and other information is stored as part of the Bookflow, not the Book itself.
class Book {

    // Private reference to the BookalopeClient.
    private $bookalope;

    // Public attributes of the Book.
    public $id;
    public $url;
    public $name;
    public $created;
    public $bookflows;

    // Constructor. If $id_or_packed is NULL then a new book with an empty
    // bookflow are created; if it's a string then it's expected to be a valid
    // book id and the book is retrieved from the Bookalope server; if it's an
    // object then this instance is initialized based on it.
    public function __construct($bookalope, $id_or_packed=NULL) {
        assert($bookalope instanceof BookalopeClient);
        $this->bookalope = $bookalope;
        if ($id_or_packed === NULL) {
            $params = array("name" => "<none>");
            $url = "/api/books";
            $book = $this->bookalope->http_post($url, $params)->book;
        }
        else if (is_string($id_or_packed)) {
            if (!is_token($id_or_packed)) {
                throw new BookalopeTokenException($id_or_packed);
            }
            $url = "/api/books/" . $id_or_packed;
            $book = $this->bookalope->http_get($url)->book;
        }
        else if (is_object($id_or_packed)) {
            $book = $id_or_packed;
        }
        else {
            throw new BookalopeError("Unexpected parameter type: \$id_or_packed.");
        }
        $this->id = $book->id;
        $this->url = "/api/books/" . $this->id;
        $this->name = $book->name;
        $this->created = DateTime::createFromFormat("Y-m-d\TH:i:s", $book->created, new DateTimeZone("UTC"));
        $this->bookflows = array();
        foreach ($book->bookflows as $bookflow) {
            $this->bookflows[] = new Bookflow($this->bookalope, $this, $bookflow);
        }
    }

    // Query the Bookalope server for this Book's server-side data and update
    // this instance. Note that this creates a new list of new Bookflow instances
    // that may alias with other references to this Book's Bookflows.
    public function update() {
        $book = $this->bookalope->http_get($this->url)->book;
        $this->name = $book->name;
        $this->bookflows = array();
        foreach ($book->bookflows as $bookflow) {
            $this->bookflows[] = new Bookflow($this->bookalope, $book, $bookflow);
        }
        return NULL;
    }

    // Post this Book's instance data to the Bookalope server, i.e. store the
    // name of this book.
    public function save() {
        $params = array("name" => $this->name);
        return $this->bookalope->http_post($this->url, $params);
    }

    // Delete this Book from the Bookalope server. Subsequent calls to save()
    // will fail on the server side.
    public function delete() {
        return $this->bookalope->http_delete($this->url);
    }
}

// The Bookflow class describes a Bookalope conversion flow--the 'bookflow'. A
// bookflow also contains the book's title, author, and other related information.
// All document uploads, image handling, and conversion is handled by this class.
class Bookflow {

    // Private reference to the BookalopeClient.
    private $bookalope;

    // Public attributes of a Bookflow.
    public $id;
    public $name;
    public $step;
    public $book;
    public $url;

    // Metadata of a Bookflow.
    public $title;
    public $author;
    public $copyright;
    public $isbn;
    public $language;
    public $pubdate;
    public $publisher;

    // Constructor. If $id_or_packed is NULL then a new Bookflow is created;
    // if it's a string then it's expected to be a valid bookflow id and the
    // bookflow is retrieved from the Bookalope server; if it's a object then
    // this instance is initialized based on it.
    public function __construct($bookalope, $book, $id_or_packed=NULL) {
        assert($bookalope instanceof BookalopeClient);
        $this->bookalope = $bookalope;
        if ($id_or_packed === NULL) {
            $params = array(
                "name" => "Bookflow",
                "title" => "<no-title>"
                );
            $url = "/api/books/" . $book->id . "/bookflows";
            $bookflow = $this->bookalope->http_post($url, $params)->bookflow;
        }
        else if (is_string($id_or_packed)) {
            if (!is_token($id_or_packed)) {
                throw new BookalopeTokenException($id_or_packed);
            }
            $url = "/api/books/" . $book->id . "/bookflows/" . $id_or_packed;
            $bookflow = $this->bookalope->http_get($url)->bookflow;
        }
        else if (is_object($id_or_packed)) {
            $bookflow = $id_or_packed;
        }
        else {
            throw new BookalopeError("Unexpected parameter type: \$id_or_packed.");
        }
        $this->id = $bookflow->id;
        $this->name = $bookflow->name;
        $this->step = $bookflow->step;
        $this->book = $book;
        $this->url = "/api/books/" . $book->id . "/bookflows/" . $bookflow->id;
        // Metadata
        // TODO: Consider update() here to pull in server data.
        $this->title = NULL;
        $this->author = NULL;
        $this->copyright = NULL;
        $this->isbn = NULL;
        $this->language = NULL;
        $this->pubdate = NULL;
        $this->publisher = NULL;
    }

    // Query the Bookalope server for this Bookflow's server-side data, and
    // update this instance with that data.
    public function update() {
        $bookflow = $this->bookalope->http_get($this->url)->bookflow;
        $this->title = $bookflow->title;
        $this->author = $bookflow->author;
        $this->copyright = $bookflow->copyright;
        $this->isbn = $bookflow->isbn;
        $this->language = $bookflow->language;
        $this->pubdate = $bookflow->pubdate;
        $this->publisher = $bookflow->publisher;
        return NULL;
    }

    // Post this Bookflow's instance data to the Bookalope server.
    public function save() {
        $params = array("name" => $this->name);
        foreach ($this->metadata() as $key => $value) {
            if ($value !== NULL) {
                $params[$key] = $value;
            }
        }
        return $this->bookalope->http_post($this->url, $params);
    }

    // Delete this Bookflow from the Bookalope server. Subsequent calls to save()
    // will fail on the server side.
    public function delete() {
        // TODO: Remove this Bookflow from the Book's list.
        return $this->bookalope->http_delete($this->url);
    }

    // Pack this Bookflow's metadata into an associative array and return it.
    public function metadata() {
        $metadata = array(
            "title" => $this->title,
            "author" => $this->author,
            "copyright" => $this->copyright,
            "isbn" => $this->isbn,
            "language" => $this->language,
            "pubdate" => $this->pubdate,
            "publisher" => $this->publisher,
            );
        return $metadata;
    }

    // Download the cover image as a byte array from the Bookalope server.
    public function get_cover_image() {
        return $this->get_image("cover");
    }

    // Download an image with the name 'name' as a byte array from the Bookalope
    // server.
    public function get_image($name) {
        $params = array(
            "name" => $name,
            );
        return $this->bookalope->http_get($this->url . "/files/image", $params);
    }

    // Upload the cover image for this bookflow.
    public function set_cover_image($filename, $filebytes) {
        return $this->add_image("cover", $filename, $filebytes);
    }

    // Upload an image for this bookflow using the given name.
    public function add_image($name, $filename, $filebytes) {
        $params = array(
            "name" => $name,
            "filename" => $filename,
            "file" => base64_encode($filebytes),
            );
        return $this->bookalope->http_post($this->url . "/files/image", $params);
    }

    // Download this bookflow's document. Returns a byte array of the document.
    public function get_document() {
        return $this->bookalope->http_get($this->url . "/files/document");
    }

    // Upload a document for this bookflow. This will start the style analysis,
    // and automatically extract the content and structure of the document using
    // Bookalope's default heuristics. Once this call returns, the document is
    // ready for conversion.
    public function set_document($filename, $filebytes) {
        // TODO: Check that bytes are not of an unsupported format.
        $params = array(
            "filename" => $filename,
            "filetype" => "doc",
            "file" => base64_encode($filebytes),
            );
        return $this->bookalope->http_post($this->url . "/files/document", $params);
    }

    // Convert and download this bookflow's document. Note that downloading a
    // 'test' version shuffles the letters of random words, thus making the
    // document rather useless for anything but testing purposes.
    public function convert($format, $style, $version="test") {
        $params = array(
            "format" => $format,
            "styling" => $style->short_name,
            "version" => $version,
            );
        return $this->bookalope->http_get($this->url . "/convert", $params);
    }
}

?>
