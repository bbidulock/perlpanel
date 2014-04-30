package PerlPanel::Applet::Sensors;
use Gtk2::Helper;
use Gtk2::SimpleList;
use Hardware::SensorsParser;
use warnings;
use strict;

sub new {
	return bless {package=>$_[0]}, $_[0];
}

sub configure {
	my $self = shift;
	$self->{config} = PerlPanel::get_config('Sensors');

	$self->{config}{interval} = 1000 unless $self->{config}{interval};
	$self->{config}{units} = 'celcius' unless $self->{config}{units};

	$self->{parser} = new Hardware::SensorsParser();

	$self->{sensors} = {};
	$self->{widget} = Gtk2::HBox->new;

	$self->{image} = Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('Sensors',PerlPanel::icon_size));

	$self->{button} = Gtk2::Button->new;
	$self->{button}->signal_connect(clicked=>sub{$self->dialog});
	$self->{button}->set_relief('none');
	$self->{button}->add($self->{image});

	$self->{widget}->pack_start($self->{button});
	$self->{widget}->show_all;

	$self->update;
	PerlPanel::add_timeout($self->{config}{interval}, sub{ $self->update; return 1 });

	return 1;
}

sub update {
	my $self = shift;
	my $parser = $self->{parser};
	my @chips = $parser->list_chipset();
	foreach my $chip (@chips) {
		my @sensors = $parser->list_sensors($chip);
		foreach my $sensor (@sensors) {
			my @flags = $parser->list_sensor_flags($chip,$sensor);
			foreach my $flag (@flags) {
				my $tag = "$chip:$sensor:$flag";
				$self->{sensors}{$tag} = {} unless $self->{sensors}{$tag};
				my $value = $parser->get_sensor_value($chip,$sensor,$flag);
				$self->{sensors}{$tag}{value} = $value;
				my $label = $self->{sensors}{$tag}{label};
				unless ($label) {
					$label = Gtk::Label->new;
					$label->set_use_markup(1);
					$self->{widget}->pack_start($label, 0, 0, 0);
					$self->{sensors}{$tag}{label} = $label;
				}
				my $markup;
				if ($self->{config}{units} eq 'fahrenheit') {
					$value = $self->celsius_to_fahrenheit($value);
					$markup = sprintf("%d\N{DEGREES}F", $value);
				} elsif ($self->{config}{units} eq 'kelvin') {
					$value = $self->celsius_to_kelvin($value);
					$markup = sprintf("%d\N{DEGREES}K", $value);
				} else {
					$markup = sprintf("%d\N{DEGREES}C", $value);
				}
				my $tooltip = "Chip: $chip\nSensor: $sensor\nFlag: $flag\nValue: $markup";
				PerlPanel::tips->set_type($label, $tooltip);
				$label->set_markup("<small><b>$markup</b></small>");
			}
		}
	}
	return 1;
}

sub dialog {
	my $self = shift;
	$self->{button}->set_sensitive(0);

	my $list = Gtk2::SimpleList->new(units=>'text');
	@{$list->{data}} = qw(celsius fahrenheit kelvin);

	my $glade = PerlPanel::load_glade('sensors');
	$glade->get_widget('units')->set_model($list->get_model);

	my $i = 0;
	foreach my $unit (@{$list->{data}}) {
		if ($unit->[0] eq $self->{config}{units}) {
			$glade->get_widget('units')->set_active($i);
		}
		$i++;
	}
	$glade->get_widget('config_dialog')->set_icon(PerlPanel::icon);
	my $callback = sub{
		my($dialog,$response) = @_;
		if ($response eq 'ok') {
			$self->{config}{units} = $list->{data}[$glade->get_widget('units')->get_active]->[0];
			PerlPanel::save_config;
			$self->update;
		}
		$self->{button}->set_sensitive(1);
		$dialog->destroy;
	};
	$glade->get_widget('config_dialog')->signal_connect(response=>$callback);
	$glade->get_widget('config_dialog')->signal_connect(delete_event=>$callback);
	return 1;
}

sub button {
	return shift->{button};
}

sub widget {
	return shift->{widget};
}

sub expand {
	return 0;
}

sub fill {
	return 0;
}

sub end {
	return 'start';
}

sub get_default_config {
	return {
		interval => 10000,
		units => 'celcius',
	};
}

sub celsius_to_fahrenheit {
	my ($self, $celsius) = @_;
	return ($celsius * 1.8) + 32;
}

sub celsius_to_kelvin {
	my ($self, $celsius) = @_;
	return $celsius + 273.15;
}

1;
