# $Id: About.pm,v 1.13 2004/05/27 16:29:52 jodrell Exp $
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
package PerlPanel::Applet::About;
use strict;

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;
	$self->{widget} = Gtk2::Button->new;
	$self->{widget}->set_relief('none');
	$self->{widget}->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('about', PerlPanel::icon_size)));
	$self->{widget}->signal_connect('clicked', sub { $self->about });
	PerlPanel::tips->set_tip($self->{widget}, _('About {name}', name => $PerlPanel::NAME));
	return 1;

}

sub about {
	my $self = shift;
	my $lead_authors = join(", ", @PerlPanel::LEAD_AUTHORS);
	$lead_authors =~ s/</&lt;/g;
	$lead_authors =~ s/>/&gt;/g;
	my $co_authors = join(", ", @PerlPanel::CO_AUTHORS);
	$co_authors =~ s/</&lt;/g;
	$co_authors =~ s/>/&gt;/g;
	my $markup = sprintf(
		"<span foreground=\"#FFFFFF\">%s\n\n%s\n\n%s %s\n\n<span size=\"small\">%s %s</span>\n\n%s\n\n<span size=\"small\">%s\n\n%s</span></span>",
		($PerlPanel::VERSION eq '@VERSION@' ? _('Sandbox Mode') : _('Version {version}', version => $PerlPanel::VERSION)),
		$PerlPanel::DESCRIPTION,
		_('Author:'),
		$lead_authors,
		_('With:'),
		$co_authors,
		$PerlPanel::URL,
		$PerlPanel::LICENSE,
		_(
			'Using Perl v{perl_ver}, Gtk+ v{gtk_ver} and Gtk2.pm v{gtk2_ver}.',
			perl_ver	=> sprintf('%vd', $^V),
			gtk_ver		=> sprintf('%d.%d.%d', Gtk2->get_version_info),
			gtk2_ver	=> $Gtk2::VERSION,
		),
	);

	my $i = Gtk2::Image->new_from_file(sprintf('%s/share/pixmaps/%s-about.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)));

	my $l = Gtk2::Label->new;
	$l->set_size_request($i->get_pixbuf->get_width, -1);
	$l->set_justify('center');
	$l->set_line_wrap(1);
	$l->set_markup($markup);

	my $f = Gtk2::Fixed->new;

	$f->add($i);

	$f->put($l, 0, 115);

	my $e = Gtk2::EventBox->new;
	$e->signal_connect('button_release_event', sub { exit });
	$e->add($f);

	my $w = Gtk2::Window->new;
	$w->set_decorated(0);
	$w->set_modal(1);
	$w->set_position('center');
	$w->add($e);
	$w->show_all;

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
	return undef;
}

1;
