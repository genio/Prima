use strict;
use warnings;
use Prima::Bidi;

package 
    tb;
use vars qw(@oplen %opnames);

@oplen = ( 4, 2, 3, 4, 3, 2, 4, 3);   # lengths of OP_XXX constants ( see below ) + 1
# basic opcodes
use constant OP_TEXT               =>  0; # (3) text offset, text length, text width
use constant OP_COLOR              =>  1; # (1) 0xRRGGBB or COLOR_INDEX | palette_index
use constant OP_FONT               =>  2; # (2) op_font_mode, font info
use constant OP_TRANSPOSE          =>  3; # (3) move current point to delta X, delta Y
use constant OP_CODE               =>  4; # (2) code pointer and parameters 

# formatting opcodes
use constant OP_WRAP               =>  5; # (1) on / off
use constant OP_MARK               =>  6; # (3) id, x, y
use constant OP_BIDIMAP            =>  7; # (2) visual, $map

%opnames = (
	text      => OP_TEXT,
	color     => OP_COLOR,
	font      => OP_FONT,
	transpose => OP_TRANSPOSE,
	code      => OP_CODE,
	wrap      => OP_WRAP,
	mark      => OP_MARK,
	bidimap   => OP_BIDIMAP,
);


# OP_TEXT 
use constant T_OFS                => 1;
use constant T_LEN                => 2;
use constant T_WID                => 3;

# OP_FONT
use constant F_MODE                => 1;
use constant F_DATA                => 2;

# OP_COLOR
use constant COLOR_INDEX           => 0x01000000; # index in colormap() array
use constant BACKCOLOR_FLAG        => 0x02000000; # OP_COLOR flag for backColor
use constant BACKCOLOR_DEFAULT     => BACKCOLOR_FLAG|COLOR_INDEX|1;
use constant COLOR_MASK            => 0xFCFFFFFF;

# OP_TRANSPOSE - indices
use constant X_X     => 1;
use constant X_Y     => 2;
use constant X_FLAGS => 3;

# OP_TRANSPOSE - X_FLAGS constants
use constant X_TRANSPOSE             => 0;
use constant X_EXTEND                => 1;
use constant X_DIMENSION_PIXEL       => 0;
use constant X_DIMENSION_FONT_HEIGHT => 2; # multiply by font height
use constant X_DIMENSION_POINT       => 4; # multiply by resolution / 72


# OP_MARK
use constant MARK_ID                 => 1;
use constant MARK_X                  => 2;
use constant MARK_Y                  => 3;

# OP_BIDIMAP
use constant BIDI_VISUAL             => 1;
use constant BIDI_MAP                => 2;

# block header indices
use constant  BLK_FLAGS            => 0;
use constant  BLK_WIDTH            => 1;
use constant  BLK_HEIGHT           => 2;
use constant  BLK_X                => 3;
use constant  BLK_Y                => 4;
use constant  BLK_APERTURE_X       => 5;
use constant  BLK_APERTURE_Y       => 6;
use constant  BLK_TEXT_OFFSET      => 7;
use constant  BLK_DATA_START       => 8;
use constant  BLK_FONT_ID          => BLK_DATA_START; 
use constant  BLK_FONT_SIZE        => 9; 
use constant  BLK_FONT_STYLE       => 10;
use constant  BLK_COLOR            => 11; 
use constant  BLK_DATA_END         => 12;
use constant  BLK_BACKCOLOR        => BLK_DATA_END;
use constant  BLK_START            => BLK_DATA_END + 1;

# OP_FONT again
use constant  F_ID    => BLK_FONT_ID;
use constant  F_SIZE  => BLK_FONT_SIZE;
use constant  F_STYLE => BLK_FONT_STYLE;
use constant  F_HEIGHT=> 1000000; 

# BLK_FLAGS constants
use constant T_SIZE      => 0x1;
use constant T_WRAPABLE  => 0x2;
use constant T_IS_BIDI   => 0x4;

# realize_state mode

use constant REALIZE_FONTS   => 0x1;
use constant REALIZE_COLORS  => 0x2;
use constant REALIZE_ALL     => 0x3;

# trace constants
use constant TRACE_FONTS          => 0x01;
use constant TRACE_COLORS         => 0x02;
use constant TRACE_PENS           => TRACE_COLORS | TRACE_FONTS;
use constant TRACE_POSITION       => 0x04;
use constant TRACE_TEXT           => 0x08;
use constant TRACE_GEOMETRY       => TRACE_FONTS | TRACE_POSITION;
use constant TRACE_UPDATE_MARK    => 0x10;
use constant TRACE_PAINT_STATE    => 0x20;
use constant TRACE_REALIZE        => 0x40;
use constant TRACE_REALIZE_FONTS  => TRACE_FONTS | TRACE_REALIZE;
use constant TRACE_REALIZE_COLORS => TRACE_COLORS | TRACE_REALIZE;
use constant TRACE_REALIZE_PENS   => TRACE_PENS | TRACE_REALIZE;

use constant YMAX => 1000;

sub block_create
{
	my $ret = [ ( 0 ) x BLK_START ];
	$$ret[ BLK_FLAGS ] |= T_SIZE;
	push @$ret, @_;
	return $ret;
}

