# $Id: MenuBase.pm,v 1.25 2004/07/04 12:32:37 jodrell Exp $
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
package PerlPanel::MenuBase;
use Gtk2::SimpleList;
use strict;

=pod

=head1 NAME

PerlPanel::MenuBase - a base class for PerlPanel menu applets.

=head1 SYNOPSIS

	package PerlPanel::Applet::MyMenu;
	use base 'PerlPanel::MenuBase';
	use strict;

	sub create_menu {

		my $self = shift;

		$self->menu->append($self->menu_item(
			'Hello World!',
			$icon,
			sub { print "Hello World!\n" }
		));
		return 1;
	}

	1;

=head1 DESCRIPTION

C<PerlPanel::MenuBase> is a base class that does as much as possible to
abstract the nuts-and-bolts details of building a PerlPanel menu applet. If you
use C<PerlPanel::MenuBase> to write a menu applet, you don't need to worry
about menu hierarchies or icons - all that's done for you. Instead to can
concentrate on building your menu backend.

=head1 USAGE

C<PerlPanel::MenuBase> is a base class - that means, you must write a Perl
module that inherits from it. The C<use base> line in the example above is one
way you can do this. Then you simply override the C<configure()> and
C<create_menu()> methods with your own.

=cut

sub new {
	my $self		= {};
	$self->{package}	= shift;
	bless($self, $self->{package});
	return $self;
}

sub configure {
	my $self = shift;

	$self->{widget}	= Gtk2::Button->new;
	$self->{menu}	= Gtk2::Menu->new;

	$self->widget->signal_connect('clicked', sub { $self->popup });

	$self->create_menu;

	$self->add_control_items if ($self->show_control_items);

	return 1;
}

sub widget {
	return $_[0]->{widget};
}

