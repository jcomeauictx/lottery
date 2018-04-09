# allow for bashisms
SHELL := /bin/bash
GAS ?= 1000000
TESTDIR ?= ~/.ethtest0
TESTNET ?= $(shell date +%s)
GETHTEST := geth --datadir $(TESTDIR) --networkid $(TESTNET) --maxpeers 0
# for converting space-separated list to comma-separated
COMMA := ,
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
# change the gas by e.g. `make GAS=500000 /tmp/simple.bin`
default: lottery.test
%.test: debug.js /tmp/%.abi /tmp/%.bin %.js
	$(GETHTEST) --preload $(subst $(SPACE),$(COMMA),$+) console
setup:
	rm -rf $(TESTDIR)
	mkdir $(TESTDIR)
	# make 2 accounts to begin with
	$(GETHTEST) account new
	$(GETHTEST) account new
	$(GETHTEST) init genesis.json
	# process substitution lets us set TOPOFF variable
	$(GETHTEST) js <(echo var TOPOFF = true) debug.js
account:
	$(GETHTEST) account new
run: debug.js
	$(GETHTEST) --preload $< console
/tmp/%.abi: %.sol
	solc --output-dir $(@D) --overwrite --abi $<
	program=$$(awk '$$1 ~ /^contract$$/ {print $$2}' $<) && \
	 echo -n "var $(notdir $*)Contract = eth.contract(" > $@ && \
	 cat $(@D)/$$program.abi >> $@ && \
	 echo ")" >> $@
/tmp/%.bin: %.sol
	solc --output-dir $(@D) --overwrite --bin $<
	program=$$(awk '$$1 ~ /^contract$$/ {print $$2}' $<) && \
	 echo "personal.unlockAccount(eth.accounts[0])" > $@ && \
	 echo -n "var $* = $*Contract.new({from: eth.accounts[0]" >> $@ && \
	 echo -n ', data: "0x' >> $@ && \
	 cat $(@D)/$$program.bin >> $@ && \
	 echo '", gas: $(GAS)})' >> $@ && \
	 echo "mine(1)" >> $@
sync:
	# quickest way to sync live blockchain
	# https://ethereum.stackexchange.com/questions/392/
	#  how-can-i-get-a-geth-node-to-download-the-blockchain-quickly
	geth --fast --cache=512
argstest:
	$(GETHTEST) --preload \
	 <(echo args = [5, 6]),<(echo 'console.log(args[0] + args[1])') \
	 console
%.interact: %.sol
	# get original version of contract and interact with it on mainnet
	revno=$$(bzr log $< | \
	 awk '$$1 ~ /^revno:$$/ {print $$2}' | tail -n 1); \
	bzr cat -r$$revno $< > /tmp/original.$<
	$(MAKE) /tmp/original.$(<:.sol=.abi)
