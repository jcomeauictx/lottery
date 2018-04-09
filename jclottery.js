if (typeof(jclottery) == "undefined") {
  console.warn("should use `make jclottery.test`")
  require("debug.js")
  require("/tmp/jclottery.abi")
  require("/tmp/jclottery.bin")
}
function buyTickets(number) {
  /* buy tickets until there's a winner (number == 0)
   * or until lottery has self-destructed (number == -1)
   * or until given number has been bought (number > 0)
   * should be a winner every 256 tries on average even with the same account
   * buying all tickets, assuming each purchased is mined in its own block.
   * more unique addresses should mean more wins.
   */
  var attempt = 0
  var account = 0  // switch between two accounts for testing
  var completed = jclottery.lotteriesCompleted()
  var txhash, receipt, txstatus, price
  console.log("NOTE! mining first purchase often takes a very long time!")
  console.log("don't freak out, take a coffee break and come back.")
  while (true) {
    price = 1000000 + (20000 * jclottery.totalEntries())
    console.log("buying ticket", attempt, "from", eth.accounts[account])
    txhash = jclottery.ticket.sendTransaction({
      value: jclottery.ticketPrice(),
      from: eth.accounts[account],
      gas: price
    })
    mine(1)
    receipt = eth.getTransactionReceipt(txhash)
    txstatus = debug.traceTransaction(txhash)
    if (receipt.cumulativeGasUsed == price) {
      console.error("problem purchasing ticket:")
      if (txstatus.structLogs != undefined) {
        console.error("final low-level statement:", JSON.stringify(
          txstatus.structLogs[txstatus.structLogs.length - 1]))
      }
      console.error("receipt:", JSON.stringify(receipt))
      break
    } else {
      console.log("cumulative gas used:", receipt.cumulativeGasUsed)
    }
    console.log("currentBlock:", jclottery.currentBlock())
    console.log("lastBlockhash:", jclottery.lastBlockhash())
    console.log("eth.accounts[0] balance:", eth.getBalance(eth.accounts[0]))
    console.log("eth.accounts[1] balance:", eth.getBalance(eth.accounts[1]))
    console.log("lottery jackpot:", jclottery.jackpot())
    console.log("lottery balance:", eth.getBalance(jclottery.address))
    attempt++
    account = (account + 1) % 2
    if (jclottery.lotteriesCompleted() > completed) {
      console.log("winning block:", jclottery.lastBlockhash())
      completed = jclottery.lotteriesCompleted()
      if (number >= 0) break
    } else if (jclottery.lotteriesCompleted() < completed) {
      console.log("lottery has apparently selfdestructed")
      break
    } else if (number > 0 && attempt == number) break
  }
}
console.log("jclottery.transactionHash:", jclottery.transactionHash)
console.log("jclottery.address:", jclottery.address)
while (jclottery.address == undefined) {
  var receipt = eth.getTransactionReceipt(jclottery.transactionHash)
  if (receipt && receipt.contractAddress) {
    var contract = eth.contract(jclottery.abi)
    jclottery = contract.at(receipt.contractAddress)
  } else {
    admin.sleep(0.1)
  }
}
topoff()
console.log("jclottery.address:", jclottery.address)
if (jclottery.address == undefined) {
  console.error("failed instantiating lottery contract")
} else {
  console.log("unlocking accounts so we can buy tickets")
  personal.unlockAccount(eth.accounts[0], null, 1000000)
  personal.unlockAccount(eth.accounts[1], null, 1000000)
  var events = jclottery.allEvents("pending")
  events.watch(function(error, result) {
    console.log(
      "EVENT from allEvents:",
      result.args != undefined ?
        readable(result.args.message) :
        JSON.stringify(result)
    )
  })
  console.log("sending a donation to the unnamed acceptor function")
  eth.sendTransaction({
    from: eth.accounts[0],
    to: jclottery.address,
    value: web3.toWei(.0111, "ether"),
    gas: 500000
  })
  console.log("test transaction which should produce an event log")
  jclottery.testEvent.sendTransaction({from: eth.accounts[0], gas: 500000})
  buyTickets(0)  // buy tickets until lottery is won, or error
  events.stopWatching()
}
/* vim: set tabstop=2 expandtab shiftwidth=2 softtabstop=2: */
