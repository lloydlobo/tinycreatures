# zip -r src/tinybloodcells.love src -x@.gitignore
release:
	rm -f tinybloodcells.love
	zip -r tinybloodcells.love .

run:
	love .

watch:
	find -name '*.lua' | entr -crs 'date; make run; echo exit status $?'