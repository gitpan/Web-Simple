package Web::Simple::DispatchNode;

use Moo;

extends 'Web::Dispatch::Node';

has _app_object => (is => 'ro', init_arg => 'app_object', required => 1);

around _curry => sub {
  my ($orig, $self) = (shift, shift);
  $self->$orig($self->_app_object, @_);
};

1;
