# $Id: Clock.pm,v 1.9 2003/06/05 14:33:31 jodrell Exp $
package PerlPanel::Applet::Clock;
use POSIX qw(strftime);
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
	$self->{label}= Gtk2::Label->new();
	$self->{widget}->add($self->{label});
	$self->{widget}->signal_connect('clicked', sub { $self->prefs });
	$self->update;
	Glib::Timeout->add($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{interval}, sub { $self->update });
	return 1;
}

sub update {
	my $self = shift;
	$self->{label}->set_text(strftime($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{format}, localtime(time())));
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, strftime($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{date_format}, localtime(time())));
	return 1;
}

sub prefs {
	my $self = shift;
	$self->{widget}->set_sensitive(0);
	$self->{window} = Gtk2::Dialog->new;
	$self->{window}->set_title("$PerlPanel::NAME: Clock Configuration");
	$self->{window}->signal_connect('delete_event', sub { $self->{widget}->set_sensitive(1) });
	$self->{window}->set_border_width(8);
	$self->{window}->vbox->set_spacing(8);
	$self->{table} = Gtk2::Table->new(3, 2, 0);
	$self->{table}->set_col_spacings(8);
	$self->{table}->set_row_spacings(8);

	$self->{controls}{format} = Gtk2::Entry->new;
	$self->{controls}{format}->set_text($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{format});

	$self->{controls}{date_format} = Gtk2::Entry->new;
	$self->{controls}{date_format}->set_text($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{date_format});

	my $adj = Gtk2::Adjustment->new($PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{interval}, 0, 60000, 1, 1000, undef);
	$self->{controls}{interval} = Gtk2::SpinButton->new($adj, 1, 0);

	$self->{table}->attach_defaults(Gtk2::Label->new('Date format:'), 0, 1, 0, 1);
	$self->{table}->attach_defaults($self->{controls}{format}, 1, 2, 0, 1);

	$self->{table}->attach_defaults(Gtk2::Label->new('Tooltip format:'), 0, 1, 1, 2);
	$self->{table}->attach_defaults($self->{controls}{date_format}, 1, 2, 1, 2);

	$self->{table}->attach_defaults(Gtk2::Label->new('Update interval (ms):'), 0, 1, 2, 3);
	$self->{table}->attach_defaults($self->{controls}{interval}, 1, 2, 2, 3);

	$self->{buttons}{ok} = Gtk2::Button->new_from_stock('gtk-ok');
	$self->{buttons}{ok}->signal_connect('clicked', sub {
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{format}      = $self->{controls}{format}->get_text;
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{date_format} = $self->{controls}{date_format}->get_text;
		$PerlPanel::OBJECT_REF->{config}{appletconf}{Clock}{interval}    = $self->{controls}{interval}->get_value_as_int;
		$self->{widget}->set_sensitive(1);
		$self->{window}->destroy;
		$PerlPanel::OBJECT_REF->save_config;
		$PerlPanel::OBJECT_REF->reload;
	});

	$self->{buttons}{cancel} = Gtk2::Button->new_from_stock('gtk-cancel');
	$self->{buttons}{cancel}->signal_connect('clicked', sub {
		$self->{widget}->set_sensitive(1);
		$self->{window}->destroy;
	});

	$self->{window}->vbox->pack_start($self->{table}, 1, 1, 0);
	$self->{window}->action_area->pack_end($self->{buttons}{cancel}, 0, 0, 0);
	$self->{window}->action_area->pack_end($self->{buttons}{ok}, 0, 0, 0);

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
	return {
		format		=> '%H:%M',
		date_format	=> '%c',
		interval	=> 1000,
	}
}

1;