sub block_count
{
	my $block = $_[0];
	my $ret = 0;
	my ( $i, $lim) = ( BLK_START, scalar @$block);
	$i += $oplen[$$block[$i]], $ret++ while $i < $lim;
	return $ret;
}

# creates a new opcode for custom use
sub opcode
{
	my $len = $_[0] || 0;
	my $name = $_[1];
	$len = 0 if $len < 0;
	push @oplen, $len + 1;
	$opnames{$name} = scalar(@oplen) - 1 if defined $name;
	return scalar(@oplen) - 1;
}


sub text           { return OP_TEXT, $_[0], $_[1], $_[2] || 0 }
sub color          { return OP_COLOR, $_[0] } 
sub backColor      { return OP_COLOR, $_[0] | BACKCOLOR_FLAG}
sub colorIndex     { return OP_COLOR, $_[0] | COLOR_INDEX }  
sub backColorIndex { return OP_COLOR, $_[0] | COLOR_INDEX | BACKCOLOR_FLAG}  
sub fontId         { return OP_FONT, F_ID, $_[0] }
sub fontSize       { return OP_FONT, F_SIZE, $_[0] }
sub fontHeight     { return OP_FONT, F_SIZE, $_[0] + F_HEIGHT }
sub fontStyle      { return OP_FONT, F_STYLE, $_[0] }
sub moveto         { return OP_TRANSPOSE, $_[0], $_[1],  $_[2] || 0 } 
sub extend         { return OP_TRANSPOSE, $_[0], $_[1], ($_[2] || 0) | X_EXTEND } 
sub code           { return OP_CODE, $_[0], $_[1] } 
sub wrap           { return OP_WRAP, $_[0] } 
sub mark           { return OP_MARK, $_[0], 0, 0 } 
sub bidimap        { return OP_BIDIMAP, $_[0], $_[1] }

sub realize_fonts
{
	my ( $font_palette, $state) = @_;
	my $font = {%{$font_palette-> [ $$state[ BLK_FONT_ID]]}};
	if ( $$state[ BLK_FONT_SIZE] > F_HEIGHT) {
		$font->{height} = $$state[ BLK_FONT_SIZE] - F_HEIGHT;
	} else {
		$font->{size} = $$state[ BLK_FONT_SIZE];
		delete @{$font}{qw(height width)};
	}
	$font->{style} = $$state[ BLK_FONT_STYLE];
	return $font;
}

sub realize_colors
{
	my ( $color_palette, $state ) = @_;
	return (
		color     =>  (( $$state[ BLK_COLOR] & COLOR_INDEX) ? 
				( $color_palette-> [$$state[ BLK_COLOR] & COLOR_MASK]) :
				( $$state[ BLK_COLOR] & COLOR_MASK)),
		backColor =>  (( $$state[ BLK_BACKCOLOR] & COLOR_INDEX) ? 
				( $color_palette-> [$$state[ BLK_BACKCOLOR] & COLOR_MASK]) : 
				( $$state[ BLK_BACKCOLOR] & COLOR_MASK)),
		textOpaque => (( $$state[ BLK_BACKCOLOR] == BACKCOLOR_DEFAULT) ? 0 : 1),
	);
}

