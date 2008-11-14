package Catalyst::Controller::Rose::CRUD;

use strict;
use warnings;
use base qw( Catalyst::Controller::Rose );

our $VERSION = '0.05';

# should override the following methods in your subclass
sub form_class
{
    shift->throw_error("you must override form_class() or auto()");
}
sub init_form   { shift->throw_error("you must override init_form()") }
sub init_object { shift->throw_error("you must override init_object()") }
sub template    { shift->throw_error("you must override template()") }
sub model_name  { shift->throw_error("you must override model_name()") }

# optional callbacks -- see save()
sub precommit { 1 }

# authorization checks
sub can_read  { 1 }
sub can_write { 1 }

sub auto : Private
{
    my ($self, $c, @args) = @_;
    my $fc = $self->form_class;
    $c->stash->{form} ||= $fc->new;
    1;
}

sub default : Private
{
    my ($self, $c, @args) = @_;
    $c->log->warn("no action defined for the default() CRUD method");
}

# Mon Mar 19 16:35:20 CDT 2007
# see http://use.perl.org/~LTjake/journal/31738
# PathPrefix will likely end up in an official Catalyst release soon.
# this lets us have a sane default fetch() method without having
# to write one in each subclass.
sub _parse_PathPrefix_attr
{
    my ($self, $c, $name, $value) = @_;
    return PathPart => $self->path_prefix;
}

sub fetch : Chained('/') PathPrefix CaptureArgs(1)
{
    my ($self, $c, $id) = @_;
    $c->stash->{object_id} = $id;
    my @arg = $id ? (id => $id) : ();
    $c->stash->{object} = $c->model($self->model_name)->fetch(@arg);
    if ($self->has_errors($c) or !$c->stash->{object})
    {
        $self->throw_error('No such ' . $self->model_name);
    }
}

sub create : Local
{
    my ($self, $c) = @_;
    $c->forward('fetch', [0]);
    $c->detach('edit');
}

sub edit : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;
    return if $self->has_errors($c);
    unless ($self->can_write($c))
    {
        $self->throw_error('Permission denied');
        return;
    }
    my $meth = $self->init_form;
    $c->stash->{form}->$meth($c->stash->{object});

    # might get here from create()
    $c->stash->{template} = $self->template;
}

sub view : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;
    return if $self->has_errors($c);
    unless ($self->can_read($c))
    {
        $self->throw_error('Permission denied');
        return;
    }
    my $meth = $self->init_form;
    $c->stash->{form}->$meth($c->stash->{object});
}

sub save_obj
{
    my ($self, $c, $obj) = @_;
    $obj->save(catalyst => $c);
}

sub _param_hash
{
    my ($self, $c) = @_;
    return $c->request->params;
}

sub save : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;

    if ($c->request->param('_delete'))
    {
        $c->action->name('rm');    # so we can test against it in postcommit()
        $c->detach('rm');
    }

    return if $self->has_errors($c);
    unless ($self->can_write($c))
    {
        $self->throw_error('Permission denied');
        return;
    }
    my $f     = $c->stash->{form};
    my $o     = $c->stash->{object};
    my $ometh = $self->init_object;
    my $fmeth = $self->init_form;
    my $id    = $c->stash->{object_id};

    # initialize the form with the object's values
    $f->$fmeth($o);

    # set param values from request
    $f->params($self->_param_hash($c));

    # id always comes from url not form
    $f->param('id', $id);

    # override object's values with those from params
    $f->init_fields();

    # return if there was a problem with any param values
    unless ($f->validate())
    {
        $c->stash->{page}->{error} = $f->error;    # NOT throw_error()
        $c->stash->{template} ||= $self->template; # MUST specify
        return 0;
    }

    # re-set object's values from the now-valid form
    $f->$ometh($o);

    # set id explicitly since there's some bug with param() setting it above
    $o->id($id);

    # let serial column work its magic
    $o->id(undef) if (!$o->id or $o->id == 0 or $id == 0);

    # write our changes
    unless ($self->precommit($c, $o))
    {
        $c->stash->{template} ||= $self->template;
        return 0;
    }
    $self->save_obj($c, $o);
    $self->postcommit($c, $o);

    1;
}

sub rm : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;
    return if $self->has_errors($c);
    unless ($self->can_write($c))
    {
        $self->throw_error('Permission denied');
        return;
    }

    my $o = $c->stash->{object};

    unless ($self->precommit($c, $o))
    {
        return 0;
    }
    $o->delete;
    $self->postcommit($c, $o);
}