sub menu {
	return $_[0]->{menu};
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

=pod

=head1 STANDARD METHODS

	$self->add_control_items;

This method appends the standard set of PerlPanel control options to the
menu. The menu will subsequently look like this:

	|				|
	| ----------------------------- |
	| Lock Screen			|
	| Run Program...		|
	| Take Screenshot...		|
	| ----------------------------- |
	| Shut Down...			|
	| Reboot...			|
	| ----------------------------- |
	| Configure...			|
	| Reload			|
	| Close Panel			|
	| ----------------------------- |
	| About...			|
	+-------------------------------+

=cut

sub add_control_items {
	my $self = shift;
	my %params = @_;

	if (scalar($self->menu->get_children) > 0) {
		$self->menu->append(Gtk2::SeparatorMenuItem->new);
	}

	### this currently does nothing:
	if ((defined($params{menu_data}) && defined($params{menu_edit_callback})) || defined($params{menu_edit_command})) {
		my $callback;
		if (defined($params{menu_data}) && defined($params{menu_edit_callback})) {
			$callback = sub { $self->run_menu_editor($params{menu_data}, $params{menu_edit_callback}) };
		} elsif (defined($params{menu_edit_command})) {
			$callback = sub { system("$params{menu_edit_command} &") };
		}
		my $item = $self->menu_item(
			_('Edit Menu...'),
			'gtk-properties',
			$callback,
		);
		$item->set_sensitive(0) unless (defined($params{menu_edit_command}));
		$self->menu->append($item);
		$self->menu->append(Gtk2::SeparatorMenuItem->new);
	}

	chomp(my $xscreensaver = `which xscreensaver-command 2> /dev/null`);
	if (-x $xscreensaver) {
		$self->menu->append($self->menu_item(_('Lock Screen'), PerlPanel::get_applet_pbf_filename('lock'), sub { system("$xscreensaver -lock &") }));
	}
	$self->menu->append($self->menu_item(_('Run Program...'), PerlPanel::get_applet_pbf_filename('commander'), sub {
		$PerlPanel::OBJECT_REF->{commander}->run;
	}));
	$self->menu->append($self->menu_item(_('Take Screenshot...'), PerlPanel::get_applet_pbf_filename('screenshot'), sub {
		require('ScreenShot.pm');
		my $screenshot = PerlPanel::Applet::ScreenShot->new;
		$screenshot->configure;
		$screenshot->prompt;
	}));
	$self->menu->append(Gtk2::SeparatorMenuItem->new);

	# here we callously assume that the presence of this file means that bog-standard users can poweroff and reboot:	

	if (-e '/etc/pam.d/poweroff') {
		$self->menu->append($self->menu_item(
			_('Shut Down...'),
			PerlPanel::lookup_icon(sprintf('%s-action-shutdown', lc($PerlPanel::NAME))),
			sub {
				PerlPanel::question(
					_('Are you sure you want to shut down?'),
					sub { system("poweroff") },
					sub { },
				);
			},
		));

	}

	if (-e '/etc/pam.d/reboot') {
		$self->menu->append($self->menu_item(
			_('Reboot...'),
			PerlPanel::lookup_icon(sprintf('%s-action-reboot', lc($PerlPanel::NAME))),
			sub {
				PerlPanel::question(
					_('Are you sure you want to reboot?'),
					sub { system("reboot") },
					sub { },
				);
			},
		));
	}
	$self->menu->append(Gtk2::SeparatorMenuItem->new);
	$self->menu->append($self->menu_item(_('Configure...'), PerlPanel::get_applet_pbf_filename('configurator'), sub {
		require('Configurator.pm');
		my $configurator = PerlPanel::Applet::Configurator->new;
		$configurator->configure;
		$configurator->init;
	}));
	$self->menu->append($self->menu_item(_('Reload'), PerlPanel::get_applet_pbf_filename('reload'), sub { PerlPanel::reload }));

	if ($PerlPanel::OBJECT_REF->{config}->{panel}->{show_quit_button} eq 'true') {
		$self->menu->append(
			$self->menu_item(_('Close Panel'),
			'gtk-close',
			sub { PerlPanel::shutdown }
		));
	}

	my $item = $self->menu_item(_('Add To Panel'), 'gtk-add');
	my $applet_menu = Gtk2::Menu->new;
	$item->set_submenu($applet_menu);

	my $registry = PerlPanel::load_appletregistry;

	foreach my $category (@PerlPanel::APPLET_CATEGORIES) {
		my $icon = PerlPanel::lookup_icon(sprintf('%s-applets-%s', lc($PerlPanel::NAME), lc($category)));
		unless (-e $icon) {
			$icon = PerlPanel::lookup_icon(sprintf('%s-applets', lc($PerlPanel::NAME)));
		}
		my $item = $self->menu_item(
			_($category),
			$icon,
		);
		my $submenu = Gtk2::Menu->new;
		$item->set_submenu($submenu);
		$applet_menu->append($item);

		foreach my $applet (sort @{$registry->{_categories}->{$category}}) {
			my $item = $self->menu_item(
				$applet,
				PerlPanel::get_applet_pbf($applet),
				sub {$self->add_applet_dialog($applet)},
			);
			PerlPanel::tips->set_tip($item, $registry->{$applet});
			$submenu->append($item);
		}
	}

	foreach my $applet (sort @{$registry->{_categories}->{''}}) {
		my $item = $self->menu_item(
			$applet,
			PerlPanel::get_applet_pbf($applet),
			sub {$self->add_applet_dialog($applet)},
		);
		PerlPanel::tips->set_tip($item, $registry->{$applet});
		$applet_menu->append($item);
	}

	my $dir = sprintf('%s/.%s/applets', $ENV{HOME}, lc($PerlPanel::NAME));
	if (-d $dir) {
		if (!opendir(DIR, $dir)) {
			print STDERR "*** Error opening '$dir': $!\n";

		} else {
	
			my @applets = grep { /\.pm$/i } readdir(DIR);
			closedir(DIR);

			if (scalar(@applets) > 0) {
				$applet_menu->append(Gtk2::SeparatorMenuItem->new);

				foreach my $filename (sort @applets) {
					my ($applet, undef) = split(/\./, $filename, 2);
	
					$applet_menu->append($self->menu_item(
						$applet,
						PerlPanel::get_applet_pbf($applet),
						sub {$self->add_applet_dialog($applet)},

					));

				}

			}
		}
	}

	$self->menu->append($item);

	$self->menu->append(Gtk2::SeparatorMenuItem->new);

	$self->menu->append($self->menu_item(_('About...'), PerlPanel::get_applet_pbf_filename('about'), sub {
		require('About.pm');
		my $about = PerlPanel::Applet::About->new;
		$about->configure;
		$about->about;
	}));
	return 1;
}

=pod

	my $item = $self->menu_item($label, $icon, $callback);

This returns a ready-prepared Gtk2::ImageMenuItem. This method does a lot of
hard work for you - C<$label> is set as the text label for the item, and if
defined, C<$callback> is connected to the C<'activate'> signal.

C<$icon> can be either a file, a C<Gtk::Gdk::Pixbuf>, or a stock ID.
C<menu_item> will automagically resize the icon to fit in with the rest of
the menu.

=cut

sub menu_item {
	my ($self, $label, $icon, $callback) = @_;
	my $item;
	my $pbf;
	if (-f $icon) {
		# it's a file:
		$pbf = Gtk2::Gdk::Pixbuf->new_from_file($icon);
	} elsif (ref($icon) eq 'Gtk2::Gdk::Pixbuf') {
		# it's a pixbuf:
		$pbf = $icon;
	} elsif ($icon =~ /^gtk-/) {
		# assume it's a stock ID:
		$pbf = $self->widget->render_icon($icon, PerlPanel::menu_icon_size_name);
	} else {
		$pbf = $self->widget->render_icon('gtk-new', PerlPanel::menu_icon_size_name);

	}
	if (ref($pbf) ne 'Gtk2::Gdk::Pixbuf') {
		$item = Gtk2::MenuItem->new_with_label($label);

	} else {
		$item = Gtk2::ImageMenuItem->new_with_label($label);
		my $x0 = $pbf->get_width;
		my $y0 = $pbf->get_height;
		if ($x0 > PerlPanel::menu_icon_size || $y0 > PerlPanel::menu_icon_size) {
			my ($x1, $y1);
			if ($x0 > $y0) {
				# image is landscape:
				$x1 = PerlPanel::menu_icon_size;
				$y1 = int(($y0 / $x0) * PerlPanel::menu_icon_size);
			} else {
				# image is portrait:
				$x1 = int(($x0 / $y0) * PerlPanel::menu_icon_size);
				$y1 = PerlPanel::menu_icon_size;
			}
			$pbf = $pbf->scale_simple($x1, $y1, 'bilinear');
		}
		$item->set_image(Gtk2::Image->new_from_pixbuf($pbf));
	}

	if (defined($callback)) {
		$item->signal_connect('activate', $callback);
	}
	return $item;
}

sub popup {
	my $self = shift;
	$self->menu->show_all;
	$self->menu->popup(undef, undef, sub { return $self->popup_position(@_) }, undef, undef, 0);
	return 1;
}

sub popup_position {
	my $self = shift;
	my ($x, undef) = PerlPanel::get_widget_position($self->widget);
	$x = 0 if ($x < 5);
	if (PerlPanel::position eq 'top') {
		return ($x, PerlPanel::panel->allocation->height);
	} else {
		$self->menu->realize;
		return ($x, PerlPanel::screen_height() - $self->menu->allocation->height - PerlPanel::panel->allocation->height);
	}
}

=pod

	my $icon = $self->get_icon($string, $is_submenu_parent);

This method is deprecated and is no longer available. Use PerlPanel::lookup_icon() instead.

=cut

sub add_applet_dialog {
	my ($self, $applet) = @_;
	# place the new applet next to the menu:
	my $idx = 0;
	foreach my $applet ($PerlPanel::OBJECT_REF->{hbox}->get_children) {
		last if ($applet eq $self->widget);
		$idx++;
	}
	if ($idx >= 0) {
		splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $idx+1, 0, $applet);
		PerlPanel::reload;
	}
	return 1;
}

sub run_menu_editor {
	my ($self, $data, $callback) = @_;

	my $glade = PerlPanel::load_glade('menu-editor');
	my $dialog = $glade->get_widget('main_window');

	$dialog->set_icon(PerlPanel::icon);

	# this will be a Gtk2::Simple::Tree one day:
	my $list = Gtk2::SimpleList->new_from_treeview(
		$glade->get_widget('menu_tree'),
		'entry'	=> 'text',
	);

	$dialog->signal_connect('response', sub {
		my $data = $list->{data},
		$dialog->destroy;
		&{$callback}($data);
	});
}

sub file_age {
	my $self = shift;
	return (stat($self->{file}))[9];
}

=pod

=head1 SEE ALSO

=over

=item * L<perlpanel>

=item * L<perlpanel-applet-howto>

=item * L<Gtk2>

=back

=cut

1;