sub _debug_block
{
	my ($b) = @_;
	print STDERR "FLAGS      : ", (( $$b[BLK_FLAGS] & T_SIZE ) ? "T_SIZE" : ""), (( $$b[BLK_FLAGS] & T_WRAPABLE ) ? "T_WRAPABLE" : ""), "\n";
	print STDERR "WIDTH      : ", $$b[BLK_WIDTH] // 'undef', "\n";
	print STDERR "HEIGHT     : ", $$b[BLK_HEIGHT] // 'undef', "\n";
	print STDERR "X          : ", $$b[BLK_X] // 'undef', "\n";
	print STDERR "Y          : ", $$b[BLK_Y] // 'undef', "\n";
	print STDERR "AX         : ", $$b[BLK_APERTURE_X] // 'undef', "\n";
	print STDERR "AY         : ", $$b[BLK_APERTURE_Y] // 'undef', "\n";
	print STDERR "TEXT       : ", $$b[BLK_TEXT_OFFSET] // 'undef', "\n";
	print STDERR "FONT_ID    : ", $$b[BLK_FONT_ID] // 'undef', "\n";
	print STDERR "FONT_SIZE  : ", $$b[BLK_FONT_SIZE] // 'undef', "\n";
	print STDERR "FONT_STYLE : ", $$b[BLK_FONT_STYLE] // 'undef', "\n";
	my $color = $$b[BLK_COLOR];
	unless ( defined $color ) {
		$color = "undef";
	} elsif ( $color & COLOR_INDEX) {
		$color = "index(" . ( $color & ~COLOR_INDEX) . ")";
	} else {
		$color = sprintf("%06x", $color);
	}
	print STDERR "COLOR      : $color\n";
	$color = $$b[BLK_BACKCOLOR];
	unless ( defined $color ) {
		$color = "undef";
	} elsif ( $color & COLOR_INDEX) {
		$color = "index(" . ( $color & ~COLOR_INDEX) . ")";
	} else {
		$color = sprintf("%06x", $color);
	}
	print STDERR "BACK_COLOR : $color\n";

	my ($i, $lim) = (BLK_START, scalar @$b);
	my $oplen;
	for ( ; $i < $lim; $i += $oplen[ $$b[ $i]]) {
		my $cmd = $$b[$i];
		if ( !defined($cmd) || $cmd > $#oplen ) {
			$cmd //= 'undef';
			print STDERR "corrupted block: $cmd at $i/$lim\n";
			last;
		}
		if ($cmd == OP_TEXT) {
			my $ofs = $$b[ $i + T_OFS];
			my $len = $$b[ $i + T_LEN];
			my $wid = $$b[ $i + T_WID] // 'NULL';
			print STDERR ": OP_TEXT( $ofs $len : $wid )\n";
		} elsif ( $cmd == OP_FONT ) {
			my $mode = $$b[ $i + F_MODE ];
			my $data = $$b[ $i + F_DATA ];
			if ( $mode == F_ID ) {
				$mode = 'F_ID';
			} elsif ( $mode == F_SIZE ) {
				$mode = 'F_SIZE';
			} elsif ( $mode == F_STYLE) {
				$mode = 'F_STYLE';
				my @s;
				push @s, "italic" if $data & fs::Italic;
				push @s, "bold" if $data & fs::Bold;
				push @s, "thin" if $data & fs::Thin;
				push @s, "underlined" if $data & fs::Underlined;
				push @s, "struckout" if $data & fs::StruckOut;
				push @s, "outline" if $data & fs::Outline;
				@s = "normal" unless @s;
				$data = join(',', @s);
			}
			print STDERR ": OP_FONT.$mode $data\n";
		} elsif ( $cmd == OP_COLOR ) {
			my $color = $$b[ $i + 1 ];
			my $bk = '';
			if ( $color & BACKCOLOR_FLAG ) {
				$bk = 'backcolor,';
				$color &= ~BACKCOLOR_FLAG;
			}
			if ( $color & COLOR_INDEX) {
				$color = "index(" . ( $color & ~COLOR_INDEX) . ")";
			} else {
				$color = sprintf("%06x", $color);
			}
			print STDERR ": OP_COLOR $bk$color\n";
		} elsif ( $cmd == OP_TRANSPOSE) {
			my $x = $$b[ $i + X_X ];
			my $y = $$b[ $i + X_X ];
			my $f = $$b[ $i + X_FLAGS ] ? 'EXTEND' : 'TRANSPOSE';
			print STDERR ": OP_TRANSPOSE $x $y $f\n";
		} elsif ( $cmd == OP_CODE ) {
			my $code = $$b[ $i + 1 ];
			print STDERR ": OP_CODE $code\n";
		} elsif ( $cmd == OP_BIDIMAP ) {
			my $visual = $$b[ $i + BIDI_VISUAL ];
			my $map    = $$b[ $i + BIDI_MAP ];
			$visual =~ s/([^\x{32}-\x{128}])/sprintf("\\x{%x}", ord($1))/ge;
			print STDERR ": OP_BIDIMAP: $visual / @$map\n";
		} elsif ( $cmd == OP_WRAP ) {
			my $wrap = $$b[ $i + 1 ] ? 'ON' : 'OFF';
			print STDERR ": OP_WRAP $wrap\n";
		} elsif ( $cmd == OP_MARK ) {
			my $id = $$b[ $i + MARK_ID ];
			my $x  = $$b[ $i + MARK_X ];
			my $y  = $$b[ $i + MARK_Y ];
			print STDERR ": OP_MARK $id $x $y\n";
		} else {
			my $oplen = $oplen[ $cmd ];
			my @o = ($oplen > 1) ? @$b[ $i + 1 .. $i + $oplen - 1] : ();
			print STDERR ": OP($cmd) @o\n"; 
		}
	}
}

