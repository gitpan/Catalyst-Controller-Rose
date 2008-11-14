package Catalyst::Controller::Rose;

use base qw( Catalyst::Controller );

use Catalyst::Exception;

our $VERSION = '0.05';

sub has_errors
{
    my ($self, $c) = @_;
    return scalar(@{$c->error}) || $c->stash->{error} || 0;
}

sub throw_error
{
    my ($self, $msg) = @_;
    $msg ||= 'unknown error';
    Catalyst::Exception->throw($msg);
}

1;

__END__

=head1 NAME

Catalyst::Controller::Rose - **DEPRECATED** RDBO and RHTMLO base classes for Catalyst

=head1 DESCRIPTION

B<This package is deprecated. Please use CatalystX::CRUD instead.>

Catalyst::Controller::Rose provides several base Controller classes
for creating CRUD-style Catalyst applications using Rose::DB::Object
and Rose::HTML::Objects.

This class provides a common base class with utility methods
and an overall VERSION of the
Catalyst::Controller::Rose namespace.

=head1 METHODS

=head2 has_errors( I<context> )

Returns true if I<context> error() method has any errors set or if the
C<error> value in stash() is set. Otherwise returns false (no errors).

=head2 throw_error( I<msg> )

Throws Catalyst::Exception with I<msg>. Since this method is available in
every Catalyst::Controller::Rose subclass, you can customize error handling
in each of your subclass controllers.

=cut

=head1 SEE ALSO

Catalyst::Model::RDBO

=head1 AUTHOR

Peter Karman <perl@peknet.com>

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.

=cut

