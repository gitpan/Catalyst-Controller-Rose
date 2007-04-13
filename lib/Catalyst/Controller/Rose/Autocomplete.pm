package Catalyst::Controller::Rose::Autocomplete;

use strict;
use warnings;
use base qw( Catalyst::Controller );

use Carp;

sub model_name { croak "must override model_name" }

sub find
{
    my ($self, $c, $query) = @_;
    my $col = $query->{c};

    # LIKE syntax varies between db implementations
    my $class    = $c->model($self->model_name)->name;
    my $db       = $class->new->db;
    my $is_ilike = 0;
    if ($db->driver eq 'pg')
    {
        $is_ilike = 1;
    }

    my @arg = (
               sort_by => "$col ASC",
               limit   => $query->{l},
              );

    if ($is_ilike)
    {
        push(@arg, query => [$col => {ilike => $query->{q}}]);
    }
    else
    {
        push(@arg, query => [$col => {like => $query->{q}}]);
    }

    my $res = $c->model($self->model_name)->search(@arg);
    return [map { $_->$col } @$res];
}

sub list : Local
{
    my ($self, $c, @args) = @_;

    my %q;
    $q{l} = $c->req->param('l') || 30;
    $q{c} = $c->req->param('c') || 'name';    # dumb default
    $q{q} = $c->req->param($q{c}) . '%';

    my $results = $self->find($c, \%q);
    
    my @list;
    for my $r (@$results)
    {
        push(@list, "<li>$r</li>");
    }

    unless (@list)
    {
        $c->response->body(' ');
    }
    else
    {
        $c->response->body('<ul>' . join('', @list) . '</ul>');
    }
}

1;

__END__

=head1 NAME

Catalyst::Controller::Rose::Autocomplete - RDBO/RHTMLO Ajax Autocompletion

=head1 SYNOPSIS

 # your controller code
 
 package MyApp::Controller::AC;
 use base 'Catalyst::Controller::Rose::Autocomplete';
 sub model_name { 'SomeThing' }
 1;
 
 # and in your template
 # search column 'foo' and return 10 results.
 
 [% PROCESS tt/autocomplete.tt 
            input = {
                id    = 'foo',
                url   = c.url_for('/ac/list?c=foo&l=10'),
                label = 'Enter your Foo here:'
            }
                
                %]

=head1 DESCRIPTION

Catalyst::Controller::Rose::Autocomplete is a simple controller
for answering client-side Ajax autocomplete requests. It is designed
to work with the Scriptaculous and Prototype JavaScript libraries,
but the output format can be adapted for any Ajax autocomplete framework.

=head1 METHODS

The following methods are available:

=head2 list

This method handles the input param parsing and creates a query to hand
to find(). list() then creates the correct HTML format and sets response
body.

=head2 find( I<context>, I<query> )

The default find() method returns an array
of scalar values suitable for returning to the browser. It is called
by list().

find() is a prime candidate for overriding in your subclass.

=head1 EXAMPLES

See the examples/ dir in the distribution.

=head1 AUTHOR

Peter Karman <perl@peknet.com>

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.


=cut