sub walk
{
	my ( $block, %commands ) = @_;

	my $trace      = delete($commands{trace})      // 0;
	my $position   = delete($commands{position})   // [0,0];
	my $resolution = delete($commands{resolution}) // [72,72];
	my $canvas     = delete($commands{canvas});
	my $state      = delete($commands{state})      // [];
	my $other      = delete $commands{other};
	my $ptr        = delete $commands{pointer}     // \(my $_i);
	my $def_fs     = delete $commands{baseFontSize} // 10;
	my $semaphore  = delete $commands{semaphore}   // \(my $_j);
	my $text       = delete $commands{textPtr}     // \(my $_k);
	my $fontmap    = delete $commands{fontmap};
	my $colormap   = delete $commands{colormap};
	my $realize    = delete $commands{realize}     // sub {
		$canvas->font(realize_fonts($fontmap, $_[0]))  if $_[1] & REALIZE_FONTS;
		$canvas->set(realize_colors($colormap, $_[0])) if $_[1] & REALIZE_COLORS;
	};

	my @commands;
	$commands[ $opnames{$_} ] = $commands{$_} for keys %commands;
	my $ret;

	my ( $text_offset, $f_taint, $font, $c_taint, $paint_state, %save_properties );

	# save paint state
	if ( $trace & TRACE_PAINT_STATE ) {
		$paint_state = $canvas-> get_paint_state;
		if ($paint_state) {
			$save_properties{set_font} = $canvas->get_font if $trace & TRACE_FONTS;
			if ($trace & TRACE_COLORS) {
				$save_properties{$_} = $canvas->$_() for qw(color backColor textOpaque);
			}
		} else {
			$canvas-> begin_paint_info;
		}
	}

	$text_offset = $$block[ BLK_TEXT_OFFSET]
		if $trace & TRACE_TEXT;
	@$state = @$block[ 0 .. BLK_DATA_END ]
		if !@$state && $trace & TRACE_PENS;
	$$position[0] += $$block[ BLK_APERTURE_X], $$position[1] += $$block[ BLK_APERTURE_Y]
		if $trace & TRACE_POSITION;

	# go
	my $lim = scalar(@$block);
	for ( $$ptr = BLK_START; $$ptr < $lim; $$ptr += $oplen[ $$block[ $$ptr ]] ) {
		my $i   = $$ptr;
		my $cmd = $$block[$i];
		my $sub = $commands[ $$block[$i] ];
		my @opcode;
		if ( !$sub && $other ) {
			$sub = $other;
			@opcode = ($cmd);
		}
		if ($cmd == OP_TEXT) {
			next unless $$block[$i + T_LEN] > 0;

			if (( $trace & TRACE_FONTS) && ($trace & TRACE_REALIZE) && !$f_taint) {
				$realize->($state, REALIZE_FONTS);
				$f_taint = 1;
			}
			if (( $trace & TRACE_COLORS) && ($trace & TRACE_REALIZE) && !$c_taint) {
				$realize->($state, REALIZE_COLORS);
				$c_taint = 1;
			}
			$ret = $sub->(
				@opcode,
				@$block[$i + 1 .. $i + $oplen[ $$block[ $$ptr ]] - 1],
				(( $trace & TRACE_TEXT ) ?
					substr( $$text, $text_offset + $$block[$i + T_OFS], $$block[$i + T_LEN] ) : ())
			) if $sub;
			$$position[0] += $$block[ $i + T_WID] if $trace & TRACE_POSITION;
			last if $$semaphore;
			next;
		} elsif (($cmd == OP_FONT) && ($trace & TRACE_FONTS)) {
			if ( $$block[$i + F_MODE] == F_SIZE && $$block[$i + F_DATA] < F_HEIGHT ) {
				$$state[ $$block[$i + F_MODE]] = $def_fs + $$block[$i + F_DATA];
			} else {
				$$state[ $$block[$i + F_MODE]] = $$block[$i + F_DATA];
			}
			$font = $f_taint = undef;
		} elsif (($cmd == OP_COLOR) && ($trace & TRACE_COLORS)) {
			if ( ($$block[ $i + 1] & BACKCOLOR_FLAG) ) {
				$$state[ BLK_BACKCOLOR ] = $$block[$i + 1] & ~BACKCOLOR_FLAG;
			} else {
				$$state[ BLK_COLOR ] = $$block[$i + 1];
			}
			$c_taint = undef;
		} elsif ( $cmd == OP_TRANSPOSE) {
			my $x = $$block[ $i + X_X];
			my $y = $$block[ $i + X_Y];
			my $f = $$block[ $i + X_FLAGS];
			if (($trace & TRACE_FONTS) && ($trace & TRACE_REALIZE)) {
				if ( $f & X_DIMENSION_FONT_HEIGHT) {
					unless ( $f_taint) {
						$realize->($state, REALIZE_FONTS);
						$f_taint = 1;
					}
					$font //= $canvas-> get_font;
					$x *= $font-> {height};
					$y *= $font-> {height};
					$f &= ~X_DIMENSION_FONT_HEIGHT;
				}
			}
			if ( $f & X_DIMENSION_POINT) {
				$x *= $resolution->[0] / 72;
				$y *= $resolution->[1] / 72;
				$f &= ~X_DIMENSION_POINT;
			}
			$ret = $sub->( $x, $y, $f ) if $sub;
			if (!($f & X_EXTEND) && ($trace & TRACE_POSITION)) {
				$$position[0] += $x;
				$$position[1] += $y;
			}
			last if $$semaphore;
			next;
		} elsif (( $cmd == OP_CODE) && ($trace & TRACE_PENS) && ($trace & TRACE_REALIZE)) {
			unless ( $f_taint) {
				$realize->($state, REALIZE_FONTS);
				$f_taint = 1;
			}
			unless ( $c_taint) {
				$realize->($state, REALIZE_COLORS);
				$c_taint = 1;
			}
		} elsif (($cmd == OP_BIDIMAP) && ( $trace & TRACE_TEXT )) {
			$text = \ $$block[$i + BIDI_VISUAL];
			$text_offset = 0;
		} elsif (( $cmd == OP_MARK) & ( $trace & TRACE_UPDATE_MARK)) {
			$$block[ $i + MARK_X] = $$position[0];
			$$block[ $i + MARK_Y] = $$position[1];
		} elsif ( $cmd > $#oplen ) {
			warn "corrupted block, $cmd at $$ptr\n";
			_debug_block($block);
			last;
		}
		$ret = $sub->( @opcode, @$block[$i + 1 .. $i + $oplen[ $$block[ $$ptr ]] - 1]) if $sub;
		last if $$semaphore;
	}

	# restore paint state
	if ( $trace & TRACE_PAINT_STATE ) {
		if ( $paint_state ) {
			$canvas->$_( $save_properties{$_} ) for keys %save_properties;
		} else {
			$canvas->end_paint_info;
		}
	}

	return $ret;
}

