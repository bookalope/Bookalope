<?php

ini_set("display_errors", 1);
ini_set("display_startup_errors", 1);
// ini_set("allow_url_include", 1);
error_reporting(E_ALL);
assert_options(ASSERT_BAIL, TRUE);

// Example of how to use the Bookalope classes, a wrapper and simple object model
// for the Bookalope REST API. Please read the commented code. This is meant to
// run server side as the action of a <form> submit.

include "bookalope.php";
// include "https://cdn.rawgit.com/jenstroeger/Bookalope/master/clients/php/bookalope.php";

// Helper function that gets the system's temp directory without a trailing separator,
// guaranteed. PHP does not handle this consistently across platforms, see here:
// http://php.net/manual/en/function.sys-get-temp-dir.php#80690
function get_tmp_dir() {
    $tmpdir = sys_get_temp_dir();
    return rtrim($tmpdir, DIRECTORY_SEPARATOR);
}

// In case of an error, this will hold the error message;
$error_message = FALSE;

// Sanitize the form input.
$post_title = filter_var($_POST["title"], FILTER_SANITIZE_STRING);
$post_author = filter_var($_POST["author"], FILTER_SANITIZE_STRING);
$post_docfname = filter_var($_FILES["docfile"]["name"], FILTER_SANITIZE_STRING);
$post_docerr = $_FILES["docfile"]["error"];

