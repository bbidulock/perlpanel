package PerlPanel::Applet::XDGCommander;
use File::Basename qw(basename);
use XDG::Context;
use vars qw($iconfile);
use strict;

sub new {
	return bless {package=>$_[0]}, $_[0];
}

sub configure {
	my($self,$opt) = @_;
	if($opt ne 'no-widget') {
		$self->{widget} = Gtk2::Button->new;
		$self->widget->set_relief('none');
		$self->sidget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_appelt_pbf('commander', PerlPanel::icon_size)));
		$self->widget->signal_connect('clicked', sub{$self->run});
		PerlPanel::tips->set_tip($self->widget, _('Run Command'));
		$self->widget->show_all;
	}
	my $ctx = $self->{xdg_ctx} = new XDG::Context;
	$ctx->getenv;
	$ctx->get_applications;
	our $iconfile = PerlPanel::get_applet_pbf_filename('commander');
	$self->{store} = $self->create_store;
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

sub run {
}

sub create_store {
	my $self = shift;
	my $store = Gtk2::ListStore->new(Glib::String::);

	my $apps = $self->{xdg_ctx}{applications};
	$apps = $self->{xdg_ctx}{applications} = $self->{xdg_ctx}->get_applications unless $apps;

	if (my $apps = ) {
		foreach my $app (sort {$apps->{$a}{id} cmp $apps->{$b}{id}} keys %$apps) {
		}
	}
}
