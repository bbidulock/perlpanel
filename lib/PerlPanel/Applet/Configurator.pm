# $Id: Configurator.pm,v 1.38 2004/02/18 19:27:17 jodrell Exp $
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
package PerlPanel::Applet::Configurator;
use Gtk2::SimpleList;
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
	$self->widget->add(Gtk2::Image->new_from_pixbuf(PerlPanel::get_applet_pbf('configurator', PerlPanel::icon_size)));
	$self->widget->set_relief('none');
	$self->widget->signal_connect('clicked', sub { $self->widget->set_sensitive(0) ; $self->init });
	PerlPanel::tips->set_tip($self->widget, 'Configure');
	return 1;
}

sub load_appletregistry {
	my $self = shift;
	$self->{regfile} = sprintf('%s/share/%s/applet.registry', $PerlPanel::PREFIX, lc($PerlPanel::NAME));
	open(REGFILE, $self->{regfile});
	while (<REGFILE>) {
		chomp;
		s/^\s*//g;
		s/\s*$//g;
		next if (/^$/ or /^#/);
		if (/^(\w+)=(.+)$/) {
			$self->{registry}{$1} = $2;
		}
	}
	close(REGFILE);
	return 1;
}

sub init {
	my $self = shift;
	$self->load_appletregistry;
	# oh man, is this a kludge. but no matter how much i tried i couldn't dereference the ref
	# in order to make a copy of the hash:
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
	$self->{window}->set_has_separator(0);
	$self->{window}->set_default_size(250, 350);
	$self->{window}->action_area->set_layout('end');
	$self->{window}->set_icon(PerlPanel::icon);

	$self->{notebook} = Gtk2::Notebook->new;
	$self->{notebook}->set_border_width(6);
	$self->{window}->vbox->pack_start($self->{notebook}, 1, 1, 0);

	$self->{pages}{panel_table} = Gtk2::Table->new(3, 2, 0);
	$self->{pages}{panel_table}->set_col_spacings(12);
	$self->{pages}{panel_table}->set_row_spacings(12);

	$self->{pages}{panel_table}->attach_defaults($self->control_label('Panel position:'), 0, 1, 0, 1);
	$self->{controls}{position} = $self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'position', 'enum', qw(top bottom));
	$self->{pages}{panel_table}->attach($self->{controls}{position}, 1, 2, 0, 1, 'fill', 'expand', 0, 0);

	$self->{pages}{panel_table}->attach_defaults($self->control_label('Applet spacing:'), 0, 1, 1, 2);
	$self->{controls}{spacing} = $self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'spacing', 'int');
	$self->{pages}{panel_table}->attach_defaults($self->{controls}{spacing}, 1, 2, 1, 2);

	$self->{pages}{panel_table}->attach_defaults($self->control_label('Icon size:'), 0, 1, 2, 3);
	$self->{controls}{icon_size} = $self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'size', 'enum', qw(tiny small medium large));
	$self->{pages}{panel_table}->attach($self->{controls}{icon_size}, 1, 2, 2, 3, 'fill', 'expand', 0, 0);

	$self->{pages}{panel} = Gtk2::VBox->new(0,0);
	$self->{pages}{panel}->set_border_width(12);
	$self->{pages}{panel}->set_spacing(6);

	$self->{pages}{panel}->pack_start($self->{pages}{panel_table}, 0, 0, 0);
	$self->{pages}{panel}->pack_start($self->control($PerlPanel::OBJECT_REF->{config}{panel}, 'autohide', 'boolean', 'Autohide'), 0, 0, 0);

	$self->{notebook}->append_page($self->{pages}{panel}, 'Panel');

	$self->{pages}{menu} = Gtk2::VBox->new;

	if (PerlPanel::has_application_menu) {

		my $label = Gtk2::Label->new;
		$label->set_markup('<span weight="bold">Menu</span>');
		my $align = Gtk2::Alignment->new(0, 0.5, 0, 0);
		$align->add($label);
		$self->{pages}{menu}->pack_start($align, 0, 0, 0);

		$self->{iconfile}{label} = $self->control_label('Menu icon:');

		$self->{menu_vbox} = Gtk2::VBox->new;
		$self->{menu_vbox}->set_border_width(12);
		$self->{menu_vbox}->set_spacing(6);

		$self->{menu_vbox_wrapper} = Gtk2::HBox->new;
		$self->{menu_vbox_wrapper}->pack_start(Gtk2::Label->new('    '), 0, 0, 0);
		$self->{menu_vbox_wrapper}->pack_start($self->{menu_vbox}, 1, 1, 0);

		$self->{iconfile}{icon} = Gtk2::Image->new_from_file($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}{icon});
		$self->{controls}{iconfile} = Gtk2::Button->new;
		$self->{controls}{iconfile}->add($self->{iconfile}{icon});
		$self->{controls}{iconfile}->set_relief('none');
		$self->{controls}{iconfile}->signal_connect(
			'clicked',
			sub {
				$self->choose_menu_icon('BBMenu', 'iconfile');
			}
		);


		$self->{menu}{label} = $self->control_label('Menu label:');
		$self->{controls}{label} = $self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}, 'label', 'text', 'Menu label');

		$self->{menu}{table} = Gtk2::Table->new(3, 2);
		$self->{menu}{table}->set_col_spacings(12);
		$self->{menu}{table}->set_row_spacings(12);

		if (!PerlPanel::has_action_menu) {
			$self->{menu}{submenu_label} = $self->control_label('Submenu label:');
			$self->{controls}{submenu_label} = $self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}, 'submenu_label', 'text', 'Submenu label');
			$self->{menu}{table}->attach_defaults($self->{menu}{submenu_label},     0, 1, 0, 1);
			$self->{menu}{table}->attach_defaults($self->{controls}{submenu_label}, 1, 2, 0, 1);

		}
		$self->{menu}{table}->attach_defaults($self->{menu}{label},    0, 1, 1, 2);
		$self->{menu}{table}->attach_defaults($self->{controls}{label}, 1, 2, 1, 2);

		$self->{menu}{table}->attach_defaults($self->{iconfile}{label},    0, 1, 2, 3);

		$self->{menu}{icon_align} = Gtk2::Alignment->new(0, 0.5, 0, 0);
		$self->{menu}{icon_align}->add($self->{controls}{iconfile});
		$self->{menu}{table}->attach_defaults($self->{menu}{icon_align}, 1, 2, 2, 3);

		if (PerlPanel::has_application_menu && !PerlPanel::has_action_menu) {
			$self->{menu_vbox}->pack_start($self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}, 'show_control_items', 'boolean', 'Show control items in menu'), 0, 0, 0);
		}

		$self->{menu_vbox}->pack_start($self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}, 'relief', 'boolean', 'Show border on button'), 0, 0, 0);
		$self->{menu_vbox}->pack_start($self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}, 'arrow', 'boolean', 'Show arrow on icon'), 0, 0, 0);

		if (!PerlPanel::has_action_menu) {
			my $control = $self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{BBMenu}, 'apps_in_submenu', 'boolean', 'Place applications in a submenu');
			$control->signal_connect('toggled', sub { $self->{controls}{submenu_label}->set_sensitive($control->get_active) });
			$self->{controls}{submenu_label}->set_sensitive($control->get_active);
			$self->{menu_vbox}->pack_start($control, 0, 0, 0);
		}

		$self->{menu_vbox}->pack_start($self->{menu}{table}, 0, 0, 0);

	}

	if (PerlPanel::has_action_menu) {
		my $label = Gtk2::Label->new;
		$label->set_markup('<span weight="bold">Action Menu</span>');
		my $align = Gtk2::Alignment->new(0, 0.5, 0, 0);
		$align->add($label);
		$self->{pages}{menu}->pack_start($align, 0, 0, 0);


		$self->{pages}{menu}->pack_start($self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{ActionMenu}, 'relief', 'boolean', 'Show border on button'), 0, 0, 0);

		$self->{action_menu}{table} = Gtk2::Table->new(3, 2);
		$self->{action_menu}{table}->set_col_spacings(12);
		$self->{action_menu}{table}->set_row_spacings(12);

		$self->{action_menu}{label} = $self->control_label('Action Menu label:');
		$self->{controls}{action_menu_label} = $self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{ActionMenu}, 'label', 'text', 'Menu label');

		$self->{action_menu_iconfile}{label} = $self->control_label('Action Menu icon:');

		$self->{action_menu_iconfile}{icon} = Gtk2::Image->new_from_file($PerlPanel::OBJECT_REF->{config}{appletconf}{ActionMenu}{icon});
		$self->{controls}{action_menu_iconfile} = Gtk2::Button->new;
		$self->{controls}{action_menu_iconfile}->add($self->{action_menu_iconfile}{icon});
		$self->{controls}{action_menu_iconfile}->set_relief('none');
		$self->{controls}{action_menu_iconfile}->signal_connect(
			'clicked',
			sub {
				$self->choose_menu_icon('ActionMenu', 'action_menu_iconfile');
			}
		);

		$self->{action_menu}{table}->attach_defaults($self->{action_menu}{label},    0, 1, 1, 2);
		$self->{action_menu}{table}->attach_defaults($self->{controls}{action_menu_label}, 1, 2, 1, 2);

		$self->{action_menu}{table}->attach_defaults($self->{action_menu_iconfile}{label},    0, 1, 2, 3);

		$self->{action_menu}{icon_align} = Gtk2::Alignment->new(0, 0.5, 0, 0);
		$self->{action_menu}{icon_align}->add($self->{controls}{action_menu_iconfile});

		$self->{action_menu}{table}->attach_defaults($self->{action_menu}{icon_align}, 1, 2, 2, 3);

		$self->{pages}{menu}->pack_start($self->{action_menu}{table}, 0, 0, 0);

	}

	if (PerlPanel::has_application_menu || PerlPanel::has_action_menu) {
		$self->{notebook}->append_page($self->{pages}{menu}, 'Menus');
	}

	if ($PerlPanel::OBJECT_REF->has_pager) {
		$self->{pages}{pager_table} = Gtk2::Table->new(1, 2);
		$self->{pages}{pager_table}->attach_defaults($self->control_label('Number of rows:'), 0, 1, 0, 1);
		$self->{pages}{pager_table}->attach_defaults($self->control($PerlPanel::OBJECT_REF->{config}{appletconf}{Pager}, 'rows', 'int', 1), 1, 2, 0, 1);

		$self->{pages}{pager} = Gtk2::VBox->new(0,0);
		$self->{pages}{pager}->set_border_width(12);
		$self->{pages}{pager}->set_spacing(6);
		$self->{pages}{pager}->pack_start($self->{pages}{pager_table}, 0, 0, 0);

		$self->{notebook}->append_page($self->{pages}{pager}, 'Pager');
	}

	$self->create_list;

	$self->{scrwin} = Gtk2::ScrolledWindow->new;
	$self->{scrwin}->set_shadow_type('in');
	$self->{scrwin}->set_policy('automatic', 'automatic');
	$self->{scrwin}->add($self->{view});

	$self->{buttonbox} = Gtk2::HButtonBox->new;

	$self->{buttons}{add} = Gtk2::Button->new_from_stock('gtk-add');
	$self->{buttons}{add}->set_relief('none');
	$self->{buttons}{add}->signal_connect('clicked', sub { $self->add_dialog });

	$self->{buttons}{delete} = Gtk2::Button->new_from_stock('gtk-remove');
	$self->{buttons}{delete}->set_relief('none');
	$self->{buttons}{delete}->signal_connect('clicked', sub {
		my (undef, $iter) = $self->{view}->get_selection->get_selected;
		return undef unless (defined($iter));
		my $idx = ($self->{view}->get_model->get_path($iter)->get_indices)[0];
		$self->{view}->get_model->remove($iter);
		splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $idx, 1);
	});

	$self->{buttonbox}->add($self->{buttons}{add});
	$self->{buttonbox}->add($self->{buttons}{delete});

	$self->{pages}{applets} = Gtk2::VBox->new;
	$self->{pages}{applets}->set_spacing(12);
	$self->{pages}{applets}->set_border_width(12);
	$self->{pages}{applets}->pack_start($self->{scrwin}, 1, 1, 0);
	$self->{pages}{applets}->pack_start(Gtk2::Label->new('Drag and drop items in the list to move them.'), 0, 0, 0);
	$self->{pages}{applets}->pack_start($self->{buttonbox}, 0, 0, 0);

	$self->{notebook}->append_page($self->{pages}{applets}, 'Applets');

	$self->{window}->add_buttons(
		'gtk-cancel', 1,
		'gtk-ok', 0,
	);

	$self->{window}->signal_connect(
		'response',
		sub {
			$self->{window}->destroy;
			if ($_[1] == 0) {
				$self->rebuild_appletlist;
				if ($PerlPanel::OBJECT_REF->{config}{panel}{autohide} eq 'false' && $self->{backup}{panel}{autohide} eq 'true') {
					PerlPanel::panel->signal_handler_disconnect($PerlPanel::OBJECT_REF->{enter_connect_id});
					PerlPanel::panel->signal_handler_disconnect($PerlPanel::OBJECT_REF->{leave_connect_id});
				}
				PerlPanel::save_config;
				PerlPanel::reload;
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
		my $adj = Gtk2::Adjustment->new($ref->{$name}, $values[0], 5000, 1, 100, undef);
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
	} elsif (lc($type) eq 'boolean') {
		$control = Gtk2::CheckButton->new($values[0]);
		$control->set_active(1) if ($ref->{$name} eq 'true');
		$control->signal_connect('clicked', sub { $ref->{$name} = ($control->get_active ? 'true' : 'false') });
	} else {
		$control = Gtk2::Entry->new;
		$control->set_text($ref->{$name});
		$control->signal_connect('changed', sub { $ref->{$name} = $control->get_text ; return 1 });
	}
	return $control;
}

sub create_list {
	my $self = shift;
	$self->{view} = Gtk2::SimpleList->new(
		'Icon'	=> 'pixbuf',
		'Name'	=> 'text',
	);
	$self->{view}->set_reorderable(1);
	$self->{view}->set_headers_visible(0);

	foreach my $appletname (@{$PerlPanel::OBJECT_REF->{config}{applets}}) {
		push(@{$self->{view}->{data}}, [PerlPanel::get_applet_pbf($appletname, 24), $appletname]);
	}
	return 1;
}

sub rebuild_appletlist {
	my $self = shift;
	$PerlPanel::OBJECT_REF->{config}{applets} = [];
	foreach my $row (@{$self->{view}->{data}}) {
		push(@{$PerlPanel::OBJECT_REF->{config}{applets}}, @{$row}[1]);
	}
	return 1;
}

sub discard {
	my $self = shift;
	$self->{widget}->set_sensitive(1);
	$PerlPanel::OBJECT_REF->{config} = $self->{backup};
	PerlPanel::save_config;
	return 1;
}

sub add_dialog {
	my $self = shift;
	my $dialog = Gtk2::Dialog->new;
	$dialog->set_title("$PerlPanel::NAME: Add Applet");
	$dialog->set_position('center');
	$dialog->set_modal(1);
	$dialog->set_border_width(12);
	$dialog->set_default_size(450, 350);
	$dialog->set_icon(PerlPanel::icon);

	my $view = Gtk2::SimpleList->new(
		'Icon'		=> 'pixbuf',
		'Name'		=> 'text',
	);
	$view->set_headers_visible(0);

	my $column = $view->get_column(1);
	$column->set_spacing(12);

	my ($renderer) = $column->get_cell_renderers;

	$column->clear_attributes($renderer);
	$column->add_attribute($renderer, 'markup', 1);

	my @files;
	foreach my $dir (@PerlPanel::APPLET_DIRS) {
		opendir(DIR, $dir) or next;
		push(@files, grep { /\.pm$/ } readdir(DIR));
		closedir(DIR);
	}

	@files = sort(@files);

	foreach my $file (@files) {
		my ($appletname, undef) = split(/\./, $file, 2);
		push(@{$view->{data}}, [
			PerlPanel::get_applet_pbf($appletname),
			sprintf("<span weight=\"bold\">%s</span>\n<span size=\"small\">%s</span>", $appletname, ($self->{registry}{$appletname} ne '' ? $self->{registry}{$appletname} : 'No description available.')),
		]);
	}

	my $scrwin = Gtk2::ScrolledWindow->new;
	$scrwin->set_shadow_type('in');
	$scrwin->set_policy('automatic', 'automatic');
	$scrwin->add($view);

	$dialog->vbox->pack_start($scrwin, 1, 1, 0);

	$dialog->add_buttons(
		'gtk-cancel', 1,
		'gtk-ok', 0,
	);

	$dialog->signal_connect('response', sub {
		$dialog->hide_all;
		if ($_[1] == 0) {
			# 'ok' was clicked
			my $seln = $view->get_selection;
			return unless (defined($seln));
			my ($blah, $iter) = $seln->get_selected;
			return undef unless (defined($iter));
			my $idx = ($view->get_model->get_path($iter)->get_indices)[0];
			my ($appletname, undef) = split(/\./, $files[$idx], 2);
			push(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $appletname);
			push(@{$self->{view}->{data}}, [PerlPanel::get_applet_pbf($appletname, 24), $appletname]);
		}
		$dialog->destroy;
	});

	$dialog->show_all;

	return 1;
}

sub control_label {
	my ($self, $message) = @_;
	my $label = Gtk2::Label->new($message);
	$label->set_alignment(0, 0.5);
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

sub choose_menu_icon {
	my ($self, $applet, $control) = @_;
	my $selector = Gtk2::FileSelection->new('Choose Icon');
	$selector->set_filename($PerlPanel::OBJECT_REF->{config}{appletconf}{$applet}{icon});
	$selector->ok_button->signal_connect('clicked', sub {
		$PerlPanel::OBJECT_REF->{config}{appletconf}{$applet}{icon} = $selector->get_filename;
		my $new_image = Gtk2::Image->new_from_file($PerlPanel::OBJECT_REF->{config}{appletconf}{$applet}{icon});
		$new_image->show;
		$self->{controls}{$control}->remove($self->{controls}{$control}->child);
		$self->{controls}{$control}->add($new_image);
		$selector->destroy;
	});
	$selector->cancel_button->signal_connect('clicked', sub {
		$selector->destroy;
	});
	$selector->show_all;
	return 1;
}

1;
