
uberon.owl:
	curl -L 'http://purl.obolibrary.org/obo/uberon/ext.owl' -o $@

emapa.owl:
	curl -L -O 'http://purl.obolibrary.org/obo/emapa.owl'

ontology.ofn: uberon.owl emapa.owl mouse_structure.ofn
	robot merge -i uberon.owl -i emapa.owl -i mouse_structure.ofn -o ontology.ofn

xrefs.tsv: uberon.owl xrefs.rq
	robot query -i $< -f TSV -q xrefs.rq $@.tmp &&\
	tail -n +2 $@.tmp \
	| sed 's/^<http:\/\/purl.obolibrary.org\/obo\/UBERON_/UBERON:/' \
	| sed 's/>//' \
	| sed 's/"//g' \
	| sort -u >$@.tmp2 &&\
	rm $@.tmp && mv $@.tmp2 $@

uberon_terms.tsv: xrefs.tsv
	echo 'defined_class	term' >$@.tmp
	cut -f 1 $< | sed -E 's/(.*)/\1-mouse\t\1/' >>$@.tmp && mv $@.tmp $@

mouse_structure.ofn: uberon.owl uberon_terms.tsv mouse_structure.yaml
	dosdp-tools generate --obo-prefixes=true --ontology=uberon.owl --outfile=$@ --template=mouse_structure.yaml --infile=uberon_terms.tsv

probs.tsv: xrefs.tsv
	sed -E 's/(UBERON:[0-9]+)/\1-mouse/' <$< \
	| sed 's/$$/	0.10	0.09	0.80	0.01/' >$@

uberon-emapa: probs.tsv ontology.ofn
	rm -rf $@ &&\
	boomer --ptable probs.tsv --ontology ontology.ofn --window-count 1 --runs 500 --prefixes prefixes.yaml --output $@ --exhaustive-search-limit 14 --restrict-output-to-prefixes=UBERON --restrict-output-to-prefixes=EMAPA

JSONS=$(wildcard uberon-emapa/*.json)
PNGS=$(patsubst %.json, %.png, $(JSONS))

uberon-emapa/%.json: uberon-emapa

%.dot: %.json
	og2dot.js -s uberon-emapa-style.json $< >$@

%.png: %.dot
	dot $< -Tpng -Grankdir=BT >$@

pngs: $(PNGS)
