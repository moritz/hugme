package Hugme::ProjectManager;

use JSON qw(from_json);
use File::Slurp qw(slurp);
use Net::GitHub;

sub new {
    my $class = shift;
    my $options = shift || { };

    my $self = bless {}, $class;
    $self->{tokens}      = from_json( slurp 'tokens.json' );
    $self->{projects}    = from_json( slurp 'projects.json' );
    $self->_mogrify_project_list();
}

sub _mogrify_project_list {
    my $self = shift;
    for (values %{$self->{projects}}) {
        $_->{auth} = { map {; $_ => 1} @{$_->{auth}} };
    }
}

sub add_collab {
    my ($self, $who, $repo, $auth) = @_;
    unless ($self->{projects}{$repo}) {
        return "sorry, I don't know anything about project '$repo'";
    }
    unless ($self->{projects}{$repo}{auth}{$auth}) {
        return "sorry, you don't have permissions to change '$repo'";
    }

    my $owner = $self->{projects}{$repo}{owner};

    my $github = Net::GitHub->new(
        owner   => $owner,
        login   => $owner,
        repo    => $repo,
        token   => $self->{tokens}{$owner},
    );
    my $response = $github->repos->add_collaborator($who);

    if (reftype($response) eq 'HASH') {
        return "ERROR: Can't add $who to $repo:  $response->{error}";
    } elsif (reftype($response) eq 'ARRAY') {
        my %u;
        @u{@$response} = (1) x @$response;
        if ($u{$who}) {
            return "successfully added $who to $repo";
        } else {
            return "github reported success, but it didn't work anyway - WTF?";
        }
    } else {
        return "github responded in a a really unexpected way - HUH?";
    }
}

sub projects {
    $_[0]->{projects};
}


1;
