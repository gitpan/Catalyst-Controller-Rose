package CatRose::Forms::Song;
use strict;
use warnings;
use base qw( Rose::HTML::Form );
use Rose::HTMLx::Form::Field::Autocomplete;
use Carp;

sub init_with_song
{
    my $self = shift;
    my $song = shift;
    if (!$song or !$song->isa('CatRose::Song'))
    {
        croak "need CatRose::Song object";
    }
    $self->init_with_object($song);
}

sub song_from_form
{
    my $self = shift;
    my $song = shift or croak "need CatRose::Song object";
    $self->object_from_form($song);
    return $song;
}

sub build_form
{
    my $self = shift;
    $self->add_fields(
                      title =>
                        Rose::HTMLx::Form::Field::Autocomplete->new(
                                                    size      => 30,
                                                    required  => 1,
                                                    label     => 'Song Title',
                                                    maxlength => 128,
                                                    autocomplete => '/song/list'
                        ),
                      artist =>
                        Rose::HTMLx::Form::Field::Autocomplete->new(
                                                    size         => 30,
                                                    required     => 1,
                                                    label        => 'Artist',
                                                    maxlength    => 128,
                                                    autocomplete => '/song/list'
                        ),
                      length => {
                                 type      => 'text',
                                 size      => 16,
                                 maxlength => 16,
                                 required  => 1,
                                 label     => 'Song Length'
                                }
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
