#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Cwd;
use File::Spec::Functions;
use IO::All;

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
			::isa_ok($entry, "XML::Feed::Entry::Format::Atom", "XML::Feed::Entry::Format::Atom object as second arg on new feed entry");
			$cnt++;
			POE::Kernel->stop if $cnt == 21;
		};

		has 'server' => (
			is => 'rw',
		);

		has 'client' => (
			is => 'rw',
		);

		sub BUILD {
			my ( $self ) = @_;
			$self->client(POE::Component::FeedAggregator->new());
		}

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
				},
				Headers => { Server => 'FeedServer' },
			));
			::isa_ok($self->client, "POE::Component::FeedAggregator", "Getting POE::Component::FeedAggregator object on new");
			$self->client->add_feed({
				url => 'http://localhost:'.$port.'/atom',
				name => '03-atom',
				delay => 10,
				max_headlines => 10,
			});
		}

	}

	my $test = Test::PoCoFeAg::Example->new();
	unlink $test->client->tmpdir.'/03-atom.feedcache' if (-f $test->client->tmpdir.'/03-atom.feedcache');

	POE::Kernel->run;

	is($cnt,21,'21 entries are received');

	ok(-f $test->client->tmpdir.'/03-atom.feedcache', "03-atom Cachefile exist");
	
	my @lines = io($test->client->tmpdir.'/03-atom.feedcache')->slurp;
	
	my $count = @lines;

	is($count, 10, "03-atom Cachefile has just 10 lines");
	
	unlink $test->client->tmpdir.'/03-atom.feedcache';
}

done_testing;
