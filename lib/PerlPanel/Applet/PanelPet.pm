# $Id: PanelPet.pm,v 1.13 2005/01/13 22:25:38 jodrell Exp $
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
# Copyright: (C) 2005 Gavin Brown <gavin.brown@uk.com>
#
package PerlPanel::Applet::PanelPet;
use vars qw($VERSION);
use strict;

$VERSION = "0.60";

# Applet Constructor
sub new {
    my $self            = {};
    $self->{package}    = shift;
    bless($self, $self->{package});

    if ( system("fortune > /dev/null 2>&1") == 0 ) {
        $self->{fortune} = 1;

        $self->_get_fortune_databases();
    }

    return $self;
}

# Build the Gtk Widget for our applet
sub configure {
    my $self = shift;

    $self->{config} = PerlPanel::get_config('PanelPet');

    $self->{widget} = Gtk2::Button->new;
    $self->{widget}->set_relief('none');

    # Handle right mouse click events
    $self->{widget}->signal_connect(
            'button_release_event',
            sub { $self->_button_click ($_[1]->button) ; return undef });

    my $tip;
    unless ( -f $self->{config}{image} ) {
        $self->_no_pet;
    }
    else {
        $self->_got_pet;

    }

    $self->widget->show_all;

    return 1;
}

# Return the widget
sub widget {
    return $_[0]->{widget};
}

# return the expand (1 or 0) for packing:
sub expand {
    return 0;
}

# return the fill (1 or 0) for packing:
sub fill {
    return 0;
}

# return 'start' or 'end':
sub end {
    return 'end';
}

# Build and return the default config values for this applet
sub get_default_config {
    my $image_dir = sprintf('%s/share/%s/panelpet', $PerlPanel::PREFIX, lc($PerlPanel::NAME));
    return { image      => "$image_dir/oldwanda.png",
             frames     => 3,
             interval   => 2000,
             fortune    => "ALL",
           };
}

##########################################################################
# Private Functions
##########################################################################

sub _no_pet {
    my $self = shift;
    PerlPanel::notify(_("You don't seem to have a pet!  Go into the PanelPet preferences, and choose an image for your pet."), sub { $self->_preferences } );
    my $pbf =
        $PerlPanel::OBJECT_REF->panel->render_icon('gtk-missing-image',
        'dialog')->scale_simple(
        PerlPanel::icon_size,
        PerlPanel::icon_size,
        'bilinear'
    );
    $self->{icon} = Gtk2::Image->new_from_pixbuf($pbf);
    $self->widget->add($self->{icon});
    PerlPanel::tips->set_tip($self->widget, _("This could be your Panel Pet if you were to choose an image"));
    $self->{has_pet} = 0;
}

sub _got_pet {
    my $self = shift;

    $self->{has_pet} = 1;

    # Set the tooltip for the applet
    $self->{current_frame} = 1;
    $self->_update;

    PerlPanel::add_timeout(
        $self->{config}{interval},
        sub { $self->_update },
    );

    PerlPanel::tips->set_tip($self->widget, _("Hi, I'm your Panel Pet!"));
}

# Button click handler -- call the appropriate function based on the button the
# user pressed
sub _button_click {
    my ( $self, $button ) = @_;

    if ($button == 1) {
        $self->_panel_pet;

    } elsif ($button == 3) {
        $self->_right_click_menu;

    }

    return 1;
}

sub _right_click_menu {
    my $self = shift;
    my $menu = Gtk2::Menu->new;

    my $preferences = Gtk2::ImageMenuItem->new_from_stock('gtk-preferences');
    $preferences->signal_connect('activate', sub { $self->_preferences });

    my $about = Gtk2::ImageMenuItem->new_from_stock('gtk-dialog-info');
    $about->signal_connect('activate', sub { $self->_about });

    $menu->add($preferences);
    $menu->add($about);
    $menu->show_all;
    $menu->popup(
        undef, undef,
        sub { return $self->_popup_position($menu) },
        undef, 3, undef
    );

    return 1;
}

sub _popup_position {
        my ($self, $menu) = @_;
        my ($x, undef) = PerlPanel::get_widget_position($self->widget);
        $x = 0 if ($x < 5);
        if (PerlPanel::position eq 'top') {
            return ($x, PerlPanel::panel->allocation->height);
        }
        else {
            $menu->realize;
            return ($x, PerlPanel::screen_height() -
                        $menu->allocation->height  -
                        PerlPanel::panel->allocation->height
            );
        }
}


