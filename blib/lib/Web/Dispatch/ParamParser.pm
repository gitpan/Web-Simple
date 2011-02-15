package Web::Dispatch::ParamParser;

use strict;
use warnings FATAL => 'all';

sub UNPACKED_QUERY () { __PACKAGE__.'.unpacked_query' }
sub UNPACKED_BODY () { __PACKAGE__.'.unpacked_body' }

sub get_unpacked_query_from {
  return $_[0]->{+UNPACKED_QUERY} ||= do {
    _unpack_params($_[0]->{QUERY_STRING})
  };
}

sub get_unpacked_body_from {
  return $_[0]->{+UNPACKED_BODY} ||= do {
      if (index(lc($_[0]->{CONTENT_TYPE}||''), 'application/x-www-form-urlencoded') >= 0 
        and defined $_[0]->{CONTENT_LENGTH}) {
      $_[0]->{'psgi.input'}->read(my $buf, $_[0]->{CONTENT_LENGTH});
      _unpack_params($buf);
    } else {
      {}
    }
  };
}


{
  # shamelessly stolen from HTTP::Body::UrlEncoded by Christian Hansen

  my $DECODE = qr/%([0-9a-fA-F]{2})/;

  my %hex_chr;

  foreach my $num ( 0 .. 255 ) {
    my $h = sprintf "%02X", $num;
    $hex_chr{ lc $h } = $hex_chr{ uc $h } = chr $num;
  }

  sub _unpack_params {
    my %unpack;
    (my $params = $_[0]) =~ s/\+/ /g;
    my ($name, $value);
    foreach my $pair (split(/[&;](?:\s+)?/, $params)) {
      next unless (($name, $value) = split(/=/, $pair, 2)) == 2;
        
      s/$DECODE/$hex_chr{$1}/gs for ($name, $value);

      push(@{$unpack{$name}||=[]}, $value);
    }
    \%unpack;
  }
}

1;
