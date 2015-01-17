#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use lib "$FindBin::Bin/lib";
use File::Basename;
use Getopt::Long;
use Log::Minimal;

$Log::Minimal::AUTODUMP = 1;

Getopt::Long::Configure ("no_ignore_case");
GetOptions(
    "c|config=s" => \my $config_file,
    "h|help" => \my $help,
);

if ( $help || !$config_file ) {
    print "usage: $0 --config config.pl\n";
    exit(1);
}

my $c;
{
    $c = do $config_file;
    croakf "%s: %s", $config_file, $@ if $@;
    croakf "%s: %s", $config_file, $! if $!;
    croakf "%s does not return hashref", $config_file if ref($c) ne 'HASH';
}

open my $fh, '<', "$FindBin::Bin/schema.sql" or die "failed to open: $!";
my $sql = do { local $/; <$fh> };

my $dbi = DBI->connect($c->{dsn}, $c->{username}, $c->{password});
map {$dbi->do($_) if $_ =~ /CREATE TABLE/ } split /;/, $sql;
