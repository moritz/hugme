use strict;
use warnings;
use 5.010;
use POE qw(Component::IRC);
use Data::Dumper;
use lib 'lib';
use Hugme::ProjectManager;

my $pm = Hugme::ProjectManager->new();

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

# Bot logic

my %jobs;

sub hug {
    my ($msg, $info, $extra) = @_;
    unless (defined $extra) {
        $extra = '';
        $extra = ' and blushes' if rand() > 0.95;
        $extra = "; $info->{nick}++" if rand() > 0.99;
    }
    if ($msg =~ m/^(hug|cuddle) (\S+)/) {
        return ($2 eq 'me' ? "ACTION $1s $info->{nick}" : "ACTION $1s $2")
            . $extra;
    }
}

sub list_projects {
    return 'I know about ' .  join ', ', sort keys %{ $pm->projects };
}

sub show {
    my $msg = shift;
    if ($msg =~ m/^show\s+(\S+)/) {
        my $proj = $1;
        if (defined $pm->projects($proj)) {
            return "the following people have power over '$proj': "
                    . join(", ", $pm->admins($proj))
                    . '. URL: ' . $pm->url($proj);
        } else {
            return "sorry, I don't know anything about '$proj'";
        }
    }
}

sub add {
    my ($msg, $info) = @_;
    if ($msg =~ m/^add (\S+) to (\S+)\s*$/i) {
        say "starting whois() to add $1 to $2";
        push @{$jobs{$info->{nick}}}, {
            channel => $info->{channel},
            whom    => $1,
            proj    => $2,
        };
        $irc->yield( whois => $info->{nick});
    }
    return;
}

sub reload {
    $pm->read_data();
    return "reloaded successfully";
}

sub help {
    return '(add $who to $project | list projects | show $project | hug $nickname)';
}

my %actions = (
    add             => \&add,
    hug             => \&hug,
    cuddle          => \&hug,
    'list projects' => \&list_projects,
    show            => \&show,
    reload          => \&reload,
    help            => \&help,
);

my $action_re = join '|',
   sort { length($b) <=> length($a) }
   keys %actions;

print $action_re, $/;

sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];
    my $response;
    my %info = (
        channel => $channel,
        nick    => $nick,
    );
    if ($what =~ /^ \Q$nickname\E [:;,.]?  \s* (.+) /x) {
        my $msg = $1;
        print "received msg <<$msg>>\n";
        if ($msg =~ m/^($action_re)/) {
            my $response = $actions{$1}->($msg, \%info);
            say_or_action($response, $channel, $nick) if defined $response;
        }
    } elsif ($what =~ /^:(?:wq|x|q!?)/) {
        $irc->yield( ctcp => $channel, "ACTION hugs $nick, good vi(m) user!");
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
            my $response = $pm->add_collab($_->{whom}, $_->{proj}, $account);
            say_or_action($response, $channel, $nick);
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

sub say_or_action {
    my ($response, $channel, $nick) = @_;
    if (defined($response)) {
        if ($response =~ m/^ACTION/) {
            $irc->yield( ctcp => $channel, $response);
        } else  {
            $irc->yield(
                privmsg =>  $channel, "$nick: $response",
            );
        }
    }
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

$poe_kernel->run();
