my $c = {
    username => 'root',
    password => '',
    hostname => '127.0.0.1',
    database => 'hrforecast',
    dsn      => 'dbi:mysql:hrforecast;hostname=127.0.0.1',
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

%conf = (
    %$c,
    (   port => '80',

        #host => '127.0.0.1',
        front_proxy => [],
        allow_from  => [],
    )
);

\%conf;
