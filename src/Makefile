# zip -r src/tinybloodcells.love src -x@.gitignore
release:
	rm -f tinybloodcells.love
	zip -r tinybloodcells.love .

run:
	love .

watch:
	find -name '*.lua' -or -name '*.frag' | entr -crs 'date; make run; echo exit status $?'