# convert block with bidicharacters to its visual representation
sub bidi_visualize
{
	my ( $b, $substr ) = @_;

	my ($p, $visual) = Prima::Bidi::paragraph($substr);
	my $map     = $p->map;
	my $revmap  = Prima::Bidi::revmap($map);
	my @new     = ( @$b[0..BLK_DATA_END], bidimap( $visual, $map ) );
	$new[BLK_FLAGS] |= T_IS_BIDI;
	my $oplen;
	my ($x, $y, $i, $lim) = (0,0,BLK_START, scalar @$b);

	# step 1 - record how each character is drawn with font/color, and also 
	# where other ops are positioned
	my @default_fc        = @$b[ 0 .. BLK_DATA_END ]; # fc == fonts and colors
	my %id_hash           = ( join(".", @default_fc[BLK_DATA_START .. BLK_DATA_END]) => 0 );
	my @fonts_and_colors  = ( \@default_fc ); # this is the number #0, default char state
	my @current_fc        = @default_fc;
	my $current_state     = 0;
	
	my @char_states       = (-1) x length($visual); # not all chars are displayed
	my $char_offset       = 0;
	my %other_ops_after;

	my $font_and_color = sub {
		my $key = join(".", @current_fc[ BLK_DATA_START .. BLK_DATA_END ]);
		my $state;
		if (defined ($state = $id_hash{$key}) ) {
			$current_state = $state;
		} else {
			push @fonts_and_colors, [ @current_fc ];
			$id_hash{$key} = ++$current_state;
		}
	};

	walk( $b,
		trace => TRACE_PENS,
		state => \@current_fc,
		text => sub {
			my ( $ofs, $len ) = @_;
			for ( my $k = 0; $k < $len; $k++) {
				$char_states[ $revmap->[ $ofs + $k ]] = $current_state;
			}
			$char_offset = $revmap->[$ofs + $len - 1];
		},
		font  => $font_and_color,
		color => $font_and_color,
		other  => sub { push @{$other_ops_after{ $char_offset }}, @_ }
	);

	# step 2 - produce RLEs for text and stuff font/colors/other ops in between
	my $last_char_state = 0;
	my $current_text_offset;

	# find first character displayed
	for ( my $i = 0; $i < @char_states; $i++) {
		next if $char_states[$i] < 0;
		$current_text_offset = $i;
		last;
	}

	my @initialized;
	push @char_states, -1;
	for ( my $i = 0; $i < @char_states; $i++) {
		my $char_state = $char_states[$i];
		if ( $char_state != $last_char_state ) {
			# push accumulated text
			my $ofs = $current_text_offset;
			my $len = $i - $ofs;
			$current_text_offset = ($char_state < 0) ? $i + 1 : $i;
			if ( $len > 0 ) {
				push @new, OP_TEXT, $ofs, $len, substr( $visual, $ofs, $len); # temporarily putting a string there
			}

			# change to the new font/color
			if ( $char_state >= 0 ) {
				my $old_state = $fonts_and_colors[ $last_char_state ];
				my $new_state = $fonts_and_colors[ $char_state ];
				if ( $$old_state[ BLK_COLOR ] != $$new_state[ BLK_COLOR ] ) {
					if ( $initialized[ BLK_COLOR ]++ ) {
						push @new, OP_COLOR, $$new_state[ BLK_COLOR ];
					} else {
						$new[ BLK_COLOR ] = $$new_state[ BLK_COLOR ];
					}
				}
				if ( $$old_state[ BLK_BACKCOLOR ] != $$new_state[ BLK_BACKCOLOR ] ) {
					if ( $initialized[ BLK_BACKCOLOR ]++ ) {
						push @new, OP_COLOR, $$new_state[ BLK_BACKCOLOR ] | BACKCOLOR_FLAG;
					} else {
						$new[ BLK_BACKCOLOR ] = $$new_state[ BLK_BACKCOLOR ];
					}
				}
				for ( my $font_mode = BLK_FONT_ID; $font_mode <= BLK_FONT_STYLE; $font_mode++) {
					next if $$old_state[ $font_mode ] == $$new_state[ $font_mode ];
					if ( $initialized[ $font_mode ]++ ) {
						push @new, OP_FONT, $font_mode, 
					} else {
						$new[ $font_mode ] = $$new_state[ $font_mode ];
					}
				}
				$last_char_state = $char_state;
			}
		}

		# push other ops
		if ( my $ops = $other_ops_after{ $i } ) {
			push @new, @$ops;
		}
	}

	return \@new;
}