// Server failures or wrapper problems cause a BookalopeException, which we catch
// here and handle at the end.
try {

    // Do nothing if there was a problem with the file upload.
    if ($post_docerr !== UPLOAD_ERR_OK) {
        $errors = array(
            UPLOAD_ERR_OK => NULL,
            UPLOAD_ERR_INI_SIZE => "The uploaded file exceeds the upload_max_filesize directive in php.ini.",
            UPLOAD_ERR_FORM_SIZE => "The uploaded file exceeds the MAX_FILE_SIZE directive that was specified in the HTML form.",
            UPLOAD_ERR_PARTIAL => "The uploaded file was only partially uploaded.",
            UPLOAD_ERR_NO_FILE => "No file was uploaded.",
            UPLOAD_ERR_NO_TMP_DIR => "Missing a temporary folder.",
            UPLOAD_ERR_CANT_WRITE => "Failed to write file to disk.",
            UPLOAD_ERR_EXTENSION => "A PHP extension stopped the file upload.",
            );
        throw new BookalopeException($errors[$post_docerr]);
    }

    // Create a new Bookalope client to communicate with the server.
    error_log("Creating Bookalope client...");
    $b_token = "enter-your-private-token-here";
    $b_client = new BookalopeClient;
    $b_client->set_token($b_token);

    // To convert a document, we create a new book first and then a bookflow for
    // that book. A bookflow is a single conversion of a document. Having
    // multiple bookflows per books allows us to handle multiple manuscript
    // iterations of the same book.
    error_log("Creating new book and bookflow...");
    $book = $b_client->create_book();
    $bookflow = $book->bookflows[0];

    // Set title and author for this bookflow, and save.
    if (!empty($post_title)) {
        $book->name = $post_title;
        $bookflow->title = $post_title;
    }
    if (!empty($post_author)) {
        $bookflow->author = $post_author;
    }
    $book->save();
    $bookflow->save();

    // If we've purchased a plan through the Bookalope website, then we can now
    // credit this Bookflow, thus getting access to the full version of the book.
    // $bookflow->set_credit("pro");  // Or "basic", depending on the plan.

    // Upload the manuscript document. We skip the book cover and let Bookalope
    // generate one.
    error_log("Uploading document...");
    $docfname = $_FILES["docfile"]["tmp_name"];
    $docf = file_get_contents($docfname);
    if ($docf === FALSE) {
        throw new BookalopeException("Failed to open and read document.");
    }
    $bookflow->set_document($post_docfname, $docf);

    // Wait for the analysis of the uploaded document to finish.
    while (true) {
        $bookflow->update();
        if ($bookflow->step === "processing") {
            sleep(5);
        }
        else if ($bookflow->step === "convert") {
            break;
        }
        else if ($bookflow->step === "processing_failed") {
            throw new BookalopeException("Failed to analyze document.");
        }
    }

    // Create a temporary folder and download all generated files into it. Then
    // zip that folder and return it as a response.
    $tmpdname = get_tmp_dir() . DIRECTORY_SEPARATOR . uniqid("bookalope");
    if (mkdir($tmpdname, 0700)) {

        // Convert the document into all supported export formats, and download it.
        // For every format that we download we use the 'default' styling, and we
        // download the 'test' version to avoid charges to our credit card.
        foreach ($b_client->get_export_formats() as $format) {
            error_log("Converting and downloading " . $format->name . "...");

            // Get the Style instance for the default styling. Bookalope should
            // always provide such a default styling, so we will assume here that
            // it does.
            $styles = $b_client->get_styles($format->name);
            foreach ($styles as $style) {
                if ($style->short_name === "default") {
                    $default_style = $style;
                    break;
                }
            }

            // Convert the document using the default styling, and wait for the
            // conversion to finish.
            $bookflow->convert($format->name, $default_style, "test");

            // Wait for the conversion to finish.
            while (true) {
                $status = $bookflow->convert_status($format->name, $default_style, "test");
                if ($status === "processing") {
                    sleep(5);
                }
                else if ($status === "ok") {
                    break;
                }
                else {
                    throw new BookalopeException("Conversion of " . $format->name . " failed.");
                }
            }

            // Download and save the converted document.
            $converted_bytes = $bookflow->convert_download($format->name, $default_style, "test");
            $tmpfname = $bookflow->id . "." . $format->file_exts[0];
            if (file_put_contents($tmpdname . DIRECTORY_SEPARATOR . $tmpfname, $converted_bytes) === FALSE) {
                // throw new BookalopeException("Failed to write converted document.");
                error_log("Error writing generated " . $format->name . " file, skipping.");
            }
        }

        // Zip all generated files into an archive for download.
        $zipfname = get_tmp_dir() . DIRECTORY_SEPARATOR . $bookflow->id . ".zip";
        $zip = new ZipArchive;
        $zip->open($zipfname, ZipArchive::CREATE);
        foreach (glob($tmpdname . DIRECTORY_SEPARATOR . $bookflow->id . ".*") as $fname) {
            $zip->addFile($fname, basename($fname));
        }
        // $zip->addGlob($tmpdname . DIRECTORY_SEPARATOR . $bookflow->id . ".*", 0, array("remove_all_path" => TRUE));
        $zip->close();

        // Remove the temporary folder. (Assumes the 'rm' command.)
        system("rm -rf " . escapeshellarg($tmpdname));

        // Delete the book and all of its bookflows.
        error_log("Deleting book and all bookflows...");
        $book->delete();

        // Return the archive as a response.
        // http_response_code(200);
        header("HTTP/1.1 200 OK");
        header("Content-Description: File Transfer");
        header("Content-Type: application/octet-stream");
        header("Content-Disposition: attachment; filename=\"" . basename($zipfname) . "\"");
        header("Content-Transfer-Encoding: binary");
        readfile($zipfname);
        unlink($zipfname);
        exit;
    }
    else {
        throw new BookalopeException("Failed to create temporary folder.");
    }
}
catch (BookalopeTokenException $e) {
    $error_message = $e->getMessage();
    error_log("BookalopeTokenException: " . $error_message);
}
catch (BookalopeException $e) {
    $error_message = $e->getMessage();
    error_log("BookalopeException: " . $error_message);
}

// http_response_code(500);
header("HTTP/1.1 500 Internal Server Error");
header("X-Bookalope-Error: " . $error_message);
header("Content-Type: application/json");
echo json_encode(array("error", $error_message));

?>
