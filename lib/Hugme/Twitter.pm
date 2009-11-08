package Hugme::Twitter;
use strict;
use warnings;
use JSON;

my %twitter_accounts;
load_data();

sub load_data {
    my $fn = 'twitter.json';
    open my $fh, '<', $fn or die "Can't open '$fn' for reading: $!";
    my $json = do { local $/; <$fh> };
    close $fh or warn $!;
    %twitter_accounts = %{ from_json($json) };
}

sub twit {
    my ($msg, $info, $account) = @_;
    my (undef, $twitchan, $rest) = split / /, $msg, 3;
    return "Sorry, I don't have access to twitter account '$twitchan'"
        unless defined $twitter_accounts{$twitchan};
    return "Sorry, you don't have permissions to twit on '$twitchan'"
        unless $account ~~  @{$twitter_accounts{$twitchan}{allowed}};
    my $len = length($rest);
    return "Sorry, too long ($len chars, 140 allowed)" if $len > 140;
    my $n = eval {
        require Net::Twitter::Lite;
        Net::Twitter::Lite->new(
            username    => $twitchan,
            password    => $twitter_accounts{$twitchan}{password},
            clientname  => 'IRC (hugme)',
        );
    };
    return "Sorry, Can't init Net::Twitter::Lite object (huh? $!)"
        unless defined $n;
    if (eval {$n->update($rest) }) {
        return "ACTION hugs $info->{nick}; tweet delivered";
    } else {
        return "Ooops, there was an error: $!";
    }
}

1;
