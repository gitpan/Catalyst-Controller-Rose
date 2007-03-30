package Catalyst::Controller::Rose::EIP;
use strict;
use warnings;
use base qw( Catalyst::Controller::Rose::CRUD );

use Carp;
use JSON::Syck;

sub eip_fields
{
    my $self = shift;
    return [$self->form_class->new->field_names];
}

sub eip_table_name
{
    my ($self, $c) = @_;
    my $class = ref($self) || $self;
    (my $tn = $class) =~ s/.*:://;
    return $tn;
}

my $id_joiner = '.';

sub eip_id_joiner
{
    my $self = shift;
    if (@_)
    {
        $id_joiner = shift;
    }
    return $id_joiner;
}

sub eip_table : Private
{
    my ($self, $c, %arg) = @_;

    unless (exists $arg{data})
    {
        croak "data required";
    }

    my $fc        = $arg{form_class} || $self->form_class;
    my $init_meth = $arg{init_form}  || $self->init_form;
    my %eip;

    my $form = $fc->new;
    $arg{fields} ||= $self->eip_fields || $form->field_names;
    $eip{tmpl} = {
                  id   => 0,
                  cols => $self->eip_set_cols($form, $arg{fields}),
                 };

    $eip{add_row} = {
                     cells => $self->eip_set_cells('tmpl', $form, $arg{fields}),
                     pk    => 'tmpl'
                    };

  OBJ: for my $o (@{$arg{data}})
    {
        my $form = $fc->new;
        $form->$init_meth($o);
        push(
             @{$eip{rows}},
             {
              cells => $self->eip_set_cells($o->id || '0', $form, $arg{fields}),
              pk => $o->id || '0'
             }
            );
    }

    $c->stash->{id_joiner} = $self->eip_id_joiner;

    #carp "eip: " . dump \%eip;

    return \%eip;
}

sub eip_set_cols
{
    my ($self, $form, $fields) = @_;
    my @cols;
    for my $name (@$fields)
    {
        my $f = $form->field($name);
        next if $f->name eq 'id';
        push(
             @cols,
             {
              name    => $name,
              width   => length($f->label) * 10,
              size    => $f->size,
              type    => lc((ref($f) =~ m/::(\w+)$/)[0]),
              label   => $f->label->text,
              default => $f->output_value,
              auto    => $f->can('url') ? $f->url : 0
             }
            );
    }
    return \@cols;
}

sub eip_set_cells
{
    my ($self, $id, $form, $fields) = @_;
    my @cells;
    $id ||= 0;
    for my $name (@$fields)
    {
        my $f = $form->field($name);
        next if $f->name eq 'id';
        $f->class('eip');
        $f->id(join($self->eip_id_joiner, $id, $name));
        push(
             @cells,
             {
              name => $name,
              form => $f
             }
            );
    }
    return \@cells;
}

sub auto : Private
{
    my ($self, $c, @arg) = @_;

    for my $p (qw( _before _after _id _tmpl ))
    {
        if ($c->req->param($p))
        {
            $c->stash->{eip}->{$p} = JSON::Syck::Load($c->req->param($p));
        }
    }

    return $self->NEXT::auto($c, @arg);
}

sub postcommit
{
    my ($self, $c, $obj) = @_;

    # convert object to JSON and stash in body for return
    #    if ($c->stash->{is_ajax})
    #    {
    #
    #        my $json = $obj->column_values_as_json;
    #
    #        $c->log->debug("ajax call: setting json " . $json);
    #
    #        # set header tip from
    #        # http://www.dev411.com/blog/2006/05/31/prototype-json-and-catalyst
    #        $c->response->header(
    #                       'X-JSON' => 'eval("("+this.transport.responseText+")")');
    #
    #        $c->response->body($json);
    #    }

    # just return HTML for AHAH instead. too much hassle parsing the json
    # into the correct HTML on the client side. but we do pass the new id
    # as json for easier parsing.
    $c->response->header('X-JSON' => JSON::Syck::Dump({id => $obj->id}));

    my $tmpl = $c->stash->{eip}->{_tmpl};

    # mimic TT by creating auto and widths values based on tmpl
    #carp dump $tmpl;

    my ($auto, $widths);

    for my $col (@{$tmpl->{cols}})
    {
        if ($col->{auto})
        {
            $auto->{$col->{name}} = $col->{auto};
        }
        $widths->{$col->{name}} = $col->{width} / 10;
    }

    $c->stash->{rc} = $c->req->param('_rc') || 0;   # default is !alternate
    $c->stash->{template} = $self->template;
    my $cols = $self->eip_set_cols($c->stash->{form}, $self->eip_fields);
    my $cells =
      $self->eip_set_cells($obj->id, $c->stash->{form}, $self->eip_fields);

    $c->stash->{page}->{wrapper} = 0;
    $c->stash->{row} = {pk => $obj->id, cells => $cells};
    $c->stash->{eip} = {

        name => $c->req->param('_tname') || $self->eip_table_name,
        auto => $auto,
        widths => $widths
    };

    1;
}

sub save : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;
    unless ($self->NEXT::save($c))
    {
        $c->response->status('500');
        $c->response->body("Problem saving data. <br />"
                          . ($c->stash->{error} || $c->stash->{page}->{error}));
        return;
    }
}

sub rm : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;
    unless ($self->NEXT::rm($c))
    {
        $c->response->status('500');
        $c->response->body("Problem saving data. <br />"
                          . ($c->stash->{error} || $c->stash->{page}->{error}));
        return;
    }
}

# override CRUD to keep them out of URL namespace
sub edit
{
    my ($self, $c) = @_;
    croak "no such EIP action: edit";
}

sub view
{
    my ($self, $c) = @_;
    croak "no such EIP action: view";
}

1;

__END__

=head1 NAME

Catalyst::Controller::Rose::EIP - base class for Edit In Place tables

=head1 SYNOPSIS

 # controller subclass
 
 package MyApp::Controller::User::Role;
 use base 'Catalyst::Controller::Rose::EIP';
 sub form_class  { 'User::Role::Form' }
 sub init_form   { 'init_with_role' }
 sub init_object { 'role_from_form' }
 sub template    { 'path/tt/eip_tbody.tt' }
 sub model_name  { 'Role' }

 1;
 
 # then call the methods elsewhere in a different controller
 
 sub user_roles
 {
    my ($self, $c, $uid) = @_;
    
    my $user = $c->model('User')->fetch( id => $uid );
    
    $c->stash->{roles} = $c->forward('User::Role', 
                                     'eip_table',
                                     [ data => $user->roles ]
                                     );
                                     
 }
 
 
=head1 DESCRIPTION

Catalyst::Controller::Rose::EIP is a base class for creating
and managing Edit In Place tables.

The EIP features rely heavily on the atomic_eip.js JavaScript library,
which builds on top of Prototype.js.



=head1 METHODS

Catatlyst::Controller::Rose::EIP is a subclass of 
Catalyst::Controller::Rose::CRUD.
Only new or overridden methods are documented here.

The following methods are available:

=head2 eip_fields

=head2 eip_table_name

=head2 eip_id_joiner

=head2 eip_table

=head2 eip_set_cols

=head2 eip_set_cells

=head2 auto

=head2 postcommit

=head2 save

=head2 rm

=head2 edit

=head2 view

=head1 EXAMPLES

See the examples/ dir in the distribution.


=head1 AUTHOR

Peter Karman <perl@peknet.com>

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.


=cut

