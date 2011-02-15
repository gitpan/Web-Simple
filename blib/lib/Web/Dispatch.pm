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
    if (ref($try) eq 'HASH') {
      $env = { %$env, %$try };
      next;
    } elsif (ref($try) eq 'ARRAY') {
      return $try;
    }
    my @result = $self->_to_try($try, \@match)->($env, @match);
    next unless @result and defined($result[0]);
    if (ref($result[0]) eq 'ARRAY') {
      if (@{$result[0]} == 1 and ref($result[0][0]) eq 'CODE') {
        return $result[0][0];
      }
      return $result[0];
    } elsif (blessed($result[0]) && $result[0]->isa('Plack::Middleware')) {
      die "Multiple results but first one is a middleware ($result[0])"
        if @result > 1;
      # middleware needs to uplevel exactly once to wrap the rest of the
      # level it was created for - next elsif unwraps it
      return { MAGIC_MIDDLEWARE_KEY, $result[0] };
      my $mw = $result[0];
    } elsif (
      ref($result[0]) eq 'HASH'
      and my $mw = $result[0]->{+MAGIC_MIDDLEWARE_KEY}
    ) {
      $mw->app(sub { $self->_dispatch($_[0], @match) });
      return $mw->to_app->($env);
    } elsif (blessed($result[0]) && !$result[0]->can('to_app')) {
      return $result[0];
    } else {
      # make a copy so we don't screw with it assigning further up
      my $env = $env;
      unshift @match, sub { $self->_dispatch($env, @result) };
    }
  }
  return;
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
