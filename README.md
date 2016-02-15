<img src="https://bookalope.net/img/bookalope-logo.png" width="50%" alt="Bookalope Logo">

## What is Bookalope?

[Bookalope](https://bookalope.net/) is a web service for document analysis and conversion for [XML Workflow Publishing](http://www.chicagomanualofstyle.org/tools_workflow.html) without the tedious XML exposure. It was designed to support the conversion of book manuscripts (and other documents) into ebooks or print books. Over the years, Bookalope has evolved into a powerful set of tools that are now accessible online.

Once a document is uploaded to the server, Bookalope's work flow is divided into three steps:

 - **Document analysis and content extraction.** Where Bookalope determines the structure of a document. Based on the results of this analysis, Bookalope then extracts the text contend from the uploaded document, and structures it into an internal format.

 - **Content checking and fixes.** Where Bookalope checks the structured text contend for a large number of spelling, punctuation, and typographical problems. They are flagged, and the user may choose to correct them.

 - **Conversion and download.** Where Bookalope generates a number of other file formats for electronic and print publication (EPUB2+3, MOBI, PDF) as well as conversion for continued editing and design (ICML, DOCX). Bookalope generates Table of Contents, links footnotes, adjust images, and much more. By design, Bookalope produces target file formats that validate against various industry standards.

This work flow is not one-directional; instead, the user can move seamlessly forth and back between structuring a document, checking its content, and generating target files.

<img src="https://bookalope.net/img/bookalope-convert-book-wide.jpg" width="100%" alt="Bookalope Workflos">

Bookalope can be used through a visual website interface or by invoking functions of its REST web API.

### Interactive web site

All of the Bookalope tools can be accessed with a web browser through [https://bookflow.bookalope.net](https://bookflow.bookalope.net). Please visit our [Youtube Channel](https://www.youtube.com/channel/UCCxR_k6G06qEAj3IjZ9AcoQ) to learn more about using the website, and how to convert a book using Bookalope.

### The REST API

Bookalope exposes its tools increasingly through a REST API that is documented
[here](https://github.com/jenstroeger/Bookalope/blob/master/API.md). The example scripts in the `examples` folder illustrate the use of the Bookalope API directly
from a CLI or by using a simple object-oriented wrapper in Python.

### CLI

The REST API can be accessed directly through command-line tools like [curl](http://curl.haxx.se/), [httpie](http://httpie.org/), or any other tool that allows to send HTTP requests to a server. Please refer to the [API documentation](https://github.com/jenstroeger/Bookalope/blob/master/API.md) for more examples that illustrate how to invoke Bookalope's API functions directly, or to the example script [here](https://github.com/jenstroeger/Bookalope/blob/master/examples/convert.sh).

### Object Model for Language Integration

To make the use of the REST API more comfortable, language specific wrappers provide a simple object-oriented model. This object model defines the following classes:

**BookalopeClient:** The BookalopeClient class is the main interface to Bookalope, and handles authentication and direct access to the API server. All other classes require a BookalopeClient instance to operate. Other than for testing purposes, a user should never have to use a BookalopeClient instance's methods directly.

**Profile:** The Profile class represents a user's profile data, i.e first and last name.

**Format:** The Format class represents the file format identifiers of import and export file formats that Bookalope supports. A file format identifier contains the [mime type](http://www.iana.org/assignments/media-types/media-types.xhtml) and a list of possible file name extensions.
 
**Style:** The Style class represents the visual styling information for a target document format. That styling information consists of a short and a verbose name of the style, as well as a description and the price of the style when used for a target document.

**Book:** The Book class represents a single book as it is handled by Bookalope. It is a wrapper for a number of "book flows," i.e. conversion runs of different versions of the same book. All book related information like author name, title, ISBN, and so forth are part of the book flow.

**Bookflow:** The Bookflow class represents a single conversion of a book's manuscript. Because a book may run through several manuscript edits, a Book class contains a number of Bookflows. A Bookflow contains author, title, ISBN, copyright, and other metadata information for the book. It also offers all functions required to step through the conversion of the book.

Bookalope's object model is *lazy* in a sense that the user may change the properties of an instance at any time without affecting the server data. To push local modifications to the Bookalope server, call an object's `save()` function; to update a local object with server-side data, call an object's `update()` function.

**Supported Languages.**

| Language | Wrapper and documentation |
|----------|---------------------------|
| Python 3 | [Source code](https://github.com/jenstroeger/Bookalope/blob/master/clients/py/bookalope.py) and example [convert.py](https://github.com/jenstroeger/Bookalope/blob/master/examples/convert.py) |
| PHP5     | [Source code](https://github.com/jenstroeger/Bookalope/blob/master/clients/php/bookalope.php) and example [convert.php](https://github.com/jenstroeger/Bookalope/blob/master/examples/convert.php) |