# Do this when the PanelPet is left-clicked
sub _panel_pet {
    my $self = shift;
    my $text;

    if ( $self->{fortune} ) {
        $text = _("Hello, I'm your Panel Pet!  I retrieved the following fortune:");
    }
    else {
        $text= _("Just a hello from your Panel Pet!");
    }

    if ( $self->{pet_window} ) {
        my $fortune_text = $self->_get_fortune;
        $self->{fortune_textview}->get_buffer->set_text( $fortune_text );
    }
    else {
        $self->{pet_window} = Gtk2::Dialog->new;
        $self->{pet_window}->set_position('center');
        $self->{pet_window}->set_border_width(15);
        $self->{pet_window}->set_title(_('Panel Pet: Hello'));
        $self->{pet_window}->set_icon(PerlPanel::icon);

        my $scrolled_window = Gtk2::ScrolledWindow->new;
        $scrolled_window->set_policy(qw/automatic automatic/);
        $scrolled_window->set_shadow_type('in');

        $self->{fortune_textview} = Gtk2::TextView->new;
        $self->{fortune_textview}->set_left_margin(10);
        $self->{fortune_textview}->set_right_margin(10);
        $self->{fortune_textview}->set_editable(0);
        $self->{fortune_textview}->set_cursor_visible(0);
        my $fortune_text = $self->_get_fortune;
        $self->{fortune_textview}->get_buffer->set_text( $fortune_text );
        $scrolled_window->add( $self->{fortune_textview} );

        my $vbox = Gtk2::VBox->new;
        $self->{pet_window}->vbox->set_spacing(15);
        my $label = Gtk2::Label->new();
        $label->set_justify('center');
        $label->set_text($text);

        $self->{pet_window}->vbox->pack_start($label, 0, 0, 0);
        $self->{pet_window}->vbox->pack_start($scrolled_window, 1, 1, 1);

        #my $button = Gtk2::Button->new_from_stock('gtk-ok');
        $self->{pet_window}->add_buttons(
            'gtk-ok',     0,
        );
        $self->{pet_window}->signal_connect(
            'response',
            sub {
                $self->{pet_window}->destroy;
                delete $self->{pet_window}
            },
        );

        #$window->vbox->pack_start($button, 0, 0, 0);
        #$self->{pet_window}->add($vbox);
        $self->{pet_window}->set_default_size(600,350);
        $self->{pet_window}->show_all;
    }

    return 1;
}

# Display the PanelPet about box
sub _about {
    my $self = shift;
    my $text = << "EOF";
<span weight="bold" size="x-large">
  PanelPet version $PerlPanel::Applet::PanelPet::VERSION
</span>

A little friend to keep you company while
you play around on your computer.

Author:
Eric Andreychek &lt;eric\@openthought.net&gt;

<span size="small">
  Copyright 2003-2005 Eric Andreychek

  This program is Free Software.
  You may use it under the terms
  of the GNU General Public License.
</span>
EOF

    my $window = Gtk2::Dialog->new;
    $window->set_position('center');
    $window->set_border_width(15);
    $window->set_title(_('About'));
    $window->set_icon(PerlPanel::icon);

    $window->vbox->set_spacing(15);
    my $label = Gtk2::Label->new();
    $label->set_justify('center');
    $label->set_markup($text);
    $window->vbox->pack_start($label, 1, 1, 0);

    $window->add_buttons(
        'gtk-ok',     0,
    );
    $window->signal_connect(
            'response',
            sub { $window->destroy },
    );

    $window->show_all;

    return 1;
}

