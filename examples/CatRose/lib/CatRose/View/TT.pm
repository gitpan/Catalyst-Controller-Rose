package CatRose::View::TT;

use strict;
use base 'Catalyst::View::TT';

use Carp;
use Data::Dump qw( dump );
use Sys::Hostname;
use JSON::Syck;

__PACKAGE__->config->{CONTEXT} = undef;

=head1 NAME

CatRose::View::TT - CatRose View

=head1 SYNOPSIS

See Catalyst::View::TT

=head1 DESCRIPTION



=head1 AUTHOR

Peter Karman

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->config(
    {
     PRE_CHOMP   => 1,             # strips extra whitespace from generated HTML
     POST_CHOMP  => 1,
     PRE_PROCESS => 'config',      # load TT config
     WRAPPER     => 'wrapper.tt',  # template for entire site
     TEMPLATE_EXTENSION => '.xhtml',
    }
);

# virt method replacements for Dumper plugin
sub dump_data
{
    my $s = shift;
    my $d = dump($s);
    for ($d)
    {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s,\n,<br/>\n,g;
    }
    return "<pre>$d</pre>";
}

sub as_json
{
    my $v = shift;

    #carp dump $v;
    my $j = JSON::Syck::Dump($v);

    #carp "json: $j";
    return $j;
}

$Template::Stash::HASH_OPS->{dump}   = \&dump_data;
$Template::Stash::ARRAY_OPS->{dump}  = \&dump_data;
$Template::Stash::SCALAR_OPS->{dump} = \&dump_data;

# as_json virt method dumps value as a JSON string
$Template::Stash::HASH_OPS->{as_json}   = \&as_json;
$Template::Stash::ARRAY_OPS->{as_json}  = \&as_json;
$Template::Stash::SCALAR_OPS->{as_json} = \&as_json;

my $thishost;

sub process
{
    my ($self, $c) = @_;

    $thishost ||= hostname();
    $c->stash->{page}->{host} = $thishost;

    # set dynamic include path, since we can't get at package config
    # via new()

    $self->include_path([$c->config->{root}]);

    $c->stash->{page}->{static} ||= $c->uri_for('/static');

    $c->stash->{page}->{wrapper} = 'default.tt'
      unless defined($c->stash->{page}->{wrapper});

    # must dereference config so it doesn't get modified.
    $c->stash->{page}->{css} = [@{$c->config->{view}->{css} || []}];
    $c->stash->{page}->{js}  = [@{$c->config->{view}->{js}  || []}];
    $c->stash->{page}->{format} ||= 'html';

    my $template = $c->stash->{template}
      || $self->template_name($c)
      || $c->action . $self->config->{TEMPLATE_EXTENSION};

    unless ($template)
    {
        $c->log->debug('No template specified for rendering') if $c->debug;
        return 0;
    }

    # must set before render() since wrapper.tt will test it
    unless ($c->response->content_type)
    {
        $c->response->content_type('text/html; charset=utf-8');
    }
    else
    {

        # and we always always always return utf8 regardless of MIME
        my $ct = $c->response->content_type;
        $ct =~ s,;\s*charset=utf-8,,;
        $ct .= '; charset=utf-8';
        $c->response->content_type($ct);
    }
    
    my $output = $self->render($c, $template);

    if (UNIVERSAL::isa($output, 'Template::Exception')) {
        my $error = qq/Couldn't render template "$output"/;
        $c->log->error($error);
        $c->error($error);
        return 0;
    }

    $c->response->body($output);

    return 1;

}

sub template_name
{
    my ($self, $c) = @_;

    my $extension       = $self->config->{TEMPLATE_EXTENSION} || '.xhtml';
    my $template_suffix = delete $c->stash->{template_suffix} || '';
    return $c->action->reverse . $template_suffix . $extension;
}

1;
