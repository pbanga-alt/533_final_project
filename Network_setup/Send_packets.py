#!/usr/bin/env python
import socket
import sys
import time
import struct

# --- Check for Command Line Argument ---
if len(sys.argv) < 2:
    print "Usage: python send_bfloat16.py <filename>"
    sys.exit(1)

FILE_PATH = sys.argv[1]
TARGET_IP = "10.0.0.3"
TARGET_PORT = 5030
SOURCE_PORT = 54321

# 8x8 bfloat16 parameters = 64 parameters * 2 bytes = 128 bytes per chunk
CHUNK_SIZE = 128

# Keep the original 6-byte hardware alignment padding
PAD = "\xAA\xAA\xAA\xAA\xAA\xAA"

print "Reading payload file: %s" % FILE_PATH
try:
    f = open(FILE_PATH, "rb")
    data = f.read()
    f.close()
except IOError:
    print "Error: Could not find '%s'." % FILE_PATH
    sys.exit(1)

# Dynamically slice data into 128-byte chunks
chunks = [data[i:i+CHUNK_SIZE] for i in range(0, len(data), CHUNK_SIZE)]
total_chunks = len(chunks)

print "File sliced into %d chunks of %d bytes." % (total_chunks, CHUNK_SIZE)

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, 11, 1) # Zero-checksum bypass
    s.bind(("", SOURCE_PORT))              # Lock source port

    for i, chunk in enumerate(chunks):
        # Calculate reverse counter (e.g., 31 down to 0)
        reverse_counter = (total_chunks - 1) - i
        is_final = (reverse_counter == 0)

        # Pack the 32-bit counter into big-endian raw bytes
        counter_bytes = struct.pack(">I", reverse_counter)

        # Start: C0DEFACE (high) + reverse_counter (low)
        start_marker = "\xC0\xDE\xFA\xCE" + counter_bytes

        # End: FACECODE (high) + reverse_counter (low)
        end_marker = "\xFA\xCE\xC0\xDE" + counter_bytes

        # Final packet special trailer
        if is_final:
            # \xDE\xAD\xBE\xEF\x00\x00\x00\x00 (64-bit word 1)
            # \x00\x00\x00\x00\x00\x00\x00\x00 (64-bit word 2 for Verilog result insertion)
            trailer = "\xDE\xAD\xBE\xEF\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        else:
            trailer = ""

        # Assemble the final frame
        packet = PAD + start_marker + chunk + end_marker + trailer
        s.sendto(packet, (TARGET_IP, TARGET_PORT))

        # Print terminal output for verification
        hex_start = start_marker.encode('hex').upper()
        hex_end = end_marker.encode('hex').upper()

        if is_final:
            print "Sent chunk %d/%d (Counter: %02d) [FINAL] | Start: %s | End: %s | +Trailer" % (i+1, total_chunks, reverse_counter, hex_start, hex_end)
        else:
            print "Sent chunk %d/%d (Counter: %02d)         | Start: %s | End: %s" % (i+1, total_chunks, reverse_counter, hex_start, hex_end)

        # Tiny delay to prevent overflowing the FPGA network FIFO
        time.sleep(0.05)

    print "All %d packets dispatched successfully!" % total_chunks

except Exception, e:
    print "Network Error: %s" % str(e)