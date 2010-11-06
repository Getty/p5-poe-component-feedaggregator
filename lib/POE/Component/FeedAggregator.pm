package POE::Component::FeedAggregator;
# ABSTRACT: Watch multiple feeds (Atom or RSS) for new headlines 

use MooseX::POE;
use POE qw(
	Component::FeedAggregator::Feed
	Component::Client::Feed
);
use Cwd;
use IO::All;

our $VERSION ||= '0.0development';

has feed_client => (
	isa => 'POE::Component::Client::Feed',
	is => 'ro',
	lazy => 1,
	required => 1,
	default => sub {
		POE::Component::Client::Feed->new({
			http_agent => __PACKAGE__.'/'.$VERSION,
		});
	},
);

has tmpdir => (
	isa => 'Str',
	is => 'ro',
	required => 1,
	default => sub { getcwd },
);

event feed_received => sub {
	my ( $self, $kernel, @args ) = @_[ OBJECT, KERNEL, ARG0..$#_ ];
	my $http_request = $args[0];
	my $xml_feed = $args[1];
	return if !(ref $xml_feed);
	my $feed = $args[2];
	my $cache_file = $self->tmpdir.'/'.$feed->name.'.feedcache';
	my @entries;
	if (-f $cache_file) {
		@entries = io($cache_file)->slurp;
	}
	my @new_entries;
	for my $entry ($xml_feed->entries) {
		my $link = $entry->link;
		my $title = $entry->title;
		my $known = 0;
		for (@entries) {
			chomp;
			if ( $_ =~ m/^(.+?) (.+)$/ ) {
				if ( $1 eq $link || $2 eq $title ) {
					$known = 1;
					last; 
				}
			}
		}
		next if $known;
		push @new_entries, $link.' '.$title;
		$kernel->post( $feed->sender, $feed->entry_event, $feed, $entry ) if !$known;
	}
	push @entries, @new_entries;
	my $count = @entries;
	my @save_entries = splice(@entries, $count - $feed->max_headlines > 0 ? $count - $feed->max_headlines : 0, $feed->max_headlines);
	scalar join("\n",@save_entries) > io($cache_file);
	$kernel->delay( 'request_feed', $feed->delay, $feed );
};

event request_feed => sub {
	my ( $self, $feed ) = @_[ OBJECT, ARG0..$#_ ];
	$self->feed_client->yield('request',$feed->url,'feed_received',$feed);
};

sub add_feed {
	shift->yield('_add_feed', @_);
}

event _add_feed => sub {
	my ( $self, $sender, $feed_args ) = @_[ OBJECT, SENDER, ARG0..$#_ ];
	$feed_args->{sender} = $sender;
	my $feed = POE::Component::FeedAggregator::Feed->new($feed_args);
	$self->yield( request_feed => $feed );
};

1;

__END__

=head1 SYNOPSIS

  package MyServer;
  use MooseX::POE;
  use POE::Component::FeedAggregator;

  has feedaggregator => (
    is => 'ro',
    default => sub {
      POE::Component::FeedAggregator->new();
    }
  );

  event new_feed_entry => sub {
    my ( $self, @args ) = @_[ OBJECT, ARG0..$#_ ];
    my $feed = $args[0]; # POE::Component::FeedAggregator::Feed object of the feed
    my $entry = $args[1]; # XML::Feed::Format::* object of the new entry
  };

  sub START {
    my ( $self ) = @_;
    $self->feedaggregator->add_feed({
      url => 'http://news.perlfoundation.org/atom.xml', # required
      name => 'perlfoundation',                         # required
      delay => 1200,                                    # default value
	  entry_event => 'new_feed_entry',                  # default value
    });
  }

=head1 DESCRIPTION

This POE Component works a bit like L<POE::Component::RSSAggregator>. More info soon...

=head1 SEE ALSO

=for :list
* L<POE::Component::Client::Feed>
* L<POE::Component::FeedAggregator::Feed>
* L<XML::Feed>
* L<MooseX::POE>
* L<POE::Component::RSSAggregator>
