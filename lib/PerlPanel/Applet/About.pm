# $Id: About.pm,v 1.18 2004/08/24 15:22:03 jodrell Exp $
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
use vars qw($BORDER $MARKUP_FMT);
use strict;

our $BORDER = 10;

our $MARKUP_FMT = <<"END";
<span foreground="%%s"><span size="large"><span weight="bold">%s</span>

%s</span>

<span weight="bold">%s %s</span>

<span size="small"><span weight="bold">%s</span> %s</span>

<span size="large" weight="bold">%s</span>

<span size="small">%s

%s</span></span>

END

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
		$MARKUP_FMT,
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

	$self->{image} = Gtk2::Image->new_from_file(sprintf('%s/share/%s/%s-about.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME), lc($PerlPanel::NAME)));

	$self->{label} = Gtk2::Label->new;
	$self->{label}->set_size_request($self->{image}->get_pixbuf->get_width - $BORDER, -1);
	$self->{label}->set_justify('center');
	$self->{label}->set_line_wrap(1);
	$self->{label}->set_markup(sprintf($markup, '#FFFFFF'));

	$self->{slabel} = Gtk2::Label->new;
	$self->{slabel}->set_size_request($self->{image}->get_pixbuf->get_width - $BORDER -1, -1);
	$self->{slabel}->set_justify('center');
	$self->{slabel}->set_line_wrap(1);
	$self->{slabel}->set_markup(sprintf($markup, '#000000'));

	$self->{fixed} = Gtk2::Fixed->new;

	$self->{fixed}->add($self->{image});

	$self->{fixed}->put($self->{slabel}, $BORDER+1, 115+1);
	$self->{fixed}->put($self->{label}, $BORDER, 115);

	$self->{box} = Gtk2::EventBox->new;
	$self->{box}->signal_connect('button_release_event', sub {
		$self->{window}->destroy;
	});
	$self->{box}->add($self->{fixed});

	$self->{window} = Gtk2::Window->new;
	$self->{window}->set_title(_('About {name}', name => $PerlPanel::NAME));
	$self->{window}->set_icon(PerlPanel::icon);
	$self->{window}->set_decorated(0);
	$self->{window}->set_modal(1);
	$self->{window}->set_position('center');
	$self->{window}->add($self->{box});
	$self->{window}->show_all;

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
