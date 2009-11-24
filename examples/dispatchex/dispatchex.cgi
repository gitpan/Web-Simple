use Web::Simple 'DispatchEx';

package DispatchEx;

dispatch [
  filter_response {
    [ 200, [ 'Content-type' => 'text/plain' ], $_[1] ];
  },
  subdispatch sub (.html) {
    [
      filter_response { [ @{$_[1]}, '.html' ] },
      sub (/foo) { [ '/foo' ] },
    ]
  },
  subdispatch sub (/domain/*/...) {
    return unless (my $domain_id = $_[1]) =~ /^\d+$/;
    [
      sub (/) {
        [ "Domain ${domain_id}" ]
      },
      sub (/user/*) {
        return unless (my $user_id = $_[1]) =~ /^\d+$/;
        [ "Domain ${domain_id} user ${user_id}" ]
      }
    ]
  }
];

DispatchEx->run_if_script;
