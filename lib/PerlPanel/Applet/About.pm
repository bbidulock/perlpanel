# $Id: About.pm,v 1.5 2003/07/03 16:07:39 jodrell Exp $
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
	$self->{widget}->add(Gtk2::Image->new_from_stock('gtk-dialog-info', $PerlPanel::OBJECT_REF->icon_size_name));
	$self->{widget}->signal_connect('clicked', sub { $self->about });
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, "About $PerlPanel::NAME");
	return 1;

}

sub about {
	my $self = shift;
	my $lead_authors = join("\n", @PerlPanel::LEAD_AUTHORS);
	$lead_authors =~ s/</&lt;/g;
	$lead_authors =~ s/>/&gt;/g;
	my $co_authors = join("\n", @PerlPanel::CO_AUTHORS);
	$co_authors =~ s/</&lt;/g;
	$co_authors =~ s/>/&gt;/g;
	my $text = sprintf(
		"<span weight=\"bold\" size=\"x-large\">%s version %s</span>\n\n%s\n\nAuthor:\n%s\n\n<span size=\"small\">With:\n%s</span>\n\n%s\n\n<span size=\"small\">%s\n\nUsing Perl v%vd, Gtk+ v%d.%d.%d and Gtk2.pm v%s</span>",
		$PerlPanel::NAME,
		$PerlPanel::VERSION,
		$PerlPanel::DESCRIPTION,
		$lead_authors,
		$co_authors,
		$PerlPanel::URL,
		$PerlPanel::LICENSE,
		$^V,
		Gtk2->get_version_info,
		$Gtk2::VERSION,
	);
	$self->{window} = Gtk2::Window->new('toplevel');
	$self->{window}->set_position('center');
	$self->{window}->set_border_width(15);
	$self->{window}->set_title("About $PerlPanel::NAME");
	$self->{window}->set_icon($PerlPanel::OBJECT_REF->icon);
	$self->{vbox} = Gtk2::VBox->new;
	$self->{vbox}->set_spacing(15);
	$self->{vbox}->pack_start(Gtk2::Image->new_from_file("$PerlPanel::PREFIX/share/pixmaps/perlpanel.png"), 0, 0, 0);
	$self->{label} = Gtk2::Label->new();
	$self->{label}->set_justify('center');
	$self->{label}->set_markup($text);
	$self->{vbox}->pack_start($self->{label}, 1, 1, 0);
	$self->{button} = Gtk2::Button->new_from_stock('gtk-ok');
	$self->{button}->signal_connect('clicked', sub { $self->{window}->destroy });
	$self->{vbox}->pack_start($self->{button}, 0, 0, 0);
	$self->{window}->add($self->{vbox});
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
