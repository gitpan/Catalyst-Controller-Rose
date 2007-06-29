package CatRose::Controller::Album;
use strict;
use warnings;
use base qw(
  Catalyst::Controller::Rose::CRUD
  Catalyst::Controller::Rose::Search
  Catalyst::Controller::Rose::Autocomplete
  );

sub form_class  { 'CatRose::Forms::Album' }
sub init_form   { 'init_with_album' }
sub init_object { 'album_from_form' }
sub template    { 'album/edit.xhtml' }
sub model_name  { 'Album' }

sub default : Private
{
    my ($self, $c) = @_;
    $c->response->redirect($c->uri_for('search'));
}

sub view_on_single_result
{
    my ($self, $c, $obj) = @_;
    return $c->uri_for($obj->id, 'edit');
}

# CRUD override
sub fetch : Chained('/') PathPrefix CaptureArgs(1)
{
    my ($self, $c, $id) = @_;
    $self->SUPER::fetch($c, $id);
    return if $self->has_errors($c);

    # set up EIP for related songs
    my (@songs);
    if ($id)
    {
        @songs = $c->stash->{object}->songs;
    }

    @songs = CatRose::Song->new unless @songs;

    $c->stash->{songs} =
      $c->forward('Album::Song', 'eip_table', [data => \@songs]);

}

# we want related songs deleted -- not the songs, but the related-ness
sub rm : PathPart Chained('fetch') Args(0)
{
    my ($self, $c) = @_;
    return if $self->has_errors($c);
    unless ($self->can_write($c))
    {
        $c->stash->{error} = 'Permission denied';
        return;
    }

    my $o = $c->stash->{object};

    unless ($self->precommit($c, $o))
    {
        return 0;
    }
    $o->delete(cascade => 'delete');
    $self->postcommit($c, $o);
}

# autocomplete override
sub find
{
    my ($self, $c, $query) = @_;
    if ($c->req->param('c') eq 'combo')
    {

        my $comb = $query->{q};
        my ($title, $artist) = split(m/\ :\ /, $comb);
        my @q = ('title' => {like => $title});
        push(@q, artist => {like => $artist}) if $artist;

        my $res = $c->model($self->model_name)->search(

            query   => \@q,
            sort_by => "title ASC",
            limit   => $query->{l}

        );

        return [map { join(' : ', $_->title, $_->artist) } @$res];

    }
    else
    {
        return $self->SUPER::find($c, $query);
    }
}

1;
