package Hugme::ProjectManager;

use JSON qw(from_json);
use File::Slurp qw(slurp);
use Net::GitHub;
use Scalar::Util qw(reftype);
use strict;
use warnings;

sub new {
    my $class = shift;
    my $options = shift || { };

    my $self = bless { options => $options }, $class;
    $self->read_data();
    return $self;
}

sub read_data {
    my $self = shift;
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
            return "ACTION hugs $who. Welcome to $repo!";
        } else {
            return "github reported success, but it didn't work anyway - WTF?";
        }
    } else {
        return "github responded in a a really unexpected way - HUH?";
    }
}

sub projects {
    my ($self, $proj) = @_;
    if (defined($proj)) {
        return $self->{projects}{$proj};
    } else {
        return $self->{projects};
    }
}

sub admins {
    my ($self, $proj) = @_;
    sort keys %{ $self->{projects}{$proj}{auth} };
}

sub owner {
    my ($self, $proj) = @_;
    return $self->{projects}{$proj}{owner}
}

sub url {
    my ($self, $proj) = @_;
    return "http://github.com/" . $self->owner($proj) . '/' . $proj . '/';
}

=head1 NAME

Hugme::ProjectManager - manage a collection of github projects

=head1 SYNOPSIS

    use Hugme::ProjectManager;

    # automatically load data from JSON files:
    my $p = Hugme:::ProjectManager->new();
    my @projects = $p->projects();
    my $url      = $p->url($projects[0]);

    # add a new contributor to a project
    # this is generally performed by a trusted person $trusted
    
    my ($whom, $repo, $trusted) = qw(somebody CoolProject TrustedNickname);
    my $response = $p->add_collab($whom, $repo, $trusted);

=cut

1;
