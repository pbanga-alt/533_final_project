#!/usr/bin/perl
use strict;
use warnings;

# ============================================================================
# write_mem.pl - Generic Memory Writer for NetFPGA BRAM
# ============================================================================

# Hardware register addresses and write patterns
my $CMD_REG = 0x2000300;      # Command register address
my $ADDR_REG = 0x2000304;     # Address register address
my $DIN_REG = 0x2000308;      # Data input register address
my $WE_ENABLE = 0x0000000a;   # Pattern to enable write
my $WE_DISABLE = 0x00000008;  # Pattern to disable write

# ============================================================================
# ============================================================================
# Usage: ./write_mem.pl <input_hex_file> <start_addr> <num_lines>
#
# Arguments:
#   input_hex_file - File containing hex values (one per line, 8 hex chars)
#   start_addr     - Starting BRAM address to write to (decimal e.g. 128, or hex e.g. 0x80)
#   num_lines      - Number of memory locations to write (e.g., 512)
#
# Example:
#   ./write_mem.pl program.hex 0 512
#   ./write_mem.pl program.hex 128 64
#   ./write_mem.pl program.hex 0x80 64
# ============================================================================

# Check command-line arguments
if (@ARGV != 3) {
    print STDERR "ERROR: Incorrect number of arguments!\n\n";
    print STDERR "Usage: $0 <input_hex_file> <start_addr> <num_lines>\n\n";
    print STDERR "Arguments:\n";
    print STDERR "  input_hex_file - File with hex values (one per line, 8 hex chars)\n";
    print STDERR "  start_addr     - Starting BRAM address (decimal or 0x hex)\n";
    print STDERR "  num_lines      - Number of memory locations to write\n\n";
    print STDERR "Example:\n";
    print STDERR "  $0 program.hex 0 512\n";
    exit 1;
}

my ($input_file, $start_addr_str, $num_lines) = @ARGV;
my $start_addr = parse_address($start_addr_str, "start_addr");

# Validate num_lines
if ($num_lines <= 0) {
    die "ERROR: Invalid num_lines '$num_lines'. Must be positive.\n";
}

# Check if input file exists
if (!-e $input_file) {
    die "ERROR: Input file '$input_file' does not exist!\n";
}

# Read input file
open(my $fh, '<', $input_file) or die "ERROR: Cannot open input file '$input_file': $!\n";
my @hex_data = <$fh>;
close($fh);

# Remove whitespace and validate
my @validated_data;
my $line_num = 0;
foreach my $line (@hex_data) {
    $line_num++;
    chomp($line);
    
    # Skip empty lines and comments
    $line =~ s/#.*$//;  # Remove comments
    $line =~ s/^\s+//;  # Remove leading whitespace
    $line =~ s/\s+$//;  # Remove trailing whitespace
    
    next if $line eq '';  # Skip empty lines
    
    # Validate hex format (8 hex characters)
    if ($line !~ /^[0-9A-Fa-f]{8}$/) {
        die "ERROR: Line $line_num in '$input_file' has invalid format: '$line'\n" .
            "       Expected 8 hex characters (e.g., DEADBEEF or 12345678)\n";
    }
    
    push @validated_data, uc($line);  # Store in uppercase
}

# Check if we have enough data
my $data_lines = scalar @validated_data;
if ($data_lines < $num_lines) {
    die "ERROR: Input file has only $data_lines data lines, but you requested $num_lines lines.\n" .
        "       Please provide a file with at least $num_lines hex values,\n" .
        "       or reduce the num_lines parameter to $data_lines or less.\n";
}

# Print summary
print "=" x 70 . "\n";
print "Memory Write Script\n";
print "=" x 70 . "\n";
print "Input file:     $input_file\n";
print "Data lines:     $data_lines\n";
print "Start address:  0x" . sprintf("%08X", $start_addr) . "\n";
print "Writing:        $num_lines locations\n";
print "Command reg:    0x" . sprintf("%08X", $CMD_REG) . "\n";
print "WE enable:      0x" . sprintf("%08X", $WE_ENABLE) . "\n";
print "WE disable:     0x" . sprintf("%08X", $WE_DISABLE) . "\n";
print "Address reg:    0x" . sprintf("%08X", $ADDR_REG) . "\n";
print "Data in reg:    0x" . sprintf("%08X", $DIN_REG) . "\n";
print "=" x 70 . "\n\n";

# Write data to memory
my $errors = 0;
for (my $i = 0; $i < $num_lines; $i++) {
    my $bram_addr = $start_addr + $i;
    my $data = $validated_data[$i];
    
    # Set address
    if (!regwrite($ADDR_REG, $bram_addr)) {
        print STDERR "ERROR: Failed to write address $bram_addr to address register\n";
        $errors++;
        last;
    }
    
    # Set data
    if (!regwrite($DIN_REG, hex($data))) {
        print STDERR "ERROR: Failed to write data 0x$data to data input register\n";
        $errors++;
        last;
    }
    
    # Enable write
    if (!regwrite($CMD_REG, $WE_ENABLE)) {
        print STDERR "ERROR: Failed to enable write (set WE bit)\n";
        $errors++;
        last;
    }
    
    # Disable write
    if (!regwrite($CMD_REG, $WE_DISABLE)) {
        print STDERR "ERROR: Failed to disable write (clear WE bit)\n";
        $errors++;
        last;
    }
    
    # Print progress
    if ($i % 64 == 0) {
        printf "Written up to BRAM address %d (0x%08X)...\n", $bram_addr, $bram_addr;
    }
}

# Final summary
print "\n" . "=" x 70 . "\n";
if ($errors == 0) {
    print "SUCCESS! Wrote $num_lines locations to memory.\n";
    print "=" x 70 . "\n";
    exit 0;
} else {
    print "FAILURE! Encountered $errors error(s) during write.\n";
    print "=" x 70 . "\n";
    exit 1;
}

# ============================================================================
# Helper Functions
# ============================================================================

sub parse_hex_address {
    my ($addr_str, $name) = @_;
    
    if ($addr_str =~ /^0x([0-9A-Fa-f]+)$/) {
        return hex($1);
    } else {
        die "ERROR: Invalid hex address for $name: '$addr_str'\n" .
            "       Expected format: 0xXXXXXXXX (e.g., 0x2000300)\n";
    }
}

sub parse_address {
    my ($addr_str, $name) = @_;

    if ($addr_str =~ /^0x([0-9A-Fa-f]+)$/) {
        return hex($1);         # Hex input
    } elsif ($addr_str =~ /^\d+$/) {
        return int($addr_str);  # Decimal input
    } else {
        die "ERROR: Invalid address for $name: '$addr_str'\n" .
            "       Expected hex (e.g., 0x80) or decimal (e.g., 128)\n";
    }
}

sub regwrite {
    my ($reg_addr, $value) = @_;
    
    my $cmd = sprintf("regwrite 0x%X 0x%X 2>&1", $reg_addr, $value);
    my $output = `$cmd`;
    my $exit_code = $? >> 8;
    
    if ($exit_code != 0) {
        print STDERR "regwrite command failed: $cmd\n";
        print STDERR "Output: $output\n" if $output;
        return 0;
    }
    
    return 1;
}
