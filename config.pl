my $c = {
    dsn => 'dbi:mysql:hrforecast;hostname=127.0.0.1',
    username => 'root',
    password => '',
    port => $ENV{PORT} // '5127',
    host => '127.0.0.1',
    front_proxy => [],
    allow_from => [],
};

if ($ENV{CLEARDB_DATABASE_URL} =~ m,mysql://(.*):(.*)@(.*)/(.*),) {
    my ($username, $password, $hostname, $database) = ($1, $2, $3, $4);
    $c->{username} = $username;
    $c->{password} = $password;
    $c->{hostname} = $hostname;
    $c->{database} = $database;
    $database =~ s/(.*)\?(.*)/$1/;
    $c->{dsn} = sprintf "dbi:mysql:database=%s:host=%s", $database, $hostname;
}

$c;
