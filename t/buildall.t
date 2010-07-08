use Test::More 'no_plan';

use Web::Simple 'Fork';

my @run;

sub Fork::BUILD { push @run, [ FORK => $_[1] ] }

@Knife::ISA = 'Fork';

@Spoon::ISA = 'Knife';

sub Spoon::BUILD { push @run, [ SPOON => $_[1] ] }

bless({}, 'Fork')->BUILDALL('data');

is_deeply(\@run, [ [ FORK => 'data' ] ], 'Single class ok');

@run = ();

bless({}, 'Spoon')->BUILDALL('data');

is_deeply(\@run, [ [ FORK => 'data' ], [ SPOON => 'data' ] ], 'Subclass ok');
