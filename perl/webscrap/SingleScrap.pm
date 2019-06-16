#! /usr/bin/env perl
package SingleScrap;
use strict;
use warnings;

use File::Path qw(make_path);
# use parent qw(ParentClass);

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = shift // {};
	bless $self, $class;
	return $self;
}

sub run
{
	my ($self) = @_;
	
	$self->{todo} = [];
	$self->{seen} = {};

	my $starturl = $self->{starturl};
	return unless $starturl;

	my $basedir = $self->{basedir};

	push(@{$self->{todo}}, $start_url);
	$self->{seen}->{$start_url} = 1;

	while (@{$self->{todo}}) {
		# 获取网页
		my $url = shift(@{$self->{todo}});
		my $html = $self->{wget}->($url);

		# 添加链接
		my $links = $self->{findlike}->($html, $starturl);
		foreach my $link (@$links) {
			unless ($self->{seen}->{$link}) {
				push(@{$self->{todo}}, $link);
				$self->{seen}->{$link} = 1;
			}
		}
		
	}
	
}
1;

