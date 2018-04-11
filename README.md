This is a simple lottery which runs on the Ethereum network. Your address is
your bid. You get paid if and only if someone else makes a bid after, but not
more than 256 blocks after, your bid was mined, *and* the block hash ends with
the same byte that your address does.

# Testing
- `make setup` to create private blockchain and 2 test accounts
- `make jclottery.test` to create the contract and drop you into the console.
   Once you are at the `>` prompt, you can:
 + `buyTickets(3)` to make 3 attempts to win the lottery
 + `buyTickets(0)` to keep buying until one ticket wins
 + `buyTickets(-1)` to keep buying until all lotteries specified by the
   contract have finished and it has selfdestructed.
