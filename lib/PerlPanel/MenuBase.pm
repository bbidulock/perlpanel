# $Id: MenuBase.pm,v 1.1 2004/01/19 15:48:10 jodrell Exp $
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
package PerlPanel::MenuBase;
use vars qw(@ICON_DIRECTORIES);
use File::Basename qw(basename);
use strict;

our @ICON_DIRECTORIES = (
	sprintf('%s/.perlpanel/icon-files', $ENV{HOME}),
	sprintf('%s/.icons', $ENV{HOME}),
	sprintf('%s/.icons/gnome/48x48/apps', $ENV{HOME}),
	'%s/share/icons/gnome/48x48/apps',
	'%s/share/pixmaps',
);

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
	| ----------------------------- |
	| Configure...			|
	| Reload			|
	| ----------------------------- |
	| About...			|
	+-------------------------------+

=cut

sub add_control_items {
	my $self = shift;
	if (scalar($self->menu->get_children) > 0) {
		$self->menu->append(Gtk2::SeparatorMenuItem->new);
	}
	chomp(my $xscreensaver = `which xscreensaver-command 2> /dev/null`);
	if (-x $xscreensaver) {
		$self->menu->append($self->menu_item('Lock Screen', sprintf('%s/share/pixmaps/%s/applets/lock.png', $PerlPanel::PREFIX, lc($PerlPanel::NAME)), sub { system("$xscreensaver -lock &") }));
	}
	$self->menu->append($self->menu_item('Run Program...', 'gtk-execute', sub {
		require('Commander.pm');
		my $commander = PerlPanel::Applet::Commander->new;
		$commander->configure;
		$commander->run;
	}));
	$self->menu->append(Gtk2::SeparatorMenuItem->new);
	$self->menu->append($self->menu_item("Configure...", 'gtk-preferences', sub {
		require('Configurator.pm');
		my $configurator = PerlPanel::Applet::Configurator->new;
		$configurator->configure;
		$configurator->init;
	}));
	$self->menu->append($self->menu_item("Reload", 'gtk-refresh', sub { $PerlPanel::OBJECT_REF->reload }));
	$self->menu->append(Gtk2::SeparatorMenuItem->new);
	$self->menu->append($self->menu_item("About...", 'gtk-dialog-info', sub {
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
	my $item = Gtk2::ImageMenuItem->new_with_label($label);
	my $pbf;
	if (-e $icon) {
		# it's a file:
		$pbf = Gtk2::Gdk::Pixbuf->new_from_file($icon);
	} elsif (ref($icon) eq 'Gtk2::Gdk::Pixbuf') {
		# it's a pixbuf:
		$pbf = $icon;
	} else {
		# assume it's a stock ID:
		$pbf = $self->widget->render_icon($icon, $PerlPanel::OBJECT_REF->icon_size_name);
	}
	my $x0 = $pbf->get_width;
	my $y0 = $pbf->get_height;
	if ($x0 > $PerlPanel::OBJECT_REF->icon_size || $y0 > $PerlPanel::OBJECT_REF->icon_size) {
		my ($x1, $y1);
		if ($x0 > $y0) {
			# image is landscape:
			$x1 = $PerlPanel::OBJECT_REF->icon_size;
			$y1 = int(($y0 / $x0) * $PerlPanel::OBJECT_REF->icon_size);
		} else {
			# image is portrait:
			$x1 = int(($x0 / $y0) * $PerlPanel::OBJECT_REF->icon_size);
			$y1 = $PerlPanel::OBJECT_REF->icon_size;
		}
		$pbf = $pbf->scale_simple($x1, $y1, 'bilinear');
	}
	$item->set_image(Gtk2::Image->new_from_pixbuf($pbf));
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
	my ($x, undef) = $PerlPanel::OBJECT_REF->get_widget_position($self->widget);
	$x = 0 if ($x < 5);
	if ($PerlPanel::OBJECT_REF->position eq 'top') {
		return ($x, $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	} else {
		return ($x, $PerlPanel::OBJECT_REF->screen_height - $self->{menu}->allocation->height - $PerlPanel::OBJECT_REF->{panel}->allocation->height);
	}
}

=pod

	my $icon = $self->get_icon($string, $is_submenu_parent);

This returns a scalar containing either a filename for an icon, or a stock ID.
This method is best used when used as the C<$icon> argument to the
C<menu_item()> method above.

C<menu_item()> searches a series of directories looking for an appropriate icon.
These directories are listed in @PerlPanel::ICON_DIRECTORIES.

=cut

sub get_icon {
	my ($self, $executable, $is_submenu_parent) = @_;

	$executable =~ s/\s/-/g if ($is_submenu_parent == 1);

	my $file = $self->detect_icon($executable);

	if (-e $file) {
		return $file;

	} else {
		return ($is_submenu_parent == 1 ? 'gtk-open' : 'gtk-execute');

	}
}

sub detect_icon {
	my ($self, $executable) = @_;

	my $program = lc(basename($executable));
	($program, undef) = split(/\s/, $program, 2);

	foreach my $dir (@ICON_DIRECTORIES) {
		my $file = sprintf('%s/%s.png', sprintf($dir, $PerlPanel::PREFIX), $program);
		if (-e $file) {
			return $file;
		}
	}

	return undef;
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