sub block_wrap
{
	my ( $b, %opt) = @_;
	my ($t, $canvas, $state, $width, $fontmap, $bfs, $resolution) = @opt{qw(textPtr canvas state width fontmap baseFontSize resolution)};

	$width = 0 if $width < 0;

	my $cmd;
	my ( $o) = ( $$b[ BLK_TEXT_OFFSET]);
	my ( $x, $y) = (0, 0);
	my $wrapmode = 1;
	my $stsave = $state;
	$state = [ @$state ];
	my ( $haswrapinfo, @wrapret);
	my ( @ret, $z, $ptr);
	my $lastTextOffset = $$b[ BLK_TEXT_OFFSET];
	my $has_text;

	my $newblock = sub 
	{
		push @ret, $z = block_create();
		@$z[ BLK_DATA_START .. BLK_DATA_END ] = 
			@$state[ BLK_DATA_START .. BLK_DATA_END];
		$$z[ BLK_X] = $$b[ BLK_X];
		$$z[ BLK_FLAGS] &= ~ T_SIZE;
		$$z[ BLK_TEXT_OFFSET] = $$b [ BLK_TEXT_OFFSET];
		$x = 0;
		undef $has_text;
	};

	my $retrace = sub 
	{
		$haswrapinfo = 0;
		splice( @{$ret[-1]}, $wrapret[0]); 
		@$state = @{$wrapret[1]};
		$newblock-> ();
		$ptr = $wrapret[2];
	};

	$newblock-> ();
	$$z[BLK_TEXT_OFFSET] = $$b[BLK_TEXT_OFFSET];

	my %state_hash;
	my $has_bidi;

	# first state - wrap the block
	walk( $b,
		textPtr => $t,
		pointer => \$ptr,
		canvas  => $canvas,
		state   => $state,
		trace   => TRACE_REALIZE_PENS,
		fontmap => $fontmap,
		realize => sub { $canvas->font(realize_fonts($fontmap, $_[0]))  if $_[1] & REALIZE_FONTS },
		baseFontSize => $bfs,
		resolution   => $resolution,
		text    => sub {
			my ( $ofs, $tlen ) = @_;
			my $state_key = join('.', @$state[BLK_FONT_ID .. BLK_FONT_STYLE]);
			$state_hash{$state_key} = $canvas->get_font 
				unless $state_hash{$state_key};
			$lastTextOffset = $ofs + $tlen unless $wrapmode;
		REWRAP: 
			my $tw  = $canvas-> get_text_width( substr( $$t, $o + $ofs, $tlen), 1);
			my $apx = $state_hash{$state_key}-> {width};
			if ( $x + $tw + $apx <= $width) {
				push @$z, OP_TEXT, $ofs, $tlen, $tw;
				$x += $tw;
				$has_text = 1;
			} elsif ( $wrapmode) {
				return if $tlen <= 0;
				my $str = substr( $$t, $o + $ofs, $tlen);
				my $leadingSpaces = '';
				if ( $str =~ /^(\s+)/) {
					$leadingSpaces = $1;
					$str =~ s/^\s+//;
				}
				my $l = $canvas-> text_wrap( $str, $width - $apx - $x,
					tw::ReturnFirstLineLength | tw::WordBreak | tw::BreakSingle);
				if ( $l > 0) {
					if ( $has_text) {
						push @$z, OP_TEXT, 
							$ofs, $l + length $leadingSpaces, 
							$tw = $canvas-> get_text_width( 
								$leadingSpaces . substr( $str, 0, $l), 1
							);
					} else {
						push @$z, OP_TEXT, 
							$ofs + length $leadingSpaces, $l, 
							$tw = $canvas-> get_text_width( 
								substr( $str, 0, $l), 1
							);
						$has_text = 1;
					}
					$str = substr( $str, $l);
					$l += length $leadingSpaces;
					$newblock-> ();
					$ofs += $l;
					$tlen -= $l;
					if ( $str =~ /^(\s+)/) {
						$ofs  += length $1;
						$tlen -= length $1;
						$x    += $canvas-> get_text_width( $1, 1);
						$str =~ s/^\s+//;
					}
					goto REWRAP if length $str;
				} else { # does not fit into $width
					my $ox = $x;
					$newblock-> ();
					$ofs  += length $leadingSpaces;
					$tlen -= length $leadingSpaces; 
					if ( length $str) { 
					# well, it cannot be fit into width,
					# but may be some words can be stripped?
						goto REWRAP if $ox > 0;
						if ( $str =~ m/^(\S+)(\s*)/) {
							$tw = $canvas-> get_text_width( $1, 1);
							push @$z, OP_TEXT, $ofs, length $1, $tw;
							$has_text = 1;
							$x += $tw;
							$ofs  += length($1) + length($2);
							$tlen -= length($1) + length($2);
							goto REWRAP;
						}
					}
					push @$z, OP_TEXT, $ofs, length($str),
						$x += $canvas-> get_text_width( $str, 1);
					$has_text = 1;
				}
			} elsif ( $haswrapinfo) { # unwrappable, and cannot be fit - retrace
				$retrace-> ();
			} else { # unwrappable, cannot be fit, no wrap info! - whole new block
				push @$z, OP_TEXT, $ofs, $tlen, $tw;
				$newblock-> ();
			}
		},
		wrap => sub {
			my $mode = shift;
			if ( $wrapmode == 1 && $mode == 0) {
				@wrapret = ( scalar @$z, [ @$state ], $ptr);
				$haswrapinfo = 1;
			}
			$wrapmode = $mode;
		},
		transpose => sub {
			my ( $dx, $dy, $flags) = @_;
			if ( $x + $dx >= $width) {
				if ( $wrapmode) {
					$newblock-> (); 
				} elsif ( $haswrapinfo) {
					return $retrace-> ();
				} 
			} else {
				$x += $dx;
			}
			push @$z, OP_TRANSPOSE, $dx, $dy, $flags;
		},
		other => sub { push @$z, @_ },
	);

	# remove eventual empty trailing blocks

	# second stage - position the blocks
	$state = $stsave;
	my $start;
	if ( !defined $$b[ BLK_Y]) { 
		# auto position the block if the creator didn't care
		$start = $$state[ BLK_Y] + $$state[ BLK_HEIGHT];
	} else {
		$start = $$b[ BLK_Y];
	}

	$lastTextOffset = $$b[ BLK_TEXT_OFFSET];
	my $lastBlockOffset = $lastTextOffset;

	for my $b ( @ret) {
		$$b[ BLK_Y] = $start;
	
		my @xy = (0,0);
		my $ptr;
		walk( $b,
			textPtr  => $t,
		        canvas   => $canvas,
			trace    => TRACE_FONTS | TRACE_POSITION | TRACE_UPDATE_MARK,
			state    => $state,
			position => \@xy,
			pointer  => \$ptr,
			baseFontSize => $bfs,
			resolution   => $resolution,
			text     => sub {
				my ( $ofs, $len, $wid ) = @_;
				my $f_taint = $state_hash{ join('.', 
					@$state[BLK_FONT_ID .. BLK_FONT_STYLE]
				) };
				my $x = $xy[0] + $wid;
				my $y = $xy[1];
				$$b[ BLK_WIDTH] = $x 
					if $$b[ BLK_WIDTH ] < $x;
				$$b[ BLK_APERTURE_Y] = $f_taint-> {descent} - $y 
					if $$b[ BLK_APERTURE_Y] < $f_taint-> {descent} - $y;
				$$b[ BLK_APERTURE_X] = $f_taint-> {width}   - $x 
					if $$b[ BLK_APERTURE_X] < $f_taint-> {width}   - $x;
				my $newY = $y + $f_taint-> {ascent} + $f_taint-> {externalLeading};
				$$b[ BLK_HEIGHT] = $newY if $$b[ BLK_HEIGHT] < $newY; 
				$lastTextOffset = $$b[ BLK_TEXT_OFFSET] + $ofs + $len;

				$$b[ $ptr + T_OFS] -= $lastBlockOffset - $$b[ BLK_TEXT_OFFSET];
			},
			transpose => sub {
				my ( $dx, $dy, $f ) = @_;
				my ( $newX, $newY) = ( $xy[0] + $dx, $xy[1] + $dy);
				$$b[ BLK_WIDTH]  = $newX 
					if $$b[ BLK_WIDTH ] < $newX;
				$$b[ BLK_HEIGHT] = $newY 
					if $$b[ BLK_HEIGHT] < $newY;
				$$b[ BLK_APERTURE_X] = -$newX 
					if $newX < 0 && $$b[ BLK_APERTURE_X] > -$newX;
				$$b[ BLK_APERTURE_Y] = -$newY 
					if $newY < 0 && $$b[ BLK_APERTURE_Y] > -$newY;
			},
		);
		$$b[ BLK_TEXT_OFFSET] = $lastBlockOffset;
		$$b[ BLK_HEIGHT] += $$b[ BLK_APERTURE_Y];
		$$b[ BLK_WIDTH]  += $$b[ BLK_APERTURE_X];
		$start += $$b[ BLK_HEIGHT];
		$lastBlockOffset = $lastTextOffset;
	}

	if ( $ret[-1]) {
		$b = $ret[-1];
		$$state[$_] = $$b[$_] for BLK_X, BLK_Y, BLK_HEIGHT, BLK_WIDTH;
	}

	# third stage - map bidi characters to visual representation, and update widths and positions etc
	my @text_offsets = (( map { $$_[  BLK_TEXT_OFFSET ] } @ret ), $lastTextOffset);
	for ( my $j = 0; $j < @ret; $j++) {
		my $substr  = substr( $$t, $text_offsets[$j], $text_offsets[$j+1] - $text_offsets[$j]);
		next unless Prima::Bidi::is_bidi($substr);

		my $new   = bidi_visualize($ret[$j], $substr);
		my @xy    = (0,0);
		my $ptr;
		
		$new->[ BLK_WIDTH] = 0;
		walk( $new,
			textPtr  => $t,
			canvas   => $canvas,
			fontmap  => $fontmap,
			trace    => TRACE_REALIZE_FONTS | TRACE_UPDATE_MARK | TRACE_POSITION,
			position => \@xy,
			pointer  => \$ptr,
			text     => sub { $new-> [ $ptr + T_WID ] = $canvas->get_text_width( $_[2], 1 ) },
			baseFontSize => $bfs,
			resolution   => $resolution,
		);
		$new->[ BLK_WIDTH] = $xy[0] if $new->[ BLK_WIDTH ] < $xy[0];
		splice(@ret, $j, 1, $new);
	}

	return @ret;
}

