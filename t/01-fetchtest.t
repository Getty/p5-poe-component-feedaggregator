#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Cwd;
use File::Spec::Functions;

my $path = catdir( getcwd(), 't', 'data' );
my $port = $ENV{POE_COMPONENT_FEEDAGGREGATOR_TEST_PORT} ? $ENV{POE_COMPONENT_FEEDAGGREGATOR_TEST_PORT} : 63223;

SKIP: {
	eval { require POE::Component::Server::HTTP };

	skip "You need POE::Component::Server::HTTP installed", 1 if $@;

	my $cnt = 0;

	{
		package Test::PoCoFeAg::Example;
		use MooseX::POE;
		use POE::Component::FeedAggregator;
		use POE::Component::Server::HTTP;
		use File::Spec::Functions;
		use Slurp;

		event new_feed_entry => sub {
			my ( $self, $feed, $entry ) = @_[ OBJECT, ARG0..$#_ ];
			::isa_ok($feed, "POE::Component::FeedAggregator::Feed", "Getting POE::Component::FeedAggregator::Feed object as first arg on new feed entry");
			if ($feed->name eq 'rss') {
				::isa_ok($entry, "XML::Feed::Entry::Format::RSS", "XML::Feed::Entry::Format::RSS object as second arg on new feed entry");
			} elsif ($feed->name eq 'atom') {
				::isa_ok($entry, "XML::Feed::Entry::Format::Atom", "XML::Feed::Entry::Format::Atom object as second arg on new feed entry");
			}
			$cnt++;
			POE::Kernel->stop if $cnt == 42;
		};
		
		has 'server' => (
			is => 'rw',
		);

		has 'client' => (
			is => 'rw',
		);

		sub START {
			my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
			$self->server(POE::Component::Server::HTTP->new(
				Port => $port,
				ContentHandler => {
					'/atom' => sub { 
						my ($request, $response) = @_;
						$response->code(RC_OK);
						my $content = slurp( catfile( $path, "atom.xml" ) );
						$response->content( $content );
						$response->content_type('application/xhtml+xml');
						return RC_OK;
					},
					'/rss' => sub { 
						my ($request, $response) = @_;
						$response->code(RC_OK);
						my $content = slurp( catfile( $path, "rss.xml" ) );
						$response->content( $content );
						$response->content_type('application/xhtml+xml');
						return RC_OK;
					},
				},
				Headers => { Server => 'FeedServer' },
			));
			$self->client(POE::Component::FeedAggregator->new());
			::isa_ok($self->client, "POE::Component::FeedAggregator", "Getting POE::Component::FeedAggregator object on new");
			$self->client->add_feed({
				url => 'http://localhost:'.$port.'/atom',
				name => 'atom',
				delay => 10,
				headline_as_id => 1,
			});
			$self->client->add_feed({
				url => 'http://localhost:'.$port.'/rss',
				name => 'rss',
				delay => 10,
				headline_as_id => 1,
			});
		}

	}

	my $test = Test::PoCoFeAg::Example->new();

	POE::Kernel->run;

	is($cnt,42,'42 entries are received');
}

done_testing;
