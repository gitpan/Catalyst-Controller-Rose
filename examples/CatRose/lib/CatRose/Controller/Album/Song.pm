package CatRose::Controller::Album::Song;
use strict;
use warnings;
use base qw(
  Catalyst::Controller::Rose::EIP
  );

use CatRose::Song;
use CatRose::Forms::Song;

sub form_class  { 'CatRose::Forms::Song' }
sub init_form   { 'init_with_song' }
sub init_object { 'song_from_form' }
sub template    { 'tt/eip_tbody.tt' }
sub model_name  { 'Song' }

sub eip_fields { [qw( title artist length )] }

# to get the CRUD magic, we want to work on the Song object
# not the parent Album object. But we remember Album object
# just in case we need it later for QA prior to save().

sub fetch : PathPart('song') Chained('/album/fetch') CaptureArgs(1)
{
    my ($self, $c, $id) = @_;

    unless ($self->check_err($c) and $c->stash->{object}->id)
    {
        $c->stash->{error} = 'No such album.';
        return;
    }

    # make sure we validate against Album form, not the parent Song form
    $c->stash->{form} = $self->form_class->new;

    # $id also passed as _id param and cached as ->stash->{eip}->{_id}
    #$c->log->debug("song id = $id");
    $c->stash->{album_id} = $c->stash->{object_id};
    $c->stash->{album}    = $c->stash->{object};

    # now fetch our album
    my @arg = $id ? (id => $id) : ();
    $c->stash->{object} = $c->model($self->model_name)->fetch(@arg);
    unless ($self->check_err($c))
    {
        $c->stash->{error} = 'bad Song record';
        return;
    }
    $c->stash->{object_id} = $id;
}

sub save : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;

    # fake the form params
    unless($c->req->param('artist'))
    {
        $c->req->param( artist => $c->stash->{album}->artist );
    }
    
    unless ($self->NEXT::save($c))
    {
        $c->response->status('500');
        $c->response->body("Problem saving data. <br />"
                          . ($c->stash->{error} || $c->stash->{page}->{error}));
        return;
    }
}

# we don't want to just save the song -- we want to save the relationship
sub save_obj
{
    my ($self, $c, $song) = @_;
    $song->save(catalyst => $c);
    $c->stash->{album}->add_songs($song);
    $c->stash->{album}->save;
}

1;