package Prima::Drawable::TextBlock;

my $RAD = 57.29577951;

sub new {
	my $class = shift;
	return bless {
		text         => '',
		baseFontSize => 10,
		fontmap      => [{}],
		colormap     => [cl::Black],
		resolution   => [72,72],
		@_
	}, $class;
}

sub clone
{
	my ( $self, @opt) = @_;
	my %opt = ( %$self, @opt);
	my $text = delete $opt{text};
	return ref($self)->new( $text, %opt );
}

sub text_out
{
	my ($self, $canvas, $x, $y) = @_;

	my @xy = ($x,$y);
	my @state;
	my $semaphore;

	my ($sin, $cos);
	($sin, $cos) = (sin( $self-> {direction} / $RAD ), cos( $self-> {direction} / $RAD ))
		if $self->{direction};

	tb::walk( $self->{block},
		( map { $_ => $self-> {$_} } qw(resolution baseFontSize fontmap colormap) ),
		textPtr   => \$self->{text},
		semaphore => \$semaphore,
		trace     => tb::TRACE_GEOMETRY | tb::TRACE_REALIZE_PENS | tb::TRACE_TEXT | tb::TRACE_PAINT_STATE,
		canvas    => $canvas,
		position  => \@xy,
		state     => \@state,
		text      => sub {
			my ( $ofs, $len, $wid, $tex) = @_;
			my @coord = $self-> {direction} ? ($xy[0] * $cos - $xy[1] * $sin, $xy[0] * $sin + $xy[1] * $cos) : @xy;
			$semaphore++ unless $canvas-> text_out($tex, @coord);
			$xy[0] -= $wid; # it's 0 anyway
			$xy[0] += $canvas-> get_text_width($tex);
		},
		code      => sub {
			my ( $code, $data ) = @_;
			my @coord = $self-> {direction} ? ($xy[0] * $cos - $xy[1] * $sin, $xy[0] * $sin + $xy[1] * $cos) : @xy;
			$code-> ( $self, $canvas, $b, \@state, @coord, $data);
		},
	);

	return not $semaphore;
}

