# zip -r src/tinybloodcells.love src -x@.gitignore
release:
	rm -f tinybloodcells.love
	zip -r tinybloodcells.love .

run:
	love .

watch:
	find -name '*.lua' | entr -crs 'date; make run; echo exit status $?'

test-busted:
	busted tests/*.lua

watch-busted:
	find -name '*.lua' | entr -crs 'date; make test-busted; echo exit status $?'