# Update the PanelPet preferences
sub _preferences {
    my $self = shift;

    $self->{widget}->set_sensitive(0);

    my $window = Gtk2::Dialog->new;
    $window->set_title(_('Configuration'));
    $window->signal_connect(
            'delete_event',
            sub { $self->{widget}->set_sensitive(1) }
    );

    $window->set_border_width(8);
    $window->vbox->set_spacing(8);
    $window->set_icon(PerlPanel::icon);

    my $notebook = Gtk2::Notebook->new;
    $window->vbox->add($notebook);

    my $table = Gtk2::Table->new(5, 3, 0);
    $table->set_col_spacings(8);
    $table->set_row_spacings(8);

    # Update interval preference
    my $adj_interval = Gtk2::Adjustment->new(
            $self->{config}{interval},
            100, 60000, 100, 1000, undef,
    );
    $self->{controls}{interval} = Gtk2::SpinButton->new($adj_interval, 1, 0);

    $self->{labels}{interval} = Gtk2::Label->new(_(' Update interval (ms):'));
    $self->{labels}{interval}->set_alignment(1, 0.5);
    $table->attach_defaults($self->{labels}{interval}, 0, 1, 2, 3);
    $table->attach_defaults($self->{controls}{interval}, 1, 2, 2, 3);

    # Frames in animation preference
    my $adj_frames = Gtk2::Adjustment->new(
            $self->{config}{frames},
            1, 100000, 1, 10, undef,
    );
    $self->{controls}{frames} = Gtk2::SpinButton->new($adj_frames, 1, 0);

    $self->{labels}{frames} = Gtk2::Label->new(_(' Frames in animation:'));
    $self->{labels}{frames}->set_alignment(1, 0.5);
    $table->attach_defaults($self->{labels}{frames}, 0, 1, 3, 4);
    $table->attach_defaults($self->{controls}{frames}, 1, 2, 3, 4);

    # Image for the PanelPet
    my $image = Gtk2::Image->new_from_file(
            $self->{config}{image},
    );

    $self->{controls}{image} = Gtk2::Button->new;
    $self->{controls}{image}->add($image);
    $self->{controls}{image}->set_relief('none');
    $self->{controls}{image}->signal_connect(
            'clicked', sub { $self->_choose_panelpet_image }
    );

    $self->{labels}{image} = Gtk2::Label->new(_('PanelPet Imagefile:'));
    $self->{labels}{image}->set_alignment(1, 0.5);
    $table->attach_defaults($self->{labels}{image}, 0, 1, 4, 5);
    $table->attach_defaults($self->{controls}{image}, 1, 2, 4, 5);

    # Fortune DB list
    $self->{labels}{fortune} = Gtk2::Label->new(_('Fortune Database:'));
    $self->{labels}{fortune}->set_alignment(1, 0.5);

    $self->{controls}{fortune} = Gtk2::VBox->new;

    my $scrolled_window = Gtk2::ScrolledWindow->new;
    $self->{controls}{fortune_checkbox} = Gtk2::CheckButton->new_with_label("Randomly Select From All Databases");
    $self->{controls}{fortune}->pack_start($self->{controls}{fortune_checkbox}, 0, 0, 0);
    $self->{controls}{fortune}->pack_start($scrolled_window, 1, 1, 1);
    $scrolled_window->set_policy (qw/automatic automatic/);

    my $list = Gtk2::SimpleList->new (
                                "Fortune Database" => 'text',
                                "Enabled"          => 'bool',
                            );
    $list->get_selection->set_mode('single');
    $scrolled_window->add( $list );

    if ( $self->{fortune} ) {
        $self->_get_fortune_databases();
        @{ $list->{data} } = $self->_fill_fortune_database_list;
    }
    else {
        $self->{controls}{fortune}->set_sensitive(0);
    }

    $self->{controls}{fortune_checkbox}->signal_connect('toggled', sub {
                my $button = shift;

                if ($button->get_active) {
                    $list->set_sensitive(0);
                }
                else {
                    $list->set_sensitive(1);
                }
        }
    );
    if ( $self->{config}{fortune} eq "ALL" ) {
        $self->{controls}{fortune_checkbox}->set_active(1);
    }

    $window->add_buttons(
        'gtk-cancel', 1,
        'gtk-ok',     0,
    );

    $window->signal_connect('response', sub {

        # 'Okay' was clicked, this all needs to be saved
        if ($_[1] == 0) {
            $self->{config}{interval} =
                                $self->{controls}{interval}->get_value_as_int;
            $self->{config}{frames} =
                                $self->{controls}{frames}->get_value_as_int;
            $self->{config}{image} =
                                $self->{controls}{selector}{filename} ||
                                $self->{config}{image};

            if ( $self->{controls}{fortune_checkbox}->get_active) {
                $self->{config}{fortune} = "ALL";
            }
            else {
                $self->{config}{fortune} =
                    $self->_get_selected_fortune_databases( $list->{data} );

            }

            $self->{widget}->set_sensitive(1);
            $window->destroy;
            PerlPanel::save_config;

            # If we didn't have a pet before, we need to plug in the aquarium
            unless ( $self->{has_pet} ) {
                $self->_got_pet;
            }

        }
        elsif ($_[1] == 1) {
            $self->{widget}->set_sensitive(1);
            $window->destroy;
        }
    });

    my $label_g = Gtk2::Label->new('General');
    my $label_f = Gtk2::Label->new('Fortune');
    $notebook->append_page($table, $label_g);
    $notebook->append_page($self->{controls}{fortune}, $label_f);

    $window->show_all;

    return 1;
}

sub _get_fortune_databases {
    my $self = shift;

    my @data = `fortune -f 2>&1`;
    shift @data;
    chomp @data;

    @{ $self->{fortune_dbs} } = sort map { ((split /\s+/)[2]) } @data;
}

sub _get_fortune_database_by_name {
    my ( $self, $name ) = @_;

    my $i = 0;
    foreach my $database ( @{ $self->{fortune_dbs} } ) {
        return $i if $name eq $database;
        $i++;
    }

    return 0;
}

sub _get_fortune_database_by_id {
    my ( $self, $id ) = @_;

    return ${ $self->{fortune_dbs} }[$id];
}

