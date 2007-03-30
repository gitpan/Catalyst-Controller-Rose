package Catalyst::Controller::Rose::Search;

use strict;
use warnings;
use base qw( Catalyst::Controller );
use Carp;
use Data::Pageset;
use Sort::SQL;

sub model_name { croak "you must override model_name() or search()" }

sub make_form
{
    croak "you must either stash a form object or override make_form()";
}

sub can_search            { 1 }
sub view_on_single_result { 0 }

# prep for RDBO syntax
sub setup
{
    my ($self, $c, @args) = @_;

    # make form sticky
    my $form = $c->stash->{form} || $self->make_form($c);
    $c->stash->{form} ||= $form;    # in case we got it from make_form()
    $form->params($c->req->params);
    $form->init_fields();

    my $q = $self->rose_query($c, @args);
    my $s = $c->req->param('o') || 'id DESC';
    my $sp = Sort::SQL->string2array($s);

    # dis-ambiguate common column names
    $s =~ s,\bname\ ,t1.name ,;
    $s =~ s,\bid\ ,t1.id ,;

    # Rose requires ASC/DESC be UPPER case
    $s =~ s,\b(asc|desc)\b,uc($1),eg;

    my $page_size = $c->request->param('p') || 50;
    $page_size = 100 if $page_size > 100;
    my $page = $c->req->param('page') || 1;

    my %query = (
                 query           => $q,
                 sort_by         => $s,
                 limit           => $page_size,
                 offset          => ($page - 1) * $page_size,
                 sort_order      => $sp,
                 plain_query     => $self->plain_query($c, @args),
                 plain_query_str => $self->plain_query_str($c, @args),
                );

    return \%query;
}

sub results
{
    my ($self, $c, $query, $hits, $results) = @_;
    $c->stash->{search} = {
                           results   => $results,
                           query     => $query->{plain_query},
                           query_str => $query->{plain_query_str},
                           order     => $query->{sort_order},
                           pager =>
                             Data::Pageset->new(
                                {
                                 total_entries    => $hits,
                                 entries_per_page => $query->{limit},
                                 current_page  => $c->req->param('page') || 1,
                                 pages_per_set => 10,
                                 mode          => 'slide',
                                }
                             )
                          };

}

sub plain_query
{
    my ($self, $c, @args) = @_;
    my $form = $args[0] || $c->stash->{form};
    my %q;
    for my $p ($form->field_names)
    {
        next unless exists $c->req->params->{$p};
        next unless grep { m/./ } $c->req->param($p);
        $q{$p} = [$c->req->param($p)];
    }
    return \%q;
}

sub plain_query_str
{
    my ($self, $c) = @_;
    my $q = $self->plain_query($c);
    my @s;
    for my $p (sort keys %$q)
    {
        my @v = @{$q->{$p}};
        next unless grep { m/\S/ } @v;
        push(@s, "$p = " . join(' or ', @v));
    }
    return join(' AND ', @s);
}

