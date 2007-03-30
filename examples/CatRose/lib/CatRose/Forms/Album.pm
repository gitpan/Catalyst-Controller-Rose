package CatRose::Forms::Album;
use strict;
use warnings;
use base qw( Rose::HTML::Form );
use Rose::HTMLx::Form::Field::Autocomplete;
use Carp;

sub init_with_album
{
    my $self  = shift;
    my $album = shift;
    if (!$album or !$album->isa('CatRose::Album'))
    {
        croak "need CatRose::Album object";
    }
    $self->init_with_object($album);
}

sub album_from_form
{
    my $self = shift;
    my $album = shift or croak "need CatRose::Album object";
    $self->object_from_form($album);
    return $album;
}

sub build_form
{
    my $self = shift;
    $self->add_fields(
        title =>
          Rose::HTMLx::Form::Field::Autocomplete->new(
                                                   size         => 30,
                                                   required     => 1,
                                                   label        => 'Title',
                                                   maxlength    => 128,
                                                   autocomplete => '/album/list'
          ),
        artist =>
          Rose::HTMLx::Form::Field::Autocomplete->new(
                                                   size         => 30,
                                                   required     => 1,
                                                   label        => 'Artist',
                                                   maxlength    => 128,
                                                   autocomplete => '/album/list'
          ),

        # used by autocomplete
        combo =>
          Rose::HTMLx::Form::Field::Autocomplete->new(
                                                   size     => 30,
                                                   label    => 'Title : Artist',
                                                   maxlength    => 128,
                                                   autocomplete => '/album/list'
          ),
    );

}

sub error
{
    my $self = shift;
    my @err = ($self->SUPER::error || '');

    for my $field ($self->fields)
    {
        if ($field->error)
        {
            push(@err, "Error message: " . $field->error);
        }
    }

    return join("\n", @err);
}
1;
