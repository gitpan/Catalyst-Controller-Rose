package CatRose::DB::Object;
use strict;
use warnings;
use base qw( Rose::DB::Object );
use CatRose::DB;

sub init_db
{
    my $class = shift;
    return CatRose::DB->new(@_, database => $ENV{DB_PATH});
}

=head2 save([ catalyst => $c ])

Commit changes to the database. 

The optional C<catalyst> name/value
pair takes a Catalyst context object as its value. If present, several
things happen:
an eval() is wrapped around the database interaction and any fatal
RaiseError calls are caught and logged to Catalyst. The 
C<dbi_error_called> flag is set in the Catalyst stash so that
your Catalyst end() block can decide to display the error or not. 
And finally, the error
saved in Catalyst's C<stash->{error}> is trimmed to hide all the line
numbers and file names, in order to provide a little security.

=cut

sub save
{
    my $self = shift;
    my %arg  = @_;
    if ($arg{catalyst})
    {
        return $self->_cat_error('save', $arg{catalyst});
    }
    $self->SUPER::save(%arg);
}

=head2 delete([ catalyst => $c ])

Behaves just like save().

=cut

sub delete
{
    my $self = shift;
    my %arg  = @_;
    if ($arg{catalyst})
    {
        return $self->_cat_error('delete', $arg{catalyst});
    }
    $self->SUPER::delete(%arg);
}

sub _cat_error
{
    my $self = shift;
    my $meth = shift;
    my $cat  = shift;

    my $func = 'SUPER::' . $meth;
    my $ret;
    eval { $ret = $self->$func(@_); };
    if ($@ or $self->error)
    {

        $cat->stash->{dbi_error_called}++;
        my $msg     = $self->error;
        my $usermsg = '';

        # mysql errs
        if ($msg =~ /(Duplicate entry (\S+))/)
        {
            $usermsg = $1;

        }
        elsif ($msg =~ /(You have an error in your SQL syntax)/i)
        {
            $usermsg = $1;

        }

        # postgres errs
        elsif ($msg =~ m/duplicate key/)
        {
            $usermsg = "Cannot save duplicate value";
        }

        # TODO others here
        else
        {
            $usermsg = $msg;

        }

        $cat->log->error($self->db->nick . " $meth failed: $msg");
        $cat->stash->{error} = "Database error: $usermsg";

        # call the handle_error method now that we've intercepted
        # the error message so that Catalyst will stop processing
        $self->meta->handle_error($self);
    }
    return $ret;
}

1;
