var mine = function(blocks, threads) {
  threads = threads || 4
  alreadyMining = eth.mining
  if (!alreadyMining) miner.start(threads)
  admin.sleepBlocks(blocks)
  if (!alreadyMining) miner.stop()
}
var logs = function(contract, startBlock) {
  startBlock = startBlock || (contract ? eth.getTransactionReceipt(
    contract.transactionHash).blockNumber : 0)
  console.debug(
    "getting logs for contract", contract.address, "from block", startBlock
  )
  var filter = eth.filter({address: contract.address, fromBlock: startBlock})
  return filter.get()
}
var logdata = function(contract, startBlock) {
  return logs(contract, startBlock).map(
    function(s) {return s.data}
  )
}
var logstrings = function(contract, startBlock) {
  return logs(contract, startBlock).map(
    function(s) {return readable(s.data)}
  )
}
var nulltrim = function(string) {
  return string.replace(/^[\s\x00]+|[\s\x00]+$/g, "")
}
var readable = function(hexstring) {
  return nulltrim(web3.toAscii(hexstring)) + " (" + hexstring + ")"
}
var sum = function(amounts) {
  return parseFloat(amounts[0]) + parseFloat(amounts[1])
}
var difference = function(amounts) {
  return parseFloat(amounts[0]) - parseFloat(amounts[1])
}
var onHand = function(balances, amount) {
  // ensure that sum of two balances has a certain value
  var total = sum(balances)
  console.debug("checking balance " + total + " >= " + amount)
  return total >= parseFloat(amount)
}
var topoff = function() {
  // make sure top 2 accounts have at least 5ETH each
  // FIXME: find out gas price and make this precise
  var amount;
  console.log("starting topoff")
  while (!onHand(
      [eth.getBalance(eth.accounts[0]), eth.getBalance(eth.accounts[1])],
      web3.toWei(10.2, "ether"))) {
    console.log("eth.accounts[0] balance", eth.getBalance(eth.accounts[0]))
    console.log("eth.accounts[1] balance", eth.getBalance(eth.accounts[1]))
    console.log("mining 10 blocks")
    mine(10)
  }
  console.debug("splitting the proceeds")
  console.log("eth.accounts[0] balance", eth.getBalance(eth.accounts[0]))
  console.log("eth.accounts[1] balance", eth.getBalance(eth.accounts[1]))
  personal.unlockAccount(eth.accounts[0])
  personal.unlockAccount(eth.accounts[1])
  if (onHand(
      [eth.getBalance(eth.accounts[1]), 0],
      web3.toWei(5.1, "ether"))) {
    console.log("unnecessarily large amount in eth.accounts[1]")
    amount = difference(
      [eth.getBalance(eth.accounts[1]), web3.toWei(5.1, "ether")]
    )
    if (amount > 0) {
      console.log("moving", amount, "from eth.accounts[1] to eth.accounts[0]")
      eth.sendTransaction({
        from: eth.accounts[1],
        to: eth.accounts[0],
        value: amount,
        gas: 50000
      })
    }
  } else {
    console.log("we need more in eth.accounts[1]")
    amount = difference(
      [web3.toWei(5.1, "ether"), eth.getBalance(eth.accounts[1])]
    )
    console.log("moving " + amount + " from eth.accounts[0] to eth.accounts[1]")
    eth.sendTransaction({
      from: eth.accounts[0],
      to: eth.accounts[1],
      value: amount,
      gas: 50000
    })
  }
  mine(1)
  console.log("eth.accounts[0] balance", eth.getBalance(eth.accounts[0]))
  console.log("eth.accounts[1] balance", eth.getBalance(eth.accounts[1]))
}
console.log("TOPOFF:", typeof(TOPOFF))
if (typeof(TOPOFF) != "undefined" && TOPOFF) topoff()
