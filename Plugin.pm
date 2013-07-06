package Plugins::RandomAlbum::Plugin;

# Random Album plugin for the Squeezeserver (Logitech Media Server).
# based on the HelloWorld tutorial plugin by Mitch Gerdisch.
#
# This code is derived from code with the following copyright message:
#
# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use base qw(Slim::Plugin::Base);
use Scalar::Util qw(blessed);
use Slim::Control::Request;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);
use HTTP::Status qw(
    RC_FORBIDDEN
	RC_PRECONDITION_FAILED
	RC_UNAUTHORIZED
	RC_MOVED_PERMANENTLY
	RC_NOT_FOUND
	RC_METHOD_NOT_ALLOWED
	RC_OK
	RC_NOT_MODIFIED
);
use URI;
use JSON::XS;

our $baseUrl = 'plugins/RandomAlbum';

# used for logging
# To debug, run squeezecenter.exe from the command prompt as follows:
# squeezecenter.exe --debug plugin.<plugin name>=<logging level in caps>
# Log levels are DEBUG, INFO, WARN, ERROR, FATAL where a level will include messages for all levels to the right.
# So, squeezecenter.exe --debug plugin.helloworld=INFO,persist will show all messages fro INFO, WARN, ERROR, and FATAL.
# The "persist" bit of text allows the system to remember that logging level between invocations of squeezecenter.
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.randomalbum',
	'defaultLevel' => 'INFO',
	'description'  => getDisplayName(),
});

sub getDisplayName {
	return 'PLUGIN_RANDOM_ALBUM';
}

sub initPlugin {
	my $class = shift;
	
	$class->SUPER::initPlugin();
}

sub getRandomAlbums {
	my ($n) = @_;
	
	my $sql = 
		'SELECT albums.id, contributors.name, albums.title, albums.artwork, COUNT(tracks.id) AS numtracks ' . 
		'FROM albums ' . 
		'LEFT JOIN contributors ON albums.contributor = contributors.id ' .
		'LEFT JOIN tracks ON albums.id = tracks.album ' .
		'GROUP BY albums.id ' .
		'HAVING numtracks > 1 ' .
		'ORDER BY RANDOM() ' .
		'LIMIT ' .$n;
		
	my $dbh = Slim::Schema->dbh;
	return $dbh->selectall_arrayref($sql);
}

sub getAllAlbums {
	my $sql = 
		'SELECT albums.id, contributors.name, albums.title, albums.artwork, COUNT(tracks.id) AS numtracks ' . 
		'FROM albums ' . 
		'LEFT JOIN contributors ON albums.contributor = contributors.id ' .
		'LEFT JOIN tracks ON albums.id = tracks.album ' .
		'GROUP BY albums.id ';

	my $dbh = Slim::Schema->dbh;
	return $dbh->selectall_arrayref($sql);
}

sub webPages {
	my $class = shift;
	
	my $title = $class->getDisplayName();
	
	Slim::Web::Pages->addPageLinks( 'plugins', { $title => $baseUrl . '/' });
	
	Slim::Web::Pages->addPageFunction(qr/$baseUrl\/(index\.html)?$/, \&mainPageFunc);
	Slim::Web::Pages->addRawFunction(qr/$baseUrl\/list_.*$/, \&listRawPageFunc);
	Slim::Web::Pages->addPageFunction(qr/$baseUrl\/play_.*$/, \&playPageFunc);
}

sub mainPageFunc {
	# serve the main web page.
	my ($client, $params) = @_;

	return Slim::Web::HTTP::filltemplatefile("$baseUrl/albums.html", $params);
}

sub listRawPageFunc {
	# serve album data.
	# can be invoked as either list_<rows>x<cols>, which will return a rows-by-cols json array of random albums, or
	# list_all, which will return a text table of all albums in the collection.
	my ($httpClient, $response) = @_;
	
	my $uri = $response->request()->uri();
	my $path = $uri->path();

	my $body = '';
	if ($path =~ m/$baseUrl\/list_(\d+)x(\d+)$/)
	{
		my $cols = $1;
		my $rows = $2;

		$body .= '[ ';

		my @albums = @{ getRandomAlbums($rows * $cols) };
		for (my $i = 0; $i < $rows; $i++)
		{
			$body .= ",\n" if $i > 0;
			$body .= "[ ";

			for (my $j = 0; $j < $cols; $j++)
			{
				$body .= ', ' if $j > 0;
				my $album = shift @albums;
				if ($album)
				{
					# convert *from* UTF-8 before passing on to encode_json -- otherwise there will be double encodings.
					foreach (@{ $album })
					{
						utf8::decode($_);
					}
					
					$body .= encode_json($album);
				}
			}
			
			$body .= ' ]';
		}
		
		$body .= "\n]";
	}
	elsif ($path =~ m/$baseUrl\/list_all$/)
	{
		my @albums = @{ getAllAlbums() };
		foreach (@albums)
		{
			my $album = $_;
			$body .= join(' ', @{ $album }) . "\n";
		}
	}

	$response->code(RC_OK);
	$response->content_type('text/plain; charset=utf-8');
	$response->header('Cache-Control' => 'private, max-age=0, no-cache');
	$response->content_length(length($body));
	Slim::Web::HTTP::addHTTPResponse($httpClient, $response, \$body, 1, 0);
}

sub playPageFunc {
	# use Slim::Control::Request::executeRequest to play the album.
	my ($client, $params, $prepareResponseForSending, $httpClient, $response) = @_;

	my $path = $params->{'path'};
	my $host = $params->{'host'};
	
	my $body = 'Unknown album.';
	if ($path =~ m/$baseUrl\/play_(.+)$/) 
	{
		my $album_id = Slim::Utils::Misc::unescape($1, 1);
	
		my @verbs = ('playlistcontrol', 'cmd:load', 'album_id:' . $album_id);
		Slim::Control::Request::executeRequest( $client, \@verbs );

		$body = 'Playing album ' . $album_id . '.';
	}
	
	$prepareResponseForSending->($client, $params, \$body, $httpClient, $response);
}

# Always end with a 1 to make Perl happy
1;
