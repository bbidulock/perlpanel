# $Id: PanelPet.pm,v 1.5 2004/05/21 10:22:50 jodrell Exp $
package PerlPanel::Applet::PanelPet;
use strict;

$PerlPanel::Applet::PanelPet::VERSION = "0.20";

# Applet Constructor
sub new {
    my $self            = {};
    $self->{package}    = shift;
    bless($self, $self->{package});
    return $self;
}

# Build the Gtk Widget for our applet
sub configure {
    my $self = shift;

    $self->{config} = PerlPanel::get_config('PanelPet');

    $self->{widget} = Gtk2::Button->new;
    $self->{widget}->set_relief('none');

    # Handle left mouse click events
    $self->{widget}->signal_connect(
            'clicked',
            sub { $self->_button_click( $_[1]->button) }
    );

    # Handle right mouse click events
    $self->{widget}->signal_connect(
            'button_release_event',
            sub { $self->_button_click ($_[1]->button) ; return undef });

    # Set the tooltip for the applet
    PerlPanel::tips->set_tip($self->{widget},
                                     _("Hi, I'm your Panel Pet!"));
    $self->{current_frame} = 1;
    $self->_update;

    Glib::Timeout->add(
        $self->{config}{interval},
        sub { $self->_update },
    );

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
    return { image      => "$PerlPanel::PREFIX/share/pixmaps/fish/oldwanda.png",
             frames     => 3,
             interval   => 2000,
           };
}

##########################################################################
# Private Functions
##########################################################################

# Button click handler -- call the appropriate function based on the button the
# user pressed
sub _button_click {
    my ( $self, $button ) = @_;

    if ( $button == 1 ) {
        $self->_panel_pet;
    }
    elsif ( $button == 3 ) {
        $self->_right_click_menu;
    }
}

sub _right_click_menu {
    my $self = shift;
    $self->{factory} = Gtk2::ItemFactory->new('Gtk2::Menu', '<main>', undef);
    $self->{factory}->create_items(
                        [
                            '/',
                            undef,
                            undef,
                            undef,
                            '<Branch>',
                        ],

                        [
                            "/"._('Preferences'),
                            undef,
                            sub { $self->_preferences },
                            undef,
                            "<StockItem>",
                            "gtk-preferences",
                        ],
                        [
                            "/"._('About'),
                            undef,
                            sub { $self->_about },
                            undef,
                            "<StockItem>",
                            "gtk-dialog-info",
                        ],
                        [
                            "/Separator",
                            undef,
                            undef,
                            undef,
                            '<Separator>',
                        ],
                        [
                            "/"._('Remove From Panel'),
                            undef,
                            sub { $self->_remove },
                            undef,
                            "<StockItem>",
                            "gtk-remove",
                        ],
    );
    $self->{menu} = $self->{factory}->get_widget('<main>');
    $self->{menu}->popup(
                undef, undef,
                sub { return $self->_popup_position(@_) },
                0, $self->{widget}, undef,
    );

    return 1;
}

# Location for the right-click menu
sub _popup_position {
    my $self = shift;
    my $x0 = $_[1];
    if (PerlPanel::position eq 'top') {
        return ($x0, PerlPanel::panel->allocation->height);
    }
    else {
        $self->{menu}->realize;
        $self->{menu}->show_all;
        return (
            $x0,
            PerlPanel::screen_height -
            $self->{menu}->allocation->height     -
            PerlPanel::panel->allocation->height,
        );
    }
}

# Do this when the PanelPet is left-clicked
sub _panel_pet {
    my $self = shift;
    my $text = _("Just a hello from your Panel Pet!\n\nBark Bark");

    $self->{window} = Gtk2::Window->new('toplevel');
    $self->{window}->set_position('center');
    $self->{window}->set_border_width(15);
    $self->{window}->set_title(_('Panel Pet: Hello'));
    $self->{window}->set_icon(PerlPanel::icon);
    $self->{vbox} = Gtk2::VBox->new;
    $self->{vbox}->set_spacing(15);
    $self->{label} = Gtk2::Label->new();
    $self->{label}->set_justify('center');
    $self->{label}->set_markup($text);
    $self->{vbox}->pack_start($self->{label}, 1, 1, 0);
    $self->{button} = Gtk2::Button->new_from_stock('gtk-ok');
    $self->{button}->signal_connect(
            'clicked',
            sub { $self->{window}->destroy },
    );
    $self->{vbox}->pack_start($self->{button}, 0, 0, 0);
    $self->{window}->add($self->{vbox});
    $self->{window}->show_all;

    return 1;
}