sub _get_fortune {
    my $self = shift;

    if ( $self->{fortune} ) {

        if ( $self->{config}{fortune} eq "ALL" ) {
            return `fortune`;
        }
        else {
            my @databases = join " ", $self->_selected_fortune_databases;
            return `fortune @databases`;
        }
    }
    else {
        return "Bark Bark\n\n(If you install the 'fortune' program, I'd consider giving you a fortune instead of barking)";
    }
}

sub _get_selected_fortune_databases {
    my ( $self, $list ) = @_;

    my $selected_list = "";
    foreach my $item ( @{ $list } ) {
        if ( $item->[1] ) {
            $selected_list .= "$item->[0],";
        }
    }

    chop $selected_list;
    return $selected_list;
}

sub _selected_fortune_databases {
    my $self = shift;

    my @databases = split /,/, $self->{config}{fortune};

    return @databases;
}

sub _database_is_selected {
    my ( $self, $name ) = @_;

    my @databases = split /,/, $self->{config}{fortune};

    foreach my $database ( @databases ) {
        return 1 if $database eq $name;
    }

    return "";
}

sub _fill_fortune_database_list {
    my $self = shift;

    my @list;
    foreach my $fortune_db ( @{ $self->{fortune_dbs} } ) {
        push @list, [ $fortune_db, $self->_database_is_selected($fortune_db) ];
    }

    return @list;
}

# Update the PanelPet image
sub _update {
    my $self = shift;

    my $filename =
        $self->{config}{image};

    $self->{frames} =
        $self->{config}{frames};

    my $base_image = Gtk2::Gdk::Pixbuf->new_from_file($filename);
    my $original_width  = ( $base_image->get_width / $self->{frames} );
    my $original_height = $base_image->get_height;
    my $display_image = Gtk2::Gdk::Pixbuf->new(
        $base_image->get_colorspace,
        $base_image->get_has_alpha,
        $base_image->get_bits_per_sample,
        $original_width,
        $original_height,
    );

    my $copy_area = $original_width * $self->{current_frame} - $original_width;
    $base_image->copy_area($copy_area, 0, $original_width, $original_height,
                           $display_image, 0, 0 );

    # If the current image is larger than the panel, we need to scale it down
    if ($original_height != PerlPanel::icon_size) {
        my ($scaled_width, $scaled_height);

        # Image is landscape
        if ($original_width > $original_height) {
            $scaled_height = PerlPanel::icon_size;
            $scaled_width  = int(($original_width / $original_height) *
                             $scaled_height);
        }
        # Image is square
        elsif ($original_width == $original_height) {
            $scaled_width  = PerlPanel::icon_size;
            $scaled_height = PerlPanel::icon_size;
        }
        # Image is portrait
        else {
            $scaled_width = int(($original_width / $original_height) *
                            PerlPanel::icon_size
            );
            $scaled_height = PerlPanel::icon_size;
        }

        $display_image = $display_image->scale_simple(
                $scaled_width,
                $scaled_height,
                'bilinear',
        );
    }

    if ( exists $self->{icon} ) {
        $self->{icon}->set_from_pixbuf($display_image);
    }
    else {
        $self->{icon} = Gtk2::Image->new_from_pixbuf($display_image);
        $self->{widget}->add($self->{icon});
    }
    $self->{widget}->queue_draw;

    $self->{current_frame}++;
    $self->{current_frame} = 1 if $self->{current_frame} > $self->{frames};

    return 1;
}

sub _choose_panelpet_image {
    my $self = shift;
    my $selector;
    if ('' ne (my $msg = Gtk2->check_version (2, 4, 0)) or $Gtk2::VERSION < 1.040) {
        $selector = Gtk2::FileSelection->new(_('Choose PanelPet Image'));
    } else {
        $selector = Gtk2::FileChooserDialog->new(
            _('Choose PanelPet Image'),
            undef,
            'open',
            'gtk-cancel'    => 'cancel',
            'gtk-ok' => 'ok'
        );
    }

    $selector->set_filename($self->{config}{image});
    $selector->signal_connect('response', sub {
    	if ($_[1] eq 'ok') {
	    $self->{controls}{selector}{filename} = $selector->get_filename;
            my $new_image = Gtk2::Image->new_from_file($self->{controls}{selector}{filename});
            $new_image->show;
            $self->{controls}{image}->remove($self->{controls}{image}->child);
            $self->{controls}{image}->add($new_image);
    	}
    	$selector->destroy;
    });
    $selector->show_all;

    return 1;
}

sub _remove {
    my $self = shift;

    for (my $i=0; $i < @{ $PerlPanel::OBJECT_REF->{config}{applets} }; $i++) {
        if ($PerlPanel::OBJECT_REF->{config}{applets}[$i] eq "PanelPet") {
            splice(@{$PerlPanel::OBJECT_REF->{config}{applets}}, $i, 1);
        }
    }

    PerlPanel::save_config;
    $self->widget->parent->remove($self->widget);
}

1;

