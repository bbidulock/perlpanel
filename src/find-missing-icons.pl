#!/usr/bin/perl
# $Id: find-missing-icons.pl,v 1.1 2005/01/08 14:03:27 jodrell Exp $
# This file is part of PerlPanel.
# 
# PerlPanel is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# PerlPanel is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with PerlPanel; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Copyright: (C) 2003-2004 Gavin Brown <gavin.brown@uk.com>
#
# This script is run against a source tree and reports what icons are missing
# from the various themes available. It assumes that the authoritative list
# of icons is the 'hicolor' theme.
use File::Basename qw(basename dirname);
use strict;

my $icon_dir = sprintf('%s/share/icons', $ENV{PWD});

opendir(DIR, $icon_dir) or die("$icon_dir: $!");

my @themes = grep { !/^(\.{1,2}|CVS)$/ } readdir(DIR);

closedir(DIR);

my $themes = {};
foreach my $theme (@themes) {
	my $dir = sprintf('%s/%s/48x48/apps', $icon_dir, $theme);
	opendir(DIR, $dir) or die("$dir: $!");
	map { $themes->{$theme}->{$_}++ } grep { /(svg|png)$/ } readdir(DIR);
	closedir(DIR);
}

my $missing = {};
foreach my $icon (keys(%{$themes->{'hicolor'}})) {
	foreach my $theme (grep { $_ ne 'hicolor' } keys(%{$themes})) {
		push(@{$missing->{$theme}}, $icon) if ($themes->{$theme}->{$icon} < 1);
	}
}

foreach my $theme (sort keys(%{$missing})) {
	printf("The '%s' theme is missing the following icons:\n\t", $theme);
	print join("\n\t", sort(@{$missing->{$theme}}))."\n\n";
}

exit 0;