sub postcommit
{
    my ($self, $c, $o) = @_;

    if ($c->action->name eq 'rm')
    {
        $c->response->redirect($c->uri_for(''));
    }
    else
    {
        $c->response->redirect($c->uri_for('', $o->id, 'view'));
    }

    1;
}

1;

__END__

=head1 NAME

Catalyst::Controller::Rose::CRUD - **DEPRECATED** RDBO and RHTMLO for Catalyst CRUD apps

=head1 SYNOPSIS

 package MyApp::Controller::SomeCrud;
 
 use base 'Catalyst::Controller::Rose::CRUD';
 
 use MyApp::Forms::SomeCrud;
 
 sub form_class  { 'MyApp::Forms::SomeCrud' }
 sub init_form   { 'init_with_somecrud' }
 sub init_object { 'somecrud_from_form' }
 sub template    { 'path/to/somecrud/edit.xhtml' }
 sub model_name  { 'SomeCrud' }

 1;

=head1 DESCRIPTION

B<This package is deprecated. Please use CatalystX::CRUD instead.>

This base controller is useful for creating scaffolding for your CRUD
(Create, Read, Update, Delete) web applications.

It assumes you are using the Rose::DB::Object and Rose::HTML::Object 
modules or a subclass thereof.

Each controller assumes one form object = one db object.

Your subclass should define the following methods:

=over

=item form_class

The name of the HTML form object class.

=item init_form

The name of the method in your HTML class that will initialize
the HTML object.

=item init_object

The name of the method in your HTML class that will initialize
the RDBO object.

=item template

The name of the default template to use for the form rendering.

=item fetch

This is the most important method. fetch() defines the URL to which
your controller will bind itself, how many arguments it expects
before each action, and handles the retrieval of your DB object from the
appropriate Model. See the SYNOPSIS for an example.

You must set an 'object' key and an 'object_id' key
in your stash() for the rest of the CRUD
magic methods to work.

=back

=head1 METHODS

The following methods are available:

=head2 auto

The default auto() method will create a form object and stash() it under the
C<form> key. In order for that magic to work, you must override
the form_class() method and then C<use> the form class in your subclass.

Otherwise, you can override auto() in your subclass and do whatever you want
to. However, all the other methods expect a form object under the C<form>
key in the stash().

=head2 default

Doesn't do anything except satisfy the Catalyst namespace conventions.
A warning will be written to your log if anyone hits the URL that the default()
method maps to (if any).


=head2 create

Detachs to edit() with an id of C<0>.

=head2 edit

Initializes the form with the db object.

=head2 view

Does not do anything except satisfy the namespace. Your template can handle
the rendering of a non-editable view of the db object, or you can override
view() to handle it however you'd like.

=head2 rm

Deletes the db row from the db.

 TODO: should redirect someplace safe to protect from browser re-load.

=head2 save

Takes the form input, initializes the form object with it, validates
the form, and then if the form is valid, initializes the db object,
calls presave() and then saves the db object with save_obj().

If there are any validation errors, the stash->page->error value is set
to the form object error() value and save() returns 0.

There's a lot going on in save(). Grok the code yourself to see what's what.

=head2 precommit( I<context>, I<object> )

Callback method invoked by save() and rm()
just before committing changes to the db.

If precommit() returns true (the default), the calling method will
continue to commit. Otherwise, the method will abort and return 0.

precommit() is intended to be overridden in your subclass, in order
to do any last-minute checks, hacks and fudges on the data you deem
necessary.

=head2 save_obj( I<context>, I<object> )

By default just calls the save() method on I<object>. Override
if you want to do anything you can't do in precommit().

=head2 postcommit( I<context>, I<object> )

Called by save() and rm() after the db commit.

postcommit() is intended to be overridden in your subclass, although the
default behaviour is sane.

=head2 can_read( I<context> )

=head2 can_write( I<context> )

Authorization control with these two methods. The default is to return
true (1) from both, for unlimited access. Override them to provide
more fine-grained access.

Return true (1) to allow read or write. Return false (0) to deny access.

=head1 EXAMPLES

See the examples/ dir in the distribution.

=head1 SEE ALSO

Catalyst::Controller::Rose::Search
Catalyst::Controller::Rose::EIP
Catalyst::Controller::Rose::Autocomplete

=head1 AUTHOR

Peter Karman <perl@peknet.com>

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.


=cut

