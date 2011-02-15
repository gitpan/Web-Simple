package Web::Dispatch::Predicates;

use strictures 1;
use base qw(Exporter);

our @EXPORT = qw(
  match_and match_or match_not match_method match_path match_path_strip
  match_extension match_query match_body
);

sub match_and {
  my @match = @_;
  sub {
    my ($env) = @_;
    my $my_env = { %$env };
    my $new_env;
    my @got;
    foreach my $match (@match) {
      if (my @this_got = $match->($my_env)) {
        my %change_env = %{shift(@this_got)};
        @{$my_env}{keys %change_env} = values %change_env;
        @{$new_env}{keys %change_env} = values %change_env;
        push @got, @this_got;
      } else {
        return;
      }
    }
    return ($new_env, @got);
  }
}

sub match_or {
  my @match = @_;
  sub {
    foreach my $try (@match) {
      if (my @ret = $try->(@_)) {
        return @ret;
      }
    }
    return;
  }
}

sub match_not {
  my ($match) = @_;
  sub {
    if (my @discard = $match->($_[0])) {
      ();
    } else {
      ({});
    }
  }
}

sub match_method {
  my ($method) = @_;
  sub {
    my ($env) = @_;
    $env->{REQUEST_METHOD} eq $method ? {} : ()
  }
}

sub match_path {
  my ($re) = @_;
  sub {
    my ($env) = @_;
    if (my @cap = ($env->{PATH_INFO} =~ /$re/)) {
      $cap[0] = {}; return @cap;
    }
    return;
  }
}

sub match_path_strip {
  my ($re) = @_;
  sub {
    my ($env) = @_;
    if (my @cap = ($env->{PATH_INFO} =~ /$re/)) {
      $cap[0] = {
        SCRIPT_NAME => ($env->{SCRIPT_NAME}||'').$cap[0],
        PATH_INFO => pop(@cap),
      };
      return @cap;
    }
    return;
  }
}

sub match_extension {
  my ($extension) = @_;
  my $wild = (!$extension or $extension eq '*');
  my $re = $wild
             ? qr/\.(\w+)$/
             : qr/\.(\Q${extension}\E)$/;
  sub {
    if ($_[0]->{PATH_INFO} =~ $re) {
      ($wild ? ({}, $1) : {});
    } else {
      ();
    }
  };
}

sub match_query {
  my $spec = shift;
  require Web::Dispatch::ParamParser;
  sub {
    _extract_params(
      Web::Dispatch::ParamParser::get_unpacked_query_from($_[0]),
      $spec
    )
  };
}

sub match_body {
  my $spec = shift;
  require Web::Dispatch::ParamParser;
  sub {
    _extract_params(
      Web::Dispatch::ParamParser::get_unpacked_body_from($_[0]),
      $spec
    )
  };
}

sub _extract_params {
  my ($raw, $spec) = @_;
  foreach my $name (@{$spec->{required}||[]}) {
    return unless exists $raw->{$name};
  }
  my @ret = (
    {},
    map {
      $_->{multi} ? $raw->{$_->{name}}||[] : $raw->{$_->{name}}->[-1]
    } @{$spec->{positional}||[]}
  );
  # separated since 'or' is short circuit
  my ($named, $star) = ($spec->{named}, $spec->{star});
  if ($named or $star) {
    my %kw;
    if ($star) {
      @kw{keys %$raw} = (
        $star->{multi}
          ? values %$raw
          : map $_->[-1], values %$raw
      );
    }
    foreach my $n (@{$named||[]}) {
      next if !$n->{multi} and !exists $raw->{$n->{name}};
      $kw{$n->{name}} = 
        $n->{multi} ? $raw->{$n->{name}}||[] : $raw->{$n->{name}}->[-1];
    }
    push @ret, \%kw;
  }
  @ret;
}

1;
