import serial
from time import sleep
import sys

# "CONSTANTS"
BOOTLOADER_START = 0x1B0
JUMP_TO_BOOTLOADER = 0xC000 | (BOOTLOADER_START - 1)
FLASH_PAGE_BYTES = 0x20
FLASH_SIZE = 1024
PAGES_AVAILABLE = int((2 * BOOTLOADER_START) / FLASH_PAGE_BYTES)

def chunks(l, n):
    for i in range(0, len(l), n):
        yield l[i:i + n]
		
def getChunk(flash, i):
	ch = [0xFF for i in range(FLASH_PAGE_BYTES + 2)]
	reg = ((int(i)) << 5) & 0xFFFF
	ch[0] = (reg & 0xFF00) >> 8
	ch[1] = reg & 0xFF
	if len(flash) > i:
		pos = 2
		for e in flash[i]:
			ch[pos] = e
			pos = pos + 1
			
	return bytes(ch)

if len(sys.argv) < 4:
	print("Usage: " + sys.argv[0] + " w COM3 input.bin\n       " + sys.argv[0] + " r COM3 output.bin")
	exit()
	
if sys.argv[1] == "w":
	with open(sys.argv[3], "rb") as binaryfile :
		flashBin = bytearray(binaryfile.read())
	
	programStart = ((flashBin[0] + (flashBin[1] << 8)) & 0xfff) + 1

	if programStart != 0x0A:
		print("Your program starts at " + hex(programStart) + ". It might not work properly, as bootloader jumps to 0x0A to start user application!")
		
	if len(flashBin) > BOOTLOADER_START:
		print("Your binary overlaps bootloader. It will be truncated to fit available memory, so your application might not work correctly!")
	
	# Replace rjmp at RESET interrupt vector to jump to bootloader
	flashBin[0] = JUMP_TO_BOOTLOADER & 0xff
	flashBin[1] = JUMP_TO_BOOTLOADER >> 8
	flashBin = list(chunks(flashBin, FLASH_PAGE_BYTES))
	if len(flashBin) > PAGES_AVAILABLE:
		flashBin = flashBin[0:PAGES_AVAILABLE]

with serial.Serial(sys.argv[2], 9600, timeout=2) as ser:
	if sys.argv[1] == "r": # Write R letter for flash reading mode
		ser.write(bytes([0x52]))
		ser.flush()
		r = ser.read(FLASH_SIZE + 1)
		
		with open(sys.argv[3], "wb") as binaryfile :
			binaryfile.write(r[1:])
			
		print("DONE.")
	elif sys.argv[1] == "w":
		for i in range(PAGES_AVAILABLE):
			ser.write(bytes([0x50])) # Write P letter for flash programming mode
			ser.flush()
			for b in getChunk(flashBin, i):
				ser.write(bytes([b]))
				ser.flush()
				sleep(0.002) # IF THERE ARE ERRORS DURING PROGRAMMING, INCREASE IT A BIT

			resp = ser.read(FLASH_PAGE_BYTES + 4)
			if (resp[-1] == 89):
				print(format(i * FLASH_PAGE_BYTES, '03x') + "..." + format((i + 1) * FLASH_PAGE_BYTES, '03x') + ": ACK")
			else:
				print(format(i * FLASH_PAGE_BYTES, '03x') + "..." + format((i + 1) * FLASH_PAGE_BYTES, '03x') + ": NAK")
		
		print("DONE.")