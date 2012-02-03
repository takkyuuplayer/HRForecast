package HRForecast::Web;

use strict;
use warnings;
use utf8;
use Kossy;
use HTTP::Date;
use Time::Piece;
use HRForecast::Data;
use Log::Minimal;
use JSON;

my $JSON = JSON->new()->ascii(1);
sub encode_json {
    $JSON->encode(shift);
}

sub data {
    my $self = shift;
    $self->{__data} ||= HRForecast::Data->new();
    $self->{__data};
}

sub calc_term {
    my $self = shift;
    my ($term, $from, $to) = @_;
    if ( $term eq 'w' ) {
        $from = time - 86400 * 10;
        $to = time;
    }
    elsif ( $term eq 'm' ) {
        $from = time - 86400 * 40;
        $to = time;
    }
    elsif ( $term eq 'y' ) {
        $from = time - 86400 * 400;
        $to = time;
    }
    else {
        $from = HTTP::Date::str2time($from);
        $to = HTTP::Date::str2time($to);
    }
    $from = localtime($from - ($from % 3600));
    $to = localtime($to - ($to % 3600));
    return ($from,$to);
}

filter 'sidebar' => sub {
    my $app = shift;
    sub {
        my ( $self, $c )  = @_;
        my $services = $self->data->get_services();
        my @services;
        for my $service ( @$services ) {
            my $sections = $self->data->get_sections($service);
            my @sections;
            for my $section ( @$sections ) {
                push @sections, {
                    active => 
                        $c->args->{service_name} && $c->args->{service_name} eq $service &&
                            $c->args->{section_name} && $c->args->{section_name} eq $section ? 1 : 0,
                    name => $section
                };
            }
            push @services , {
                name => $service,
                sections => \@sections,
            };
        }
        $c->stash->{services} = \@services;
        $app->($self,$c);
    }
};


filter 'get_metrics' => sub {
    my $app = shift;
    sub {
        my ($self, $c) = @_;
        my $row = $self->data->get(
            $c->args->{service_name}, $c->args->{section_name}, $c->args->{graph_name},
        );
        $c->halt(404) unless $row;
        $c->stash->{metrics} = $row;
        $app->($self,$c);
    }
};


get '/' => [qw/sidebar/] => sub {
    my ( $self, $c )  = @_;
    $c->render('index.tx', {});
};

get '/docs' => sub {
    my ( $self, $c )  = @_;
    $c->render('docs.tx',{});
};

get '/list/:service_name/:section_name' => [qw/sidebar/] => sub {
    my ( $self, $c )  = @_;
    my $result = $c->req->validator([
        't' => {
            default => 'm',
            rule => [
                [['CHOICE',qw/w m y c/],'invalid browse term'],
            ],
        },
        'from' => {
            default => localtime(time-86400*35)->strftime('%Y/%m/%d %T'),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid From datetime'],
            ],
        },
        'to' => {
            default => localtime()->strftime('%Y/%m/%d %T'),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid To datetime'],
            ],
        },
    ]);
    my $rows = $self->data->get_metricses(
        $c->args->{service_name}, $c->args->{section_name}
    );
    my ($from ,$to) = $self->calc_term( map {$result->valid($_)} qw/t from to/);
    $c->render('list.tx',{ 
        metricses => $rows, valid => $result, 
        date_window => encode_json([$from->strftime('%Y/%m/%d %T'), 
                                    $to->strftime('%Y/%m/%d %T')]),
    });
};

get '/csv/:service_name/:section_name/:graph_name' => [qw/get_metrics/] => sub {
    my ( $self, $c )  = @_;
    my $result = $c->req->validator([
        't' => {
            default => 'm',
            rule => [
                [['CHOICE',qw/w m y c/],'invalid browse term'],
            ],
        },
        'from' => {
            default => localtime(time-86400*35)->strftime('%Y/%m/%d %T'),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid From datetime'],
            ],
        },
        'to' => {
            default => localtime()->strftime('%Y/%m/%d %T'),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid To datetime'],
            ],
        },
    ]);
    my ($from ,$to) = $self->calc_term( map{ $result->valid($_) } qw/t from to/);
    my ($rows,$opt) = $self->data->get_data(
        $c->stash->{metrics}->{id},
        $from, $to
    );
    my $csv = sprintf("Date,%s\n",$c->args->{graph_name});
    foreach my $row ( @$rows ) {
        $csv .= sprintf "%s,%d\n", $row->{datetime}->strftime('%Y/%m/%d %T'), $row->{number}
    }
    $c->res->content_type('text/plain');
    $c->res->body($csv);
    $c->res;
};

post '/api/:service_name/:section_name/:graph_name' => sub {
    my ( $self, $c )  = @_;
    my $result = $c->req->validator([
        'number' => {
            rule => [
                ['NOT_NULL','number is null'],
                ['INT','number is not null']
            ],
        },
        'datetime' => {
            rule => [
                ['NOT_NULL','datetime is null'],
                [ sub { HTTP::Date::str2time($_[1]) } ,'datetime is not null']                
            ],
        },
    ]);

    if ( $result->has_error ) {
        my $res = $c->render_json({
            error => 1,
            messages => $result->messages
        });
        $res->status(400);
        return $res;
    }

    my $ret = $self->data->update(
        $c->args->{service_name}, $c->args->{section_name}, $c->args->{graph_name},
        $result->valid('number'), HTTP::Date::str2time($result->valid('datetime'))
    );
    $c->render_json({ error => 0 });
};

1;

