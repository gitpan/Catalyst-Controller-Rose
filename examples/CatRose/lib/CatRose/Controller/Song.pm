package CatRose::Controller::Song;
use strict;
use warnings;
use base qw(
  Catalyst::Controller::Rose::CRUD
  Catalyst::Controller::Rose::Search
  Catalyst::Controller::Rose::Autocomplete
  );

use CatRose::Forms::Song;
use CatRose::Album;

sub form_class  { 'CatRose::Forms::Song' }
sub init_form   { 'init_with_song' }
sub init_object { 'song_from_form' }
sub template    { 'song/edit.xhtml' }
sub model_name  { 'Song' }

sub view_on_single_result
{
    my ($self, $c, $obj) = @_;
    return $c->uri_for($obj->id, 'edit');
}

sub fetch : Chained('/') PathPrefix CaptureArgs(1)
{
    my ($self, $c, $id) = @_;
    $c->stash->{object_id} = $id;
    my @arg = $id ? (id => $id) : ();
    $c->stash->{object} = $c->model($self->model_name)->fetch(@arg);
    unless ($self->check_err($c) and $c->stash->{object})
    {
        $c->stash->{error} = 'No such ' . $self->model_name;
    }

    # set up EIP for related albums
    my (@albums);
    if ($id)
    {
        @albums = $c->stash->{object}->albums;
    }

    @albums = CatRose::Album->new unless @albums;

    $c->stash->{albums} =
      $c->forward('Song::Album', 'eip_table', [data => \@albums]);

}

sub default : Private
{
    my ($self,$c) = @_;
    $c->response->redirect($c->uri_for('search'));
}

1;
