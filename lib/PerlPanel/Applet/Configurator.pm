# $Id: Configurator.pm,v 1.8 2003/06/19 15:57:03 jodrell Exp $
package PerlPanel::Applet::Configurator;
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
	$self->{image} = Gtk2::Image->new_from_stock('gtk-preferences', $PerlPanel::OBJECT_REF->icon_size_name);
	$self->{widget}->add($self->{image});
	$self->{widget}->set_relief('none');
	$self->{widget}->signal_connect('clicked', sub { $self->{widget}->set_sensitive(0) ; $self->init });
	$PerlPanel::TOOLTIP_REF->set_tip($self->{widget}, 'PerlPanel Configurator');
	return 1;
}

sub init {
	my $self = shift;
	$self->{backup} = XML::Simple::XMLin(XML::Simple::XMLout($PerlPanel::OBJECT_REF->{config}));
	$self->build_ui;
	$self->show_all;
	return 1;
}

sub build_ui {
	my $self = shift;
	$self->{window} = Gtk2::Dialog->new;
	$self->{window}->signal_connect('delete_event', sub { $self->discard });
	$self->{window}->set_title('PerlPanel Configuration');
	$self->{window}->set_position('center');
	$self->{window}->set_border_width(8);
	$self->{window}->set_default_size(275, 325);
	$self->{window}->vbox->set_border_width(8);
	$self->{window}->vbox->set_spacing(8);

	$self->{notebook} = Gtk2::Notebook->new;
	$self->{window}->vbox->pack_start($self->{notebook}, 1, 1, 0);

	$self->{pages}{panel} = Gtk2::Table->new(4, 2, 0);
	$self->{pages}{panel}->set_border_width(8);
	$self->{pages}{panel}->set_col_spacings(8);
	$self->{pages}{panel}->set_row_spacings(8);

	$self->{pages}{panel}->attach_defaults($self->control_label('Panel position:'), 0, 1, 0, 1);
	$self->{controls}{position} = $self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'position', 'enum', qw(top bottom));
	$self->{pages}{panel}->attach($self->{controls}{position}, 1, 2, 0, 1, 'fill', 'expand', 0, 0);

	$self->{pages}{panel}->attach_defaults($self->control_label('Panel spacing:'), 0, 1, 1, 2);
	$self->{controls}{spacing} = $self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'spacing', 'int');
	$self->{pages}{panel}->attach_defaults($self->{controls}{spacing}, 1, 2, 1, 2);

	$self->{pages}{panel}->attach_defaults($self->control_label('Icon size:'), 0, 1, 2, 3);
	$self->{controls}{icon_size} = $self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'size', 'enum', qw(tiny small medium large));
	$self->{pages}{panel}->attach($self->{controls}{icon_size}, 1, 2, 2, 3, 'fill', 'expand', 0, 0);

	$self->{notebook}->append_page($self->{pages}{panel}, $self->control_label('Panel'));

	if (!defined($PerlPanel::OBJECT_REF->{screen})) {

		$self->{pages}{screen} = Gtk2::Table->new(2, 2, 0);
		$self->{pages}{screen}->set_border_width(8);
		$self->{pages}{screen}->set_col_spacings(8);
		$self->{pages}{screen}->set_row_spacings(8);

		$self->{pages}{screen}->attach_defaults($self->control_label('Screen width:'), 0, 1, 0, 1);
		$self->{pages}{screen}->attach_defaults($self->control($PerlPanel::OBJECT_REF->{config}{screen}, 'width', 'int'), 1, 2, 0, 1);

		$self->{pages}{screen}->attach_defaults($self->control_label('Screen height:'), 0, 1, 1, 2);
		$self->{pages}{screen}->attach_defaults($self->control($PerlPanel::OBJECT_REF->{config}{screen}, 'height', , 'int'), 1, 2, 1, 2);

		$self->{notebook}->append_page($self->{pages}{screen}, $self->control_label('Screen'));

	}

	$self->{store} = Gtk2::ListStore->new('Glib::String');

	$self->{view} = Gtk2::TreeView->new($self->{store});
	$self->{renderer} = Gtk2::CellRendererText->new;
	$self->{column} = Gtk2::TreeViewColumn->new_with_attributes('Applet', $self->{renderer}, text => 0);
	$self->{view}->append_column($self->{column});

	$self->populate_list;

	$self->{scrwin} = Gtk2::ScrolledWindow->new;
	$self->{scrwin}->set_policy('automatic', 'automatic');
	$self->{scrwin}->add_with_viewport($self->{view});

	$self->{buttonbox} = Gtk2::VButtonBox->new;

	$self->{buttons}{up} = Gtk2::Button->new_from_stock('gtk-go-up');
	$self->{buttons}{up}->set_relief('none');
	$self->{buttons}{up}->signal_connect('clicked', sub { $self->move(-1) });

	$self->{buttons}{down} = Gtk2::Button->new_from_stock('gtk-go-down');
	$self->{buttons}{down}->set_relief('none');
	$self->{buttons}{down}->signal_connect('clicked', sub { $self->move(1) });

	$self->{buttons}{add} = Gtk2::Button->new_from_stock('gtk-add');
	$self->{buttons}{add}->set_relief('none');
	$self->{buttons}{add}->signal_connect('clicked', sub { $self->add_dialog });

	$self->{buttons}{delete} = Gtk2::Button->new_from_stock('gtk-delete');
	$self->{buttons}{delete}->set_relief('none');
	$self->{buttons}{delete}->signal_connect('clicked', sub {
		my ($iter, undef) = $self->{view}->get_selection->get_selected;
		return undef unless (defined($iter));
		my $idx = ($self->{store}->get_path($iter)->get_indices)[0];
		$self->{store}->remove($iter);
		splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $idx, 1);
	});

	$self->{buttonbox}->add($self->{buttons}{up});
	$self->{buttonbox}->add($self->{buttons}{down});
	$self->{buttonbox}->add($self->{buttons}{add});
	$self->{buttonbox}->add($self->{buttons}{delete});

	$self->{pages}{applets} = Gtk2::HBox->new;
	$self->{pages}{applets}->set_spacing(8);
	$self->{pages}{applets}->set_border_width(8);
	$self->{pages}{applets}->pack_start($self->{scrwin}, 1, 1, 0);
	$self->{pages}{applets}->pack_start($self->{buttonbox}, 0, 0, 0);

	$self->{notebook}->append_page($self->{pages}{applets}, $self->control_label('Applets'));

	$self->{window}->add_buttons(
		'gtk-cancel', 1,
		'gtk-ok', 0,
	);

	$self->{window}->signal_connect(
		'response',
		sub {
			$self->{window}->destroy;
			if ($_[1] == 0) {
				$PerlPanel::OBJECT_REF->save_config;
				$PerlPanel::OBJECT_REF->reload;
			} elsif ($_[1] == 1) {
				$self->discard;
			}
		}
	);

	return 1;
}

