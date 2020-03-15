#! /usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw(say);

use Getopt::Long qw(GetOptions);
use LWP::UserAgent;
use JSON qw(decode_json encode_json);
use MIME::Base64 qw(encode_base64);
use File::Slurp qw(read_file write_file);
use File::Basename;
use Encode qw(decode);

=head1 convert.pl

Parse and handle command line arguments. The command line has the following structure:

   convert.pl [--title <book-title>] [--author <book-author>] [--cover <cover-image>] <token> <filename>

where C<--title> and C<--author> are optional arguments, I<< <token> >> is the Bookalope authentication
token, and I<< <filename> >> the document that's to be converted.

=cut

my $author = 'Author';
my $title = 'Title';
my $cover;
GetOptions(
    'author=s' => \$author,
    'title=s' => \$title,
    'cover=s' => \$cover,
) or die 'Unknown command line options';
my $token = shift or die 'Missing command line argument: token';
my $filename = shift or die 'Missing command line argument: filename';

# Turn string arguments (which might contain utf8 encoded characters) into Perl's internal form.
$author = decode('UTF-8', $author);
$title = decode('UTF-8', $title);

# Helper function to make an HTTP request and handle the response. If the response
# contains a JSON encoded body, return the decoded Perl object; if the response
# contains a binary attachment, return the bytes; else return nothing.

sub make_request {
    my ($method, $url, $params) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(300);

    my $request;
    my $response;
    $request = HTTP::Request->new($method => 'https://bookflow.bookalope.net' . $url);
    $request->header('content-type' => 'application/json');
    $request->authorization_basic($token, '');
    if ($params) {
        $request->content(encode_json($params));
    }
    $response = $ua->request($request);
    if ($response->is_success) {
        if ($response->header('X-Bookalope-Api-Version') ne '1.2.0') {
            die 'Invalid API server version, please update this client';
        }
        if (substr($response->header('Content-Type'), 0, 16) eq 'application/json') {
            my $json_body = $response->decoded_content;
            if ($json_body eq 'null') {
                return;
            }
            return decode_json($json_body);
        }
        my $disp = $response->header('Content-Disposition');
        if ($disp and index($disp, 'attachment') == 0) {
            return $response->content;
        }
        return;
    }
    my $json_err = decode_json($response->decoded_content);
    my $err_message = $json_err->{'errors'}[0]->{'description'};
    die 'HTTP response error ' . $response->code . ': ' . $err_message;
}

sub get_request {
    my ($url, $params) = @_;
    my $u = URI->new($url);
    $u->query_form($params);
    return make_request('GET', $u->as_string);
}

sub post_request {
    return make_request('POST', @_);
}

sub delete_request {
    return make_request('DELETE', @_);
}

# Helper function to trigger conversion of a document, wait for that conversion
# to finish, and then download the final book.

sub convert_and_download {
    my ($api_bookflows, $format) = @_;
    my $api_convert = "$api_bookflows/convert";

    say 'Converting document to ' . $format . ' and waiting for it to finish...';
    my $convert_info = post_request($api_convert, {'format' => $format, 'style' => 'default', 'version' => 'test'});
    my $download_id = $convert_info->{'download_id'};
    my $api_download = substr("$api_bookflows/download/$download_id", 4);  # /download URLs have no /api/ path segment.
    my $api_download_status = "$api_download/status";
    do {
        sleep 5;
        $convert_info = get_request($api_download_status);
        if ($convert_info->{'status'} eq 'failed') {
            die 'Conversion to ' . $format . ' failed!';
        }
    } while ($convert_info->{'status'} ne 'ok');

    say 'Downloading ' . $format . '...';
    return get_request($api_download);
}

# Base URL for the API.
my $api = '/api';

# Create a new book with an empty bookflow.
my $api_books = "$api/books";
my $book = post_request($api_books, {'name' => $title});
my $book_id = $book->{'book'}{'id'};
my $bookflow = $book->{'book'}{'bookflows'}[0];
my $bookflow_id = $bookflow->{'id'};
say 'Created new book ' . $book_id . ' with bookflow ' . $bookflow_id;

# Set author and title for this bookflow.
my $api_bookflows = "$api/bookflows/$bookflow_id";
post_request($api_bookflows, {'name' => 'Bookflow 1', 'title' => $title, 'author' => $author});

# If we've purchased a plan through the Bookalope website, then we can now credit
# this Bookflow, thus getting access to the full version of the book.
# post_request("$api_bookflows/credit", {'type' => 'pro'});  # Or 'basic', depending on the plan.

# Upload the document. Instead of passing `'filetype' => 'doc'` here, let the Bookalope
# server determine and handle the uploaded file.
say 'Uploading document...';
my $api_document = "$api_bookflows/files/document";
post_request($api_document, {'filename' => basename($filename), 'file' => encode_base64(read_file($filename))});

# Wait until the bookflow has finished processing.
say 'Waiting for bookflow to finish...';
do {
    sleep 5;
    $bookflow = get_request($api_bookflows);
} while ($bookflow->{'bookflow'}->{'step'} eq 'processing');
if ($bookflow->{'bookflow'}->{'step'} eq 'processing_failed') {
    die 'Processing of bookflow ' . $bookflow_id . ' failed, aborting!'
}

# Upload the cover image, if one was given.
if ($cover) {
    say 'Uploading cover image...';
    my $api_cover = "$api_bookflows/files/image";
    post_request($api_cover, {'name' => 'cover-image', 'filename' => basename($cover), 'file' => encode_base64(read_file($cover))});
}

# Convert and download the files.
# TODO Use threads for parallel conversion: https://perldoc.perl.org/perlthrtut.html
write_file($bookflow_id . '.epub', convert_and_download($api_bookflows, 'epub'));
write_file($bookflow_id . '.mobi', convert_and_download($api_bookflows, 'mobi'));
write_file($bookflow_id . '.pdf', convert_and_download($api_bookflows, 'pdf'));
write_file($bookflow_id . '.icml', convert_and_download($api_bookflows, 'icml'));
write_file($bookflow_id . '.docx', convert_and_download($api_bookflows, 'docx'));
write_file($bookflow_id . '.xml', convert_and_download($api_bookflows, 'docbook'));
write_file($bookflow_id . '.html', convert_and_download($api_bookflows, 'htmlbook'));

# Delete the book and all of its data.
delete_request("$api/books/$book_id");
say 'Deleted book and bookflow';

# Done.
exit 0;