# make a RDBO-compatible query object
sub rose_query
{
    my ($self, $c, @args) = @_;
    my $form = $args[0] || $c->stash->{form};
    my @q;

    # LIKE syntax varies between db implementations
    my $class    = $c->model($self->model_name)->name;
    my $db       = $class->new->db;
    my $is_ilike = 0;
    if ($db->driver =~ m/psql/i)
    {
        $is_ilike = 1;
    }

    for my $p ($form->field_names)
    {

        next unless exists $c->req->params->{$p};
        my @v    = $c->req->param($p);
        my @safe = @v;
        next unless grep { /./ } @safe;

        if (grep { /[\%\*]|^!/ } @v)
        {
            grep { s/\*/\%/g } @safe;
            my @wild = grep { m/\%/ } @safe;
            if (@wild)
            {
                if ($is_ilike)
                {
                    push(@q, ($p => {ilike => \@wild}));
                }
                else
                {
                    push(@q, ($p => {like => \@wild}));
                }
            }

            my @not = grep { m/^!/ } @safe;
            if (@not)
            {
                push(@q, ($p => {ne => [grep { s/^!// } @not]}));
            }
        }
        else
        {
            push(@q, $p => [@safe]);
        }
    }

    return \@q;
}

sub default : Private
{
    my ($self, $c, @arg) = @_;
    $c->response->redirect($c->uri_for('search'));
}

sub search : Local
{
    my ($self, $c, @args) = @_;
    unless ($self->can_search($c))
    {
        $c->response->status(401);
        $c->response->body('permission denied');
        return;
    }
    my $query = $self->setup($c, @args);
    if (scalar @{$query->{query}})
    {
        my $hits = $c->model($self->model_name)->count(query => $query->{query})
          || 0;
        my $result = $c->model($self->model_name)->search(%$query);
        if (   $hits == 1
            && (my $uri = $self->view_on_single_result($c, $result->[0]))
            && !$c->stash->{_no_view_on_single_result})
        {
            $c->response->redirect($uri);
        }
        else
        {
            $self->results($c, $query, $hits, $result);
        }
    }
}

1;

__END__

=head1 NAME

Catalyst::Controller::Rose::Search - base class for searching a RDBO model

=head1 SYNOPSIS

 # subclass this module in your controller
 
 package MyApp::Controller::Foo;
 use base qw( Catalyst::Controller::Rose::Search );
 
 use Foo::Form;
 
 sub make_form  { Foo::Form->new }
 sub model_name { 'Foo' }     # isa Catalyst::Model::RDBO subclass
 sub can_search
 {
     my ($self, $c) = @_;
     return $c->session->{user}->{roles}->{search};
 }
 
 1;
 
 # now can call http://yoururl/foo/search
 # or just http://yoururl/foo
 
=head1 DESCRIPTION

Catalyst::Controller::Rose::Search provides controller access
to many of the features of Catalyst::Model::RDBO.

=head1 URL-ACCESSIBLE METHODS

The following methods are tagged as C<Local> and will appear in
your subclass's URL namespace by default.

=head2 default

A generic default() method which just issues a redirect() to search().

=head2 search

The primary method. See setup() and results() for ways to alter
the default bahaviour.

=head1 INTERNAL METHODS

The following methods can be overridden in your subclass.

=head2 can_search

Returns true (1) if the request is authorized, false (0) if not.
Default is true.

=head2 view_on_single_result

If the search results match only one row, then redirect to the
URL returned. Default return is false (disabled).

Example:

 sub view_on_single_result
 {
     my ($self, $c, $obj) = @_;
     return $c->uri_for('/my/record', $obj->id, 'edit');
 }
 
This method is intended for use with Catalyst::Controller::Rose::CRUD.

Called by search().

You can temporarily override the return value of this method
by setting a true value in the stash key C<_no_view_on_single_result>:

  $c->stash->{_no_view_on_single_result} = 1;  # override
  
This allows for calling search() from other controllers and getting
results even if there is only one hit.

=head2 setup

Called by search() to create the query structure passed to the model.
Some string mangling is performed in order to play nicely with the
RDBO query conventions.

This method calls make_form() and rose_query().

=head2 make_form

Returns a form object, which should be a subclass of Rose::HTML::Form
(or at least have a similar API).

Override this method or stash a form object in your auto() method.
If creating the form object is time-intensive, consider caching
the form object and then just clearing it every time a request
arrives:
 
 use Foo::Form;
 my $form = Foo::Form->new;
 
 sub make_form
 {
     $form->clear;
     return $form;
 }
 
You can also avoid make_form() altogether by stashing the form object
yourself in auto():

 sub auto : Private
 {
     my ($self, $c) = @_;
     $c->stash->{form} = Foo::Form->new;
     1;
 }
 
=head2 model_name

Should return the name of the Model to be called in search().

=head2 rose_query()

Creates a RDBO query structure based on the incoming request params()
and the fields defined in the make_form() form object. Some special
syntax is supported:

=over

=item *

You may use C<*> or C<%> as a wildcard.

=item !

You may put a C<!> at the start of a query to invert it:

 !foo       # means NOT foo
 
=back

=head2 results

Sets up the stash for use by the View. The following structure is
set by default under the C<search> keyword:

 {
    results     => [ @array_of_RDBO_objects ],
    query       => { %param_to_values },
    query_str   => $plain_query_suitable_for_humans,
    order       => [ @array_of_hashrefs_used_by_view_column_sort ],
    pager       => $Data_Pageset_object
 }
 
=head1 EXAMPLES

See the examples/ dir in the distribution.

=head1 AUTHOR

Peter Karman <perl@peknet.com>

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.


=cut

