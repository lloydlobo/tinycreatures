# Makefile

test-busted:
	busted tests/*.lua

watch-test-busted:
	find tests -name '*.lua' | entr -crs 'date; make test-busted; echo exit status $?;'


# luarocks install busted --local
# echo 'export PATH=~/.luarocks/bin:$PATH' >> ~/.zprofile
# source ~/.zprofile
# busted tests/*.lua
