
all:
	gnatmake -O2 -D obj -Isrc -gnatwaF -gnaty3aAbdhikmnpr -we main.adb

clean:
	rm -f main obj/*.ali obj/*.o

