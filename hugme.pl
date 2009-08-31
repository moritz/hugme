use strict;
use warnings;
use 5.010;
use POE qw(Component::IRC);
use Net::GitHub;
use Data::Dumper;
use Scalar::Util qw(reftype);
use JSON qw(from_json);
use File::Slurp qw(slurp);

# Github interface stuff
my %tokens = %{ from_json( slurp 'tokens.json' ) };

my %projects = %{ from_json( slurp 'projects.json' ) };
for (values(%projects)) {
    $_->{auth} = { map {; $_ => 1} @{$_->{auth}} };
}

sub add_collab {
    my ($who, $repo, $auth) = @_;
    unless ($projects{$repo}) {
        return "sorry, I don't know anything about project '$repo'";
    }
    unless ($projects{$repo}{auth}{$auth}) {
        return "sorry, you don't have permissions to change '$repo'";
    }

    my $owner = $projects{$repo}{owner};

    my $github = Net::GitHub->new(
        owner   => $owner,
        login   => $owner,
        repo    => $repo,
        token   => $tokens{$owner},
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

# IRC stuff
# mostly taken from the POE::Component::IRC's SYNOPSIS

my $nickname = 'hugme';
my $ircname = 'Adds collaborators to github projects';
my $server = 'irc.freenode.net';

my @channels = ('#perl6');

# We create a new PoCo-IRC object
my $irc = POE::Component::IRC->spawn(
        nick => $nickname,
        ircname => $ircname,
        server => $server,
) or die "Oh noooo! $!";

POE::Session->create(
    package_states => [
        main => [ qw(_default _start irc_001 irc_public irc_whois) ],
    ],
    heap => { irc => $irc },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

# retrieve our component's object from the heap where we
# stashed it
    my $irc = $heap->{irc};

    $irc->yield( register => 'all' );
    $irc->yield( register => 'whois' );
    $irc->yield( connect => { } );
    return;
}

sub irc_001 {
    my $sender = $_[SENDER];

# Since this is an irc_* event, we can get the component's
# object by
# accessing the heap of the sender. Then we register and
# connect to the
# specified server.
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

# we join our channels
    $irc->yield( join => $_ ) for @channels;
    return;
}

my %jobs;

sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $response;

    if ($what =~ /^ \Q$nickname\E [:;,.]?  \s* (.+) /x) {
        my $msg = $1;
        print "received msg <<$msg>>\n";
        if ($msg =~ m/^add (\S+) to (\S+)\s*$/i) {
            say "starting whois() to add $1 to $2";
            push @{$jobs{$nick}}, {
                channel => $channel,
                whom    => $1,
                proj    => $2,
            };
            $irc->yield( whois => $nick);
        } elsif ($msg =~ m/^(hug|cuddle) (\S+)/) {
            $irc->yield(ctcp => $channel => "ACTION $1s $2");
        } elsif ($msg =~ m/^(?:list project|project list)/) {
            my $proj = join ', ', sort keys %projects;
            $response = "I know about these projects: $proj";
        } elsif ($msg =~ m/^show (\S+)/) {
            my $proj = $1;
            if ($projects{$proj}) {
                $response = "the following people have power over $proj: "
                            . join(", ", keys %{$projects{$proj}{auth}});
            } else {
                $response = "sorry, I don't know anything about '$proj'";
            }

        } elsif ($msg =~ m/^help/i) {
            $response = "'$nickname: (add \$who to \$project | list projects"
                        . " | show \$project | hug \$nickname)'";
        }
        if (defined($response)) {
            $irc->yield(
                privmsg => $channel,
                "$nick: $response",
            );
        }
    }
    return;
}

sub irc_whois {
    my $w = $_[ARG0];
# a typical response inlcudes:
# 'identified' => 'is signed on as account foo'
    my $nick = $w->{nick};
    say "irc_whois($nick)";
    my $channel = eval {
        $jobs{ $nick }[-1]{channel};
    } or return;
    if ($w->{identified}
            && $w->{identified} =~ m/^is signed on as account (.*)/) {
        my $account = $1;
        for (@{ $jobs{ $nick }}) {
            my $response = add_collab($_->{whom}, $_->{proj}, $account);
            $irc->yield(
                privmsg => $channel, "$nick: $response",
            );
        }
    } else {
        $irc->yield(
            privmsg => $channel,
            "$w->{nick}: You need to register with freenode first",
        );
    }
    delete $jobs{ $nick };
    return;
}

# We registered for all events, this will produce some debug info.
sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event: " );

    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']');
        }
        else {
            push ( @output, "'$arg'" );
        }
    }
#    say join ' ', @output;
    return 0;
}
