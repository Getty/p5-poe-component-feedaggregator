package POE::Component::FeedAggregator::Feed;
# ABSTRACT: A Feed specification for POE::Component::FeedAggregator

use Moose;

has sender => (
	isa => 'POE::Session',
	is => 'ro',
	required => 1,
);

has url => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has name => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has delay => (
	isa => 'Int',
	is => 'ro',
	required => 1,
	default => sub { 1200 },
);

has entry_event => (
	isa => 'Str',
	is => 'ro',
	required => 1,
	default => sub { 'new_feed_entry' },
);

has max_headlines => (
	isa => 'Int',
	is => 'ro',
	required => 1,
	default => sub { 100 },
);

has headline_as_id => (
	isa => 'Bool',
	is => 'ro',
	required => 1,
	default => sub { 1 },
);

1;