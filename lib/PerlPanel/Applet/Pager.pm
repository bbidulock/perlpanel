# $Id: Pager.pm,v 1.5 2004/02/12 00:26:34 jodrell Exp $
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
package PerlPanel::Applet::Pager;
use Gnome2::Wnck;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{screen} = Gnome2::Wnck::Screen->get_default;
	$self->{screen}->force_update;

	$self->{widget} = Gnome2::Wnck::Pager->new($self->{screen});
	$self->widget->set_shadow_type('in');
	$self->widget->set_n_rows($PerlPanel::OBJECT_REF->{config}{appletconf}{Pager}{rows});

	# this is always fixed:
	my $y0 = $PerlPanel::OBJECT_REF->icon_size;

	# this is the height in pixels for each screen element in the pager:
	my $screen_height = $y0 / $PerlPanel::OBJECT_REF->{config}{appletconf}{Pager}{rows};

	# this is the width in pixels for each screen element in the pager:
	my $screen_width = $screen_height * ($PerlPanel::OBJECT_REF->{screen_width} / $PerlPanel::OBJECT_REF->{screen_height});

	# this is the number of columns in the pager, the pager is always square, unless it's a single row:
	my $cols = ($PerlPanel::OBJECT_REF->{config}{appletconf}{Pager}{rows} == 1 ? 4 : $PerlPanel::OBJECT_REF->{config}{appletconf}{Pager}{rows});

	# this is the width of the space we need to request:
	my $x0 = $screen_width * $cols;

	$self->widget->set_size_request($x0, $y0);

	# this is a hack to force the pager to resize to the correct size, after it's become visible.
	Glib::Timeout->add(10, sub {
		if ($self->widget->allocation->width != ($self->widget->allocation->height * $cols)) {
			$self->widget->set_size_request(
				$self->widget->allocation->height * $cols,
				$self->widget->allocation->height,
			);
			return 1;
		} else {
			return undef;
		}
	});

	PerlPanel::tips->set_tip($self->widget, 'Workspace Pager');
	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub expand {
	return 0;
}

sub fill {
	return 0;
}

sub end {
	return 'end';
}

sub get_default_config {
	return {rows => 1};
}

1;