sub control {
	my ($self, $ref, $name, $type, @values) = @_;
	my $control;
	if (lc($type) eq 'int') {
		my $adj = Gtk2::Adjustment->new($ref->{$name}, 0, 5000, 1, 100, undef);
		$control = Gtk2::SpinButton->new($adj, 1, 0);
		$adj->signal_connect('value_changed', sub { $ref->{$name} = $control->get_value_as_int });
	} elsif (lc($type) eq 'enum') {
		$control = Gtk2::OptionMenu->new;
		my $menu = Gtk2::Menu->new;
		$control->set_menu($menu);
		for (my $i = 0 ; $i < scalar(@values) ; $i++) {
			my $value = $values[$i];
			my $item = Gtk2::MenuItem->new($value);
			$item->signal_connect('activate', sub { $ref->{$name} = $value });
			$menu->append($item);
			if ($value eq $ref->{$name}) {
				$control->set_history($i);
			}
		}
	} else {
		$control = Gtk2::Entry->new;
		$control->set_text($ref->{$name});
		$control->signal_connect('key_press_event', sub { $ref->{$name} = $control->get_text });
	}
	return $control;
}

sub populate_list {
	my $self = shift;
	foreach my $appletname (@{$PerlPanel::OBJECT_REF->{config}{applets}}) {
		my $iter = $self->{store}->append;
		$self->{store}->set($iter, 0, $appletname);
	}
	return 1;
}

