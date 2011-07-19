#!/usr/bin/env perl

use Mojolicious::Lite;
use WebService::Simple;
use utf8;
use Encode;
use Data::Dumper;
use JSON;
use Cache::FileCache;
use Math::Round qw/nearest/;
use LWP::UserAgent qw/get/;

get '/' => sub {
  my $self = shift;

  my $cache = Cache::FileCache->new({
    cache_root => '/tmp',
    namespace => 'setuden',
    default_expires_in  => '10m',
  });
  my $uri = 'http://tepco-usage-api.appspot.com/latest.json';
  my $data = $cache->get($uri);

  if (defined($data)) {
    my $ret_ref = get_jsond($data);
    $self->stash(jsond => $ret_ref->{jsond});
    $self->stash(usage => $ret_ref->{usage});
    $self->stash(peek_usage => $ret_ref->{peek_usage});
  } else {
    my $ua = LWP::UserAgent->new;
    my $res = $ua->get($uri);
    $cache->set($uri, $res->content);
    $cache->Purge();

    my $ret_ref = get_jsond($res->content);
    $self->stash(jsond => $ret_ref->{jsond});
    $self->stash(usage => $ret_ref->{usage});
    $self->stash(peek_usage => $ret_ref->{peek_usage});
  }
  $self->render("index");
};

sub get_jsond {
  my $data = shift;
  my $jsond = decode_json($data);
  my $usage = nearest(0.1, $jsond->{usage} / $jsond->{capacity} * 100);
  my $peek_usage = nearest(0.1, $jsond->{forecast_peak_usage} / $jsond->{capacity} * 100);

  my %ret = (
    jsond => $jsond,
    usage => $usage,
    peek_usage => $peek_usage,
  );
  return \%ret;
}

app->start;

__DATA__
@@ index.html.ep
% layout 'default';
% title '東京電力 今日のでんりょく予報';
<div id="header">
<h2>東京電力 今日のでんりょく予報</h2>
</div>
<div id="content">
<h3>最新情報</h3>
<%= $jsond->{year} %>年<%= $jsond->{month} %>月<%= $jsond->{day} %>日 
<%= $jsond->{hour} %>〜<%= $jsond->{hour}+1 %>時
<br /> 
<br /> 
この時間帯の電力使用状況　<font color="red"><%= $usage %></font> % 
<br />
<br /> 
消費電力：<%= $jsond->{usage} %>万KW 　供給可能最大電力：<%= $jsond->{capacity} %>万KW）
<br />
<br />
<div id="graph">
<img src="http://chart.apis.google.com/chart?chxs=0,000000,10.5,0,l,000000&chxt=x&chbh=a,4,1&chs=337x90&cht=bhs&chco=FF0000,80C65A&chd=t:<%= $usage %>|100&chdl=%E4%BD%BF%E7%94%A8%E7%8E%87&chma=0,0,10,10&chtt=%E6%9D%B1%E4%BA%AC%E9%9B%BB%E5%8A%9B+%E9%9B%BB%E5%8A%9B%E4%BD%BF%E7%94%A8%E7%8A%B6%E6%B3%81&chts=0B0B0B,14" width="337" height="90" alt="東京電力 電力使用状況" />
</div>
<br />
<h3>本日の最大需要予測</h3>
時間帯：　<%= $jsond->{forecast_peak_period} %>時
<br />
予想最大電力：<%= $jsond->{forecast_peak_usage} %>万KW 　ピーク時供給力：<%= $jsond->{capacity} %>万KW）
<div id="graph">
<img src="http://chart.apis.google.com/chart?chxs=0,000000,10.5,0,l,000000&chxt=x&chbh=a,4,1&chs=337x90&cht=bhs&chco=929292,FFCC33&chd=t:<%= $peek_usage %>|100&chdl=%E4%BD%BF%E7%94%A8%E7%8E%87&chma=0,0,10,10&chtt=%E6%9D%B1%E4%BA%AC%E9%9B%BB%E5%8A%9B+%E9%9B%BB%E5%8A%9B%E4%BD%BF%E7%94%A8%E7%8A%B6%E6%B3%81&chts=0B0B0B,14" width="337" height="90" alt="東京電力 電力使用状況" />
</div>
</div>

@@ layouts/default.html.ep
<!doctype html>
  <html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=UTF-8">
    <%= stylesheet 'css/common.css' %>
    <title><%= title %></title>
  </head>
  <body>
    <%= content %>
  </body>
</html>
