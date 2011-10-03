package Web::Dispatch;

use Sub::Quote;
use Scalar::Util qw(blessed);

sub MAGIC_MIDDLEWARE_KEY { __PACKAGE__.'.middleware' }

use Moo;
use Web::Dispatch::Parser;
use Web::Dispatch::Node;

with 'Web::Dispatch::ToApp';

has app => (is => 'ro', required => 1);
has parser_class => (
  is => 'ro', default => quote_sub q{ 'Web::Dispatch::Parser' }
);
has node_class => (
  is => 'ro', default => quote_sub q{ 'Web::Dispatch::Node' }
);
has node_args => (is => 'ro', default => quote_sub q{ {} });
has _parser => (is => 'lazy');

sub _build__parser {
  my ($self) = @_;
  $self->parser_class->new;
}

sub call {
  my ($self, $env) = @_;
  $self->_dispatch($env, $self->app);
}

sub _dispatch {
  my ($self, $env, @match) = @_;
  while (my $try = shift @match) {

    return $try if ref($try) eq 'ARRAY';
    if (ref($try) eq 'HASH') {
      $env = { %$env, %$try };
      next;
    }

    my @result = $self->_to_try($try, \@match)->($env, @match);
    next unless @result and defined($result[0]);

    my $first = $result[0];

    if (my $res = $self->_have_result( $first, \@result, \@match, $env )) {

      return $res;
    }

    # make a copy so we don't screw with it assigning further up
    my $env = $env;
    unshift @match, sub { $self->_dispatch($env, @result) };
  }

  return;
}

sub _have_result {
  my ( $self, $first, $result, $match, $env ) = @_;

  if ( ref($first) eq 'ARRAY' ) {
    return $self->_unpack_array_match( $first );
  }
  elsif ( blessed($first) && $first->isa('Plack::Middleware') ) {
    return $self->_uplevel_middleware( $first, $result );
  }
  elsif ( ref($first) eq 'HASH' and $first->{+MAGIC_MIDDLEWARE_KEY} ) {
    return $self->_redispatch_with_middleware( $first, $match, $env );
  }
  elsif ( blessed($first) && !$first->can('to_app') ) {
    return $first;
  }

  return;
}

sub _unpack_array_match {
  my ( $self, $match ) = @_;
  return $match->[0] if @{$match} == 1 and ref($match->[0]) eq 'CODE';
  return $match;
}

sub _uplevel_middleware {
  my ( $self, $match, $results ) = @_;
  die "Multiple results but first one is a middleware ($match)"
    if @{$results} > 1;
  # middleware needs to uplevel exactly once to wrap the rest of the
  # level it was created for - next elsif unwraps it
  return { MAGIC_MIDDLEWARE_KEY, $match };
}

sub _redispatch_with_middleware {
  my ( $self, $first, $match, $env ) = @_;

  my $mw = $first->{+MAGIC_MIDDLEWARE_KEY};

  $mw->app(sub { $self->_dispatch($_[0], @{$match}) });

  return $mw->to_app->($env);
}

sub _to_try {
  my ($self, $try, $more) = @_;
  if (ref($try) eq 'CODE') {
    if (defined(my $proto = prototype($try))) {
      $self->_construct_node(
        match => $self->_parser->parse($proto), run => $try
      )->to_app;
    } else {
      $try
    }
  } elsif (!ref($try) and ref($more->[0]) eq 'CODE') {
    $self->_construct_node(
      match => $self->_parser->parse($try), run => shift(@$more)
    )->to_app;
  } elsif (blessed($try) && $try->can('to_app')) {
    $try->to_app;
  } else {
    die "No idea how we got here with $try";
  }
}

sub _construct_node {
  my ($self, %args) = @_;
  $self->node_class->new({ %{$self->node_args}, %args });
}

1;
