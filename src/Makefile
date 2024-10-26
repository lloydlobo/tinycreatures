# zip -r src/tinybloodcells.love src -x@.gitignore
release:
	rm -f tinybloodcells.love
	zip -r tinybloodcells.love .

run:
	love .

watch:
	find -name '*.lua' | entr -crs 'date; make run; echo exit status $?'

# luarocks install busted --local
# echo 'export PATH=~/.luarocks/bin:$PATH' >> ~/.zprofile
# source ~/.zprofile
# busted tests/*.lua
test-busted:
	busted tests/*.lua

watch-busted:
	find -name '*.lua' | entr -crs 'date; make test-busted; echo exit status $?'