sub discard {
	my $self = shift;
	$self->{widget}->set_sensitive(1);
	$PerlPanel::OBJECT_REF->{config} = $self->{backup};
	$PerlPanel::OBJECT_REF->save_config;
	return 1;
}

sub add_dialog {
	my $self = shift;
	my $dialog = Gtk2::Dialog->new;
	$dialog->set_title("$PerlPanel::NAME: Add Applet");
	$dialog->set_position('center');
	$dialog->set_modal(1);
	$dialog->set_border_width(8);
	$dialog->set_default_size(200, 250);
	my $model = Gtk2::ListStore->new('Glib::String');
	my $view = Gtk2::TreeView->new($model);
	my $renderer = Gtk2::CellRendererText->new;
	my $column = Gtk2::TreeViewColumn->new_with_attributes('Applet', $renderer, text => 0);
	$view->append_column($column);

	my @files;
	foreach my $dir (sprintf('%s/lib/%s/%s/Applet', $PerlPanel::PREFIX, lc($PerlPanel::NAME), $PerlPanel::NAME), sprintf('%s/.%s/applets', $ENV{HOME}, lc($PerlPanel::NAME))) {
		opendir(DIR, $dir) or next;
		push(@files, grep { /\.pm$/ } readdir(DIR));
		closedir(DIR);
	}

	@files = sort(@files);

	foreach my $file (@files) {
		my ($appletname, undef) = split(/\./, $file, 2);
		my $iter = $model->append;
		$model->set($iter, 0, $appletname);
	}

	my $scrwin = Gtk2::ScrolledWindow->new;
	$scrwin->set_policy('automatic', 'automatic');
	$scrwin->add_with_viewport($view);

	$dialog->vbox->pack_start($scrwin, 1, 1, 0);

	$self->{window}->add_buttons(
		'gtk-cancel', 1,
		'gtk-ok', 0,
	);

	$self->{window}->signal_connect('response', sub {
		if ($_[1] == 0) {
			# 'ok' was clicked
			my ($iter, $blah) = $view->get_selection->get_selected;
			return undef unless (defined($iter));
			my $idx = ($model->get_path($iter)->get_indices)[0];
			my ($appletname, undef) = split(/\./, $files[$idx], 2);
			push(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $appletname);
			my $newiter = $self->{store}->append;
			$self->{store}->set($newiter, 0, $appletname);
			$dialog->destroy;
		} elsif ($_[1] == 1) {
			# 'cancel' was clicked
			$dialog->destroy;
		}
	});

	$dialog->show_all;

	return 1;
}

sub move {
	my ($self, $move) = @_;
	my ($iter, $blah) = $self->{view}->get_selection->get_selected;
	return undef unless (defined($iter));
	my $idx = ($self->{store}->get_path($iter)->get_indices)[0];
	my $newidx = $idx + $move;
	return undef if ($newidx < 0 || $newidx >= scalar(@{$PerlPanel::OBJECT_REF->{config}{applets}}));
	$self->{store}->clear;
	splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $newidx, 0, splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $idx, 1));
	$self->populate_list;
	return 1;
}

sub control_label {
	my ($self, $message) = @_;
	my $label = Gtk2::Label->new($message);
	$label->set_alignment(1, 0.5);
	return $label;
}

sub show_all {
	my $self = shift;
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