# Display the PanelPet about box
sub _about {
    my $self = shift;
    my $text = << "EOF";
<span weight="bold" size="x-large">
  PanelPet version $PerlPanel::Applet::PanelPet::VERSION
</span>

A friend for people who spend far too much
time on their computers, and have no other
social contact.

Author:
Eric Andreychek &lt;eric\@openthought.net&gt;

<span size="small">
  Copyright 2003 Eric Andreychek

  This program is Free Software.
  You may use it under the terms
  of the GNU General Public License.
</span>
EOF

    $self->{window} = Gtk2::Window->new('toplevel');
    $self->{window}->set_position('center');
    $self->{window}->set_border_width(15);
    $self->{window}->set_title(_('About'));
    $self->{window}->set_icon(PerlPanel::icon);
    $self->{vbox} = Gtk2::VBox->new;
    $self->{vbox}->set_spacing(15);
    #$self->{vbox}->pack_start(Gtk2::Image->new_from_file("$PerlPanel::PREFIX/share/pixmaps/perlpanel.png"), 0, 0, 0);
    $self->{label} = Gtk2::Label->new();
    $self->{label}->set_justify('center');
    $self->{label}->set_markup($text);
    $self->{vbox}->pack_start($self->{label}, 1, 1, 0);
    $self->{button} = Gtk2::Button->new_from_stock('gtk-ok');
    $self->{button}->signal_connect(
            'clicked',
            sub { $self->{window}->destroy },
    );

    $self->{vbox}->pack_start($self->{button}, 0, 0, 0);
    $self->{window}->add($self->{vbox});
    $self->{window}->show_all;

    return 1;
}

# Update the PanelPet preferences
sub _preferences {
    my $self = shift;
    $self->{widget}->set_sensitive(0);
    $self->{window} = Gtk2::Dialog->new;
    $self->{window}->set_title(_('Configuration'));
    $self->{window}->signal_connect(
            'delete_event',
            sub { $self->{widget}->set_sensitive(1) }
    );

    $self->{window}->set_border_width(8);
    $self->{window}->vbox->set_spacing(8);
    $self->{window}->set_icon(PerlPanel::icon);
    $self->{table} = Gtk2::Table->new(5, 2, 0);
    $self->{table}->set_col_spacings(8);
    $self->{table}->set_row_spacings(8);

    my $adj_interval = Gtk2::Adjustment->new(
            $self->{config}{interval},
            100, 60000, 100, 1000, undef,
    );

    $self->{controls}{interval} = Gtk2::SpinButton->new($adj_interval, 1, 0);

    $self->{labels}{interval} = Gtk2::Label->new(_('Update interval (ms):'));
    $self->{labels}{interval}->set_alignment(1, 0.5);
    $self->{table}->attach_defaults($self->{labels}{interval}, 0, 1, 2, 3);
    $self->{table}->attach_defaults($self->{controls}{interval}, 1, 2, 2, 3);

    my $adj_frames = Gtk2::Adjustment->new(
            $self->{config}{frames},
            1, 100000, 1, 10, undef,
    );

    $self->{controls}{frames} = Gtk2::SpinButton->new($adj_frames, 1, 0);

    $self->{labels}{frames} = Gtk2::Label->new(_('Frames in animation:'));
    $self->{labels}{frames}->set_alignment(1, 0.5);
    $self->{table}->attach_defaults($self->{labels}{frames}, 0, 1, 3, 4);
    $self->{table}->attach_defaults($self->{controls}{frames}, 1, 2, 3, 4);

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
    $self->{table}->attach_defaults($self->{labels}{image}, 0, 1, 4, 5);
    $self->{table}->attach_defaults($self->{controls}{image}, 1, 2, 4, 5);

    $self->{window}->add_buttons(
        'gtk-cancel', 1,
        'gtk-ok',     0,
    );

    $self->{window}->signal_connect('response', sub {

        # 'Okay' was clicked, this all needs to be saved
        if ($_[1] == 0) {
            $self->{config}{interval} =
                                $self->{controls}{interval}->get_value_as_int;
            $self->{config}{frames} =
                                $self->{controls}{frames}->get_value_as_int;
            $self->{config}{image} =
                                $self->{controls}{selector}{filename};

            $self->{widget}->set_sensitive(1);
            $self->{window}->destroy;
            PerlPanel::save_config;
            PerlPanel::reload;

        }
        elsif ($_[1] == 1) {
            $self->{widget}->set_sensitive(1);
            $self->{window}->destroy;
        }
    });

    $self->{window}->vbox->pack_start($self->{table}, 1, 1, 0);
    $self->{window}->show_all;

    return 1;
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
    $selector->ok_button->signal_connect('clicked', sub {
        $self->{controls}{selector}{filename} = $selector->get_filename;
        my $new_image = Gtk2::Image->new_from_file($self->{controls}{selector}{filename});
        $new_image->show;
        $self->{controls}{image}->remove($self->{controls}{image}->child);
        $self->{controls}{image}->add($new_image);
        $selector->destroy;
    });
    $selector->cancel_button->signal_connect('clicked', sub {
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
    PerlPanel::reload;
}

1;