sub get_text_width_with_overhangs
{
	my ($self, $canvas) = @_;
	my $first_a_width = 0;
	my $last_c_width = 0;
	my $width = 0;
	tb::walk( $self->{block},
		( map { $_ => $self-> {$_} } qw(resolution baseFontSize fontmap) ),
		textPtr   => \$self->{text},
		trace     => tb::TRACE_GEOMETRY | tb::TRACE_REALIZE | tb::TRACE_TEXT | tb::TRACE_PAINT_STATE,
		canvas    => $canvas,
		text      => sub {
			my $t = pop;
			if ( !defined $first_a_width) {
				my $char = substr( $t, 0, 1 );
				( $first_a_width ) = @{ $canvas->get_font_abc(ord($char), ord($char), utf8::is_utf8($t)) };
			}
			my $char = substr( $t, -1, 1 );
			( undef, undef, $last_c_width ) = @{ $canvas->get_font_abc(ord($char), ord($char), utf8::is_utf8($t)) };
			$width += $canvas-> get_text_width($t);
		},
	);
	$first_a_width = ( $first_a_width < 0 ) ? -$first_a_width : 0;
	$last_c_width  = ( $last_c_width  < 0 ) ? -$last_c_width : 0;
	return ($width, $first_a_width, $last_c_width);
}

sub get_text_width
{
	my ( $self, $canvas, $add_overhangs) = @_;
	if ( $add_overhangs ) {
		my ( $width, $a, $c) = $self-> get_text_width_with_overhangs($canvas);
		return $width + $a + $c;
	}

	my $width = 0;
	tb::walk( $self->{block},
		( map { $_ => $self-> {$_} } qw(resolution baseFontSize fontmap) ),
		textPtr   => \$self->{text},
		trace     => tb::TRACE_GEOMETRY | tb::TRACE_REALIZE | tb::TRACE_TEXT | tb::TRACE_PAINT_STATE,
		canvas    => $canvas,
		text      => sub { $width += $canvas-> get_text_width($_[-1]) },
	);

	return $width;
}

sub get_text_box
{
	my ( $self, $canvas, $text) = @_;
	my ( $w, $a, $c) = $self-> get_text_width_with_overhangs($canvas);

	my ( $fa, $fd ) = ( $canvas->font->ascent - 1, $canvas->font->descent );

	my @ret = (
		-$a,      $fa,
		-$a,     -$fd,
		$w - $c,  $fa,
		$w - $c, -$fd,
		$w, 0
	);
	unless ( $canvas-> textOutBaseline) {
		$ret[$_] += $fd for (1,3,5,7,9);
	}
	if ( my $dir = $self-> {direction}) {
		my $s = sin( $dir / $RAD );
		my $c = cos( $dir / $RAD );
		my $i;
		for ( $i = 0; $i < 10; $i+=2) {
			my ( $x, $y) = @ret[$i,$i+1];
			$ret[$i]   = $x * $c - $y * $s;
			$ret[$i+1] = $x * $s + $y * $c;
		}
	}
	return \@ret;
}

sub block        { $#_ ? $_[0]->{block}      = $_[1]   : $_[0]->{block} }
sub text         { $#_ ? $_[0]->{text}       = $_[1]   : $_[0]->{text} }
sub fontmap      { $#_ ? $_[0]->{fontmap}    = $_[1]   : $_[0]->{fontmap} }
sub colormap     { $#_ ? $_[0]->{colormap}   = $_[1]   : $_[0]->{colormap} }
sub resolution   { $#_ ? $_[0]->{resolution} = $_[1]   : $_[0]->{resolution} }
sub baseFontSize { $#_ ? $_[0]->{baseFontSize} = $_[1] : $_[0]->{baseFontSize} }

1;