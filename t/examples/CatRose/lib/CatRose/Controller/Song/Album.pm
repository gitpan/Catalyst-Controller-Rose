package CatRose::Controller::Song::Album;
use strict;
use warnings;
use base qw(
  Catalyst::Controller::Rose::EIP
  );

use CatRose::Album;
use CatRose::Forms::Album;

sub form_class  { 'CatRose::Forms::Album' }
sub init_form   { 'init_with_album' }
sub init_object { 'album_from_form' }
sub template    { 'tt/eip_tbody.tt' }
sub model_name  { 'Album' }

sub eip_fields { [qw( combo )] }

# to get the CRUD magic, we want to work on the Album object
# not the parent Song object. But we remember Song object
# because we need it later to save().

sub fetch : PathPart('album') Chained('/song/fetch') CaptureArgs(1)
{
    my ($self, $c, $id) = @_;

    if ($self->has_errors($c) or !$c->stash->{object}->id)
    {
        $c->stash->{error} = 'No such song.';
        return;
    }

    # make sure we validate against Album form, not the parent Song form
    $c->stash->{form} = $self->form_class->new;

    # $id also passed as _id param and cached as ->stash->{eip}->{_id}
    #$c->log->debug("album id = $id");
    $c->stash->{song_id} = $c->stash->{object_id};
    $c->stash->{song}    = $c->stash->{object};

    # now fetch our album
    my @arg = $id ? (id => $id) : ();
    $c->stash->{object} = $c->model($self->model_name)->fetch(@arg);
    if ($self->has_errors($c))
    {
        $c->stash->{error} = 'bad Album record';
        return;
    }
    $c->stash->{object_id} = $id;
}

sub save : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;

    # fake the form params
    my $comb = $c->req->param('combo');
    my ($title, $artist) = split(m/ : /, $comb);
    $c->req->param(title  => $title);
    $c->req->param(artist => $artist);
    unless ($self->NEXT::save($c))
    {
        $c->response->status('500');
        $c->response->body("Problem saving data. <br />"
                          . ($c->stash->{error} || $c->stash->{page}->{error}));
        return;
    }
}

# we don't want to save the album -- we want to save the relationship
sub save_obj
{
    my ($self, $c, $album) = @_;
    $c->stash->{song}->add_albums($album);
    $c->stash->{song}->save;
}

1;
