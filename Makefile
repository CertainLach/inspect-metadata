PHONY: quartz-metadata
quartz-metadata:
	chainql -e "cql.chain('wss://eu-ws-quartz.unique.network:443').latest._meta" > metadata.json

metadata.json:
	chainql -e "cql.chain('wss://eu-ws-quartz.unique.network:443').latest._meta" > metadata.json
js-codegen/lookup.ts: metadata.json
	chainql js-codegen/genCoder.jsonnet -S > $@
